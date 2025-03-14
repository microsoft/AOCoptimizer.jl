#=
Algorithms.jl

Collection of other algorithms and heuristics for QUMO, QUBO, Ising, and Mixed-Ising problems.

=#

module Algorithms

using Compat

@compat public EnhancedRandom

include("enhanced_random.jl")

end