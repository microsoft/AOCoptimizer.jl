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


KernelAbstractions.get_backend(::Engine) = CPU()
KernelAbstractions.get_backend(::EngineLocalCpu) = CPU()

_engines = PriorityQueue{Engine, Int}()

_engine_local = EngineLocalCpu()
push!(_engines, _engine_local => 1000)

function _add_engine(engine::Engine, priority::Int)
    push!(_engines, engine => priority)
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

const current_engine, set_current_engine = let
    _current_engine = nothing

    function current_engine()
        if _current_engine === nothing
            _current_engine = _best_engine()
        end
        return _current_engine
    end

    function set_current_engine(engine::Engine)
        if !haskey(_engines, engine)
           error("Engine not registered: $engine")
        end
        _current_engine = engine
        return
    end

    return current_engine, set_current_engine
end
