#=
exploration.jl

Implementation of the exploration phases.

=#

const TIterationNumberChooser = Function where {ReturnType<:Integer}

"""
    ExplorationResult{T <: Real, TV <: AbstractVector, TM <: AbstractMatrix}

The result of an exploration phase. It supports the opaque field CollectorAdditionalInfo,
which may be used by the collector to store additional information.
"""
struct ExplorationResult{T<:Real,TV<:AbstractVector{<:Number},TM<:AbstractMatrix{<:Number}}
    Best::Collector.BestFound{T, TV}
    Measurements::TM
    CollectorAdditionalInfo::Union{Nothing, Any}
end

Adapt.@adapt_structure ExplorationResult

"""
    make_exploration(name, sampler, assignment_collector = Collector.BestAssignmentCollector())

Macro to create an exploration function with the given `name` and `sampler`.
The `assignment_collector` is used to specify which samples to collect during the exploration.
By default, it uses `Collector.BestAssignmentCollector()`, which collects the
best assignment found during the exploration.
"""
macro make_exploration(
    name,
    sampler,
    assignment_collector = Collector.BestAssignmentCollector()
)
    return quote
        function $(esc(name))(
            problem::Problem{T,TEval},
            initial_setup::Setup{T},
            batch_size::Integer,
            ctx::CancellationToken,
            iterations::TIterationNumberChooser,
            repetitions::Integer,
            rng::AbstractRNG,
        ) where {T<:Real,TEval<:Real}

            setup = expand(initial_setup, repetitions)
            total_experiments = length(setup.Annealing)
            @assert total_experiments > 1

            workspace = make_workspace(problem, setup, batch_size)
            energies = _similar_vector(
                            problem.InteractionsWide,
                            max(total_experiments, batch_size)
                        )

            assignment = Collector.create(
                            $assignment_collector,
                            problem.Interactions,
                            problem.Size
                        )

            current_setup = make_empty_setup(setup, batch_size)

            initial_spin_sampler = IsingInverseSizeSampler(problem.Size)

            # We need to know whether we are working in the GPU,
            # because we need to synchronize before reading min value
            backend = KernelAbstractions.get_backend(problem.InteractionsWide)

            local_seed = rand(rng, 1:10_000_000)
            local_rng = Random.default_rng(local_seed)

            @debug "Entering exploration loop"

            current = 1
            # dummy assignment to make sure that the variable is valid after the while loop.
            last_index = 0

            try
                # We need to make sure that the loop is entered at least once.
                # Otherwise, the energies reported will be random.
                # This is why if current==1, then the loop must be executed.
                while current < total_experiments && (current == 1 || !is_cancelled(ctx))
                    last_index = min(total_experiments, current + batch_size - 1)

                    @debug "[$(now())] Processing $current to $last_index"

                    batch_energies = @view energies[current:last_index]
                    annealing = @view setup.Annealing[current:last_index]

                    copy_view_to!(current_setup, view(setup, current:last_index))
                    initialize_workspace!(local_rng, workspace, annealing, initial_spin_sampler)

                    number_of_iterations = iterations()
                    delta = make_annealing_delta(current_setup, number_of_iterations)
                    $(esc(sampler))(problem, current_setup, workspace, number_of_iterations, delta)

                    # @debug "[$(now())] Calculating energies for $current to $last_index"
                    calculate_energies!(
                        batch_energies,
                        workspace.spins,
                        problem.InteractionsWide,
                        problem.FieldWide,
                    )
                    # @debug "[$(now())] Finished calculating energies for $current to $last_index"

                    KernelAbstractions.synchronize(backend)

                    # Observe that the workspace.spins is a scratch matrix; the columns that are
                    # valid are those that correspond to the number of experiments, i.e.,
                    # to the length of batch_energies
                    Collector.update!($assignment_collector, assignment, batch_energies, workspace.spins)
                    current += batch_size

                    yield()
                end # while

            catch e
                @error "Error in exploration loop: $e"
                @error "  Stacktrace: $(stacktrace(catch_backtrace()))"
                rethrow()
            end # try

            @debug "Exiting exploration loop"

            completed_measurements = last_index ÷ repetitions
            valid_measurements = completed_measurements * repetitions
            valid_energies = energies[1:valid_measurements]

            KernelAbstractions.synchronize(backend)

            _dispose(workspace)

            Collector.finish($assignment_collector, assignment)
            collected = Collector.retrieve($assignment_collector, assignment)
            info = Collector.info($assignment_collector, assignment)

            @debug "Exiting after collecting $last_index samples (seed $local_seed)"

            return ExplorationResult(collected, reshape(valid_energies, (repetitions, completed_measurements)), info)
        end # function

        function $(esc(name))(
            problem::Problem{T,TEval},
            initial_setup::Setup{T},
            batch_size::Integer,
            ctx::CancellationToken,
            iterations::Integer,
            repetitions::Integer,
            rng::AbstractRNG,
        ) where {T<:Real,TEval<:Real}
            return $(esc(name))(
                problem,
                initial_setup,
                batch_size,
                ctx,
                () -> iterations,
                repetitions,
                rng,
            )
        end # function
    end # quote
end #macro

"""
    exploration(
        problem::Problem{T,TEval},
        initial_setup::Setup{T},
        batch_size::Integer,
        ctx::CancellationToken,
        iterations::Integer,
        repetitions::Integer,
        rng::AbstractRNG
    )
    exploration(
        problem::Problem{T,TEval},
        initial_setup::Setup{T},
        batch_size::Integer,
        ctx::CancellationToken,
        iterations::TIterationNumberChooser,
        repetitions::Integer,
        rng::AbstractRNG
    )
"""
function exploration end

function exploration_binary end

function exploration_qumo end

@make_exploration(exploration, sampler!)
@make_exploration(exploration_binary, sampler_binary!)
@make_exploration(exploration_qumo, sampler_qumo!)
