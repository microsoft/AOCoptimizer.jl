#=
init.jl

=#

function init()
    @info "Initializing AOCoptimizer..."

    Solver.__register_non_linearities()
    return
end
