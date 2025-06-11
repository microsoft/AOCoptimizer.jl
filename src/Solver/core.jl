#=
core.jl

Implementation of the core solver.

=#

macro make_solver(name, exploration)
    name_internal = Symbol("_run_", exploration)

    return quote
        @inline function $(esc(name_internal))(
            ::CPU,
            problem::Problem{T},
            setup::Setup{T},
            batch_size::Integer,
            rng::AbstractRNG,
            parameters,
        ) where {T<:Real}
            run_for(
                ctx -> $(esc(exploration))(
                    problem,
                    setup,
                    batch_size,
                    ctx,
                    parameters.Iterations,
                    parameters.Samples,
                    rng,
                ),
                Second(ceil(parameters.TimeBudget));
                threads = _MAX_NUMBER_OF_CPU_THREADS(),
            )
        end # function

        @inline function $(esc(name_internal))(
            ::GPU,
            problem::Problem{T},
            setup::Setup{T},
            batch_size::Integer,
            rng::AbstractRNG,
            parameters,
        ) where {T<:Real}
            run_for(
                ctx -> $(esc(exploration))(
                    problem,
                    setup,
                    batch_size,
                    ctx,
                    parameters.Iterations,
                    parameters.Samples,
                    rng,
                ),
                Second(ceil(parameters.TimeBudget));
                threads = 1,
            )
        end # function

        function $(esc(name))(
            T::DataType,
            interactions::AbstractMatrix{TInput},
            field::Union{Nothing,AbstractVector{TInput}},
            binary::Integer,
            timeout::Second;
            rng::AbstractRNG = Random.GLOBAL_RNG,
            backend::Backend = DefaultBackEnd(),
            annealing::ClosedInterval = ClosedInterval(0.01, 1.0),
            gradient::ClosedInterval = ClosedInterval(0.01, 1.0),
            momentum::ClosedInterval = ClosedInterval(0.95, 0.99),
            deep_search_iterations::ClosedInterval = ClosedInterval(500, 20000),
            dt::Real = 0.5,
            phase_1_fraction::Real = 0.1,
            phase_2_fraction::Real = 0.2,
        ) where {TInput<:Real}
            @assert timeout > zero(Second)
            @assert T <: Real
            n, m = size(interactions)
            @assert n == m
            @assert binary <= n
            @assert binary >= 0
            @assert all(diag(interactions)[1:binary] .== zero(TInput))
            @assert issymmetric(interactions)
            @assert field === nothing || length(field) == n
            @assert annealing.left >= 0.0
            @assert gradient.left > 0.0
            @assert momentum.left >= 0.0
            @assert momentum.right < 1.0
            @assert phase_1_fraction > 0.0
            @assert phase_1_fraction < 1.0
            @assert phase_2_fraction > 0.0
            @assert phase_2_fraction < 1.0
            @assert phase_1_fraction + phase_2_fraction < 1.0
            @assert dt > 0.0

            @debug "Starting solution"

            dt = T(dt)

            runtime = TRuntimeInfo()
            runtime[:phase_1] = TRuntimeInfo()
            runtime[:phase_2] = TRuntimeInfo()
            runtime[:deep_search] = TRuntimeInfo()

            runtime[:engine] = (backend = string(backend), T = T)

            runtime[:parameter_regions] = (; annealing, gradient, momentum)

            runtime[:dt] = dt
            runtime[:timing] = (; timeout, phase_1_fraction, phase_2_fraction)

            runtime[:start] = now()

            # Timeout is in seconds
            timeout = 1.0 * timeout.value

            exploration_1 = _exploration_resources_allocation(n, timeout, phase_1_fraction)
            exploration_2 = _exploration_resources_allocation_extra(n, timeout, phase_2_fraction)

            λ = _calculate_normalization_factor(interactions)
            @debug "Computed normalization factor" λ

            problem = make_problem(T, interactions, field, binary)
            problem = adapt(backend, problem)

            configuration = ConfigurationSpace{T}(annealing, gradient, momentum)
            annealing, gradient, momentum =
                sample_configuration_space(_NUMBER_OF_PARAMETERS_TO_SEARCH, configuration)
            @. annealing = annealing / gradient
            @. gradient = 1.0 / (gradient * λ)

            @debug "Computed configuration parameters"

            annealing = adapt(backend, copy(annealing))
            gradient = adapt(backend, gradient)
            momentum = adapt(backend, momentum)

            batch_size = _optimal_batch_size(backend, problem)

            #
            # First phase
            #

            seed = rand(rng, 1:1_000_000)
            p1rng = Random.default_rng(seed)
            runtime[:phase_1][:seed] = seed

            @debug "Starting phase 1" seed

            initial_setup = make_setup(annealing, gradient, momentum, dt, 1)

            phase_1_info = phase_start()
            phase_1_result = $(esc(name_internal))(
                backend,
                problem,
                initial_setup,
                batch_size,
                p1rng,
                exploration_1,
            )
            phase_end!(phase_1_info)

            @assert phase_1_result !== nothing
            @assert all(x -> x !== nothing, phase_1_result) "Some of the results came back as nothing, Results=\n$phase_1_result\n"

            phase_1_statistics = vec(mean(phase_1_result[1].Measurements; dims = 1))
            phase_1_ordering = sortperm(phase_1_statistics)

            #
            # Second phase
            #

            second_setup = reorder(initial_setup, phase_1_ordering)
            seed = rand(rng, 1:1_000_000)
            p2rng = Random.default_rng(seed)
            runtime[:phase_2][:seed] = seed

            @debug "Starting phase 2" seed

            phase_2_info = phase_start()
            phase_2_result =
                $(esc(name_internal))(backend, problem, second_setup, batch_size, p2rng, exploration_2)
            phase_end!(phase_2_info)

            @assert phase_2_result !== nothing
            @assert all(x -> x !== nothing, phase_2_result) "Some of the results came back as nothing."

            phase_2_statistics = vec(mean(phase_2_result[1].Measurements; dims = 1))
            phase_2_ordering = sortperm(phase_2_statistics)

            #
            # Deep search
            #

            seed = rand(rng, 1:1_000_000)
            seed_iterations = rand(rng, 1:1_000_000)
            p3rng = Random.default_rng(seed)
            iteration_chooser = Random.default_rng(seed_iterations)
            runtime[:deep_search][:seed] = seed
            runtime[:deep_search][:seed_iterations] = seed_iterations

            third_setup = reorder(second_setup, phase_2_ordering)
            if length(third_setup) > exploration_2.PointsToSave
                third_setup = adapt(backend, third_setup[1:exploration_2.PointsToSave])
            else
                third_setup = adapt(backend, third_setup)
            end

            remaining_time = timeout - (now() - runtime[:start]).value / 1000.0

            #= Estimate the number of iterations to use:
            The number of iterations determines the time it takes to complete the operation.
            All samples will complete the number of iterations, hence, miscalculating the number of iterations
            will increase the execution time, often far beyond the timeout value.
            Hence, we first estimate the number of iterations that can be executed in the remaining time.
            If it is less than the number of iterations requested, we adjust the request.
            Even if there are no resources, we will at least run the same number of iterations as the second phase,
            if there is any time left.
            Observe that it is ok to have a negative remaining time, since later on we will not run
            the deep stage.
            =#
            minimum_number_of_iterations = deep_search_iterations.left
            maximum_number_of_iterations = deep_search_iterations.right
            phase_2_elapsed_time = _elapsed(phase_2_info)
            estimate_iterations_per_sec = 1000.0 * exploration_2.Iterations / phase_2_elapsed_time.value

            #=
            It is possible that the required number of iterations (even the minimum)
            may be too large to fit in the remaining time. In that case, we need
            to adjust the bounds requested by the caller. Since, our estimate of the
            rate of iterations may be wrong (and it seems that we underestimate), we
            adjust the computation below by a factor of 4 that seems to work ok
            in practice.

            TODO: Improve the estimate of the rate of iterations
            =#
            max_possible_iterations = 4*ceil(Int, remaining_time * estimate_iterations_per_sec)

            maximum_number_of_iterations = max(min(maximum_number_of_iterations, exploration_2.Iterations), min(maximum_number_of_iterations, max_possible_iterations))
            minimum_number_of_iterations = max(min(minimum_number_of_iterations, exploration_2.Iterations), min(minimum_number_of_iterations, max_possible_iterations))
            @debug "Iters/sec: $estimate_iterations_per_sec; adjusted iters: $minimum_number_of_iterations - $maximum_number_of_iterations"

            if minimum_number_of_iterations == maximum_number_of_iterations
                @warn "The number of iterations will be: $minimum_number_of_iterations (instead of in the range $(deep_search_iterations.left)…$(deep_search_iterations.right))"
                @warn phase_2_elapsed_time, estimate_iterations_per_sec, max_possible_iterations
            elseif minimum_number_of_iterations != deep_search_iterations.left || maximum_number_of_iterations != deep_search_iterations.right
                @warn "Range of iterations adjusted from $(deep_search_iterations.left)…$(deep_search_iterations.right) to $minimum_number_of_iterations…$maximum_number_of_iterations"
            end

            iteration_number_chooser = let
                d = DiscreteUniform(minimum_number_of_iterations, maximum_number_of_iterations)
                f() = rand(iteration_chooser, d)
                f
            end


            @debug "Starting deep search" seed seed_iterations remaining_time

            #=
            No matter what, we want to run the sampler at least once
            in the deep search phase. We may run in this situation,
            if the timeout specified by the caller is too small,
            or we have made poor choices in the allocation of time
            for the first two phases (most likely, because of miscalculating
            the capabilities of the backend).
            =#
            if remaining_time <= 0.0
                remaining_time = 1.0
            end

            #=
            To avoid violating the timeout, we continuously estimate the rate
            of iterations for the problem. We use that to estimate the time
            that will take for the next set of experiments, and it that is deemed
            to be much larger than the remaining time, we stop the search.
            Observe that we still run at least one iteration.
            =#
            estimated_loop_time_per_iteration = nothing

            results = []
            iterations = []
            deep_search_info = phase_start()
            while remaining_time > 0.0
                @debug "Starting new iteration" remaining_time

                number_of_iterations = iteration_number_chooser()
                @assert number_of_iterations > 0 "The number of iterations must be positive, got $number_of_iterations"
                if estimated_loop_time_per_iteration !== nothing
                    estimated_loop_time = estimated_loop_time_per_iteration * number_of_iterations
                    if remaining_time < 0.5 * estimated_loop_time
                        break
                    end
                end

                start_time = now()

                parameters = (
                    Samples = cld(batch_size, length(third_setup)),
                    Iterations=number_of_iterations,
                    TimeBudget = remaining_time,
                )
                result = $(esc(name_internal))(
                    backend, problem, third_setup, batch_size, p3rng, parameters)
                diff_time = (now() - start_time).value / 1000.0

                loop_time_per_iteration = diff_time / number_of_iterations
                if estimated_loop_time_per_iteration === nothing
                    estimated_loop_time_per_iteration = loop_time_per_iteration
                else
                    estimated_loop_time_per_iteration = 0.5 * estimated_loop_time_per_iteration + 0.5 * loop_time_per_iteration
                end

                append!(results, result)
                append!(iterations, parameters.Iterations)
                remaining_time -= diff_time
            end
            phase_end!(deep_search_info)

            #
            # Wrap-up
            #

            runtime[:stop] = now()
            runtime[:duration] = runtime[:stop] - runtime[:start]

            KernelAbstractions.synchronize(backend)

            phase_1_overview = PhaseStatistics(phase_1_info, initial_setup, phase_1_result, [exploration_1.Iterations])
            phase_2_overview = PhaseStatistics(phase_2_info, second_setup, phase_2_result, [exploration_2.Iterations])
            deep_search_overview = PhaseStatistics(deep_search_info, third_setup, results, iterations)

            runtime[:phase_1] = adapt(CPU(), phase_1_overview)
            runtime[:phase_2] = adapt(CPU(), phase_2_overview)
            runtime[:deep_search] = adapt(CPU(), deep_search_overview)

            runtime[:eigenvalue_lr] = λ

            return runtime
        end # function

        @inline function $(esc(name))(
            T::DataType,
            interactions::AbstractMatrix{TInput},
            timeout::Second;
            kwargs...,
        ) where {TInput<:Real}
            $(esc(name))(
                T, interactions, nothing, size(interactions, 1), timeout;
                kwargs...)
        end

        @inline function $(esc(name))(
            T::DataType,
            interactions::AbstractMatrix{TInput},
            field::AbstractVector{TInput},
            timeout::Second;
            kwargs...,
        ) where {TInput<:Real}
            $(esc(name))(
                T, interactions, field, size(interactions, 1), timeout;
                kwargs...)
        end

    end # quote
