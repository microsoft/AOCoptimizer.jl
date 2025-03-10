#=
qubo.jl

Utility methods for processing QUBO problems.

TODO: Greedy heuristic in GPU
    The code below implements a very simple greedy heuristic for QUBO problems.
    The heuristic is used for benchmarking purposed (e.g., what a very naive
    algorithm can do). The implementation is CPU-based. Ideally, we would like
    to implement a GPU-based version of the algorithm.
=#

module QUBO

using Compat
using LinearAlgebra
using Random
using AOCoptimizer: CancellationToken, is_cancelled
using AOCoptimizer: Direction, MINIMIZATION, MAXIMIZATION

export qubo
@compat public qubo, greedy_random, evaluate, size, increase!, decrease!

"""
    qubo{T}

A structure representing a Quadratic Unconstrained Binary Optimization (QUBO) problem.
The `qubo` structure contains the following fields:
- `Sense`: The direction of optimization, either `MINIMIZATION` or `MAXIMIZATION`.
- `Terms`: A matrix representing the quadratic terms of the QUBO problem.
"""
struct qubo{T<:Real}
    Sense::Direction
    Terms::AbstractMatrix{T}

    function qubo{T}(sense::Direction, terms::AbstractMatrix) where {T<:Real}
        s = size(terms)
        if length(s) != 2
            throw(ArgumentError("QUBO terms must be 2D"))
        end
        if s[1] != s[2]
            throw(ArgumentError("QUBO terms must be square"))
        end

        #=
        Observe that we do not check that the matrix does not contain
        diagonal elements and that is symmetric. We expect the user to
        provide a valid QUBO matrix.
        =#

        return new(sense, T.(terms))
    end

    qubo(terms::AbstractMatrix{T}) where {T<:Real} = new{T}(MINIMIZATION, terms)
    qubo{T}(terms::AbstractMatrix) where {T<:Real} = new(MINIMIZATION, T.(terms))
    qubo(sense::Direction, terms::AbstractMatrix{T}) where {T<:Real} = new{T}(sense, terms)

end

"""
    size(q::qubo)::Integer

Returns the size of the QUBO problem represented by `q`.
"""
size(q::qubo)::Integer = Base.size(q.Terms)[1]

"""
    evaluate(q::qubo, assignment)

Evaluates the objective function of the QUBO problem `q` for a given assignment.
Returns the value of the objective function.
"""
function evaluate end

evaluate(q::qubo{T}, assignment::AbstractVector{T}) where {T<:Real} =
    assignment' * UpperTriangular(q.Terms) * assignment
evaluate(q::qubo{T}, assignment::BitVector) where {T<:Real} =
    assignment' * UpperTriangular(q.Terms) * assignment
evaluate(terms::AbstractMatrix{T}, assignment::AbstractVector{T}) where {T<:Real} =
    assignment' * UpperTriangular(terms) * assignment
evaluate(terms::AbstractMatrix{T}, assignment::BitVector) where {T<:Real} =
    assignment' * UpperTriangular(terms) * assignment

"""
    _random(rng::AbstractRNG, q::qubo{T})::AbstractVector{T} where {T<:Real}

Generates a random assignment for the QUBO problem `q` using the provided random number generator `rng`.
"""
function _random(rng::AbstractRNG, q::qubo{T})::AbstractVector{T} where {T<:Real}
    x = Vector{T}(undef, size(q))
    rand!(rng, x, (0, 1))
    return x
end

function _random(
    rng::AbstractRNG,
    terms::AbstractMatrix{T},
)::AbstractVector{T} where {T<:Real}
    n, _ = Base.size(terms)
    x = Vector{T}(undef, n)
    rand!(rng, x, (0, 1))
    return x
end

_random!(rng::AbstractRNG, x::AbstractVector{T}) where {T<:Number} = rand!(rng, x, (0, 1))

