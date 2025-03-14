#=
qio.jl

These are JSON files that contain a list of terms,
and they naturally encode PUBO problems.
They can also be used to encode Ising problems.

TODO: Document the QIO file format.
    This is a custom JSON format that describes Ising and PUBO problems.

=#

module QIO

using Compat
using SparseArrays
using JSON
using LinearAlgebra

using ...AOCoptimizer: Direction, MINIMIZATION
using ..FileFormats: FileNotFoundException

@compat public QUBO, Ising, QIOProblem, QIOException
@compat public read_qubo, read_ising, read
@compat public is_ising, is_qubo

"""
    QIOException(msg::AbstractString)

Exception thrown when encountering errors in parsing files
"""
struct QIOException <: Exception
    msg::AbstractString
end

# Matrices with sparsity less than this number will be represented as sparse matrices
const sparsity_rate = 0.2

"""
    Metadata{T<:Real}

Metadata for QIO problems. Metadata include the following fields:
- `Objective`: The objective value of the problem; this is the best known minimum or maximum value of the objective function.
- `Instance`: The name of the instance; this can be used to identify the problem.
- `Sense`: The optimization direction (MINIMIZATION or MAXIMIZATION).
- `NumberOfTerms`: The number of terms in the problem.
- `NumberOfInteractions`: The number of interactions in the problem.
- `MaxDegree`: The maximum degree of the problem.
"""
struct Metadata{T<:Real}
    Objective::T
    Instance::String
    Sense::Direction
    NumberOfTerms::Int
    NumberOfInteractions::Int
    MaxDegree::Int
end

"""
    QIOProblem
Abstract type for QIO problems.
"""
abstract type QIOProblem end

"""
    QUBO{T<:Real} <: QIOProblem

QUBO problem type. QUBO problems are represented as a matrix of coefficients.
These instances do not contain linear terms.
"""
struct QUBO{T<:Real} <: QIOProblem
    Info::Metadata{T}
    Terms::AbstractMatrix{T}
end

"""
    Ising{T<:Real} <: QIOProblem

Ising problem type. Ising problems are represented with a matrix of coefficients
and a vector of fields.
"""
struct Ising{T<:Real} <: QIOProblem
    Info::Metadata{T}
    Field::AbstractVector{T}
    Terms::AbstractMatrix{T}
end

ProblemInfo = Dict{String,Any}

function _read_problem_name(problem::ProblemInfo)::String
    if haskey(problem, "instance")
        return problem["instance"]
    elseif haskey(problem, "name")
        return problem["name"]
    else
        @warn "Cannot find instance name in topology; will continue"
        return ""
    end
end

function _read_filetype_version(problem::ProblemInfo)::String
    version = problem["version"]
    if version != "1.0"
        @warn "Unknown version number in topology `$version`; will continue"
    end

    return version
end

function _read_optimization_direction(::ProblemInfo)
    # This is the default direction of the problem, and in the current version
    # there seems to be no option to specify maximization
    return MINIMIZATION
end

function _read_json_file(filename::AbstractString)::ProblemInfo
    if !isfile(filename)
        @error "Cannot find file `$filename` for reading; aborting operation"
        throw(FileNotFoundException(filename))
    end

    return JSON.parsefile(filename)
end
function _read_json_file(io::IO)::ProblemInfo
    if eof(io)
        @error "Reached end of stream before reading JSON; aborting operation"
        throw(EOFError())
    end

    return JSON.parse(io)
end

function _read_terms_to_matrix(::Type{T}, problem::ProblemInfo) where {T<:Real}
    i = Vector{Integer}()
    j = Vector{Integer}()
    v = Vector{T}()

    number_of_nodes = 0
    number_of_interactions = 0

    for term in problem["terms"]
        ids = term["ids"]
        weight = T(term["c"])

        if length(ids) == 1
            id = ids[1] + 1
            append!(i, id)
            append!(j, id)
            append!(v, weight)

            number_of_nodes = max(number_of_nodes, id)
            number_of_interactions = number_of_interactions + 1

        elseif length(ids) == 2
            id_i = ids[1] + 1
            id_j = ids[2] + 1

            append!(i, id_i)
            append!(j, id_j)
            append!(v, weight)

            append!(i, id_j)
            append!(j, id_i)
            append!(v, weight)

            number_of_nodes = max(number_of_nodes, id_i, id_j)
            number_of_interactions = number_of_interactions + 1

        else
            @error "Problem is not QUBO, it has terms $ids; aborting matrix creation"
            throw(
                QIOException(
                    "Expecting QUBO problem, got $(length(ids)) interacting terms: $ids",
                ),
            )
        end
    end

    @debug "Discovered $number_of_nodes nodes and $number_of_interactions interactions"
    if number_of_interactions < sparsity_rate * number_of_nodes * number_of_nodes
        @debug "Will construct a sparse matrix"
        matrix = sparse(i, j, v, number_of_nodes, number_of_nodes)
    else
        matrix = zeros(T, number_of_nodes, number_of_nodes)
        matrix[(i.-1)*number_of_nodes.+j] .= v
    end

    return matrix, number_of_nodes, number_of_interactions
