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

struct PhaseStatistics
    runtime::PhaseInfo
    setup::Setup
    results::Vector{ExplorationResult}
    iterations::Vector{Integer}
end

Adapt.@adapt_structure PhaseStatistics