end # macro

"""
    solve(
        T::DataType,
        interactions::AbstractMatrix{TInput},
        field::Union{Nothing,AbstractVector{TInput}},
        binary::Integer,
        timeout::Second;
        rng::AbstractRNG = Random.GLOBAL_RNG,
        backend::Backend = DefaultBackEnd(),
        annealing = ClosedInterval(0.01, 1.0),
        gradient = ClosedInterval(0.01, 1.0),
        momentum = ClosedInterval(0.95, 0.99),
        deep_search_iterations = ClosedInterval(500, 20000),
        dt::Real = 0.5,
        phase_1_fraction::Real = 0.1,
        phase_2_fraction::Real = 0.2,
    )

    solve(
        T::DataType,
        interactions::AbstractMatrix{TInput},
        timeout::Second;
        rng::AbstractRNG = Random.GLOBAL_RNG,
        backend::Backend = DefaultBackEnd(),
        annealing = ClosedInterval(0.01, 1.0),
        gradient = ClosedInterval(0.01, 1.0),
        momentum = ClosedInterval(0.95, 0.99),
        deep_search_iterations = ClosedInterval(500, 20000),
        dt::Real = 0.5,
        phase_1_fraction::Real = 0.1,
        phase_2_fraction::Real = 0.2,
    )

Invokes the AOC solver on a mixed-Ising problem, described
by the `interactions` matrix and the `field` vector (if provided).
The computation is performed with the `T` primitive type (e.g., `Float32`,
`Float64`, `Float16`). The first `binary` variables in the `interactions`
matrix and in the `field` vector are treated as binary variables. The first
`binary` diagonal elements of the `interactions` matrix must be zero.
The `interactions` matrix must be symmetric.

The computation will be performed in the `backend` backend, which can
be `CPU`, `CUDABackend`, etc.

The solver will run for `timeout` seconds. That time is divided into three phases:
- Phase 1: Exploration of the configuration space with a limited number of iterations;
  this phase will take `phase_1_fraction` of the total time.
- Phase 2: Exploration of the configuration space with a larger number of iterations;
  this phase will take `phase_2_fraction` of the total time.
- Deep search: A deep search phase, which will run for the remaining time. The number
  of iterations in this phases is chosen with the `deep_search_iterations` parameter.
  The number of iterations may be adjusted based on the capabilities of the `backend`.

The configuration space is sampled from the intervals specified in the
`annealing`, `gradient`, and `momentum` parameters.

The `dt` parameter specifies the time step for the simulation.
"""
function solve end

