#=
enhanced_random.jl

A very simple heuristic that tries to solve *Ising* problems,
by starting from a number of random solutions and
continuously trying to improve them using single flips.

The heuristic works as follows:
1. Make a random assignment of spins
2. Examine all spins one-by-one in random order
2.1. If swapping a spin lowers energy, then make the swap.
2.2. If 2.1 resulted in spin swap, then repeat 2 (using a different order of examination).
3. Repeat 1, and keep the minimal energy found.


TODO: Add unit tests for the methods in EnhancedRandom

=#

module EnhancedRandom

using Compat
using Distributions
using LinearAlgebra
using Random
using ...AOCoptimizer: Direction, MINIMIZATION, MAXIMIZATION
using ...AOCoptimizer: hamiltonian
using ...AOCoptimizer: CancellationToken, is_cancelled

@compat public search, search_qumo, QuadraticMatrix

#= Rule for making a heuristic swap:
    The common rule for making a swap is summarized in the code below:

    ```julia
        diff = matrix[i, :]' * assignment
        if diff * assignment[i] < 0
            # make the swap
        end
    ```

    First, recall that the Hamiltonian is defined as ``-∑_{i>j} matrix_{i,j} * x_i * x_j``,
    where the variables to be assigned are the ``x_i``'s.
    The value of diff measures the contribution of the spin ``i`` to the energy of the system for
    the current assignment. However, observe the negative sign out of the sum.
    This implies that we need to maximize the diff to minimize the energy.
    Hence, if ``diff * x_i`` is negative, then we need to flip spin ``i`` to make ``diff * x_i positive``,
    and subsequently reduce the energy.

    Similarly, in the presence of an external field the Hamiltonian is defined as

    ```math
    -∑_{i>j} matrix_{i,j} * x_i * x_j - ∑_{i} h_i * x_i,
    ```

    where ``h_i`` is the external field for spin ``i``.
=#

function improve!(
    assignment::AbstractVector{T},
    matrix::AbstractMatrix{T},
    indices::AbstractVector{<:Integer};
    ctx::Union{Nothing,CancellationToken} = nothing,
)::Bool where {T<:Real}

    progress = false
    for i in indices
        diff = matrix[i, :]' * assignment
        if diff * assignment[i] < T(0)
            assignment[i] = -assignment[i]
            progress = true
        end

        if ctx !== nothing && is_cancelled(ctx)
            break
        end
    end

    return progress
end

function improve!(
    assignment::AbstractVector{<:Integer},
    matrix::AbstractMatrix{T},
    indices::AbstractVector{<:Integer};
    ctx::Union{Nothing,CancellationToken} = nothing,
)::Bool where {T<:Real}

    progress = false
    changes = 0
    for i in indices
        diff = matrix[i, :]' * assignment
        if diff * assignment[i] < T(0)
            assignment[i] = -assignment[i]
            progress = true
            changes += 1
        end

        if ctx !== nothing && is_cancelled(ctx)
            break
        end
    end

    # @debug "Made $changes changes"
    return progress
end

function improve!(
    assignment::AbstractVector{T},
    matrix::AbstractMatrix{T},
    field::AbstractVector{T},
    indices::AbstractVector{<:Integer};
    ctx::Union{Nothing,CancellationToken} = nothing,
)::Bool where {T<:Real}

    progress = false
    for i in indices
        diff = matrix[i, :]' * assignment + field[i] * assignment[i]
        if diff * assignment[i] < T(0)
            assignment[i] = -assignment[i]
            progress = true
        end

        if ctx !== nothing && is_cancelled(ctx)
            break
        end
    end

    return progress
end

function improve!(
    assignment::AbstractVector{<:Integer},
    matrix::AbstractMatrix{T},
    field::AbstractVector{T},
    indices::AbstractVector{<:Integer};
    ctx::Union{Nothing,CancellationToken} = nothing,
)::Bool where {T<:Real}

    progress = false
    changes = 0
    for i in indices
        diff = matrix[i, :]' * assignment + field[i] * assignment[i]
        if diff * assignment[i] < T(0)
            assignment[i] = -assignment[i]
            progress = true
            changes += 1
        end

        if ctx !== nothing && is_cancelled(ctx)
            break
        end
    end

    # @debug "Made $changes changes"
    return progress
end

