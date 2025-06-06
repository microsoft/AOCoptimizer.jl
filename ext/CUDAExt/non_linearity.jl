#=
non_linearity.jl


=#

function AOCoptimizer.Solver._cuda_non_linearity_extension_code(::AOCoptimizer.Solver.BackendCuda, fn_sym, fn)
    @inline function launch_kernel(nthreads, nblocks, kernel)
        CUDA.@cuda threads=nthreads blocks=nblocks kernel()
        return
    end

    quote
        # Definitions of this environment that need to be available
        # when the macro is expanded
        const CuMat = $(CUDA.CuMatrix)
        const CuArr = $(CUDA.CuArray)
        const DevMem = $(CUDA.DeviceMemory)
        const CuBackend = $(CUDA.CUDABackend)
        const CuBlockIdx = $(CUDA.blockIdx)
        const CuBlockDim = $(CUDA.blockDim)
        const CuThreadIdx = $(CUDA.threadIdx)
        const CuDevice = $(CUDA.device)
        const CuAttribute = $(CUDA.attribute)
        const CuDevAttrMaxThreadsPerBlock = $(CUDA.DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK)

        @inline function $(esc(fn_sym))(
            binaries::Union{
                CuMat{T},
                SubArray{
                    T,
                    2,
                    CuArr{T,2,DevMem},
                    Tuple{UnitRange{Int64},Base.Slice{Base.OneTo{Int64}}},
                    false,
                },
            },
        ) where {T<:Real}
            lx = length(binaries)
            if lx == 0 return nothing end

            function check_and_set!()
                index = (CuBlockIdx().x - 1) * CuBlockDim().x + CuThreadIdx().x
                if index > lx return nothing end
                @inbounds binaries[index] = $(esc(fn))(binaries[index])
                return nothing
            end

            device = CuDevice(binaries)
            nthreads = CuAttribute(device, CuDevAttrMaxThreadsPerBlock)
            nblocks = cld(lx, nthreads)
            # @cuda threads=nthreads blocks=nblocks check_and_set!()
            $(launch_kernel)(nthreads, nblocks, check_and_set!)
            return nothing
        end

        @inline function $(esc(fn_sym))(::CuBackend, x::AbstractArray)
            $(esc(fn_sym))(x)
        end
    end
end