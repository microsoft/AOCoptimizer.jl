#=
Solver.jl

Main module for the AOC software solver.
=#

module Solver

using Adapt
using ArnoldiMethod: Target, LR, SR, partialschur
using BFloat16s
using Compat
using Dates
using Distributions
using IntervalSets
using KernelAbstractions
using LinearAlgebra
using Printf
using Random
using Sobol
using SparseArrays

@compat public @make_wall, enforce_inelastic_wall!
@compat public enforce_inelastic_wall_ising!, enforce_inelastic_wall_binary!
@compat public calculate_energies!, calculate_energies
@compat public Problem, make_problem
@compat public Setup, make_empty_setup, make_setup
@compat public Workspace, make_workspace, initialize_workspace
@compat public @make_non_linearity
@compat public non_linearity_sign!, non_linearity_tanh!, non_linearity_binary!
@compat public @make_sampler
@compat public sampler!
@compat public ConfigurationSpace, sample_configuration_space, sample_single_configuration
@compat public @make_exploration
@compat public explore, explore_with_tracer, collect_exploration_results
@compat public PhaseInfo, PhaseStatistics
@compat public solve, solve_binary, solve_qumo

using ..AOCoptimizer: CancellationToken, is_cancelled

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

# the following files implement the sampler
include("non_linearity.jl")
include("sampler.jl")
include("sampler_tracer.jl")

# the following files implement exploration
include("collectors.jl")
include("exploration.jl")

# the following files implement the solver workflow
include("configuration.jl")
include("estimators.jl")
include("phase_stats.jl")

end # module