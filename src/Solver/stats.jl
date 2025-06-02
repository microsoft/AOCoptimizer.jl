#=
stats.jl

Helper methods for computing auxiliary statistics.

=#

#=
For each configuration set (α, β), we perform a number of
experiments and collect the observed energies in a matrix,
where each column corresponds to a set (α, β) and each row
corresponds to an experiment.
We assess the quality of each configuration (α, β) by the
number of experiments with that configuration that hit the
minimum observed energy.
=#

"""
    count_min_energy_hits(observations::TEnergyObservations{<:Real})::AbstractVector{T}

Count the number of experiments that hit the minimum observed energy.
In the input matrix, each column corresponds to a configuration and
each row corresponds to an experiment. The output is a vector of
length equal to the number of columns (configurations) in the input matrix.
The entry at index `i` is the number of experiments that hit the minimum
observed energy for configuration `i`.
"""
function count_min_energy_hits(
    observations::TEnergyObservations{T},
)::AbstractVector{<:Integer} where {T<:Real}

    # For some reason, a type annotation on the return type of CuVector{T} fails.
    best_energy = minimum(observations)
    return vec(count(≈(best_energy), observations; dims = 1))
end

"""
    calculate_energies!(
        energies::AbstractVector{TEval},
        spins::AbstractMatrix{T},
        matrix::AbstractMatrix{TEval},
        external::Union{Nothing,AbstractVector{TEval}},
    ) where {T<:Real,TEval<:Real}

Calculate the energies for each configuration given the `spins`, the interaction `matrix`
and an optional `external` field.
The `energies` vector is modified in place to hold the computed energies.
"""
function calculate_energies!(
    energies::AbstractVector{TEval},
    spins::AbstractMatrix{T},
    matrix::AbstractMatrix{TEval},
    external::Union{Nothing,AbstractVector{TEval}},
) where {T<:Real,TEval<:Real}
    # It is possible that the last set of experiments was smaller than the size
    # of the workspace. This means that some columns of the spins matrix are
    # invalid. So, we will throw them away, and use only the subset of valid experiments.
    if length(energies) < size(spins)[2]
        spins = spins[:, 1:length(energies)]
    end

    sum!(energies, -(spins' * matrix) .* spins' / TEval(2.0))

    if external !== nothing
        energies .-= spins' * external
    end

    return nothing
end

"""
    calculate_energies(
        spins::AbstractMatrix{T},
        matrix::AbstractMatrix{TEval},
        external::Union{Nothing,AbstractVector{TEval}},
    )::AbstractVector{TEval} where {T<:Real,TEval<:Real}

Calculate the energies for each configuration given the `spins`, the interaction `matrix`
and an optional `external` field.
The result is returned as a new vector of energies.
"""
function calculate_energies(
    spins::AbstractMatrix{T},
    matrix::AbstractMatrix{TEval},
    external::Union{Nothing,AbstractVector{TEval}},
)::AbstractVector{TEval} where {T<:Real,TEval<:Real}
    energies = sum(-(spins' * matrix) .* spins' / TEval(2.0), dims = 2)

    if external !== nothing
        energies .-= spins' * external
    end

    return vec(energies)
end
