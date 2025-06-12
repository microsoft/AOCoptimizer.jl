#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmark the implementation of the exploration function

# First, set up the environment
using Revise
using BenchmarkTools
using CUDA
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

# Cancellation token not really used in this benchmark, but required for the setup
ctx = AOCoptimizer.CancellationToken();

rng = Random.default_rng();

graph = create_random_graph(T, n);

# Create inputs; these will be used to process in CPU
interactions = copy(graph);
problem = AOCoptimizer.Solver.Problem(interactions);
annealing, gradient, momentum = AOCoptimizer.Solver.sample_configuration_space(T, 128);
setup = AOCoptimizer.Solver.make_setup(annealing, gradient, momentum, dt, 16);

# ## Run in the CPU

@benchmark begin
    result = AOCoptimizer.Solver.exploration(
        problem,
        setup,
        batch_size,
        ctx,
        iterations,
        repetitions,
        rng
    );
end

# ## Run in the CPU

# Convert the problem to work with CUDA

g_problem = adapt(CUDA.CUDABackend(), problem);
g_setup = adapt(CUDA.CUDABackend(), setup);
CUDA.synchronize();

# Benchmark the exploration function in the GPU
CUDA.@bprofile begin
    g_result = AOCoptimizer.Solver.exploration(
        g_problem,
        g_setup,
        batch_size,
        ctx,
        iterations,
        repetitions,
        rng
    );
    CUDA.synchronize();
end

# ## Run with a custom sampler

amplified_tanh(x::T) where {T<:Real} = tanh(T(2.0) * x)
Solver.@make_non_linearity("amplified_tanh", amplified_tanh)
Solver.@make_sampler(my_sampler, amplified_tanh!, AOCoptimizer.Solver.enforce_inelastic_wall_ising!, 0, mul!)
Solver.@make_exploration(my_exploration, my_sampler!)

# First, run in the CPU
@benchmark begin
    result = my_exploration(
        problem,
        setup,
        batch_size,
        ctx,
        iterations,
        repetitions,
        rng
    );
end

# Run also in the GPU with CUDA
CUDA.@bprofile begin
    g_result = my_exploration(
        g_problem,
        g_setup,
        batch_size,
        ctx,
        iterations,
        repetitions,
        rng
    );
    CUDA.synchronize()
end

# ## System information
#
# The benchmark was run on the following system:
info = local_system_info()
println(JSON.json(info, 4))

# The benchmark was completed at the following date and time:
datetime = Dates.now()
println("Benchmark completed at: ", datetime)
