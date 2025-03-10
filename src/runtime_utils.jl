#=
runtime_utils.jl

Utility functions for simplifying common runtime tasks
=#

module RuntimeUtils

using Compat
using Dates
using Base.Threads: Atomic, atomic_xchg!
using AOCoptimizer: CancellationToken, create_cancellation_token, cancel!

export run_for
@compat public run_for, RuntimeException

"""
    RuntimeException

Exception type for runtime errors.
"""
struct RuntimeException <: Exception
    msg::AbstractString
end

function _with_timeout(func::Function, timeout::Real)
    ctx = create_cancellation_token()
    result = Ref{Any}(nothing)

    async_task = @async begin
        # @debug "Starting async task at $(now()) with timeout $timeout"
        result[] = func(ctx)
        # @debug "Async task finished at $(now())"
    end

    status = timedwait(() -> istaskdone(async_task), timeout)

    if status == :timed_out
        @debug "Timeout occurred"
        cancel!(ctx)  # Set the timeout flag for the worker
        wait(async_task)  # Wait for the worker to finish handling the timeout
    end

    if async_task.result !== nothing && isa(async_task.result, Exception)
        @error "Async failed with an exception: $(async_task.result)"
        throw(async_task.result)
    end

    return result[]
end

"""
    run_for(fn, timeout; threads)

Executes function `fn` for `timeout` seconds using `threads` parallel threads.
The function `fn` should accept just one argument, which is a cancellation token;
it can return any value.
Returns the output of all executions.
"""
function run_for(
    fn::Function,
    timeout::TimePeriod;
    threads::Union{Nothing,Integer} = nothing,
)
    if timeout < Second(1)
        @error "Invalid timeout $timeout; aborting operation"
        throw(RuntimeException("Invalid timeout $timeout"))
    end

    # In the solver all timeouts are in seconds
    timeout = convert(Second, timeout)

    if threads === nothing
        if Threads.nthreads() > 3
            threads = Threads.nthreads() - 2
        else
            threads = 1
        end
    end
    if threads < 1
        @warn "Invalid value for threads ($threads); will set to 1"
        threads = 1
    end

    @debug "Will use $threads threads for a timeout of $timeout seconds"

    tasks = [Threads.@spawn _with_timeout(fn, timeout.value) for _ = 1:threads]
    results = fetch.(tasks)

    return results
end

end
