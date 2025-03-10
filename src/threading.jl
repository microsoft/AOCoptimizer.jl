#=
threading.jl

Support for CPU multi-threading programming
=#

"""
Cancellation tokens can be used to enable the caller
of a task to cancel the task execution
"""
CancellationToken = Threads.Atomic{Bool}

"""
    create_cancellation_token()

Create a cancellation token.
"""
function create_cancellation_token()::CancellationToken
    return CancellationToken()
end

"""
    is_cancelled(ctx)

Checks whether cancellation token `ctx` has been cancelled
"""
function is_cancelled(ctx::CancellationToken)::Bool
    return ctx.value
end

"""
    cancel!(ctx)

Send a cancellation message using cancellation token `ctx`.
"""
function cancel!(ctx::CancellationToken)
    Threads.atomic_xchg!(ctx, true)
    return
end
