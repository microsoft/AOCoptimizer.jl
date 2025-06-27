#=
wrapper.jl

=#

"""
    Optimizer{T} <: MOI.AbstractOptimizer

This struct is responsible for integrating AOCoptimizer with MathOptInterface,
which is how we can build a solver that can be used by JuMP models.

```julia
using JuMP
using AOCoptimizer

model = Model(AOCoptimizer.Optimizer)

@variable(model, x[1:5], Bin)
@variable(model, -2 <= y[1:5] <= 2)

@objective(model, Max, sum(x) - sum(y) + 2 * x'y)

optimize!(model)
```
"""
mutable struct Optimizer{T} <: MOI.AbstractOptimizer
    sense::MOI.OptimizationSense

    quadratic::Matrix{T}
    linear::Union{Vector{T},Nothing}
    offset::T
    continuous::Union{Vector{Bool},Nothing}

    moi_attributes::Dict{Symbol,Any}
    raw_attributes::Dict{String,Any}
    aim_attributes::Dict{Symbol,Any}

    variable_map::Dict{VI,Int}
    variable_info::VariableInfo{T}

    fixed::Dict{VI,T}

    output::Union{Dict{String,Any},Nothing}

    function Optimizer{T}() where {T}
        return new{T}(
            MOI.MIN_SENSE,          # sense
            Matrix{T}(undef, 0, 0), # quadratic
            nothing,                # linear
            zero(T),                # offset
            nothing,                # continuous
            Dict{Symbol,Any}( # moi - default
                :name           => "",
                :silent         => false,
                :time_limit_sec => nothing,
            ),
            Dict{String,Any}(),
            Dict{Symbol,Any}( # aim - default
                :seed => 0,
            ),
            Dict{VI,Int}(),         # variable_map
            Dict{VI,Variable{T}}(), # variable_info
            Dict{VI,T}(),           # fixed variables
            nothing,
        )
    end

    Optimizer() = Optimizer{Float64}()
end

function MOI.empty!(optimizer::Optimizer{T}) where {T}
    optimizer.sense      = MOI.MIN_SENSE
    optimizer.quadratic  = Matrix{T}(undef, 0, 0)
    optimizer.linear     = nothing
    optimizer.offset     = zero(T)
    optimizer.continuous = nothing
    optimizer.output     = nothing

    Base.empty!(optimizer.variable_map)
    Base.empty!(optimizer.variable_info)
    Base.empty!(optimizer.fixed)

    return optimizer
end

function MOI.is_empty(optimizer::Optimizer{T}) where {T}
    return isempty(optimizer.quadratic)     &&
           isnothing(optimizer.linear)      &&
           isnothing(optimizer.continuous)  &&
           iszero(optimizer.offset)         &&
           isempty(optimizer.variable_map)  &&
           isempty(optimizer.variable_info) &&
           isempty(optimizer.fixed)
end

function Base.show(io::IO, ::Optimizer)
    return print(io, "AOC Optimizer")
end
