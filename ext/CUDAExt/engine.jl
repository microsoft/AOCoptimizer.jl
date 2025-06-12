#=
engine.jl

Custom code for using CUDA as the engine for the solver

=#

KernelAbstractions.get_backend(::AOCoptimizer.Solver.EngineCuda) = CUDABackend()

function AOCoptimizer.Solver._register_engine(::Type{<:AOCoptimizer.Solver.EngineCuda})::Nothing
    @info "Registering CUDA engines for AOCoptimizer.Solver"

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
        engine = AOCoptimizer.Solver.EngineCuda(CUDA.deviceid(id))
        AOCoptimizer.Solver._add_engine(engine, 200)
    end
end

function Base.string(engine::AOCoptimizer.Solver.EngineCuda)
    description = CUDA.name(CUDA.CuDevice(engine.id))
    return "CUDA Engine with ID: $(engine.id), Description: $description"
end

function AOCoptimizer.Solver._optimal_batch_size(
    engine::AOCoptimizer.Solver.EngineCuda,
    problem::AOCoptimizer.Solver.Problem
)::Integer
    # TODO: Have to adapt the following heuristic to the specific hardware.
    return cld(6.0e7 * problem.Size^(-1.381), 1)
end

function AOCoptimizer.Solver._cuda_solver_extension_code(
    ::Type{<:AOCoptimizer.Solver.EngineCuda},
    solver_internal_name, exploration_name
)::Expr

    return quote
        const set_gpu = $(CUDA.device!)

        @inline function $(esc(solver_internal_name))(
                    engine::EngineCuda,
                    problem::Problem{T},
                    setup::Setup{T},
                    batch_size::Integer,
                    rng::AbstractRNG,
                    parameters,
        ) where {T<:Real}
            run_for(
                ctx -> begin
                    set_gpu(engine.id)

                    $(esc(exploration_name))(
                        problem,
                        setup,
                        batch_size,
                        ctx,
                        parameters.Iterations,
                        parameters.Samples,
                        rng,
                    )
                end,
                Second(ceil(parameters.TimeBudget));
                threads = 1,
            )
        end # function
    end # quote
end # function

