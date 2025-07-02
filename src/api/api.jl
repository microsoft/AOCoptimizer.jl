#=
api.jl

Provides an easier to use interface to the AOCoptimizer,
including changes to the inputs (that allow user more flexibility
in specifying the problem). It also provides more consistent
access to the server that will be easier to use from other languages.

=#

module api

using BFloat16s
using Compat
using Dates
using LinearAlgebra
using Random
using ..AOCoptimizer: graph_cut_from_hamiltonian, Direction, MAXIMIZATION
using ..Solver: Engine, EngineLocalCpu, best_engine
using ..Solver: solve_mixed_ising, solve_positive_qumo, solve_qumo
using ..Solver: find_best

@compat public adjust_inputs_to_engine, compute_max_cut, GraphCutResult
@compat public compute_ising, compute_mixed_ising
@compat public compute_qumo_positive, compute_qumo

"""
    adjust_inputs_to_engine(
        ::Engine,
        matrix::AbstractMatrix{T},
        linear::Union{Nothing,AbstractVector{T}} = nothing
    )::Tuple{DataType, AbstractMatrix{T}, Union{Nothing, AbstractVector{T}}

Converts the types of the input problem to a form that is compatible with the specified engine.
The conversion takes into account the capabilities of the underlying hardware.
"""
function adjust_inputs_to_engine end

function adjust_inputs_to_engine(
    ::Engine,
    matrix::AbstractMatrix{T},
    linear::Union{Nothing,AbstractVector{T}} = nothing
) where T<:Real
    return T, matrix, linear
end

function adjust_inputs_to_engine(
    ::EngineLocalCpu,
    matrix::AbstractMatrix{T},
    linear::Union{Nothing,AbstractVector{T}}  = nothing
) where T<:Real
    # TODO: Some CPUs now support Float16 and BFloat16.
    if T === Float16 || T === BFloat16
        @warn "Computing with Float16 or BFloat16 on the CPU is not supported. Switching to Float32."
        if linear !== nothing
            linear = Float32.(linear)
        end
        return Float32, Float32.(matrix), nothing, linear
    end

    return T, matrix, linear
end

"""
Stores the result of a graph cut computation
"""
struct GraphCutResult
    Cut::Float64
    Hamiltonian::Float64
    Assignment::Vector{Int}
    Group1::Vector{Int}
    Group2::Vector{Int}
end

"""
    compute_max_cut(
        matrix::AbstractMatrix{T},
        seed::Integer,
        timeout::Integer;
        work_dir::Union{Nothing,String} = nothing,
        engine::Engine = best_engine()
    )::GraphCutResult

Heuristic to find a cut of maximal value for a graph represented by
the adjacency `matrix`. The heuristic will use `seed` to initialize the
random number generator, and will work for `timeout` seconds.

Optionally, the user can specify the backend used for the computation,
using `engine`, and a working directory `work_dir` for the storing logs
(not used at the time).
"""
function compute_max_cut(
    matrix::AbstractMatrix{T},
    seed::Integer,
    timeout_in_seconds::Integer;
    work_dir::Union{Nothing,String} = nothing,
    engine::Engine = best_engine()
)::GraphCutResult where {T<:Real}
    T_, matrix, _ = adjust_inputs_to_engine(engine, matrix, nothing)

    M = Array(-matrix)
    rng = Xoshiro(seed)

    result = solve_mixed_ising(
        T_, M, Second(timeout_in_seconds);
        rng = rng, engine=engine)
    optimum = find_best(result)

    # The following may fail if we perform the computation using Float16; hence, we convert to Float64 to be sure.
    maxcut = graph_cut_from_hamiltonian(Float64, matrix, optimum.Objective)

    output = GraphCutResult(
        maxcut, optimum.Objective,
        optimum.Vars,
        findall(x -> x == 1, optimum.Vars),
        findall(x -> x == -1, optimum.Vars)
    )

    return output
end

"""
Stores the result of an Ising computation
"""
struct IsingResult
    Hamiltonian::Float64
    Assignment::Vector{Float64}
end

