#=
qumo.jl

Implement helper methods for QUMO problems

=#

module QUMO

using Compat
using LinearAlgebra
using AOCoptimizer: Direction, MINIMIZATION, MAXIMIZATION

@compat public qumo, mixed_ising, convert_positive_qumo_to_mixed_ising
export qumo, mixed_ising, convert_to_mixed_ising, convert_to_qumo

"""
    qumo{T}

A structure representing a Quadratic Unconstrained Mixed Optimization (QUMO).
Such problems can be either minimization or maximization problems. They
can contain both binary and continuous variables, but the continuous
variables are expected to be in the range [-1, 1] and the binary variables
are in {0, 1}. The objective function is (1/2)x'Qx + f'x + c,
where x is the vector of variables, Q is the quadratic matrix,
f is the linear vector (if it exists), and c is a constant offset.

The `qumo` structure contains the following fields:
- `Sense`: The direction of optimization, either `MINIMIZATION` or `MAXIMIZATION`.
- `Quadratic`: A matrix representing the quadratic terms of the QUMO problem.
- `Field`: A vector representing the linear terms of the QUMO problem.
- `Binary`: A vector of booleans indicating whether each variable is binary.
- `Offset`: A constant offset added to the objective function.

It is expected that the `Quadratic` matrix is symmetric and that the diagonal elements
that correspond to binary variables are zero. (This is not checked in the constructor.)
"""
struct qumo{T<:Real}
    Sense::Direction
    Quadratic::AbstractMatrix{T}
    Field::Union{Nothing,AbstractVector{T}}
    Binary::AbstractVector{Bool}
    Offset::T

    function qumo(
        sense::Direction,
        binary::AbstractVector{Bool},
        terms::AbstractMatrix{T},
        linear::Union{Nothing,AbstractVector{T}} = nothing,
        offset::T = T(0.0),
    ) where {T<:Real}
        d1, d2 = size(terms)
        @assert d1 == d2
        @assert linear === nothing || d1 == length(linear)
        @assert d1 == length(binary)

        return new{T}(sense, terms, linear, binary, offset)
    end

    function qumo(binary::AbstractVector{Bool}, terms::AbstractMatrix{T}) where {T<:Real}
        return qumo(MINIMIZATION, binary, terms, nothing)
    end

    function qumo(
        binary::AbstractVector{Bool},
        terms::AbstractMatrix{T},
        linear::AbstractVector{T},
    ) where {T<:Real}
        return qumo(MINIMIZATION, binary, terms, linear)
    end

end

"""
    isapprox(q1::qumo, q2::qumo; kwargs...)

Checks if two `qumo` objects are approximately equal,
i.e., have the same optimization direction and approximately
the same weights in the quadratic and linear terms.
They should also have the same binary and continuous variables.
"""
function Base.isapprox(q1::qumo, q2::qumo; kwargs...)
    return q1.Sense == q2.Sense &&
        isapprox(q1.Quadratic, q2.Quadratic; kwargs...) &&
        (
            (q1.Field === nothing && q2.Field === nothing) || (
                q1.Field !== nothing &&
                q2.Field !== nothing &&
                isapprox(q1.Field, q2.Field; kwargs...)
            )
        ) &&
        q1.Binary == q2.Binary &&
        isapprox(q1.Offset, q2.Offset; kwargs...)
end

"""
    mixed_ising{T}

A structure representing a Mixed Ising problem. Such problems
are always minimization problems and, unlike traditional Ising
problems, they can contain both binary and continuous variables.
The continuous variables have a range of [-1, 1], while the binary
variables are in {-1, 1}.

The `mixed_ising` structure contains:
- `Quadratic`: A matrix representing the quadratic terms of the Ising problem.
- `Field`: A vector representing the linear terms of the Ising problem.
- `Binary`: A vector of booleans indicating whether each variable is binary.
- `Offset`: A constant offset added to the objective function.
"""
struct mixed_ising{T<:Real}
    Quadratic::AbstractMatrix{T}
    Field::AbstractVector{T}
    Binary::AbstractVector{Bool}
    Offset::T

    function mixed_ising(
        quadratic::AbstractMatrix{T},
        field::Union{Nothing,AbstractVector{T}},
        binary::AbstractVector{Bool},
        offset::T = T(0.0),
    ) where {T<:Real}
        d1, d2 = size(quadratic)
        @assert d1 == d2
        @assert field === nothing || d1 == length(field)
        @assert d1 == length(binary)

        if field === nothing
            field = similar(quadratic, d1)
            field .= T(0.0)
        end

        return new{T}(quadratic, field, binary, offset)
    end

