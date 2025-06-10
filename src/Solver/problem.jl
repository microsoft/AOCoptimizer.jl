#=
problem.jl

Data structures and helper methods for specifying the input to the solver.

=#

"""
    AbstractProblem{T<:Real}

Abstract type for specifying the problem to be solved.
"""
abstract type AbstractProblem{T<:Real} end

"""
    _widen_for_eval(T::DataType)

Helper function to determine the data type to use for computing the energies.
The main challenge is that evaluating energies using `Float16` or `BFloat16`
leads to numerical inaccuracies and incorrect results. Hence, for picking
the best configurations, we use a wider data type.
"""
@inline function _widen_for_eval(T::DataType)
    @assert T <: Real

    if T === Float16 || T === BFloat16
        TEval = widen(T)
    else
        TEval = T
    end

    return TEval
end

"""
    _are_all_diags_zero(m::AbstractMatrix{T}, binary::Integer) where {T<:Real}

Check if all the diagonal elements of the matrix `m` are zero.
For valid (mixed-)Ising and QUMO/QUBO problems, we require that all diagonal elements
that correspond to binary variables (`{-1, 1}` spins for Ising) are zero;
those terms, if necessary, should be folded into the external field (for QUMO/QUBO) or
the constant term (for Ising).
If `binary` is provided, it specifies the number of binary variables,
and only the first `binary` diagonal elements are checked.
"""
_are_all_diags_zero(m::AbstractMatrix{T}, binary::Integer) where {T<:Real} =
    all(diag(m)[1:binary] .== zero(T))
_are_all_diags_zero(m::AbstractMatrix{T}) where {T<:Real} = all(diag(m) .== zero(T))
function _are_all_diags_zero(::AbstractSparseMatrix, ::Integer)
    @warn "Sparse matrices are assumed to have binary diagonal equal to zero."
    return true
end

