#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmark the implementation of the exploration function

using Revise
using BenchmarkTools
using CUDA
using LinearAlgebra
using Random
using AOCoptimizer
using AOCoptimizer.Solver

include("utils.jl")

CUDA.allowscalar(false)
AOCoptimizer.init()

T = Float32;
n = 800;
number_of_experiments = 2048;
dt = T(0.1);
batch_size = 256;
iterations = 500;
repetitions = 4;

# Cancellation token not really used in this benchmark, but required for the setup
ctx = AOCoptimizer.CancellationToken();

rng = Random.default_rng();

graph = create_random_graph(T, n);

interactions = copy(graph);
problem = AOCoptimizer.Solver.Problem(interactions);
annealing, gradient, momentum = AOCoptimizer.Solver.sample_configuration_space(T, 128);
setup = AOCoptimizer.Solver.make_setup(annealing, gradient, momentum, dt, 16);

result = AOCoptimizer.Solver.exploration(
    problem,
    setup,
    batch_size,
    ctx,
    iterations,
    repetitions,
    rng
);


g_problem = adapt(CUDA.CUDABackend(), problem);
g_setup = adapt(CUDA.CUDABackend(), setup);
CUDA.synchronize();

g_result = AOCoptimizer.Solver.exploration(
    g_problem,
    g_setup,
    batch_size,
    ctx,
    iterations,
    repetitions,
    rng
);
