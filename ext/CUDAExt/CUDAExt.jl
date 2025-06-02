
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

using CUDA: CuArray, CuVector, NVML, CUDABackend

"""
    _get_cuda_info()::Dict{String,Any}

Get information about the CUDA environment, if available.
"""
function AOCoptimizer.Environment._get_cuda_info()::Dict{String,Any}
    if !CUDA.has_cuda()
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
    CUDA.@cuda threads=nthreads blocks=nblocks check_and_set!()
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
    CUDA.@cuda threads=nthreads blocks=nblocks check_and_set!()
    return nothing
end

end # module CUDAExt