"""
    Problem{T<:Real} <: AbstractProblem{T}

Data structure for specifying the problem to be solved. This is the case
where the problem has an external field.
The problem is specified by the interaction matrix and the external field.
The problem can contain both binary and continuous variables.
It is assumed that the binary variables are the first indices in the matrix and in the field.
It is also required that the diagonal of the interaction matrix for the binary variables is zero.
For the continuous, the diagonal can be non-zero, as it represents quadratic terms.
"""
struct Problem{T<:Real,TEval<:Real} <: AbstractProblem{T}
    """The interaction matrix"""
    Interactions::AbstractMatrix{T}

    """The external field"""
    Field::Union{Nothing,AbstractVector{T}}

    """The number of spins"""
    Size::Integer

    """The number of binary variables"""
    Binary::Integer

    """Wider version of interaction matrix for evaluation"""
    InteractionsWide::AbstractMatrix{TEval}

    """Wider version of external field for evaluation"""
    FieldWide::Union{Nothing,AbstractVector{TEval}}

    function Problem(
        interactions::AbstractMatrix{T},
        ::Nothing,
        size::Integer,
        binary::Integer,
        interactions_wide::AbstractMatrix{TEval},
        ::Nothing
    ) where {T<:Real,TEval<:Real}
        # This is used internally to convert between backends.
        # Do not use explicitly.
        new{T,TEval}(interactions, nothing, size, binary, interactions_wide, nothing)
    end
    function Problem(
        interactions::AbstractMatrix{T},
        field::AbstractVector{T},
        size::Integer,
        binary::Integer,
        interactions_wide::AbstractMatrix{TEval},
        field_wide::AbstractVector{TEval},
    ) where {T<:Real,TEval<:Real}
        # This is used internally to convert between backends.
        # Do not use explicitly.
        new{T,TEval}(interactions, field, size, binary, interactions_wide, field_wide)
    end

    function Problem(
        interactions::AbstractMatrix{T},
        field::AbstractVector{T},
        binary::Integer,
        interactions_wide::AbstractMatrix{TEval},
        field_wide::AbstractVector{TEval},
    ) where {T<:Real,TEval<:Real}
        n, m = size(interactions)
        @assert n == m
        @assert n == length(field)
        @assert binary <= n

        @assert get_backend(interactions) == get_backend(field)
        @assert get_backend(interactions_wide) == get_backend(field_wide)

        # The diagonal of the interaction matrix should be zero for all binary variables.
        # For the rest it can be non-zero, as it represents quadratic terms.
        @assert _are_all_diags_zero(interactions, binary)
        @assert _are_all_diags_zero(interactions_wide, binary)

        new{T,TEval}(interactions, field, n, binary, interactions_wide, field_wide)
    end

    function Problem(
        interactions::AbstractMatrix{T},
        field::AbstractVector{T},
        binary::Integer,
    ) where {T<:Real}
        n, m = size(interactions)
        @assert n == m
        @assert n == length(field)
        @assert binary <= n

        @assert get_backend(interactions) == get_backend(field)

        # The diagonal of the interaction matrix should be zero for all binary variables.
        # For the rest it can be non-zero, as it represents quadratic terms.
        @assert _are_all_diags_zero(interactions, binary)

        TEval = _widen_for_eval(T)
        new{T,TEval}(interactions, field, n, binary, TEval.(interactions), TEval.(field))
    end

    function Problem{T,TEval}(
        interactions::AbstractMatrix{<:Real},
        field::AbstractVector{<:Real},
        binary::Integer,
    ) where {T<:Real,TEval<:Real}
        return Problem(
            T.(interactions),
            T.(field),
            binary,
            TEval.(interactions),
            TEval.(field),
        )
    end

    function Problem{T}(
        interactions::AbstractMatrix{<:Real},
        field::AbstractVector{<:Real},
        binary::Integer,
    ) where {T<:Real}

        TEval = _widen_for_eval(T)
        return Problem(
            T.(interactions),
            T.(field),
            binary,
            TEval.(interactions),
            TEval.(field),
        )
    end

    function Problem(interactions::AbstractMatrix{T}, binary::Integer) where {T<:Real}
        n, m = size(interactions)
        @assert n == m
        @assert binary <= n

        # The diagonal of the interaction matrix should be zero for all binary variables.
        # For the rest it can be non-zero, as it represents quadratic terms.
        @assert _are_all_diags_zero(interactions, binary)

        TEval = _widen_for_eval(T)
        new{T,TEval}(interactions, nothing, n, binary, TEval.(interactions), nothing)
    end

    function Problem(
        interactions::AbstractMatrix{T},
        binary::Integer,
        interactions_wide::AbstractMatrix{TEval},
    ) where {T<:Real,TEval<:Real}
        n, m = size(interactions)
        nw, mw = size(interactions_wide)
        @assert n == m
        @assert nw == mw
        @assert nw == n
        @assert binary <= n

        # The diagonal of the interaction matrix should be zero for all binary variables.
        # For the rest it can be non-zero, as it represents quadratic terms.
        @assert _are_all_diags_zero(interactions, binary)
        @assert _are_all_diags_zero(interactions_wide, binary)

        new{T,TEval}(interactions, nothing, n, binary, interactions_wide, nothing)
    end

    function Problem(
        interactions::AbstractMatrix{T},
        field::AbstractVector{T},
    ) where {T<:Real}
        n, _ = size(interactions)
        return Problem(interactions, field, n)
    end

    function Problem{T,TEval}(
        interactions::AbstractMatrix{<:Real},
        binary::Integer,
    ) where {T<:Real,TEval<:Real}
        n, m = size(interactions)
        @assert n == m
        @assert binary <= n

        # The diagonal of the interaction matrix should be zero for all binary variables.
        # For the rest it can be non-zero, as it represents quadratic terms.
        @assert _are_all_diags_zero(interactions, binary)

        new{T,TEval}(T.(interactions), nothing, n, binary, TEval.(interactions), nothing)
    end

    function Problem{T}(
        interactions::AbstractMatrix{<:Real},
        binary::Integer,
    ) where {T<:Real}
        return Problem(T.(interactions), binary)
    end

    function Problem(interactions::AbstractMatrix{T}) where {T<:Real}
        n, _ = size(interactions)
        return Problem(interactions, n)
    end

    function Problem{T}(interactions::AbstractMatrix{<:Real}) where {T<:Real}
        return Problem(T.(interactions))
    end

    function Problem{T,TEval}(
        interactions::AbstractMatrix{<:Real},
    ) where {T<:Real,TEval<:Real}
        n, m = size(interactions)
        @assert n == m
        @assert _are_all_diags_zero(interactions)

        new{T,TEval}(T.(interactions), nothing, n, n, TEval.(interactions), nothing)
    end

end

Adapt.@adapt_structure(Problem)
KernelAbstractions.get_backend(problem::Problem) =
    KernelAbstractions.get_backend(problem.Interactions)

make_problem(
    T::DataType,
    interactions::AbstractMatrix{<:Real},
    field::Union{Nothing,AbstractVector{<:Real}},
    binary::Integer,
) = begin
    if field === nothing
        return Problem(T.(interactions), binary)
    else
        return Problem(T.(interactions), T.(field), binary)
    end
end

make_problem(T::DataType, interactions::AbstractMatrix{<:Real}) = begin
    n, m = size(interactions)
    @assert n == m
    return make_problem(T, interactions, nothing, n)
end