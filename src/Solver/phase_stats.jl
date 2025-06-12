#=
phase_stats.jl

Helper structures to store statistics about the solver phases.
=#

mutable struct PhaseInfo
    start::Union{Nothing,DateTime}
    stop::Union{Nothing,DateTime}

    PhaseInfo() = new(nothing, nothing)
    PhaseInfo(start::DateTime) = new(start, nothing)
    PhaseInfo(start::DateTime, stop::DateTime) = new(start, stop)
end

_elapsed(phase::PhaseInfo) = phase.stop - phase.start

phase_start() = PhaseInfo(now())
phase_end!(phase::PhaseInfo) = phase.stop = now()

function elapsed(phase::PhaseInfo)::Union{Nothing,TimePeriod}
    if phase.start === nothing || phase.stop === nothing
        @warn "Not enough information to compute the elapsed time."
        return nothing
    else
        return phase.stop - phase.start
    end
end

const TExplorationResultVector = Vector{ExplorationResult}

struct PhaseStatistics
    runtime::PhaseInfo
    setup::Setup
    results::TExplorationResultVector
    iterations::Vector{Integer}
end

#=
We need to explicitly convert the elements of the result vector.
If we leave as a vector, `Adapt.jl` will not automatically parse the vector
(which is typically a simple CPU vector, but which contains inner vectors
as elements those inner vectors may have a different backend)
=#
Adapt.adapt_structure(to, v::TExplorationResultVector) =
    map(x -> Adapt.adapt(to, x), v)

Adapt.@adapt_structure PhaseStatistics
