#=
Solver.jl

Main module for the AOC software solver.
=#

module Solver

using Adapt
using ArnoldiMethod: Target, LR, SR, partialschur
using BFloat16s
using Compat
using DataStructures
using Dates
using Distributions
using IntervalSets
using KernelAbstractions
using LinearAlgebra
using OrderedCollections
using Printf
using Random
using Sobol
using SparseArrays

@compat public @make_wall, enforce_inelastic_wall!
@compat public enforce_inelastic_wall_ising!, enforce_inelastic_wall_positive!
@compat public calculate_energies!, calculate_energies
@compat public Problem, make_problem
@compat public Setup, make_empty_setup, make_setup
@compat public Workspace, make_workspace, initialize_workspace!
@compat public @make_non_linearity
@compat public non_linearity_sign!, non_linearity_tanh!, non_linearity_binary!
@compat public @make_sampler
@compat public sample_mixed_ising!, sample_positive_qumo!, sample_qumo!
@compat public ConfigurationSpace, sample_configuration_space, sample_single_configuration
@compat public SamplerTracer, sample_qumo_with_tracer!, sample_mixed_ising_with_tracer!
@compat public @make_exploration
@compat public explore_mixed_ising, explore_positive_qumo, explore_qumo
@compat public PhaseInfo, PhaseStatistics
@compat public get_engines, best_engine, get_current_engine, set_current_engine
@compat public @make_solver, solve_mixed_ising, solve_positive_qumo, solve_qumo
@compat public find_best, search_for_best_configuration, get_solver_results_summary
@compat public extract_runtime_information

using ..AOCoptimizer: CancellationToken, is_cancelled
using ..AOCoptimizer.RuntimeUtils: run_for

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
include("engine.jl")
include("estimators.jl")
include("phase_stats.jl")
include("normalization.jl")
include("core.jl")
include("results_stats.jl")

end # module