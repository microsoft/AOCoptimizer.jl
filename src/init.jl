#=
init.jl

=#

function init()
    @debug "Initializing AOCoptimizer..."

    Solver.__register_non_linearities()
    Solver.__register_engines()
    Solver.__register_solvers()

    @debug "End of AOCoptimizer initialization."
    return
end
