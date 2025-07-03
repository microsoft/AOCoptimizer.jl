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

include("attributes.jl")
include("objective.jl")
include("constraints.jl")
include("solutions.jl")

function MOI.supports(::Optimizer{T}, ::Type{X}, ::Type{Y}) where {T,X,Y}
    @error("Do not support ($X, $Y)")

    return false
end

function _copy_attributes!(optimizer, model)
    # Copy attributes
    for attr in MOI.get(model, MOI.ListOfModelAttributesSet())
        if attr isa MOI.ObjectiveFunction
            continue
        end

        if MOI.supports(optimizer, attr)
            MOI.set(optimizer, attr, MOI.get(model, attr))
        else
            throw(MOI.UnsupportedAttribute(attr))
        end
    end

    for attr in MOI.get(model, MOI.ListOfOptimizerAttributesSet())
        if MOI.supports(optimizer, attr)
            MOI.set(optimizer, attr, MOI.get(model, attr))
        else
            throw(MOI.UnsupportedAttribute(attr))
        end
    end

    # Copy variable attributes
    for attr in MOI.get(model, MOI.ListOfVariableAttributesSet())
        if attr isa MOI.VariableName
            continue
        end

        if MOI.supports(optimizer, attr, VI)
            for vi in MOI.get(model, MOI.ListOfVariablesWithAttributeSet(attr))
                MOI.set(optimizer, attr, vi, MOI.get(model, attr, vi))
            end
        else
            throw(MOI.UnsupportedAttribute(attr))
        end
    end

    # Copy constraint attributes
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        for attr in MOI.get(model, MOI.ListOfConstraintAttributesSet{F,S}())
            if MOI.supports(optimizer, attr, CI{F,S})
                for ci in MOI.get(model, MOI.ListOfConstraintsWithAttributeSet{F,S}(attr))
                    MOI.set(optimizer, attr, ci, MOI.get(model, attr, ci))
                end
            else
                # throw(MOI.UnsupportedAttribute(attr))
            end
        end
    end

    return nothing
end

function MOI.copy_to(optimizer::Optimizer{T}, model::MOI.ModelLike) where {T}
    @debug "Copying model for AOC/AIM optimizer"

    index_map = MOIU.IndexMap()

    _copy_attributes!(optimizer, model)

    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        if !MOI.supports_constraint(optimizer, F, S)
            error("Unsupported constraint type: $F ∈ $S")
        end
    end

    # Binary Variables
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.ZeroOne}())
        vi = MOI.get(model, MOI.ConstraintFunction(), ci)::VI

        optimizer.variable_info[vi] = Variable{T}(:binary)

        index_map[ci] = ci
    end

    # Intervals
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.Interval{T}}())
        vi = MOI.get(model, MOI.ConstraintFunction(), ci)::VI
        si = MOI.get(model, MOI.ConstraintSet(), ci)::MOI.Interval{T}

        @assert !haskey(optimizer.variable_info, vi) || optimizer.variable_info[vi].type === :continuous

        optimizer.variable_info[vi] = Variable{T}(:continuous; lower = si.lower, upper = si.upper)

        index_map[ci] = ci
    end

    # Lower Bounds
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,GT{T}}())
        vi = MOI.get(model, MOI.ConstraintFunction(), ci)::VI
        si = MOI.get(model, MOI.ConstraintSet(), ci)::GT{T}

        @assert !haskey(optimizer.variable_info, vi) || optimizer.variable_info[vi].type === :continuous || si.lower <= zero(T)

        let v = if haskey(optimizer.variable_info, vi)
                Variable{T}(:continuous; lower = si.lower, upper = optimizer.variable_info[vi].upper)
            else
                Variable{T}(:continuous; lower = si.lower)
            end

            if v.lower == v.upper # Fixed variable
                optimizer.fixed[vi] = v.lower
            end

            optimizer.variable_info[vi] = v
        end

        index_map[ci] = ci
    end

    # Upper Bounds
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,LT{T}}())
        vi = MOI.get(model, MOI.ConstraintFunction(), ci)::VI
        si = MOI.get(model, MOI.ConstraintSet(), ci)::LT{T}

        @assert !haskey(optimizer.variable_info, vi) || optimizer.variable_info[vi].type === :continuous || si.upper >= one(T)

        let v = if haskey(optimizer.variable_info, vi)
                Variable{T}(:continuous; lower = optimizer.variable_info[vi].lower, upper = si.upper)
            else
                Variable{T}(:continuous; upper = si.upper)
            end

            if v.lower == v.upper # Fixed variable
                optimizer.fixed[vi] = v.lower
            end

            optimizer.variable_info[vi] = v
        end

        index_map[ci] = ci
    end

    for vi in MOI.get(model, MOI.ListOfVariableIndices())
        @assert haskey(optimizer.variable_info, vi) && is_bounded(optimizer.variable_info[vi]) "Unbounded variable $(vi)"

        index_map[vi] = vi
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,EQ{T}}())
        vi = MOI.get(model, MOI.ConstraintFunction(), ci)::VI
        si = MOI.get(model, MOI.ConstraintSet(), ci)::EQ{T}

        if !haskey(optimizer.variable_info, vi)
            optimizer.variable_info[vi] = Variable{T}(:continuous; lower = si.value, upper = si.value)
        end

        optimizer.fixed[vi] = si.value
    end

    # Fixed variables are not included in the variable list, so they won't get an index
    variable_list = sort!(
        filter(vi -> !haskey(optimizer.fixed, vi), collect(keys(optimizer.variable_info)));
        by = (vi -> (optimizer.variable_info[vi].type === :continuous, vi.value))
    )

    optimizer.variable_map  = Dict{VI,Int}(vi => i for (i, vi) in enumerate(variable_list))
    optimizer.continuous    = [optimizer.variable_info[vi].type === :continuous for vi in variable_list]

    # Parse objective
    let F = MOI.get(model, MOI.ObjectiveFunctionType())
        f = MOI.get(model, MOI.ObjectiveFunction{F}())

        Q, ℓ, c = _parse_objective(
            f,
            optimizer.variable_map,
            optimizer.fixed,
            optimizer.continuous
        )

        A, b = _scaling(optimizer.variable_info, optimizer.variable_map)

        optimizer.quadratic = A' * Q * A
        optimizer.linear    = vec(b' * Q * A + ℓ' * A)
        optimizer.offset    = c + b' * Q * b + ℓ' * b
    end

    return index_map
