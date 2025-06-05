#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Benchmarking clamping techniques in Julia for CPU and GPU

#=
The purpose of this notebook is to investigate the various techniques for performing clamping,
i.e., making sure that the spins take values in the range -1 to 1.

Additionally, we also want to make sure that when the spins indeed are limiting to either -1 or 1,
the corresponding momentum (i.e. the momentum for the same spin) take a value of 0.0.
I.e., the rate of changing the spins is zero, and we implement elastic walls.
=#

using Revise
using BenchmarkTools
import CUDA
using Dates
using KernelAbstractions
using JSON
using AOCoptimizer.Environment: local_system_info
using AOCoptimizer

CUDA.allowscalar(false)
AOCoptimizer.init()

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# ## CPU based implementation


@inline function enforce_inelastic_wall!(
    x::AbstractArray{T,N}
) where {T<:Real,N}
    limit = T(1.0)
    @simd for index in range(1, length = length(x))
        @inbounds if x[index] > limit
            x[index] = limit
        elseif x[index] < -limit
            x[index] = -limit
        end
    end
end

@inline function enforce_inelastic_wall!(
    y::AbstractArray{T,N},
    x::AbstractArray{T,N}
) where {T<:Real,N}
    @assert length(x) == length(y)

    limit = T(1.0)
    @simd for index in range(1, length = length(x))
        @inbounds if x[index] > limit
            x[index] = limit
            y[index] = zero(T)
        elseif x[index] < -limit
            x[index] = -limit
            y[index] = zero(T)
        end
    end
end

@kernel function enforce_inelastic_wall_kernel!(
    x::AbstractArray{T,N}
) where {T<:Real,N}
    limit = T(1.0)
    I = @index(Global)
    @inbounds begin
        if x[I] > limit
            x[I] = limit
        elseif x[I] < -limit
            x[I] = -limit
        end
    end
end

@kernel function enforce_inelastic_wall_kernel!(
    x::AbstractArray{T,N},
    y::AbstractArray{T,N}
) where {T<:Real,N}
    limit = T(1.0)
    I = @index(Global)
    @inbounds begin
        if x[I] > limit
            x[I] = limit
            y[I] = zero(T)
        elseif x[I] < -limit
            x[I] = -limit
            y[I] = zero(T)
        end
    end
end

function enforce_inelastic_wall_with_kernel!(
    x::AbstractArray{T,N}
) where {T<:Real,N}
    backend = get_backend(x)
    kernel = enforce_inelastic_wall_kernel!(backend)
    kernel(x, ndrange = size(x))
    synchronize(backend)
    return
end

function enforce_inelastic_wall_with_kernel!(
    x::AbstractArray{T,N},
    y::AbstractArray{T,N}
) where {T<:Real,N}
    @assert length(x) == length(y)

    backend = get_backend(x)
    @assert get_backend(y) == backend

    kernel = enforce_inelastic_wall_kernel!(backend)
    kernel(x, y, ndrange = size(x))
    synchronize(backend)
    return
end

@inline function combine_clamp!(
    y::AbstractArray{T,N},
    x::AbstractArray{T,N};
) where {T<:Real,N}
    limit = T(1.0)
    r = range(1, length(x))
    @. y[r] = ifelse(x[r] > limit, zero(T), ifelse(x[r] < -limit, zero(T), y[r]))
    clamp!(x, -limit, limit)
    return x, y
end

# Let's benchmark the CPU based implementations

T = Float32;
matrix_size = 4 * 1024;
experiments = 8 * 1024;

cpu_x = rand(T, matrix_size, experiments);
cpu_y = rand(T, matrix_size, experiments);

# ### The default implementation using clamp
#
# This is the more straightforward implementation.
@benchmark clamp!(cpu_x, T(-1.0), T(1.0))

# ### The inelastic wall implementation
#
# This is the the default implementation that we use in the code.
@benchmark enforce_inelastic_wall!(cpu_x)

