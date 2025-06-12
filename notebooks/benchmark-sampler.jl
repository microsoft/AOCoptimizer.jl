#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmark the implementation of the sampler

using Revise
using BenchmarkTools
using CUDA
using LinearAlgebra
using Random
using AOCoptimizer
using AOCoptimizer.Solver
using AOCoptimizer.Environment: local_system_info

include("utils.jl")

CUDA.allowscalar(false)
AOCoptimizer.init()

# Setup environment
T = Float32;
n = 800;
number_of_experiments = 2048;

graph = create_random_graph(T, n);

# ## Run in the CPU

interactions = copy(graph);

binaries = size(interactions)[1];
gradient = similar(interactions, number_of_experiments);
momentum = similar(interactions, number_of_experiments);
annealing_orig = similar(interactions, number_of_experiments);

rand!(gradient);
rand!(momentum);

iterations = 200;
annealing_orig .= T(1);

x = similar(interactions, n, number_of_experiments);
y = similar(x);
fields = similar(x);
spins = similar(x);

y .= T(0);
fields .= T(0);
spins .= T(0);

annealing = copy(annealing_orig);
delta = annealing / iterations;
dt = T(0.1);

# Default sampler
@benchmark Solver._sampler_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)

# Binary sampler
@benchmark Solver._sampler_binary_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)

# QUMO sampler
@benchmark Solver._sampler_qumo_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)

# ## Run in an NVIDIA GPU (CUDA)

interactions = cu(graph);

binaries = size(interactions)[1];
gradient = similar(interactions, number_of_experiments);
momentum = similar(interactions, number_of_experiments);
annealing_orig = similar(interactions, number_of_experiments);

rand!(gradient);
rand!(momentum);

iterations = 200;
annealing_orig .= T(1);

x = similar(interactions, n, number_of_experiments);
y = similar(x);
fields = similar(x);
spins = similar(x);

y .= T(0);
fields .= T(0);
spins .= T(0);

annealing = copy(annealing_orig);
delta = annealing / iterations;
dt = T(0.1);

# Default sampler
CUDA.@bprofile begin
    Solver._sampler_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)
    CUDA.synchronize()
end

# Binary sampler
CUDA.@bprofile begin
    Solver._sampler_binary_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)
    CUDA.synchronize()
end

# QUMO sampler
CUDA.@bprofile begin
    Solver._sampler_qumo_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)
    CUDA.synchronize()
end

# ## Work with custom non-linearity

amplified_tanh(x::T) where {T<:Real} = tanh(T(2.0) * x)
Solver.@make_non_linearity("amplified_tanh", amplified_tanh)
Solver.@make_sampler(my_sampler, amplified_tanh!, enforce_inelastic_wall_ising!, 0, mul!)

CUDA.@bprofile begin
    _my_sampler_internal!(interactions, nothing, binaries, gradient, momentum, x, y, fields, spins, annealing, delta, dt, iterations)
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