end

function _parse_objective(vi::VI, vmap::Dict{VI,Int}, fixed::Dict{VI,T}, ::Vector{Bool}) where {T}
    n = length(vmap)

    Q = zeros(T, n, n)
    ℓ = zeros(T, n)
    c = zero(T)

    if haskey(fixed, vi)
        c += fixed[vi]
    else
        ℓ[vmap[vi]] = one(T)
    end

    return (Q, ℓ, c)
end

function _parse_objective(
    f::SAF{T},
    vmap::Dict{VI,Int},
    fixed::Dict{VI,T},
    ::Vector{Bool}
) where {T}
    n = length(vmap)

    Q = zeros(T, n, n)
    ℓ = zeros(T, n)
    c = zero(T)

    for term in f.terms
        vi = term.variable
        ci = term.coefficient

        if haskey(fixed, vi)
            c += ci * fixed[vi]
        else
            ℓ[vmap[vi]] = ci
        end
    end

    return (Q, ℓ, c)
end

function _parse_objective(
    f::SQF{T},
    vmap::Dict{VI,Int},
    fixed::Dict{VI,T},
    continuous::Vector{Bool}
) where {T}
    n = length(vmap)

    Q = zeros(T, n, n)
    ℓ = zeros(T, n)
    c = f.constant

    for term in f.affine_terms
        vi = term.variable
        li = term.coefficient

        if haskey(fixed, vi)
            c += li * fixed[vi]
        else
            ℓ[vmap[vi]] += li
        end
    end

    # Recall that the expression to optimize is -0.5 * x' * Q * x - ℓ' * x,
    # i.e., there is a factor of 0.5 in the quadratic term.
    for term in f.quadratic_terms
        vi  = term.variable_1
        vj  = term.variable_2
        qij = term.coefficient

        if haskey(fixed, vi) && haskey(fixed, vj)
            c += qij * fixed[vi] * fixed[vj]
        elseif haskey(fixed, vi)
            ℓ[vmap[vj]] += qij * fixed[vi]
        elseif haskey(fixed, vj)
            ℓ[vmap[vi]] += qij * fixed[vj]
        else
            # neither is fixed
            i = vmap[vi]
            j = vmap[vj]

            if continuous[i] || continuous[j]
                if i == j
                    #= The SQF function already has a 0.5 factor,
                        hence, we do not need to multiply with 2 here.
                        Hence, there is no need for this special case,
                        but good to keep (including this comment) to
                        avoid future errors.
                    =#
                    Q[i, j] += qij # * T(2.0)
                else
                    Q[i, j] += qij
                    Q[j, i] += qij
                end
            elseif i == j
                # both are binary, so we move the term to the linear part
                ℓ[i] += qij
            else
                Q[i, j] += qij
                Q[j, i] += qij
            end
        end
    end

    return (Q, ℓ, c)
end

function MOI.optimize!(optimizer::Optimizer{T}) where {T<:Real}
    backend = MOI.get(optimizer, Backend())

    seed       = something(MOI.get(optimizer, Seed()), trunc(Int, time()))
    time_limit = trunc(Int, something(MOI.get(optimizer, MOI.TimeLimitSec()), 10.0))
    work_dir   = MOI.get(optimizer, WorkDir())
    num_type   = MOI.get(optimizer, NumericType())

    quadratic = convert.(num_type, -optimizer.quadratic)
    linear    = convert.(num_type, -optimizer.linear)

    if optimizer.sense === MOI.MIN_SENSE
        sense = AOC.MINIMIZATION
    elseif optimizer.sense === MOI.MAX_SENSE
        sense = AOC.MAXIMIZATION
    else
        error("Unknown sense $(optimizer.sense)")
    end

    result = aoc_api.compute_qumo(
        sense,
        quadratic,
        linear,
        optimizer.continuous,
        seed,
        time_limit;
        work_dir = work_dir,
        engine   = backend,
    )

    if !(T === num_type)
        output = Dict(
            "Objective"  => convert(T, result.Objective),
            "Assignment" => convert.(T, result.Assignment),
        )
    else
        output = Dict(
            "Objective"  => result.Objective,
            "Assignment" => result.Assignment,
        )
    end

    optimizer.output = output

    return nothing
end