# ### The inelastic wall implementation with a kernel
#
# Going forward this should become the default implementation,
# as it can target multiple backends (GPUs and CPUs).
# However, it is currently slower than the hand-crafted optimization
# for CUDA. In the case of the CPUs, it is faster than the default implementation,
# because it uses all available hardware threads. However, this may
# create issues as we use thread-level parallelism to run the solver in parallel
# on the CPU.
@benchmark enforce_inelastic_wall_with_kernel!(cpu_x)

# ### Implementation in the code
# The default implementation
@benchmark AOCoptimizer.Solver.enforce_inelastic_wall!(cpu_x, Float32(1.0), Float32(-1.0))

# The Ising shortcut to the walls
@benchmark AOCoptimizer.Solver.enforce_inelastic_wall_ising!(cpu_x)

# The binary shortcut to the walls
@benchmark AOCoptimizer.Solver.enforce_inelastic_wall_binary!(cpu_x)

# ### Two arrays: the inelastic wall implementation with clamp
@benchmark combine_clamp!(cpu_x, cpu_y)

# ### Two arrays: the default inelastic wall implementation
@benchmark enforce_inelastic_wall!(cpu_x, cpu_y)

# ### Two arrays: the inelastic wall implementation with a kernel
@benchmark enforce_inelastic_wall_with_kernel!(cpu_x, cpu_y)

# ### Implementation in the code
# The default implementation

@benchmark AOCoptimizer.Solver.enforce_inelastic_wall!(cpu_x, cpu_y, Float32(1.0), Float32(-1.0))

# The Ising shortcut to the walls
@benchmark AOCoptimizer.Solver.enforce_inelastic_wall_ising!(cpu_x, cpu_y)

# The binary shortcut to the walls
@benchmark AOCoptimizer.Solver.enforce_inelastic_wall_binary!(cpu_x, cpu_y)

# ## GPU based implementations

const _MAX_THREADS_PER_BLOCK =
    CUDA.attribute(CUDA.device(), CUDA.DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK)

@inline function enforce_inelastic_wall!(
    x::CUDA.CuArray{T,N}
) where {T<:Real,N}
    limit = T(1.0)
    lx = length(x)

    nthreads = _MAX_THREADS_PER_BLOCK

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x +
                CUDA.threadIdx().x
        #src # We could get away with the following check,
        #src # should we had reserved a bit of extra capacity
        #src # to guarantee that the x[index] will not write
        #src # random memory.
        if index > lx
            return nothing
        end

        @inbounds begin
            if x[index] > limit
                x[index] = limit
            elseif x[index] < -limit
                x[index] = -limit
            end
        end

        return nothing
    end

    nblocks = cld(lx, nthreads)
    CUDA.@cuda threads=nthreads blocks=nblocks check_and_set!()
    return nothing
end

@inline function enforce_inelastic_wall!(
    y::CUDA.CuArray{T,N},
    x::CUDA.CuArray{T,N}
) where {T<:Real,N}
    @assert length(x) == length(y)

    nthreads = _MAX_THREADS_PER_BLOCK

    limit = T(1.0)
    lx = length(x)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x +
                CUDA.threadIdx().x
        if index > lx
            return nothing
        end

        @inbounds begin
            if x[index] > limit
                x[index] = limit
                y[index] = zero(T)
            elseif x[index] < -limit
                x[index] = -limit
                y[index] = zero(T)
            end
        end

        return nothing
    end

    nblocks = cld(length(x), nthreads)
    CUDA.@cuda threads = nthreads blocks = nblocks check_and_set!()
    return nothing
end

@inline function trim(x::T) where {T<:Real}
    if x > T(1.0)
        return T(1.0)
    elseif x < T(-1.0)
        return T(-1.0)
    else
        return x
    end
end

function map_trim!(x::CUDA.CuArray{T,N}) where {T<:Real} where {N}
    map!(trim, x, x)
    return nothing
end

function map_trim!(x::CUDA.CuDeviceArray{T,1}) where {T<:Real}
    map!(trim, x, x)
    return nothing
end

