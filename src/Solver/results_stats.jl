#=
result_stats.jl

Post-processing of the results returned by the solver.
These contain helper functions to find the best solution,
compute various statistics for the performance of the
solver, etc.
=#

function _find_best_from_phase(results::PhaseStatistics, label::AbstractString)
    best = nothing
    assignment = nothing
    annealing = nothing
    gradient = nothing
    momentum = nothing

    for measurement in results.results
        if best === nothing || best > measurement.Best.objective
            best = measurement.Best.objective
            assignment = measurement.Best.assignment

            #=
            In addition to the best objective and the best assignment,
            we also want to extract the configuration parameters that produced that result.
            The following is a bit tricky since we do not store the configuration parameters
            in the search process (avoid overheads). However, we also keep the first best result.
            So, we can infer that the best configuration parameters are the ones that produced
            the first entry in the `Measurements` array that has the minimum objective.
            =#
            id = findmin(measurement.Measurements)[2]
            column = id[2]
            annealing = results.setup.Annealing[column]
            gradient = results.setup.Gradient[column]
            momentum = results.setup.Momentum[column]
        end
    end

    if assignment === nothing
        @error "No best assignment found in the results (best=$best)"
        return nothing
    end
    info = (Annealing=annealing, Gradient=gradient, Momentum=momentum)
    return (Objective = best, Vars = Array(assignment), Info=info, Label=label)
end

"""
    find_best(results)

Find the best result from the results of a run of `solve`.
It returns the best Hamiltonian and the corresponding assignment in the variables.
"""
function find_best(results)
    phase_1 = _find_best_from_phase(results[:phase_1], "phase_1")
    phase_2 = _find_best_from_phase(results[:phase_2], "phase_2")
    deep_search = _find_best_from_phase(results[:deep_search], "deep_search")

    # find the best of the best
    best = nothing
    for phase in (phase_1, phase_2, deep_search)
        if phase === nothing || phase.Objective === nothing
            @warn "Error in evaluating phase; skipping it"
            continue
        end

        if best === nothing || best.Objective > phase.Objective
            best = phase
        end
    end

    return best
end

"""
    search_for_best_configuration(results::ExplorationResult)
    search_for_best_configuration(results::PhaseStatistics)
    search_for_best_configuration(results::TRuntimeInfo)

Searches for the best objective value in the results returned by the solver.
It returns the best objective value, as well as other statistics about the
solution.

CAUTION: Given the different possible inputs, there is variability
in the type of the output. Do *not* take a strong dependency on the
output of this function.
"""
function search_for_best_configuration end

function search_for_best_configuration(results::ExplorationResult)
    number_of_measurements = size(results.Measurements, 1)
    successes = sum(results.Measurements .≈ results.Best.objective; dims = 1)
    index = argmax(successes)[2]
    return (;
        objective    = results.Best.objective,
        success_rate = 1.0 * successes[index] / number_of_measurements,
        index        = index
    )
end

function search_for_best_configuration(results::PhaseStatistics)
    objective = nothing
    success_rate = nothing
    index = nothing

    for result in results.results
        stats = search_for_best_configuration(result)
        if objective === nothing || stats.objective < objective || (stats.objective ≈ objective && stats.success_rate > success_rate)
            objective = stats.objective
            success_rate = stats.success_rate
            index = stats.index
        end
    end

    # TODO: We are computing twice. The problem is that the first attempts outputs all iterations

    # Find the best run out of all runs
    success = reduce(hcat, map(vec, map(x -> sum(x.Measurements .== objective, dims=1) / size(x.Measurements)[1], results.results)) )
    success = success'
    best_run_value, best_run_index = findmax(success)
    best_run = (;
        SuccessRate = best_run_value,
        Annealing = results.setup.Annealing[best_run_index.I[2]],
        Gradient = results.setup.Gradient[best_run_index.I[2]],
        Momentum=results.setup.Momentum[best_run_index.I[2]],
        Iterations=results.iterations[best_run_index.I[1]]
    )

    return (;
        Objective    = objective,
        SuccessRate  = success_rate,
        Annealing    = results.setup.Annealing[index],
        Gradient     = results.setup.Gradient[index],
        Momentum     = results.setup.Momentum[index],
        Iterations   = results.iterations,
        BestRun      = best_run,
    )
end