"""
    compute_ising(
        matrix::AbstractMatrix{T},
        field::Union{Nothing, AbstractVector{T}},
        seed::Integer,
        timeout::Integer;
        work_dir::Union{Nothing,String} = nothing,
        engine::Engine = best_engine()
    )::IsingResult

Heuristic to solve the Ising problem for a system with
connectivity graph represented by the `matrix` and external field `field`
(optional). The heuristic will use `seed` to initialize the
random number generator, and will work for `timeout` seconds.

Optionally, the user can specify the backend used for the computation,
using `engine`, and a working directory `work_dir` for the storing logs
(not used at the time).
"""
function compute_ising(
    matrix::AbstractMatrix{T},
    field::Union{Nothing, AbstractVector{T}},
    seed::Integer,
    timeout_in_seconds::Integer;
    work_dir::Union{Nothing,String} = nothing,
    engine::Engine = best_engine()
)::IsingResult where {T<:Real}
    T_, matrix, field = adjust_inputs_to_engine(engine, matrix, field)

    M = Array(Symmetric(matrix))
    rng = Xoshiro(seed)

    nodes = size(M, 1)

    result = solve_mixed_ising(
            T_,
            M, field,
            nodes,
            Second(timeout_in_seconds);
            rng = rng, engine=engine
    )
    optimum = find_best(result)

    output = IsingResult(optimum.Objective, optimum.Vars)

    return output
end

"""
    compute_mixed_ising(
        quadratic::AbstractMatrix{T},
        field::Union{Nothing,AbstractVector{T}},
        continuous::Union{Nothing,AbstractVector{Bool}},
        seed::Int,
        timeout_in_seconds::Int;
        work_dir::Union{Nothing,String} = nothing,
        engine::Engine = best_engine()
    )::IsingResult

Heuristic to solve the mixed-Ising problem for a system with
connectivity graph represented by the `matrix` and external field `field`
(optional). The heuristic will use `seed` to initialize the
random number generator, and will work for `timeout` seconds.

The user needs to specify with `continuous` the continuous variables
in the model, which will take values between -1 and 1. (The rest are
discrete and take values either -1 or +1).

Optionally, the user can specify the backend used for the computation,
using `engine`, and a working directory `work_dir` for the storing logs
(not used at the time).
"""
function compute_mixed_ising(
    quadratic::AbstractMatrix{T},
    field::Union{Nothing,AbstractVector{T}},
    continuous::Union{Nothing,AbstractVector{Bool}},
    seed::Int,
    timeout_in_seconds::Int;
    work_dir::Union{Nothing,String} = nothing,
    engine::Engine = best_engine()
)::IsingResult where T<:Real
    T_, quadratic, field = adjust_inputs_to_engine(engine, quadratic, field)

    M = Array(Symmetric(quadratic))
    rng = Xoshiro(seed)

    n = size(quadratic, 1)
    if continuous === nothing
        reorder = collect(1:n)
        number_of_binaries = n
        matrix = quadratic
    else
        binaries = findall(x -> x == T_(0), continuous)
        number_of_binaries = length(binaries)
        continuous = setdiff(collect(1:n), binaries)
        reorder = vcat(binaries, continuous)

        matrix = quadratic[reorder, reorder]
        if field !== nothing
            field = field[reorder]
        end
    end

    binary_vector = zeros(Bool, n)
    binary_vector[1:number_of_binaries] .= true

    result = solve_mixed_ising(
        T_,
        Array(Symmetric(matrix)),
        field,
        number_of_binaries,
        Second(timeout_in_seconds);
        rng=rng, engine=engine
    )
    optimum = find_best(result)

    objective = optimum.Objective
    vars = optimum.Vars
    binary_vars = @view vars[1:number_of_binaries]
    clamp!(binary_vars, -1, 1)

    inverse_order = sortperm(reorder)
    assignment = vars[inverse_order]

    output = IsingResult(objective, assignment)

    return output
end

"""
Store the result of a QUMO computation
"""
struct QumoResult
    Objective::Float64
    Assignment::Vector{Float64}
    Sense::Direction
end