function _search(
    rng::AbstractRNG,
    matrix::AbstractMatrix{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}

    n, _ = size(matrix)
    spins = (-1, 1)
    x = rand(rng, spins, n)
    indices = collect(1:n)

    min_energy = hamiltonian(matrix, x)
    best = copy(x)

    while is_cancelled(ctx) == false
        rand!(rng, x, spins)
        shuffle!(rng, indices)
        while (improve!(x, matrix, indices; ctx = ctx))
            # yield to give a chance to the thread that will write to cancellation token to run
            yield()
        end
        energy = hamiltonian(matrix, x)
        if energy < min_energy
            min_energy = energy
            best .= x
            @debug "New minimum is $energy"
        else
            # @info "Energy found is $energy, best so far is $min_energy; sample $(x[1:10]')"
        end

        # We need to yield here to allow the thread that may write to the cancellation token to run
        yield()
    end

    return min_energy, best
end

function _search(
    rng::AbstractRNG,
    matrix::AbstractMatrix{T},
    field::AbstractVector{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}

    n, _ = size(matrix)
    spins = (-1, 1)
    x = rand(rng, spins, n)
    indices = collect(1:n)

    min_energy = hamiltonian_unchecked(matrix, field, x)
    best = copy(x)

    while is_cancelled(ctx) == false
        rand!(rng, x, spins)
        shuffle!(rng, indices)
        while (improve!(x, matrix, field, indices; ctx = ctx))
            # yield to give a chance to the thread that will write to cancellation token to run
            yield()
        end
        energy = hamiltonian_unchecked(matrix, field, x)
        if energy < min_energy
            min_energy = energy
            best .= x
            @debug "New minimum is $energy"
        else
            # @info "Energy found is $energy, best so far is $min_energy; sample $(x[1:10]')"
        end

        # We need to yield here to allow the thread that may write to the cancellation token to run
        yield()
    end

    return min_energy, best
end

#= Below are methods externally visible
=#

"""
    search(rng::AbstractRNG, matrix::AbstractMatrix{T}, ctx::CancellationToken)
    search(seed::Integer, matrix::AbstractMatrix{T}, ctx::CancellationToken)
    search(rng::AbstractRNG, matrix::AbstractMatrix{T}, field::AbstractVector{T}, ctx::CancellationToken)
    search(seed::Integer, matrix::AbstractMatrix{T}, field::AbstractVector{T}, ctx::CancellationToken)

Implement a simple heuristic that tries to solve *Ising* problems,
by starting from a number of random solutions and sequentially trying to improve them using single flips.
"""
function search(
    rng::AbstractRNG,
    matrix::AbstractMatrix{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    rows, columns = size(matrix)
    @assert rows == columns

    return _search(rng, matrix, ctx)
end

function search(
    seed::Integer,
    matrix::AbstractMatrix{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    rows, columns = size(matrix)
    @assert rows == columns

    rng = Xoshiro(seed)
    return _search(rng, matrix, ctx)
end

function search(
    rng::AbstractRNG,
    matrix::AbstractMatrix{T},
    field::AbstractVector{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    rows, columns = size(matrix)
    @assert rows == columns
    @assert rows == length(field)

    return _search(rng, matrix, field, ctx)
end

function search(
    seed::Integer,
    matrix::AbstractMatrix{T},
    field::AbstractVector{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    rows, columns = size(matrix)
    @assert rows == columns
    @assert rows == length(field)

    rng = Xoshiro(seed)
    return _search(rng, matrix, field, ctx)
end

const QuadraticMatrix = UpperTriangular

function _search_qumo_minimum(
    rng::AbstractRNG,
    quadratic::QuadraticMatrix{T},
    linear::AbstractVector{T},
    binary::AbstractVector{Int64},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    n, _ = size(quadratic)

    best = zeros(T, n)
    min_energy = T(0.0)

    dist = Distributions.Uniform(-1.0, 1.0)
    x = zeros(T, n)

    while is_cancelled(ctx) == false
        rand!(rng, dist, x)
        @. x[binary] = x[binary] .> T(0.5)

        energy = -transpose(x) * quadratic * x - transpose(linear) * x
        if energy < min_energy
            min_energy = energy
            best .= x
            @debug "New minimum is $energy"
        end

        # We need to yield here to allow the thread that may write to the cancellation token to run
        yield()
    end

    return min_energy, best
end

"""
    search_qumo(rng::AbstractRNG, quadratic::QuadraticMatrix{T}, linear::AbstractVector{T}, ctx::CancellationToken)
    search_qumo(seed::Integer, quadratic::QuadraticMatrix{T}, linear::AbstractVector{T}, ctx::CancellationToken)
    search_qumo(rng::AbstractRNG, quadratic::QuadraticMatrix{T}, ctx::CancellationToken)
    search_qumo(seed::Integer, quadratic::QuadraticMatrix{T}, ctx::CancellationToken)

Implement a simple heuristic that tries to solve *QUMO* problems,
by starting from a number of random solutions and sequentially trying to improve them using single flips.
"""
function search_qumo(
    seed::Integer,
    sense::Direction,
    quadratic::QuadraticMatrix{T},
    linear::Union{Nothing,AbstractVector{T}},
    continuous::Union{Nothing,AbstractVector{Bool}},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    rows, columns = size(quadratic)
    @assert rows == columns
    @assert linear === nothing || rows == length(linear)
    @assert continuous === nothing || rows == length(continuous)

    rng = Xoshiro(seed)

    if sense == Maximization
        quadratic = -quadratic
        if linear !== nothing
            linear = -linear
        end
    end

    n, _ = size(quadratic)
    if linear === nothing
        linear = zeros(T, n)
    end

    if continuous === nothing
        binary = collect(1:n)
    else
        binary = findall(x -> x == false, continuous)
    end

    (best, x) = _search_qumo_minimum(rng, quadratic, linear, binary, ctx)
    if sense == Maximization
        best = -best
    end

    return best, x
end

function search_qumo(
    seed::Integer,
    sense::Direction,
    quadratic::QuadraticMatrix{T},
    ctx::CancellationToken,
)::Tuple{T,AbstractVector{T}} where {T<:Real}
    rows, columns = size(quadratic)
    @assert rows == columns

    return search_qumo(seed, sense, quadratic, nothing, nothing, ctx)
end

end # module EnhancedRandom
