#=
init.jl

=#

module MOI
    Optimizer :: Ref{Any} = nothing

    function __init()
        __modules = Base.loaded_modules_array()
        __index_of_jump_ext = findfirst(x -> nameof(x) == :JuMPExt, __modules)
        __jump_ext = __modules[__index_of_jump_ext]
        Optimizer[] = __jump_ext.Optimizer
    end
end

function init()
    @debug "Initializing AOCoptimizer..."

    Solver.__register_non_linearities()
    Solver.__register_engines()
    Solver.__register_solvers()

    MOI.__init()

    @debug "End of AOCoptimizer initialization."
    return
end


