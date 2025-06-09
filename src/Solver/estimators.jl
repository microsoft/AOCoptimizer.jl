#=
estimators.jl

Implements heuristics to estimate how much time to allocate
for each phase of the solver.
=#

function _exploration_resources_allocation(
    graph_size::Integer,
    time_limit::Real,
    fraction_for_exploration::Real,
)
    if (graph_size > 5000) & (time_limit <= 100)
        num_iters = 50
        num_samples = 10
    elseif graph_size < 1000
        # default parameters
        num_iters = 100
        num_samples = 20
    elseif graph_size < 5000
        # default parameters
        num_iters = 200
        num_samples = 20
    elseif graph_size < 10000
        num_iters = 400
        num_samples = 20
    else
        num_iters = 500
        num_samples = 20
    end

    time_budget = time_limit * fraction_for_exploration
    num_points_to_save = 3000

    return (
        Samples = num_samples,
        Iterations = num_iters,
        PointsToSave = num_points_to_save,
        TimeBudget = time_budget,
    )
end

function _exploration_resources_allocation_extra(
    graph_size::Int,
    time_limit::Real,
    fraction_for_exploration_extra::Real,
)
    if (graph_size > 5000) & (time_limit <= 300)
        num_iters = 500
        num_samples = 10
    elseif graph_size < 1000
        # default parameters (are doubled wrt to initial exploration phase)
        num_iters = 100 * 2
        num_samples = 20
    elseif graph_size < 5000
        # default parameters
        num_iters = 200 * 2
        num_samples = 20
    elseif graph_size < 10000
        num_iters = 400 * 2
        num_samples = 20
    else
        num_iters = 500 * 2
        num_samples = 20
    end

    time_budget = time_limit * fraction_for_exploration_extra
    num_points_to_save = 100

    return (
        Samples = num_samples,
        Iterations = num_iters,
        PointsToSave = num_points_to_save,
        TimeBudget = time_budget,
    )
end