function search_for_best_configuration(results::TRuntimeInfo)
    phase_1 = search_for_best_configuration(results[:phase_1])
    phase_2 = search_for_best_configuration(results[:phase_2])
    deep_search = search_for_best_configuration(results[:deep_search])

    best_object = nothing
    best_success_rate = nothing
    best_configuration = nothing

    for phase in (phase_1, phase_2, deep_search)
        if phase.Objective === nothing
            continue
        end

        if best_object === nothing || phase.Objective < best_object || (phase.Objective ≈ best_object && phase.SuccessRate > best_success_rate)
            best_object = phase.Objective
            best_success_rate = phase.SuccessRate
            best_configuration = phase
        end
    end

    return (;
        Phase1=phase_1,
        Phase2=phase_2,
        DeepSearch=deep_search,
        Best=best_configuration,
    )
end


"""
    _get_time_to_solution(success_rate, time)

Computes the time to achieve the best seen solution with 99% confidence
"""
function _get_time_to_solution(
    success_rate::AbstractFloat,
    time::AbstractFloat;
    success_rate_target = 0.99
    )
    @assert 0 < success_rate <= 1 "Success rate must be in (0, 1]"
    @assert time > 0 "Time must be positive"
    @assert 0 < success_rate_target < 1 "Success rate target must be in (0, 1)"

    if success_rate >= success_rate_target
        tts = time
    elseif success_rate > 0
        tts = time * log(1.0 - success_rate_target) / log(1.0 - success_rate)
    else
        tts = Inf
    end
    return tts
end

"""
    _get_num_operations_to_solution(success_rate, operations_per_deep_search)

Computes the number of matrix-vector multiplications (i.e., basic
operations) to perform to achieve the best seen solution with 99% confidence.
"""
function _get_num_operations_to_solution(
    success_rate::AbstractFloat,
    operations_per_deep_search::Int;
    success_rate_target = 0.99
)
    @assert 0 < success_rate <= 1 "Success rate must be in (0, 1]"
    @assert operations_per_deep_search > 0 "Number of matrix-vector multiplications must be positive"
    @assert 0 < success_rate_target < 1 "Success rate target must be in (0, 1)"

    if success_rate >= success_rate_target
        effort = operations_per_deep_search
    elseif success_rate > 0
        effort =
            operations_per_deep_search * log(1.0 - success_rate_target) /
            log(1.0 - success_rate)
    else
        effort = Inf
    end
    return effort
end

"""
    get_solver_results_summary(solver_results)

Computes the relevant statistics for the solver results
"""
function get_solver_results_summary(solver_results)
    best = find_best(solver_results)
    obj_best_found = best.Objective

    results = solver_results[:deep_search].results
    iterations = solver_results[:deep_search].iterations

    if length(results) == 0
        #=
        The solver has produced no results in deep-search.
        This can happen is all the time has been used in the first two phases.
        Notice that this will happen if the allocated time is not enough to
        compile the kernels and run the first two phases.
        =#

        @warn "Solver has produced no results in deep-search"
        return nothing
    end
    @assert length(iterations) > 0

    #=
    The length of the iterations vector can be smaller than the length of the
    results vector. This is happening when we run the solver in multiple threads
    (e.g., in the CPU). We make the assumption that the number of threads stays
    the same during the whole run of the solver. Hence, the number of results
    will be a multiple of the number of iterations (i.e., multiplied by the number
    of threads)
    =#

    @assert rem(length(results), length(iterations)) == 0
    threads = fld(length(results), length(iterations))

    counts_total = 0
    num_samples_total = 0
    iterations_total = 0
    for i = 1:length(results)
        measurements = results[i].Measurements
        obj = results[i].Best.objective

        num_configs, num_samples = size(measurements)

        num_samples_total += num_configs * num_samples
        # Here, we need to divide by the number of threads to find the
        # number of iterations per sample
        iterations_total += num_samples * iterations[cld(i, threads)]

        ## number of times the solver reaches the best found objective
        counts = sum(count_min_energy_hits(measurements))
        if obj == obj_best_found
            counts_total += counts
        end
    end

    runtime = solver_results[:deep_search].runtime
    duration = runtime.stop - runtime.start

    time_per_sample = duration.value / num_samples_total

    success_rate = counts_total / num_samples_total
    time_to_solution = _get_time_to_solution(success_rate, time_per_sample)
    num_operations_to_solution = _get_num_operations_to_solution(success_rate, iterations_total)

    return (;
        obj_best_found,
        success_rate,
        num_operations_to_solution,
        time_per_sample,
        time_to_solution,
        iterations_total,
        counts_total,
        num_samples_total,
    )
end