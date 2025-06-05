#=
Solver.jl

Main module for the AOC software solver.
=#

module Solver

using Adapt
using BFloat16s
using Compat
using Distributions
using KernelAbstractions
using LinearAlgebra
using Printf
using Random
using SparseArrays

@compat public @make_wall, enforce_inelastic_wall!
@compat public enforce_inelastic_wall_ising!, enforce_inelastic_wall_binary!
@compat public calculate_energies!, calculate_energies
@compat public Problem
@compat public Setup, make_empty_setup, make_setup
@compat public Workspace, make_workspace, initialize_workspace
@compat public @make_non_linearity
@compat public non_linearity_sign!, non_linearity_tanh!, non_linearity_binary!
@compat public @make_sampler
@compat public sampler!

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
include("setup.jl")
include("workspace.jl")

include("non_linearity.jl")
include("sampler.jl")

end # module