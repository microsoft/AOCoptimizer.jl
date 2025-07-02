#=
JuMPExt.jl

Extensions to allow the integration of the AOC optimizer with the JuMP framework.
In reality, the extensions depend only on MathOptInterface, but will mostly be
used through JuMP.

The code implemented allows the user to use the AOC optimizer to solve "almost"-QUMO problems.
This extension will transform the "almost"-QUMO problems to QUMO, and then invoke the
AOCoptimizer solver to solve them. Below we implement very simple transformations.

The code below is adapted by the work of Pedro
=#

module JuMPExt

using LinearAlgebra
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

const Engine = AOC.Solver.Engine
const aoc_api = AOC.api

include("variables.jl")
include("wrapper.jl")

end # module