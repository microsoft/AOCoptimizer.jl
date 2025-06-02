#=
Solver.jl

Main module for the AOC software solver.
=#

module Solver

using Compat
using KernelAbstractions

@compat public @make_wall, enforce_inelastic_wall!
@compat public enforce_inelastic_wall_ising!, enforce_inelastic_wall_binary!

include("walls.jl")

end # module