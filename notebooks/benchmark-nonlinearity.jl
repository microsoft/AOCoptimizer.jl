#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmark implementation of non-linearity functions

using Revise
using BenchmarkTools
using CUDA
using JSON

using AOCoptimizer
using AOCoptimizer.Solver
using AOCoptimizer.Environment: local_system_info

CUDA.allowscalar(false)
AOCoptimizer.init()

# Create a random array for testing
x_reference = rand(5000, 1024);

# ## Benchmark on the CPU

# Check the `sign` function
@benchmark Solver.non_linearity_sign!(x) setup=(x = copy($x_reference))

# Then, the `tanh` function. Observe that this is way more expensive than `sign`.
@benchmark Solver.non_linearity_tanh!(x) setup=(x = copy($x_reference))

# Finally, the `binary` function
@benchmark Solver.non_linearity_binary!(x) setup=(x = copy($x_reference))

# Define and use a custom non-linearity function
amplified_tanh(x::T) where {T<:Real} = tanh(T(2.0) * x)
Solver.@make_non_linearity("amplified_tanh", amplified_tanh)
@benchmark amplified_tanh!(x) setup=(x = copy($x_reference))

# ## Benchmark on the GPU
cx_reference = cu(x_reference);

cx = copy(cx_reference)
CUDA.synchronize()

# Check the `sign` function
CUDA.@bprofile begin
    Solver.non_linearity_sign!(cx)
    CUDA.synchronize()
end

# Then, the `tanh` function
CUDA.@bprofile begin
    Solver.non_linearity_tanh!(cx)
    CUDA.synchronize()
end

# Finally, the `binary` function
CUDA.@bprofile begin
    Solver.non_linearity_binary!(cx)
    CUDA.synchronize()
end

# Check now the custom non-linearity function
CUDA.@bprofile begin
    amplified_tanh!(cx)
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
