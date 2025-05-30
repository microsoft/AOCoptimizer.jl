#= benchmark-clamping.jl

The purpose of this notebook is to investigate the various techniques for performing clamping,
    i.e. making sure that the spins take values in the range -1 to 1.

Additionally, we also want to make sure that when the spins indeed are limiting to either -1 or 1,
the corresponding momentum (i.e. the momentum for the same spin) take a value of 0.0.
I.e. the rate of changing the spins is zero, and we implement elastic walls.

=#

using Revise
using BenchmarkTools
import CUDA
using KernelAbstractions

CUDA.allowscalar(false)

#=
CPU based implementation
=#

@inline function enforce_inelastic_wall!(
    x::AbstractArray{T,N};
    limit = T(1.0),
) where {T<:Real,N}
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
    x::AbstractArray{T,N};
    limit = T(1.0),
) where {T<:Real,N}
    @assert length(x) == length(y)

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
    x::AbstractArray{T,N},
    limit = T(1.0),
) where {T<:Real,N}
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
    y::AbstractArray{T,N},
    limit = T(1.0),
) where {T<:Real,N}
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
    x::AbstractArray{T,N};
    limit = T(1.0),
) where {T<:Real,N}
    backend = get_backend(x)
    kernel = enforce_inelastic_wall_kernel!(backend)
    kernel(x, limit, ndrange = size(x))
    synchronize(backend)
    return
end

function enforce_inelastic_wall_with_kernel!(
    x::AbstractArray{T,N},
    y::AbstractArray{T,N};
    limit = T(1.0),
) where {T<:Real,N}
    @assert length(x) == length(y)

    backend = get_backend(x)
    @assert get_backend(y) == backend

    kernel = enforce_inelastic_wall_kernel!(backend)
    kernel(x, y, limit, ndrange = size(x))
    synchronize(backend)
    return
end

@inline function combine_clamp!(
    y::AbstractArray{T,N},
    x::AbstractArray{T,N};
    limit = T(1.0),
) where {T<:Real,N}
    r = range(1, length(x))
    @. y[r] = ifelse(x[r] > limit, zero(T), ifelse(x[r] < -limit, zero(T), y[r]))
    clamp!(x, -limit, limit)
    return x, y
end

T = Float32
matrix_size = 4 * 1024
experiments = 8 * 1024

cpu_x = rand(T, matrix_size, experiments)
cpu_y = rand(T, matrix_size, experiments)

@benchmark clamp!(cpu_x, T(-1.0), T(1.0))
@benchmark enforce_inelastic_wall!(cpu_x)
@benchmark enforce_inelastic_wall_with_kernel!(cpu_x)

@benchmark combine_clamp!(cpu_x, cpu_y)
@benchmark enforce_inelastic_wall!(cpu_x, cpu_y)
@benchmark enforce_inelastic_wall_with_kernel!(cpu_x, cpu_y)

#= Performance results

Values are <minimum> / <median> .. <mean> / <maximum> / <stddev>
koufalia, enforce_inelastic_wall!, X only, Float16, 4096,  8192: (ms)  25.362 /  26.082 ..  27.318 /  45.123 /  3.278
koufalia, enforce_inelastic_wall!, X only, Float16, 4096,  8192: (ms)  25.253 /  26.250 ..  27.327 /  51.085 /  3.277
koufalia, clamp!,                  X only, Float16, 4096,  8192: (ms)  32.195 /  33.339 ..  36.127 /  59.662 /  6.044
koufalia, clamp!,                  X only, Float16, 4096,  8192: (ms)  31.985 /  32.696 ..  34.061 /  56.559 /  3.801
koufalia, enforce_inelastic_wall!, X only, Float16, 8192, 16384: (ms) 104.455 / 113.211 .. 115.150 / 157.040 / 10.538
koufalia, clamp!,                  X only, Float16, 8192, 16384: (ms) 128.307 / 133.122 .. 138.190 / 160.918 / 10.120
koufalia, enforce_inelastic_wall!, X only, Float16, 5000, 50000: (ms) 191.835 / 205.689 .. 205.972 / 248.842 / 13.970
koufalia, clamp!,                  X only, Float16, 5000, 50000: (ms) 241.027 / 246.758 .. 252.415 / 285.249 / 12.531

koufalia, enforce_inelastic_wall!, X & Y,  Float16, 4096,  8192: (ms)  21.820 /  22.620 ..  23.473 /  39.586 /  2.690
koufalia, combine_clamp!,          X & Y,  Float16, 4096,  8192: (ms) 154.374 / 167.186 .. 171.530 / 194.786 / 10.553 (with quite a bit of memory allocations)


Summary: Our custom implementation is faster than using clamp!.
=#







#= GPU based implementations
=#

const _MAX_THREADS_PER_BLOCK =
    CUDA.attribute(CUDA.device(), CUDA.DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK)

