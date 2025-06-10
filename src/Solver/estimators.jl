#=
estimators.jl

Implements heuristics to estimate how much time to allocate
for each phase of the solver and how many resources to use.

The decisions made below are based on limited experience
and may not be optimal for all problems and hardware configurations.
We need to collect more data to improve the heuristics.
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

"""
    _optimal_batch_size(backend::Backend, problem::Problem)::Integer
    _optimal_batch_size(problem::Problem)::Integer

Internal method to compute the optimal batch size when solving a problem.
"""
function _optimal_batch_size end

#=
TODO: Improve heuristics for computing optimal batch size.

The performance of the solver depends on the batch size used by the solver.
We need to find the optimal batch size to make full use of the available resources,
i.e., use all available memory without putting much pressure on the memory bus.
This depends both on the hardware used, as well as the problem size, and maybe the
problem structure (e.g., use of dense or sparse matrices).

The following heuristics for computing the optimal batch size are
not tested across different hardware. They seem to work well for a number
of problems and a few hardware configurations, but they could use fine-tuning.
In particular, the heuristic for the GPU is based on measurements on a couple
of NVIDIA GPUs.
=#

_optimal_batch_size(::Backend, problem::Problem)::Integer = 100
_optimal_batch_size(::CPU, problem::Problem)::Integer = 100
_optimal_batch_size(::GPU, problem::Problem)::Integer = cld(6.0e7 * problem.Size^(-1.381), 1)
_optimal_batch_size(problem::Problem)::Integer =
    _optimal_batch_size(KernelAbstractions.get_backend(problem), problem)

const _NUMBER_OF_PARAMETERS_TO_SEARCH = 32 * 1024

"""
    _MAX_NUMBER_OF_CPU_THREADS()::Integer

Returns the number of CPU threads to use when running the solver in the CPU.
"""
const _MAX_NUMBER_OF_CPU_THREADS = let
    value = nothing

    #=
    When running the solver in the CPU, we need to figure out how many CPU threads
    to use without overloading the system. The solver uses multi-threading as well
    as SIMD instructions. At the same time, we also need to leave some CPU threads
    idle to be able to run the timer, and to allow the system to run other tasks
    and be responsive.
    The ideal number of CPU threads depends on the architecture of the CPU. We need
    more experience and experimentation to find the best value for each architecture.

    TODO: Identify the best number of CPU threads to use for each architecture.
    =#

    function get_usable_cpu_threads()
        if value === nothing
            value = Integer( max( 1, floor(Threads.nthreads() - 4 ) ) )
        end
        return value
    end
end
