#=
normalization.jl

It is important to normalize the quadratic matrix prior to using it in the solver.

=#

function _compute_eigenvalue(matrix::T, target::Target; tol::Real=1.0e-6, retries=10) where {T<:AbstractMatrix}
    @assert tol > 0.0
    @assert retries >= 0

    tol = min(tol, 0.1)
    pairs = partialschur(Symmetric(matrix); nev=1, which=target, tol=tol)
    @assert length(pairs) == 2 "Expected an pair, got $(length(pairs)): $(pairs)"
    eigenvalues = pairs[1].eigenvalues

    if length(eigenvalues) == 0 && retries > 0
        @warn "Failed to compute the largest eigenvalue with tolerance $tol; retrying with a bigger tolerance ($retries retries remaining)"
        return _compute_eigenvalue(matrix, target; tol=tol * 2.0, retries=retries - 1)
    end

    @assert (length(eigenvalues) >= 1 && eigenvalues isa AbstractVector) "Expected a vector of eigenvalues with at least one element, got $(length(eigenvalues)): $(eigenvalues);\npairs=$(pairs)\n"
    eigenvalue = eigenvalues[1]

    if length(eigenvalues) > 1
        @warn "Expected a single eigenvalue, got $(length(eigenvalues)): $(eigenvalues); will use the first one"
    end
    if eigenvalue.im ≉ 0.0
        @warn "Expected a real eigenvalue, got $(eigenvalue); will ignore the imaginary part"
    end

    return eigenvalue.re
end

function _calculate_normalization_factor(interactions::AbstractMatrix{T}) where {T<:Real}
    if T === Float32 || T == Float64
        matrix = interactions
    else
        matrix = Float32.(interactions)
    end
    λ_max = _compute_eigenvalue(interactions, LR())
    λ_min = _compute_eigenvalue(interactions, SR())

    if sign(λ_max) != sign(λ_min)
        if λ_max <= 0.1
            @warn "Largest eigenvalue $λ_max is either negative or small; using 1.0 instead"
            λ = T(1.0)
        end
        λ = λ_max
    else
        λ = ( abs(λ_max) + abs(λ_min) ) / T(2.0)
    end

    @assert λ >= 0.0 "Largest eigenvalue $λ is not positive"
    if λ <= 0.1
        @warn "Normalization factor $λ is either negative or small; using 1.0 instead"
        λ = T(1.0)
    end

    return λ
end