end

function _read_qubo(
    ::Type{T},
    problem::ProblemInfo,
    filename::AbstractString,
)::QUBO{T} where {T<:Real}
    problem_type = problem["type"]
    if problem_type != "pubo"
        @error "Expecting PUBO type problem for $filename, got $problem_type; aborting"
        throw(QIOException("Invalid topology in `$filename`"))
    end

    _read_filetype_version(problem)
    objective = T(problem["solution"])
    instance = _read_problem_name(problem)
    sense = _read_optimization_direction(problem)

    matrix, number_of_nodes, number_of_interactions = _read_terms_to_matrix(T, problem)
    meta = Metadata(objective, instance, sense, number_of_nodes, number_of_interactions, 2)
    return QUBO{T}(meta, matrix)
end

"""
    read_qubo(::Type{T}, filename::AbstractString)::QUBO{T} where {T<:Real}
    read_qubo(filename::AbstractString)::QUBO{Float64}

Read a QUBO problem from a file with name `filename`.
"""

function read_qubo(::Type{T}, filename::AbstractString)::QUBO{T} where {T<:Real}
    problem = _read_json_file(filename)
    return _read_qubo(T, problem, filename)
end

read_qubo(filename::AbstractString)::QUBO{Float64} = read_qubo(Float64, filename)

function _read_ising(
    ::Type{T},
    problem::ProblemInfo,
    filename::AbstractString,
)::Ising{T} where {T<:Real}
    problem_type = problem["type"]
    if problem_type != "ising"
        @error "Expecting Ising type problem for $filename, got $problem_type; aborting"
        throw(QIOException("Invalid topology in `$filename`"))
    end

    _read_filetype_version(problem)
    objective = T(problem["solution"])
    instance = _read_problem_name(problem)
    sense = _read_optimization_direction(problem)

    matrix, number_of_nodes, number_of_interactions = _read_terms_to_matrix(T, problem)
    fields = diag(matrix)
    matrix[diagind(matrix)] .= T(0)
    meta = Metadata(objective, instance, sense, number_of_nodes, number_of_interactions, 2)
    return Ising{T}(meta, fields, matrix)
end

"""
    read_ising(::Type{T}, filename::AbstractString)::Ising{T} where {T<:Real}
    read_ising(filename::AbstractString)::Ising{Float64}

Read an Ising problem from a file with name `filename`.
"""

function read_ising(::Type{T}, filename::AbstractString)::Ising{T} where {T<:Real}
    problem = _read_json_file(filename)
    return _read_ising(T, problem, filename)
end

read_ising(filename::AbstractString)::Ising{Float64} = read_ising(Float64, filename)

"""
    read_qio(::Type{T}, filename::AbstractString)::QIOProblem where {T<:Real}
    read_qio(filename::AbstractString)::QIOProblem
    read_qio(::Type{T}, io::IO)::QIOProblem where {T<:Real}
    read_qio(io::IO)::QIOProblem

Read a QIO problem from a file with name `filename` or from an IO stream `io`.
Optional type parameter `T` specifies the elementary type used in the the problem (e.g., Float64 or Float32).
"""
function read_qio(::Type{T}, filename::AbstractString)::QIOProblem  where {T<:Real}
    problem = _read_json_file(filename)
    problem_type = problem["type"]
    if problem_type == "pubo"
        return _read_qubo(T, problem, filename)
    elseif problem_type == "ising"
        return _read_ising(T, problem, filename)
    else
        @error "Expecting PUBO or Ising type problem for $filename, got $problem_type; aborting"
        throw(QIOException("Invalid topology in `$filename`"))
    end
end

read_qio(filename::AbstractString)::QIOProblem = read_qio(Float64, filename)

function read_qio(::Type{T}, io::IO)::QIOProblem where {T<:Real}
    problem = _read_json_file(io)
    problem_type = problem["type"]
    if problem_type == "pubo"
        return _read_qubo(T, problem, "<unknown>")
    elseif problem_type == "ising"
        return _read_ising(T, problem, "<unknown>")
    else
        @error "Expecting PUBO or Ising type problem, got $problem_type; aborting"
        throw(QIOException("Invalid topology in stream"))
    end
end

read_qio(io::IO)::QIOProblem = read_qio(Float64, io)


"""
    is_qubo(::QIOProblem) -> Bool

Check if the problem is a QUBO problem.
"""
is_qubo(::QUBO) = true
is_qubo(::Ising) = false

"""
    is_ising(::QIOProblem) -> Bool

Check if the problem is an Ising problem.
"""
is_ising(::QUBO) = false
is_ising(::Ising) = true

end