"""
    solve_binary(
        T::DataType,
        interactions::AbstractMatrix{TInput},
        field::Union{Nothing,AbstractVector{TInput}},
        binary::Integer,
        timeout::Second;
        rng::AbstractRNG = Random.GLOBAL_RNG,
        backend::Backend = DefaultBackEnd(),
        annealing = ClosedInterval(0.01, 1.0),
        gradient = ClosedInterval(0.01, 1.0),
        momentum = ClosedInterval(0.95, 0.99),
        deep_search_iterations = ClosedInterval(500, 20000),
        dt::Real = 0.5,
        phase_1_fraction::Real = 0.1,
        phase_2_fraction::Real = 0.2,
    )

    solve_binary(
        T::DataType,
        interactions::AbstractMatrix{TInput},
        timeout::Second;
        rng::AbstractRNG = Random.GLOBAL_RNG,
        backend::Backend = DefaultBackEnd(),
        annealing = ClosedInterval(0.01, 1.0),
        gradient = ClosedInterval(0.01, 1.0),
        momentum = ClosedInterval(0.95, 0.99),
        deep_search_iterations = ClosedInterval(500, 20000),
        dt::Real = 0.5,
        phase_1_fraction::Real = 0.1,
        phase_2_fraction::Real = 0.2,
    )

Invokes the AOC solver on a problem where the binary variables are
either 0 or 1, and the continuous in the range `[0, 1]`. The problem is described
by the `interactions` matrix and the `field` vector (if provided).
The computation is performed with the `T` primitive type (e.g., `Float32`,
`Float64`, `Float16`). The first `binary` variables in the `interactions`
matrix and in the `field` vector are treated as binary variables. The first
`binary` diagonal elements of the `interactions` matrix must be zero.
The `interactions` matrix must be symmetric.

The computation will be performed in the `backend` backend, which can
be `CPU`, `CUDABackend`, etc.

The solver will run for `timeout` seconds. That time is divided into three phases:
- Phase 1: Exploration of the configuration space with a limited number of iterations;
  this phase will take `phase_1_fraction` of the total time.
- Phase 2: Exploration of the configuration space with a larger number of iterations;
  this phase will take `phase_2_fraction` of the total time.
- Deep search: A deep search phase, which will run for the remaining time. The number
  of iterations in this phases is chosen with the `deep_search_iterations` parameter.
  The number of iterations may be adjusted based on the capabilities of the `backend`.

The configuration space is sampled from the intervals specified in the
`annealing`, `gradient`, and `momentum` parameters.

The `dt` parameter specifies the time step for the simulation.
"""
function solve_binary end

