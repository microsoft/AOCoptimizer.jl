#=
JuMPExt.jl


=#

module JuMPExt

import MathOptInterface as MOI
import MathOptInterface: is_empty, empty!, optimize!
import AOCoptimizer as AOC

export Optimizer

const MOIU    = MOI.Utilities
const VI      = MOI.VariableIndex
const CI{S,F} = MOI.ConstraintIndex{S,F}
const EQ{T}   = MOI.EqualTo{T}
const LT{T}   = MOI.LessThan{T}
const GT{T}   = MOI.GreaterThan{T}
const SAT{T}  = MOI.ScalarAffineTerm{T}
const SAF{T}  = MOI.ScalarAffineFunction{T}
const SQT{T}  = MOI.ScalarQuadraticTerm{T}
const SQF{T}  = MOI.ScalarQuadraticFunction{T}

include("variables.jl")
include("wrapper.jl")

end # module