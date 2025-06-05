#=
init.jl

=#

function init()
    @info "Initializing AOCoptimizer..."

    Solver.register_non_linearities()
end
