#=
environment.jl

Capture properties of the environment

=#

module Environment

using CpuId
using Compat

@compat public local_system_info

function _get_cuda_info end

"""
    local_system_info()::Dict{String,Any}

Capture the local system information and return it as a dictionary.
"""
function local_system_info()::Dict{String,Any}
    local_system = Dict{String,Any}()
    local_system["hostname"] = gethostname()
    local_system["os"] = Sys.KERNEL
    local_system["arch"] = Sys.ARCH

    local_system["cpu"] = Dict{String,Any}()
    local_system["cpu"]["vendor"] = cpuvendor()
    local_system["cpu"]["nodes"] = CpuId.cpunodes()
    local_system["cpu"]["threads"] = Sys.CPU_THREADS
    local_system["cpu"]["brand"] = cpubrand()
    local_system["cpu"]["cores"] = cpucores()
    local_system["cpu"]["cores_total"] = cputhreads()
    local_system["cpu"]["architecture"] = cpuarchitecture()
    local_system["cpu"]["features"] = collect(cpufeatures())

    local_system["julia"] = Dict{String,Any}()
    local_system["julia"]["version"] = VERSION
    local_system["julia"]["arch"] = Sys.ARCH
    local_system["julia"]["os"] = Sys.KERNEL

    if isdefined(Main, :CUDA)
        local_system["cuda"] = _get_cuda_info()
    end

    return local_system
end

end