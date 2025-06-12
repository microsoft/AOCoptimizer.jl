#=
collectors.jl

The functionality here extends the exploration process to allow flexibility in
collecting statistics and other information about the output of the sampler.
By default, we collect the best solution found so far.

=#

module Collector

using Adapt
using ..Solver: _similar_vector

"""
    BestFound{T<:Real, TV<:AbstractVector}

A structure to hold the best found solution and its objective value.
All collectors return this structure (when calling the retrieve method on them).

Observe that the elementary type of the assignment vector can be different
from the type of the objective value. For example, the objective may be computed
at higher precision (e.g., Float32) than the assignment vector (e.g., Float16).
"""
struct BestFound{T <: Real, TV <: AbstractVector{<:Number}}
    objective::T
    assignment::TV
end

Adapt.@adapt_structure BestFound

abstract type AbstractCollector end
abstract type AbstractState end

create(::AbstractCollector, _assignments, _number_of_variables) = error("Attempting to create an abstract collector")
update!(::AbstractCollector, _state, _energies, _assignments) = error("Attempting to update an abstract collector")
finish(::AbstractCollector, _state) = error("Attempting to finalize an abstract collector")
retrieve(::AbstractCollector, _state) = error("Attempting to retrieve from an abstract collector")
info(::AbstractCollector, _state) = error("Attempting to retrieve the additional state of an abstract collector")

struct BestAssignmentCollector <: AbstractCollector end

"""
    BestSolutionState{T<:Real, TV<:AbstractVector}

A state structure to hold the best solution found so far. This structure can
be updated with new solutions, and it will keep the best one found so far.

Observe that the elementary type of the assignment vector can be different
from the type of the objective value. For example, the objective may be computed
at higher precision (e.g., Float32) than the assignment vector (e.g., Float16).
"""
mutable struct BestSolutionState{T<:Real,TV<:AbstractVector{<:Number}} <: AbstractState
    objective::Union{Nothing, T}
    assignment::TV

    function BestSolutionState(objective::T, assignment::TV) where {T<:Real,TV<:AbstractVector{<:Number}}
        return new{T,TV}(objective, assignment)
    end
    function BestSolutionState(assignments::TV) where {TV<:AbstractVector{<:Real}}
        return new{eltype(TV),TV}(nothing, assignments)
    end
    function BestSolutionState(T, assignments::TV) where {TV<:AbstractVector{<:Number}}
        @assert T <: Real
        return new{T,TV}(nothing, assignments)
    end
end

Adapt.@adapt_structure BestSolutionState


@inline create(::BestAssignmentCollector, assignments::TV, number_of_variables) where {TV<:AbstractMatrix{<:Number}} =
    BestSolutionState(_similar_vector(assignments, number_of_variables))

@inline function update!(::BestAssignmentCollector, state::BestSolutionState, energies, assignments)
    best_objective, index = findmin(energies)
    if state.objective === nothing || best_objective < state.objective
        state.objective = best_objective
        state.assignment .= assignments[:, index]
    end
    return nothing
end
@inline finish(::BestAssignmentCollector, state::BestSolutionState) = nothing
@inline retrieve(::BestAssignmentCollector, state::BestSolutionState)::BestFound = BestFound(state.objective, state.assignment)
@inline info(::BestAssignmentCollector, state::BestSolutionState)::Nothing = nothing

"""
    _default_best_assignment_collector

Internal variable to hold an object of the BestAssignmentCollector type.
"""
_default_best_assignment_collector = BestAssignmentCollector()



struct FinalAssignmentCollector <: AbstractCollector end

mutable struct FinalAssignmentState{T<:Real,TV<:AbstractVector{<:Number}} <: AbstractState
    best::BestSolutionState{T,TV}
    assignments::Vector
end

Adapt.@adapt_structure FinalAssignmentState

@inline function create(::FinalAssignmentCollector, assignments, number_of_variables)
    best = create(_default_best_assignment_collector, assignments, number_of_variables)
    return FinalAssignmentState(best, Vector())
end

@inline function update!(::FinalAssignmentCollector, state::FinalAssignmentState, energies, assignments)
    update!(_default_best_assignment_collector, state.best, energies, assignments)
    # Here we assume that we know that the assignments matrix is a scratch matrix where not all columns are valid.
    # The valid ones are the ones that correspond to the number of energies.
    assignments = @view assignments[:, 1:length(energies)]
    push!(state.assignments, copy(assignments))
    return nothing
end

@inline finish(::FinalAssignmentCollector, state::FinalAssignmentState) = nothing
@inline retrieve(::FinalAssignmentCollector, state::FinalAssignmentState)::BestFound = BestFound(state.best.objective, state.best.assignment)
@inline info(::FinalAssignmentCollector, state::FinalAssignmentState) = state.assignments

function get_final_assignments(state::FinalAssignmentState)
    return vcat(state.assignments'...)'
end
function get_final_assignments(assignments::Vector{<:AbstractMatrix})
    return vcat(assignments'...)'
end

end # module Collector
