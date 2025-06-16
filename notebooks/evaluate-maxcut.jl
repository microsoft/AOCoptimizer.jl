#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}

# # Evaluate solver  performance on MaxCut problems.
#
# Input problems are from the G-Set library. For many of these problems,
# the optimal solution is known; for the rest, there are best-known solutions.

using Revise
using CUDA
using CSV
using DataFrames
using Dates
using LinearAlgebra
using SparseArrays
using AOCoptimizer
using AOCoptimizer.Solver

CUDA.allowscalar(false)
AOCoptimizer.init()

T = Float32;

input_path = joinpath(@__DIR__, "..", "data", "GSet");

reference_file = joinpath(input_path, "reference.csv");
baseline = CSV.read(reference_file, DataFrame);

filename = "G1";
input_file = joinpath(input_path, filename);
graph = AOCoptimizer.FileFormats.read_graph_matrix(input_file);
graph = T.(graph);

timeout = Second(100);

engine = AOCoptimizer.Solver.EngineCuda(0);
sol = AOCoptimizer.Solver.solve(T, -graph, timeout; engine=engine);
perf = AOCoptimizer.Solver.get_solver_results_summary(sol);
max_cut = AOCoptimizer.graph_cut_from_hamiltonian(graph, perf.obj_best_found);