end

Base.isapprox(q1::mixed_ising, q2::mixed_ising; kwargs...) =
    isapprox(q1.Quadratic, q2.Quadratic; kwargs...) &&
    isapprox(q1.Field, q2.Field; kwargs...) &&
    q1.Binary == q2.Binary &&
    isapprox(q1.Offset, q2.Offset; kwargs...)

"""
    number_of_variables(q::qumo{T})::Integer where {T<:Real}

Returns the number of variables in the QUMO problem `q`.
"""
number_of_variables(q::qumo) = size(q.Quadratic)[1]

"""
    number_of_variables(q::mixed_ising{T})::Integer where {T<:Real}

Returns the number of variables in the mixed Ising problem `q`.
"""
number_of_variables(q::mixed_ising) = size(q.Quadratic)[1]

"""
    convert_to_mixed_ising(q::qumo{T})::mixed_ising{T} where {T<:Real}

Converts a QUMO problem to a mixed Ising problem.
The transformation is achieved by observing that we need to map
all binary variables from {0, 1} to {-1, 1}.
"""
function convert_to_mixed_ising(q::qumo{T})::mixed_ising{T} where {T<:Real}
    #=
    Observe that the following code makes the implicit assumption that the matrix is dense.
    It will work on sparse matrices, but it is not optimized for them.
    =#

    nvars = number_of_variables(q)
    quadratic = copy(q.Quadratic)

    if q.Field !== nothing
        field = similar(q.Field, nvars)
    else
        #= We do not know the type of the field, so we need to guess from the matrix.
        The problem is that if the matrix is sparse, we will have a sparse vector,
        however, we want a dense vector (which still contains all other properties of
        the matrix.
        The following will erase all other properties. This is ok for now:
        The only properties we care is sparsity and GPU-backed arrays.
        The statement below deals correctly with sparsity (erases it from the vector),
        and in any case the rest of the code in this method will fail for GPU-backed
        arrays (we do a lot of indexing operations).
        =#
        field = Vector(similar(q.Quadratic, nvars))
    end
    field .= T(0.0)

    zero = T(0.0)

    constant = zero
    for i in range(1, nvars)
        for j in range(1, nvars)
            if quadratic[i, j] ≈ zero
                continue
            end

            if i == j && q.Binary[i]
                # This is a binary variable but it has a non zero weight in the quadratic
                # matrix. We transform and move to field.
                @warn "Moving weight $(q.Quadratic[i, i]) for position ($i, $i) to external field"
                w = quadratic[i, i] / T(2.0)
                field[i] += w
                constant += w
                quadratic[i, i] = zero
            elseif q.Binary[i] && q.Binary[j]
                # Both binary and different
                w = quadratic[i, j] / T(4.0)
                quadratic[i, j] = w
                field[i] += w
                field[j] += w
                constant += w
            elseif q.Binary[i]
                w = quadratic[i, j] / T(2.0)
                quadratic[i, j] = w
                field[j] += w
            elseif q.Binary[j]
                w = quadratic[i, j] / T(2.0)
                quadratic[i, j] = w
                field[i] += w
            else
                # Both variables are continuous
                # there is nothing to change
            end
        end
    end

    if q.Field !== nothing
        for i in range(1, nvars)
            if q.Binary[i]
                w = q.Field[i] / T(2.0)
                field[i] += w
                constant += w
            else
                field[i] += q.Field[i]
            end
        end
    end

    if q.Sense == MAXIMIZATION
        quadratic = -quadratic
        field = -field
    end

    return mixed_ising(quadratic, field, copy(q.Binary), q.Offset + constant)
end

"""
    convert_to_qumo(q::mixed_ising{T})::qumo{T} where {T<:Real}

Converts a mixed Ising problem, i.e., a problem where binaries are
{-1, 1} and continuous in [-1, 1] to QUMO, where binaries
are in {0, 1} and continuous stay at [-1, 1].
"""
function convert_to_qumo(q::mixed_ising{T})::qumo{T} where {T<:Real}
    nvars = number_of_variables(q)
    quadratic = copy(q.Quadratic)
    field = similar(q.Quadratic, nvars)
    field .= T(0.0)

    zero = T(0.0)
    constant = zero

    for i in range(1, nvars)
        for j in range(1, nvars)
            if i == j && q.Binary[i] && quadratic[i, i] ≉ zero
                # The result of the (+1)*(+1)=(-1)*(-1)=1,
                # we will move it to the constant.
                @warn "Moving weight $(q.Quadratic[i, i]) for position ($i, $i) to constant"
                constant += quadratic[i, i]
                quadratic[i, i] = zero
            elseif i == j && q.Binary[i]
                # Nothing to do; the weight is zero.
            elseif q.Binary[i] && q.Binary[j]
                # Both binary and different
                w = quadratic[i, j]
                quadratic[i, j] = T(4.0) * w
                field[i] -= T(2.0) * w
                field[j] -= T(2.0) * w
                constant += w
            elseif q.Binary[i]
                w = quadratic[i, j]
                quadratic[i, j] = T(2.0) * w
                field[j] -= w
            elseif q.Binary[j]
                w = quadratic[i, j]
                quadratic[i, j] = T(2.0) * w
                field[i] -= w
            else
                # Both variables are continuous
                # there is nothing to change
            end
        end
    end

    for i in range(1, nvars)
        if q.Binary[i]
            w = q.Field[i]
            field[i] += T(2.0) * w
            constant -= w
        else
            field[i] += q.Field[i]
        end
    end

    if all(≈(T(0)), field)
        return qumo(MINIMIZATION, q.Binary, quadratic, nothing, q.Offset + constant)
    else
        return qumo(MINIMIZATION, q.Binary, quadratic, field, q.Offset + constant)
    end
end

"""
    convert_positive_qumo_to_mixed_ising(q::qumo{T})::mixed_ising{T} where {T<:Real}

    Converts a positive QUMO problem, i.e. a problem where all variables
    are expected to be positive (binary in {0,1}, continuous in [0,1])
    to mixed Ising, where binaries are {-1, 1} and continuous in [-1, 1].

    The transformation is achieved by observing that we need to scale
    all variables x by 2x-1 to move from [0,1] to [-1,1]. Observe,
    that the optimization objective is (1/2)x'Qx + f'x + c.
"""
function convert_positive_qumo_to_mixed_ising(q::qumo{T})::mixed_ising{T} where {T<:Real}
    quadratic = T(0.25) * q.Quadratic
    nvars = number_of_variables(q)

    e = ones(T, nvars)
    extra_field = vec(e' * q.Quadratic)
    if q.Field === nothing
        field = T(0.25) .* extra_field
        constant = T(0.125) * extra_field' * e
    else
        field = T(0.25) .* extra_field .+ T(0.5) .* q.Field
        constant = (T(0.5) * q.Field .+ T(0.125) * extra_field)' * e
    end

    if q.Sense == MINIMIZATION
        return mixed_ising(quadratic, field, q.Binary, q.Offset + constant)
    else
        return mixed_ising(-quadratic, -field, q.Binary, -q.Offset - constant)
    end
end

"""
    convert_mixed_ising_to_positive_qumo(m::mixed_ising{T})::qumo{T} where T<:Real

    Converts a mixed Ising problem, i.e. a problem where binaries are
    {-1, 1} and continuous in [-1, 1] to positive QUMO, where all variables
    are expected to be positive (binary in {0,1}, continuous in [0,1]).

    The transformation is achieved by observing that we need to scale
    all variables x by (x+1)/2 to move from [-1,1] to [0,1]. Observe,
    that the optimization objective is (1/2)x'Qx + f'x + c.
"""
function convert_mixed_ising_to_positive_qumo(m::mixed_ising{T})::qumo{T} where {T<:Real}
    quadratic = T(4.0) * m.Quadratic
    field = T(2.0) * m.Field - T(2.0) * vec(sum(m.Quadratic, dims = 1))
    constant = T(0.5) * sum(m.Quadratic) - sum(m.Field) + m.Offset

    if all(<(T(10.0) * eps(T)), field)
        return qumo(MINIMIZATION, m.Binary, quadratic, nothing, constant)
    else
        return qumo(MINIMIZATION, m.Binary, quadratic, field, constant)
    end
end

end
