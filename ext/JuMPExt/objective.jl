#=
objective.jl

Specifies the objective functions supported by the optimizer.
The optimization function can be either an affine or a quadratic function.
The optimization goal is either to minimize or maximize the objective function.
=#

MOI.get(optimizer::Optimizer, ::MOI.ObjectiveSense) = optimizer.sense

function MOI.set(optimizer::Optimizer, ::MOI.ObjectiveSense, value::MOI.OptimizationSense)
    @assert value in (MOI.MAX_SENSE, MOI.MIN_SENSE)

    optimizer.sense = value
    return nothing
end

"""Optimization can be configured with an optimization sense"""
MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
"""Optimizer supports optimization over a single variable"""
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{VI}) = true
"""Optimizer support optimization of linear and quadratic functions"""
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{F}) where {T,F<:Union{SAF{T},SQF{T}}} = true
