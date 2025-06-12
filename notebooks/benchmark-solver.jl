#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmark the implementation of the solver

# First, set up the environment
using Revise
using BenchmarkTools
using CUDA
using Dates
using JSON
using LinearAlgebra
using Random
using AOCoptimizer
using AOCoptimizer.Solver
using AOCoptimizer.Environment: local_system_info

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

engine_cpu = AOCoptimizer.Solver.EngineLocalCpu();
engine_gpu = AOCoptimizer.Solver.EngineCuda(0);

# sol = AOCoptimizer.Solver.solve(Float32, graph, Second(60));

# ## Benchmark in the CPU

sol = AOCoptimizer.Solver.solve(Float32, graph, Second(60); engine=engine_cpu);
println(JSON.json(AOCoptimizer.Solver.extract_runtime_information(sol), 4))

# ## Benchmark in the GPU
sol = AOCoptimizer.Solver.solve(Float32, graph, Second(60); engine=engine_gpu);
println(JSON.json(AOCoptimizer.Solver.extract_runtime_information(sol), 4))

# ## System information
#
# The benchmark was run on the following system:
info = local_system_info()
println(JSON.json(info, 4))

# The benchmark was completed at the following date and time:
datetime = Dates.now()
println("Benchmark completed at: ", datetime)
