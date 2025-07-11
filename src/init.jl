#=
init.jl

=#

module MOI
    Optimizer :: Ref{Any} = nothing

    """
        init()

    Enables the AOCoptimizer backend for MathOptInterface (MOI), if available.
    Typically, users should not call this explicitly. Instead, the `JuMP` and `MathOptInterface`
    packages should be imported before importing `AOCoptimizer` and
    calling `AOCoptimizer.init()`.
    """
    function init()
        __modules = Base.loaded_modules_array()
        __index_of_jump_ext = findfirst(x -> nameof(x) == :JuMPExt, __modules)
        if __index_of_jump_ext === nothing
            # JuMPExt is not loaded, leaving value to `nothing`
            Optimizer[] = nothing
        else
            __jump_ext = __modules[__index_of_jump_ext]
            Optimizer[] = __jump_ext.Optimizer
        end

        return nothing
    end
end

const __init_completed::Ref{Bool} = Ref(false)

function init()
    @debug "Initializing AOCoptimizer..."

    if __init_completed[]
        @warn "AOCoptimizer already initialized, skipping"
        return
    end

    Solver.__register_non_linearities()
    Solver.__register_engines()
    Solver.__register_solvers()

    MOI.init()

    @debug "End of AOCoptimizer initialization."
    __init_completed[] = true
    return
end


