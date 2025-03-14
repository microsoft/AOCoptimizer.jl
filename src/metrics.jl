#=
metrics.jl

Generic methods to compute various optimization metrics
(e.g., hamiltonian, max-cut) and to convert between them.

=#

"""
    hamiltonian(matrix::AbstractMatrix, x::AbstractVector)
    hamiltonian(matrix::AbstractMatrix, field::Union{Nothing,AbstractVector}, x::AbstractVector)

Computes the Hamiltonian of system with interactions
expressed in `matrix` and for a given assignment `x`.
Optionally, a field can be provided.
The `matrix` is expected to be symmetric.

!!! warning

    The `matrix` is expected to be symmetric. This is not checked.
    The `field` is expected to be a vector of the same size as `x`.
    This is not checked.

!!! warning

    We expect that the backend storage for `matrix` and `x` is the same.
    This is not checked.
"""
function hamiltonian(
    matrix::AbstractMatrix,
    x::AbstractVector
)
    return -(x' * matrix * x) / 2
end

function hamiltonian(
    matrix::AbstractMatrix,
    field::Union{Nothing,AbstractVector},
    x::AbstractVector,
)
    if field === nothing
        return -(x' * matrix * x) / T(2)
    else
        return -(x' * matrix * x) / T(2) - field' * x
    end
end

function hamiltonian(
    matrix::Union{UpperTriangular,LowerTriangular},
    field::Union{Nothing,AbstractVector},
    x::AbstractVector,
)
    if field === nothing
        return -(x' * matrix * x)
    else
        return -(x' * matrix * x) - field' * x
    end
end


"""
    graph_cut_from_hamiltonian(T::Type{<:Real}, graph::AbstractMatrix, hamiltonian::Real)
    graph_cut_from_hamiltonian(graph::AbstractMatrix, hamiltonian::Real)
    graph_cut_from_hamiltonian(sum_of_graph_weights::Real, hamiltonian::Real)

Compute the cut of a graph (represented as a matrix `graph`, or by providing the `sum_of_graph_weights`)
from its `hamiltonian` energy.

!!! danger

    In addition to assuming that the `graph` is symmetric (it is not checked), the computation
    also assumes that the `hamiltonian` has been computed from the same graph and using
    a vector assignment of `1` and `-1` values.
"""
function graph_cut_from_hamiltonian(
    T::Type{<:Real},
    graph::AbstractMatrix{<:Real},
    hamiltonian::Real,
)
    result = (sum(T.(graph)) / T(2) - T.(hamiltonian)) / T(2)
    if isnan(result)
        @warn "Failed to compute MaxCut from Hamiltonian due to overflow"
        throw(DomainError(result, "The result is NaN."))
    end

    return result
end

function graph_cut_from_hamiltonian(
    graph::AbstractMatrix{T},
    hamiltonian::T,
)::T where {T<:Real}
    result = (sum(graph) / T(2) - hamiltonian) / T(2)
    if isnan(result)
        @warn "Failed to compute MaxCut from Hamiltonian due to overflow"
        throw(DomainError(result, "The result is NaN."))
    end

    return result
end

function graph_cut_from_hamiltonian(sum_of_graph_weights::T, hamiltonian::T)::T where {T<:Real}
    result = (sum_of_graph_weights / T(2) - hamiltonian) / T(2)
    if isnan(result)
        @warn "Failed to compute MaxCut from Hamiltonian due to overflow"
        throw(DomainError(result, "The result is NaN."))
    end

    return result
end