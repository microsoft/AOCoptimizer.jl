#=
engine.jl

Custom code for using CUDA as the engine for the solver

=#

KernelAbstractions.get_backend(::AOCoptimizer.Solver.EngineCuda) = CUDABackend()

function _register_cuda_engines()
    if !CUDA.functional()
        @warn "CUDA is not functional, skipping CUDA engine registration"
        return
    end
    if !CUDA.has_cuda()
        @warn "CUDA is not available, skipping CUDA engine registration"
        return
    end

    for id in CUDA.devices()
        @info "Registered CUDA engine with ID: $id"
        engine = AOCoptimizer.Solver.EngineCuda(id.handle)
        AOCoptimizer.Solver._add_engine(engine, 200)
    end
end

_register_cuda_engines()