"""
    solve_qumo(
        T::DataType,
        interactions::AbstractMatrix{TInput},
        field::Union{Nothing,AbstractVector{TInput}},
        binary::Integer,
        timeout::Second;
        rng::AbstractRNG = Random.GLOBAL_RNG,
        backend::Backend = DefaultBackEnd(),
        annealing = ClosedInterval(0.01, 1.0),
        gradient = ClosedInterval(0.01, 1.0),
        momentum = ClosedInterval(0.95, 0.99),
        deep_search_iterations = ClosedInterval(500, 20000),
        dt::Real = 0.5,
        phase_1_fraction::Real = 0.1,
        phase_2_fraction::Real = 0.2,
    )

    solve_qumo(
        T::DataType,
        interactions::AbstractMatrix{TInput},
        timeout::Second;
        rng::AbstractRNG = Random.GLOBAL_RNG,
        backend::Backend = DefaultBackEnd(),
        annealing = ClosedInterval(0.01, 1.0),
        gradient = ClosedInterval(0.01, 1.0),
        momentum = ClosedInterval(0.95, 0.99),
        deep_search_iterations = ClosedInterval(500, 20000),
        dt::Real = 0.5,
        phase_1_fraction::Real = 0.1,
        phase_2_fraction::Real = 0.2,
    )

Invokes the AOC solver on a mixed-Ising problem, described
by the `interactions` matrix and the `field` vector (if provided).
The computation is performed with the `T` primitive type (e.g., `Float32`,
`Float64`, `Float16`). The first `binary` variables in the `interactions`
matrix and in the `field` vector are treated as binary variables. The first
`binary` diagonal elements of the `interactions` matrix must be zero.
The `interactions` matrix must be symmetric.

The computation will be performed in the `backend` backend, which can
be `CPU`, `CUDABackend`, etc.

The solver will run for `timeout` seconds. That time is divided into three phases:
- Phase 1: Exploration of the configuration space with a limited number of iterations;
  this phase will take `phase_1_fraction` of the total time.
- Phase 2: Exploration of the configuration space with a larger number of iterations;
  this phase will take `phase_2_fraction` of the total time.
- Deep search: A deep search phase, which will run for the remaining time. The number
  of iterations in this phases is chosen with the `deep_search_iterations` parameter.
  The number of iterations may be adjusted based on the capabilities of the `backend`.

The configuration space is sampled from the intervals specified in the
`annealing`, `gradient`, and `momentum` parameters.

The `dt` parameter specifies the time step for the simulation.
"""
function solve_qumo end

@make_solver(solve, exploration)
@make_solver(solve_binary, exploration_binary)
@make_solver(solve_qumo, exploration_qumo)
