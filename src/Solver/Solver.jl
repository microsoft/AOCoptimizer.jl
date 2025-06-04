#=
Solver.jl

Main module for the AOC software solver.
=#

module Solver

using Adapt
using BFloat16s
using Compat
using KernelAbstractions
using LinearAlgebra
using SparseArrays

@compat public @make_wall, enforce_inelastic_wall!
@compat public enforce_inelastic_wall_ising!, enforce_inelastic_wall_binary!
@compat public calculate_energies!, calculate_energies
@compat public Problem

"""
    TEnergyObservations{T<:Number}

Type alias for a matrix of energy observations for various configurations.
Each column corresponds to a configuration and each row corresponds to an experiment.
"""
const TEnergyObservations = AbstractMatrix

include("utils.jl")
include("walls.jl")
include("stats.jl")
include("problem.jl")

end # module