#=
sampler_tracer.jl

Extensions to the sampler to allow collecting the dynamics of the sampler.

=#

module SamplerTracer

"""
    Periodic{TM<:AbstractArray{<:Real,3}}

A tracer that collects the spins at regular intervals.
"""
mutable struct Periodic{TM<:AbstractArray{<:Real,3}}
    index::Int
    const total::Int
    const frequency::Int
    const state::TM

    function Periodic(spins::AbstractMatrix, samples::Int, frequency::Int)
        @assert frequency > 0
        state = similar(spins, size(spins, 1), size(spins, 2), samples)
        _TM = typeof(state)
        return new{_TM}(1, samples, frequency, state)
    end
end

"""
    SamplerWithPlan{TM<:AbstractArray{<:Real,3}}

A tracer that collects the spins at specific iterations, explicitly
provided by the user. These sampling points are typically related
to the number of iterations that we expect the sampler to run for.
"""
mutable struct SamplerWithPlan{TM<:AbstractArray{<:Real,3}}
    array_index::Int
    plan_index::Int
    const total::Int
    const plan::AbstractVector{Int}
    const state::TM

    function SamplerWithPlan(spins::AbstractMatrix, plan::AbstractVector{Int})
        @assert length(plan) > 0
        state = similar(spins, size(spins, 1), size(spins, 2), length(plan))
        _TM = typeof(state)
        return new{_TM}(1, 1, length(plan), copy(plan), state)
    end
end

function reset!(state::Periodic)
    state.index = 1
end

function update!(state::Periodic, iteration::Int, spins::AbstractMatrix)
    if (iteration - 1) % state.frequency == 0
        if state.index > state.total
            @warn "Periodic tracer is full; ignoring measurement"
            return
        end
        state.state[:, :, state.index] .= spins
        state.index += 1
    end
end


function reset!(state::SamplerWithPlan)
    state.array_index = 1
    state.plan_index = 1
end

function update!(state::SamplerWithPlan, iteration::Int, spins::AbstractMatrix)
    if state.plan_index < length(state.plan) && iteration == state.plan[state.plan_index]
        state.state[:, :, state.array_index] .= spins
        state.array_index += 1
        state.plan_index += 1
    end
end

end # module SamplerTracer

"""
    sampler_with_tracer!(
        problem::Problem{T, TEval},
        setup::Setup{T},
        workspace::Workspace{T},
        iterations::Integer,
        annealing_delta::AbstractVector{T},
        per_iteration_callback_state::Union{Nothing,TIterationCallbackState}=nothing
    ) where {T<:Real, TEval<:AbstractMatrix{<:T}, TIterationCallbackState}
"""
function sampler_with_tracer! end

@make_sampler(sampler_with_tracer,
    non_linearity_sign!, enforce_inelastic_wall_ising!,
    0, mul!,
    nothing, SamplerTracer.update!
)
