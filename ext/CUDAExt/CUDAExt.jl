
#=
CUDAExt.jl

CUDA specific extensions to the `AOCoptimizer.jl` package.
=#

module CUDAExt

import CUDA
using KernelAbstractions
import AOCoptimizer
import AOCoptimizer.Environment
import AOCoptimizer.Solver

using CUDA: CuArray, CuVector, NVML, CUDABackend, @cuda, has_cuda
using CUDA.CUSPARSE: CuSparseMatrix

CUDA.device(x::SubArray{T,N,C,D,F}) where {T,N,D,C,F} = CUDA.device(x.parent)

"""
    _get_cuda_info()::Dict{String,Any}

Get information about the CUDA environment, if available.
"""
function AOCoptimizer.Environment._get_cuda_info()::Dict{String,Any}
    if !has_cuda()
        @warn "CUDA is installed but it is not available"
        return Dict{String,Any}()
    end

    try
        cuda_info = Dict{String,Any}()
        devs = NVML.devices()

        # create a string IO buffer and write
        # the output of CUDA.versioninfo() to it
        io = IOBuffer()
        CUDA.versioninfo(io)
        seekstart(io)
        cuda_info["version"] = read(io, String)
        close(io)

        cuda_info["driver"] = CUDA.driver_version()
        cuda_info["runtime"] = CUDA.runtime_version()
        cuda_info["device_count"] = length(devs)

        gpus = []
        for dev in devs
            gpu = Dict{String,Any}()
            gpu["name"] = NVML.name(dev)
            gpu["uuid"] = string(NVML.uuid(dev))
            gpu["memory"] = NVML.memory_info(dev).total
            gpu["clock_info"] = NVML.max_clock_info(dev)
            push!(gpus, gpu)
        end

        cuda_info["gpus"] = gpus

        return cuda_info

    catch e
        @error "Error while querying CUDA: $e"
        return Dict{String,Any}()
    end
end

function AOCoptimizer.hamiltonian(matrix::CuArray, x::CuVector)
    y = x' * matrix
    return -mapreduce(*, +, y, x; init = 0.0) / 2
end

function AOCoptimizer.Solver._enforce_inelastic_wall!(
    ::CUDABackend,
    x::CuArray{T,N},
    upper = T(1.0),
    lower = T(-1.0),
) where {T<:Real,N}
    lx = length(x)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x +
                CUDA.threadIdx().x
        if index > lx
            return nothing
        end

        @inbounds begin
            if x[index] > upper
                x[index] = upper
            elseif x[index] < lower
                x[index] = lower
            end
        end

        return nothing
    end

    device = CUDA.device(x)
    nthreads = CUDA.attribute(device, CUDA.DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK)
    nblocks = cld(lx, nthreads)
    @cuda threads=nthreads blocks=nblocks check_and_set!()
    return nothing
end

function AOCoptimizer.Solver._enforce_inelastic_wall!(
    ::CUDABackend,
    x::CuArray{T,N},
    y::CuArray{T,N},
    upper = T(1.0),
    lower = T(-1.0),
) where {T<:Real,N}
    lx = length(x)
    @assert lx == length(y)

    function check_and_set!()
        index = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x +
                CUDA.threadIdx().x
        if index > lx
            return nothing
        end

        @inbounds begin
            if x[index] > upper
                x[index] = upper
                y[index] = zero(T)
            elseif x[index] < lower
                x[index] = lower
                y[index] = zero(T)
            end
        end

        return nothing
    end

    device = CUDA.device(x)
    nthreads = CUDA.attribute(device, CUDA.DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK)
    nblocks = cld(lx, nthreads)
    @cuda threads=nthreads blocks=nblocks check_and_set!()
    return nothing
end

include("non_linearity.jl")

function AOCoptimizer.Solver.sample_single_configuration!(samples::CuVector{T}, low::T, high::T) where {T<:Real}
    #=
    The algorithm uses array indexing and hence is not suitable for GPUs.
    However, at the same time it is not time-critical, so we can just
    generate the samples on the CPU and copy them to the GPU.
    =#
    vector = Vector{T}(undef, length(samples))
    sample_single_configuration!(vector, low, high)
    samples .= vector
end

AOCoptimizer.Solver._similar_vector(x::CuSparseMatrix, l) = CuVector{eltype(x)}(undef, l)

include("engine.jl")

function AOCoptimizer.api.adjust_inputs_to_engine(
    ::AOCoptimizer.Solver.EngineCuda,
    matrix::AbstractMatrix{T},
    linear::Union{Nothing,AbstractVector{T}} = nothing,
) where T<:Real
    version = CUDA.capability(dev.dev)

    if version < v"5.3" && T === Float16
        @warn "Computing with Float16 on a GPU with compute capability less than 5.3 is not supported. Switching to Float32."
        if linear !== nothing
            linear = Float32.(linear)
        end
        return Float32, Float32.(matrix), linear
    end

    if version < v"8.0" && T === BFloat16
        @warn "Computing with BFloat16 on a GPU with compute capability less than 8.0 is not supported. Switching to Float32."
        if linear !== nothing
            linear = Float32.(linear)
        end
        return Float32, Float32.(matrix), linear
    end

    return T, matrix, linear
end

end # module CUDAExt