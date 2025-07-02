#=
constraints.jl

Specifies the constraints supported by the optimizer.
At this low level, we only support the following constraints:
- Binary variables
- Continuous variables with lower and upper bounds.
  Observe that both need to be specified (i.e., no unbounded variables).
=#

"""Optimizer supports binary variables"""
function MOI.supports_constraint(
    ::Optimizer,
    ::Type{VI},
    ::Type{MOI.ZeroOne},
)
    return true
end

"""Optimizer supports continuous variables with lower and upper bounds"""
function MOI.supports_constraint(
    ::Optimizer{T},
    ::Type{VI},
    ::Type{F},
) where {T,F<:Union{EQ{T},LT{T},GT{T},MOI.Interval{T}}}
    return true
end

"""Optimizer does not support generic constraints"""
function MOI.supports_constraint(
    ::Optimizer,
    ::Type{S},
    ::Type{F},
) where {S<:MOI.AbstractSet,F<:MOI.AbstractFunction}
    return false
end
