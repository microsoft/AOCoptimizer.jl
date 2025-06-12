#=
engine.jl

Holds information related to the execution environment that
will be used by the solver.

=#

abstract type Engine end

struct EngineLocalCpu <: Engine end
struct EngineCuda <: Engine
    id::Integer
end

Base.string(::Engine) = "Generic Engine"
Base.string(::EngineLocalCpu) = "Local CPU Engine"


KernelAbstractions.get_backend(::Engine) = CPU()
KernelAbstractions.get_backend(::EngineLocalCpu) = CPU()

const _engines = PriorityQueue{Engine, Int}()
const _current_engine = Ref{Union{Engine, Nothing}}(nothing)

function _register_engine(::Type{<:Engine})::Nothing
    return
end
function _register_engine(::Type{<:EngineLocalCpu})::Nothing
    @info "Registering local CPU engine"
    _add_engine(EngineLocalCpu(), 1000)
    return
end

function __register_engines()::Nothing
    @info "Registering engines"
    _register_engine(EngineLocalCpu)
    _register_engine(EngineCuda)
    return
end

function _add_engine(engine::Engine, priority::Int)::Nothing
    push!(_engines, engine => priority)
    return
end

function get_engines()
    return collect(keys(_engines))
end

function best_engine()
    if isempty(_engines)
        error("No engines registered")
    end
    return first(_engines)[1]
end

function get_current_engine()
    if _current_engine[] === nothing
        _current_engine[] = best_engine()
    end
    return _current_engine[]
end

function set_current_engine()::Nothing
    _current_engine[] = best_engine()
    return
end

function set_current_engine(engine::Engine)::Nothing
    if !haskey(_engines, engine)
        error("Engine not registered: $engine")
    end
    _current_engine[] = engine
    return
end