"""
    increase!(assignment, terms, indices; ctx)

Tries to increase the objective function of an `assignment` applied to a
set of QUBO `terms` by flipping assignments one-by-one according to the order in `indices`.

If cancellation token `ctx` is present, then process will continue until
the entire list of `indices` gets visited, or cancellation token `ctx` gets triggered.

Method returns `true` if progress has been made; `false` otherwise
"""
function increase!(
    assignment::AbstractVector{TV},
    terms::AbstractMatrix{T},
    indices::AbstractVector{<:Integer};
    ctx::Union{Nothing,CancellationToken} = nothing,
)::Bool where {TV<:Number,T<:Real}
    z = zero(TV)
    o = one(TV)
    vz = zero(T)

    progress = false
    for i in indices
        if assignment[i] == z
            # Transition from 0 to 1
            delta = terms[i, :]' * assignment + terms[i, i]

            if delta > vz
                # Changing from 0 to 1
                assignment[i] = o
                progress = true
            end
        else
            # Transition from 1 to 0
            delta = terms[i, :]' * assignment

            if delta < vz
                # Changing from 1 to 0")
                assignment[i] = z
                progress = true
            end
        end

        if ctx !== nothing && is_cancelled(ctx)
            break
        end
    end

    return progress
end

"""
    decrease(assignment, terms, indices; ctx)

Tries to decrease the objective function of an `assignment` applied to a
set of QUBO `terms` by flipping assignments one-by-one according to the order in `indices`.

If cancellation token `ctx` is present, then process will continue until
the entire list of `indices` gets visited, or cancellation token `ctx` gets triggered.

Method returns `true` if progress has been made; `false` otherwise
"""
function decrease!(
    assignment::AbstractVector{TV},
    terms::AbstractMatrix{T},
    indices::AbstractVector{<:Integer};
    ctx::Union{Nothing,CancellationToken} = nothing,
)::Bool where {TV<:Number} where {T<:Real}
    z = zero(TV)
    o = one(TV)
    vz = zero(T)

    progress = false
    for i in indices
        if assignment[i] == z
            # Transition from 0 to 1
            delta = terms[i, :]' * assignment + terms[i, i]

            if delta < vz
                # Changing from 0 to 1
                assignment[i] = o
                progress = true
            end
        else
            # Transition from 1 to 0
            delta = terms[i, :]' * assignment

            if delta > vz
                # Changing from 1 to 0")
                assignment[i] = z
                progress = true
            end
        end

        if ctx !== nothing && is_cancelled(ctx)
            break
        end
    end

    return progress
end

"""
    greedy_random(rng::Union{AbstractRNG, Integer}, q::qubo{T}, ctx::Union{Nothing,CancellationToken})

Performs a greedy random search on the QUBO problem `q` using the provided random number generator `rng`.
The search continues until the cancellation token `ctx` is triggered.
Returns a tuple containing the best energy found and the corresponding assignment.
"""
function greedy_random end

function greedy_random(
    rng::AbstractRNG,
    q::qubo{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}

    matrix = q.Terms
    x = _random(rng, q)

    indices = collect(1:size(q))

    best = evaluate(matrix, x)
    best_v = copy(x)

    improve! = (q.Sense == Minimization) ? decrease! : increase!
    better_than(current::T, best::T) =
        (q.Sense == Minimization) ? current < best : current > best

    while is_cancelled(ctx) == false
        _random!(rng, x)
        shuffle!(rng, indices)
        while (improve!(x, matrix, indices; ctx = ctx))
        end
        energy = evaluate(matrix, x)
        if better_than(energy, best)
            best = energy
            best_v = copy(x)
            @debug "New minimum is $energy"
        else
            # @info "Energy found is $energy, best so far is $best; sample $(x[1:10]')"
        end
    end

    return best, best_v
end

function greedy_random(
    seed::Integer,
    q::qubo{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}

    rng = Xoshiro(seed)
    return greedy_random(rng, q, ctx)
end

end