@inline function enforce_inelastic_wall!(
    x::CUDA.CuArray{T,N};
    limit = T(1.0),
    nthreads::Integer = _MAX_THREADS_PER_BLOCK,
) where {T<:Real,N}

    lx = length(x)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
        # We could get away with the following check,
        # should we had reserved a bit of extra capacity
        # to guarantee that the x[index] will not write
        # random memory.
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
    x::CUDA.CuArray{T,N};
    limit = T(1.0),
    nthreads::Integer = _MAX_THREADS_PER_BLOCK,
) where {T<:Real,N}
    @assert length(x) == length(y)

    lx = length(x)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
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

function maptrim!(x::CUDA.CuArray{T,N}) where {T<:Real} where {N}
    map!(trim, x, x)
    return nothing
end

function maptrim!(x::CUDA.CuDeviceArray{T,1}) where {T<:Real}
    map!(trim, x, x)
    return nothing
end

function myclamp!(A::CUDA.CuArray, B::CUDA.CuArray, low, high, nthreads::Integer=_MAX_THREADS_PER_BLOCK)
    @assert length(A) == length(B)
    @assert eltype(A) == eltype(B)

    z = convert(eltype(B), 0.0)
    lx = length(A)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
        if index > lx
            return nothing
        end

        @inbounds B[index] = ifelse(A[index] > high, z, ifelse(A[index] < low, z, B[index]))
        @inbounds A[index] = clamp(A[index], low, high)

        return
    end

    nblocks = cld(length(A), nthreads)
    CUDA.@cuda threads = nthreads blocks = nblocks check_and_set!()

    return nothing
end

T = Float32
matrix_size = 4 * 1024
experiments = 64 * 1024

gpu_x = CUDA.randn(T, matrix_size, experiments)
gpu_y = CUDA.randn(T, matrix_size, experiments)
CUDA.synchronize()

function catchme()
try
    enforce_inelastic_wall!(gpu_x)
    return nothing
catch err
    return err
end
end

err = catchme()

CUDA.@bprofile begin
    enforce_inelastic_wall!(gpu_x)
    CUDA.synchronize()
end
CUDA.@bprofile begin
    maptrim!(gpu_x)
    CUDA.synchronize()
end
CUDA.@bprofile begin
    clamp!(gpu_x, T(-1.0), T(1.0))
    CUDA.synchronize()
end
CUDA.@bprofile begin
    enforce_inelastic_wall_with_kernel!(gpu_x)
    # We already synchronize in the function
    # CUDA.synchronize()
end


CUDA.@bprofile begin
    enforce_inelastic_wall!(gpu_x, gpu_y)
    CUDA.synchronize()
end
CUDA.@bprofile begin
    myclamp!(gpu_x, gpu_y, T(-1.0), T(1.0))
    CUDA.synchronize()
end
CUDA.@bprofile begin
    enforce_inelastic_wall_with_kernel!(gpu_x, gpu_y)
    # We already synchronize in the function
    # CUDA.synchronize()
end

#= Performance results

Values are <minimum> / <median> .. <mean> / <maximum> / <stddev>
koufalia, enforce_inelastic_wall!, X only, Float16, 4096,  8192: (μs)   4.300 / 328.817 .. 254.554 / 790.250 / 140.695
koufalia, enforce_inelastic_wall!, X only, Float16, 4096,  8192: (μs)   4.100 / 390.790 .. 253.412 / 786.780 / 187.885
koufalia, clamp!,                  X only, Float16, 4096,  8192: (μs)   6.350 / 477.500 .. 287.891 / 1.563ms / 238.769
koufalia, clamp!,                  X only, Float16, 4096,  8192: (μs)   6.300 / 476.050 .. 286.315 / 902.950 / 235.463
koufalia, enforce_inelastic_wall!, X only, Float16, 4096, 65536: (μs)   4.500 / 2.002ms .. 1.915ms / 2.603ms / 678.850
koufalia, clamp!,                  X only, Float16, 4096, 65536: (μs)   6.725 / 2.492ms .. 2.198ms / 3.018ms / 738.849
koufalia, maptrim!,                X only, Float16, 4096, 65536: (μs)   7.267 / 4.670ms .. 4.461ms / 7.984ms / 1.153ms
koufalia, enforce_inelastic_wall!, X & Y,  Float16, 4096, 65536: (μs)   4.700 / 2.191ms .. 1.995ms / 2.669ms / 652.787
koufalia, clamp!,                  X & Y,  Float16, 4096, 65536: (μs)   6.240 / 4.007ms .. 3.749ms / 4.601ms / 1.194ms

Again, the enforce_inelastic_wall! seems to work better.
A few samples using A100 also suggest that enforce_inelastic_wall! is faster.
=#

#= Examine generated code
=#

CUDA.@device_code_sass enforce_inelastic_wall_with_kernel!(gpu_x)
CUDA.@device_code_sass enforce_inelastic_wall!(gpu_x)
CUDA.@device_code_sass maptrim!(gpu_x)
CUDA.@device_code_sass (clamp!(x, Float16(-1.0), Float16(1.0)))

# TODO: Are there any tools to help us reason about the output?
