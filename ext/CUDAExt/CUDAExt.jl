
#=
CUDAExt.jl

CUDA specific extensions to the `AOCoptimizer.jl` package.
=#

module CUDAExt

import CUDA
import AOCoptimizer
import AOCoptimizer.Environment

using CUDA: CuArray, CuVector, NVML

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

end # module CUDAExt