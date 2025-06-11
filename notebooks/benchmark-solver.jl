#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmark the implementation of the solver

# First, set up the environment
using Revise
using BenchmarkTools
using CUDA
using Dates
using LinearAlgebra
using Random
using AOCoptimizer
using AOCoptimizer.Solver

include("utils.jl")

CUDA.allowscalar(false)
AOCoptimizer.init()

# Define the size of the problem and other parameters

T = Float32;
n = 800;
number_of_experiments = 2048;
dt = T(0.1);
batch_size = 256;
iterations = 500;
repetitions = 4;

graph = create_random_graph(T, n);

sol = AOCoptimizer.Solver.solve(Float32, graph, Second(60));