function my_clamp!(
    A::CUDA.CuArray{T,N}, B::CUDA.CuArray{T,N}
) where {T<:Real,N}
    @assert length(A) == length(B)
    @assert eltype(A) == eltype(B)

    nthreads::Integer=_MAX_THREADS_PER_BLOCK

    low = T(-1.0)
    high = T(1.0)
    lx = length(A)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x +
                CUDA.threadIdx().x
        if index > lx
            return nothing
        end

        @inbounds B[index] = ifelse(A[index] > high,
                                    T(0.0),
                                    ifelse(A[index] < low, T(0.0), B[index]))
        @inbounds A[index] = clamp(A[index], low, high)

        return
    end

    nblocks = cld(length(A), nthreads)
    CUDA.@cuda threads = nthreads blocks = nblocks check_and_set!()

    return nothing
end

# Let's benchmark the GPU based implementations.
# In the following results, pay attention to the time distribution
# reported in the "Device-side activity" section.

T = Float32;
matrix_size = 4 * 1024;
experiments = 64 * 1024;

gpu_x = CUDA.randn(T, matrix_size, experiments);
gpu_y = CUDA.randn(T, matrix_size, experiments);
CUDA.synchronize()

# ### Default GPU implementation
#
CUDA.@bprofile begin
    enforce_inelastic_wall!(gpu_x)
    CUDA.synchronize()
end

# ### Custom implementation using the map_trim! function
CUDA.@bprofile begin
    map_trim!(gpu_x)
    CUDA.synchronize()
end

# ### System-default implementation using clamp
CUDA.@bprofile begin
    clamp!(gpu_x, T(-1.0), T(1.0))
    CUDA.synchronize()
end

# ### Inelastic wall implementation with a kernel.
#
# (observe: no need to synchronize, as we do so in the function)
CUDA.@bprofile enforce_inelastic_wall_with_kernel!(gpu_x)

# ### Implementation in the code
# The default implementation
CUDA.@bprofile begin
    AOCoptimizer.Solver.enforce_inelastic_wall!(gpu_x, Float32(1.0), Float32(-1.0))
    CUDA.synchronize()
end

# The Ising shortcut to the walls
CUDA.@bprofile begin
    AOCoptimizer.Solver.enforce_inelastic_wall_ising!(gpu_x)
    CUDA.synchronize()
end

# The binary shortcut to the walls
CUDA.@bprofile begin
    AOCoptimizer.Solver.enforce_inelastic_wall_binary!(gpu_x)
    CUDA.synchronize()
end


# ### Two arrays: default implementation
CUDA.@bprofile begin
    enforce_inelastic_wall!(gpu_x, gpu_y)
    CUDA.synchronize()
end

# ### Two arrays using clamp!
CUDA.@bprofile begin
    my_clamp!(gpu_x, gpu_y)
    CUDA.synchronize()
end

# ### Two arrays with the inelastic wall implementation with a kernel:
#
# (observe: no need to synchronize, as we do so in the function)
CUDA.@bprofile enforce_inelastic_wall_with_kernel!(gpu_x, gpu_y)

# ### Two arrays: implementation in code
# The default implementation
CUDA.@bprofile begin
    AOCoptimizer.Solver.enforce_inelastic_wall!(gpu_x, gpu_y, Float32(1.0), Float32(-1.0))
    CUDA.synchronize()
end

# The Ising shortcut to the walls
CUDA.@bprofile begin
    AOCoptimizer.Solver.enforce_inelastic_wall_ising!(gpu_x, gpu_y)
    CUDA.synchronize()
end

# The binary shortcut to the walls
CUDA.@bprofile begin
    AOCoptimizer.Solver.enforce_inelastic_wall_binary!(gpu_x, gpu_y)
    CUDA.synchronize()
end

# ## Examine generated code

# To examine the generated code, use one of the following commands:

#=
CUDA.@device_code_sass enforce_inelastic_wall_with_kernel!(gpu_x)

CUDA.@device_code_sass enforce_inelastic_wall!(gpu_x)

CUDA.@device_code_sass map_trim!(gpu_x)

CUDA.@device_code_sass (clamp!(x, T(-1.0), T(1.0)))

=#

# ## System information
#
# The benchmark was run on the following system:
info = local_system_info()
println(JSON.json(info, 4))

# The benchmark was completed at the following date and time:
datetime = Dates.now()
println("Benchmark completed at: ", datetime)