"""
    compute_qumo_positive(
        sense::Direction,
        quadratic::AbstractMatrix{T},
        field::Union{Nothing,AbstractVector{T}},
        continuous::Union{Nothing,AbstractVector{Bool}},
        seed::Int,
        timeout_in_seconds::Int;
        work_dir::Union{Nothing,String} = nothing,
        engine::Engine = best_engine()
    )::QumoResult

Heuristic to solve a QUMO problem where all variables take positive values.
Problem is formulated using the quadratic (symmetric) `matrix` and
the (optional) linear `field`. The direction of optimization is
defined using `sense`.

The heuristic will use `seed` to initialize the
random number generator, and will work for `timeout` seconds.

The user needs to specify with `continuous` the continuous variables
in the model, which will take values between -1 and 1. (The rest are
discrete and take values either -1 or +1).

Optionally, the user can specify the backend used for the computation,
using `engine`, and a working directory `work_dir` for the storing logs
(not used at the time).
"""
function compute_qumo_positive(
    sense::Direction,
    quadratic::AbstractMatrix{T},
    linear::Union{Nothing,AbstractVector{T}},
    continuous::Union{Nothing,AbstractVector{Bool}},
    seed::Int,
    timeout::Int;
    work_dir::Union{Nothing,String} = nothing,
    engine::Engine = best_engine()
)::QumoResult where T<:Real
    rng = Xoshiro(seed)

    n = size(quadratic, 1)

    T_, quadratic, linear = adjust_inputs_to_engine(engine, quadratic, linear)

    if continuous === nothing
        reorder = collect(1:n)
        number_of_binaries = n
        matrix = quadratic
    else
        binaries = findall(x -> x == T_(0), continuous)
        number_of_binaries = length(binaries)
        continuous = setdiff(collect(1:n), binaries)
        reorder = vcat(binaries, continuous)

        matrix = quadratic[reorder, reorder]
        if linear !== nothing
            linear = linear[reorder]
        end
    end

    if sense == MAXIMIZATION
        matrix = -matrix
        if linear !== nothing
            linear = -linear
        end
    end

    binary_vector = zeros(Bool, n)
    binary_vector[1:number_of_binaries] .= true

    result = solve_positive_qumo(
        T_,
        matrix,
        linear,
        number_of_binaries,
        Second(timeout);
        rng=rng,
        engine=engine
    )
    optimum = find_best(result)

    objective = optimum.Objective
    vars = optimum.Vars
    binary_vars = @view vars[1:number_of_binaries]
    @. binary_vars = max(0, binary_vars)

    if sense == MAXIMIZATION
        objective = -objective
    end

    inverse_order = sortperm(reorder)
    assignment = vars[inverse_order]

    output = QumoResult(objective, assignment, sense)

    return output
end

"""
    compute_qumo(
        sense::Direction,
        quadratic::AbstractMatrix{T},
        field::Union{Nothing,AbstractVector{T}},
        continuous::Union{Nothing,AbstractVector{Bool}},
        seed::Int,
        timeout_in_seconds::Int;
        work_dir::Union{Nothing,String} = nothing,
        engine::Engine = best_engine()
    )::QumoResult

Heuristic to solve a QUMO problem.
Problem is formulated using the quadratic (symmetric) `matrix` and
the (optional) linear `field`. The direction of optimization is
defined using `sense`.

The heuristic will use `seed` to initialize the
random number generator, and will work for `timeout` seconds.

The user needs to specify with `continuous` the continuous variables
in the model, which will take values between -1 and 1. (The rest are
discrete and take values either -1 or +1).

Optionally, the user can specify the backend used for the computation,
using `engine`, and a working directory `work_dir` for the storing logs
(not used at the time).
"""
function compute_qumo(
    sense::Direction,
    quadratic::AbstractMatrix{T},
    linear::Union{Nothing,AbstractVector{T}},
    continuous::Union{Nothing,AbstractVector{Bool}},
    seed::Int,
    timeout::Int;
    work_dir::Union{Nothing,String} = nothing,
    engine::Engine = best_engine()
) where {T<:Real}
    T_, quadratic, linear = adjust_inputs_to_engine(engine, quadratic, linear)

    rng = Xoshiro(seed)

    n = size(quadratic, 1)
    if continuous === nothing
        reorder = collect(1:n)
        number_of_binaries = n
        matrix = quadratic
    else
        binaries = findall(x -> x == T_(0), continuous)
        number_of_binaries = length(binaries)
        continuous = setdiff(collect(1:n), binaries)
        reorder = vcat(binaries, continuous)

        matrix = quadratic[reorder, reorder]
        if linear !== nothing
            linear = linear[reorder]
        end
    end

    if sense == MAXIMIZATION
        matrix = -matrix

        if linear !== nothing
            linear = -linear
        end
    end

    binary_vector = zeros(Bool, n)
    binary_vector[1:number_of_binaries] .= true

    result = solve_qumo(
        T_,
        matrix,
        linear,
        number_of_binaries,
        Second(timeout);
        rng = rng,
        engine = engine
    )
    optimum = find_best(result)

    objective = optimum.Objective
    vars = optimum.Vars
    binary_vars = @view vars[1:number_of_binaries]
    @. binary_vars = max(0, binary_vars)

    if sense == MAXIMIZATION
        objective = -objective
    end

    inverse_order = sortperm(reorder)
    assignment = vars[inverse_order]

    output = QumoResult(objective, assignment, sense)

    return output
end

end # module