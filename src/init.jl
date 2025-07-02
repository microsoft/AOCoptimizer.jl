#=
init.jl

=#

module MOI
    Optimizer :: Ref{Any} = nothing

    function __init()
        __modules = Base.loaded_modules_array()
        __index_of_jump_ext = findfirst(x -> nameof(x) == :JuMPExt, __modules)
        if __index_of_jump_ext === nothing
            # JuMPExt is not loaded, leaving value to `nothing`
            Optimizer[] = nothing
        else
            __jump_ext = __modules[__index_of_jump_ext]
            Optimizer[] = __jump_ext.Optimizer
        end
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

    MOI.__init()

    @debug "End of AOCoptimizer initialization."
    __init_completed[] = true
    return
end


