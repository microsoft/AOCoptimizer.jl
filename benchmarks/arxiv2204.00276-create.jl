#=
arxiv2204.00276.jl

Instance generation for problems described in <https://arxiv.org/abs/2204.00276>
("Ising machines as hardware solvers of combinatorial optimization problems"
by Naeimeh Mohseni, Peter L. McMahon and Tim Byrnes).

Here we generate instances for the SK and MaxCut problems;
we do not generate instances for 3R3X or Logical-Planted/deceptive problems.
The instances are written to MPS files. This is a simple format
that can be read by Gurobi, in Julia and other solvers.

We favor an approach of writing the problems in a file,
so that there is a record of the exact problem generated.
This is important for reproducibility.

## Graph generation

The SK and MaxCut graphs used in the paper to benchmark the various algorithms
are generated with a simple heuristic. From the paper (caption of Figure 3):

> For the SK problem, ``J_{ij}`` is chosen from ``±1`` with equal probability.
> The MaxCut problem is mapped onto the Ising model by setting ``J_{ij}`` to
> ``0`` and ``1`` with equal probability. In both cases ``h_i = 0``.

The description should say that the weights ``J_{ij}=J_{ji}`` (when ``i≠j``) are chosen with
equal probability from the set ``{-1, 1}`` for the SK problem,
and from the set ``{0, 1}`` for the MaxCut problem. For each ``i``, ``J_{ii}`` is set to ``0``.
Observe this particular SK graph generation differs from the standard SK model
(where the weights are chosen from a Gaussian distribution).

In addition, the graphs constructed for the MaxCut problem are not guaranteed to be
connected (for graphs of small size). When generating problems for MaxCut, we
also check for connectedness and retry the generation if the graph is not connected.

## Solving with Gurobi

To solve the problem with Gurobi, use the `mps` files generated below as input
to the Gurobi command line solver. The command line is as follows:

```cmd
del problem.log
gurobi_cl.exe ResultFile=problem.sol.json JSONSolDetail=1 LogFile=problem.log problem.mps
gurobi_cl.exe ResultFile=problem.sol.json JSONSolDetail=1 LogFile=problem.log TimeLimit=600 problem.mps
````

=#

using Revise
using Graphs
using JuMP
using LinearAlgebra
using Printf
using Random
using AOCoptimizer

output_directory = joinpath(@__DIR__, "..", "data", "arxiv2204.00276")
mkpath(output_directory)

function mk_sk(n::Int, rng::AbstractRNG)
    m = rand(rng, [-1, 1], n, n)
    # make lower triangular equal to upper triangular
    m = triu(m, 1) + triu(m, 1)'
    return Symmetric(m)
end
mk_sk(n::Int, seed::Int) = mk_sk(n, Random.Xoshiro(seed))


function _mk_cut(n::Int, rng::AbstractRNG)
    m = rand(rng, [0, 1], n, n)
    # make lower triangular equal to upper triangular
    m = triu(m, 1) + triu(m, 1)'
    return Symmetric(m)
end
function mk_cut(n::Int, rng::AbstractRNG)
    while true
        m = _mk_cut(n, rng)
        # check if the graph is connected
        g = SimpleGraph(m)
        if is_connected(g)
            return m
        end
        @warn "Graph is not connected, retrying..."
    end
end
mk_cut(n::Int, seed::Int) = mk_cut(n, Random.Xoshiro(seed))

function write_max_cut_as_mps(io::IO, graph::AbstractMatrix; name::Union{Nothing,AbstractString}=nothing)
    @assert issymmetric(graph)
    n = size(graph, 1)

    if name === nothing
        name = "MaxCut_$n"
    end

    @printf(io, "%-15s%s\n", "NAME", name)
    println(io, "OBJSENSE    MAX")

    println(io, "ROWS")
    println(io, " N  GRAPHCUT")

    #= Better to use JuMP to generate the model
    m = Model()
    @variable(m, x[1:n])
    @objective(m, Max, sum(graph[i, j] * ( (1-x[j])*x[i] + (1-x[i])*x[j]) for i in 1:n for j in i+1:n if graph[i, j] != 0))
    =#

    linear = zeros(n)
    for i in 1:n
        for j in i+1:n
            if graph[i, j] != 0
                linear[i] += graph[i, j]
                linear[j] += graph[i, j]
            end
        end
    end
    println(io, "COLUMNS")
    for i in 1:n
        @printf(io, "    X%-11d%-15s%f\n", i, "GRAPHCUT", linear[i])
    end

    println(io, "BOUNDS")
    for i in 1:n
        @printf(io, "%-15sX%d\n", " BV BND", i)
    end

    println(io, "QUADOBJ")
    for i in 1:n
        for j in i+1:n
            if graph[i, j] != 0
                @printf(io, "    X%-9dX%-9d%f\n", i, j, -2.0*graph[i, j])
            end
        end
    end


    println(io, "ENDATA")
end

function write_sk_as_mps(io::IO, graph::AbstractMatrix; name::Union{Nothing,AbstractString}=nothing)
    @assert issymmetric(graph)
    n = size(graph, 1)

    if name === nothing
        name = "SK_HAMILTONIAN_$n"
    end

    @printf(io, "%-15s%s\n", "NAME", name)
    println(io, "OBJSENSE    MIN")

    println(io, "ROWS")
    println(io, " N  ENERGY")

    m = Model()
    @variable(m, x[1:n])
    y = 2.0 * x .- 1.0
    energy = -0.5 * y' * graph * y

    println(io, "COLUMNS")
    for term in energy.aff.terms
        i = term.first.index.value
        v = term.second

        @printf(io, "    X%-11d%-15s%f\n", i, "ENERGY", v)
    end

    println(io, "RHS")
    # from the manual: https://docs.gurobi.com/projects/optimizer/en/current/reference/fileformats/modelformats.html#formatmps
    # You may define an objective offset by setting the *negative* offset as right-hand side of the objective row
    @printf(io, "    %-12s%-15s%f\n", "OFFSET", "ENERGY", -energy.aff.constant)

    println(io, "BOUNDS")
    for i in 1:n
        @printf(io, "%-15sX%d\n", " BV BND", i)
    end

    println(io, "QUADOBJ")
    for term in energy.terms
        v = term.second
        if v ≈ 0.0
            continue
        end
        i = term.first.a.index.value
        j = term.first.b.index.value
        if graph[i, j] != 0
            @printf(io, "    X%-9dX%-9d%f\n", i, j, v)
        end
    end

    println(io, "ENDATA")
end

mkdir(joinpath(output_directory, "problems"))

seed = 1234
rng = Random.Xoshiro(seed)
sizes = [5; 10; 15; 20; 25; 30; 40; 50; 60; 70; 80; 90; 100; 110; 120; 130; 140; 150; 160; 170; 180; 190; 200]

for graph_size in sizes
    n = graph_size

    for repetition in 1:10
        seed = rand(rng, 1:1000000)
        graph = mk_cut(n, seed)

        file_name = joinpath(output_directory, "problems", "MaxCut-$n-Xoshiro-$seed.mps")
        open(file_name, "w") do io
            write_max_cut_as_mps(io, graph; name="MaxCut-$n-Xoshiro-$seed")
        end
    end
end

seed = 4321
rng = Random.Xoshiro(seed)

orig_sizes = [5; 10; 15; 20; 25; 30; 40; 50; 60; 70; 80; 90; 100; 110; 120; 130; 140; 150; 160; 170; 180; 190; 200]
extra_sizes = [300; 400; 500; 600; 700; 800; 900; 1000]
sizes = [orig_sizes;  extra_sizes]
for graph_size in sizes
    n = graph_size

    for repetition in 1:10
        seed = rand(rng, 1:1000000)
        #= Example input for debugging
        seed = 102711
        n = 5
        =#
        graph = mk_sk(n, seed)
        # write_sk_as_mps(stdout, graph)

        file_name = joinpath(output_directory, "problems", "SK-$n-Xoshiro-$seed.mps")
        open(file_name, "w") do io
            write_sk_as_mps(io, graph; name="SK-$n-Xoshiro-$seed")
        end
    end
end


function mk_dense_matrix(number_of_rows::Int, number_of_columns::Int, rows::AbstractVector{<:Int}, columns::AbstractVector{<:Int}, values::AbstractVector{T}) where T
    @assert length(rows) == length(columns) == length(values)
    @assert number_of_rows > 0 && number_of_columns > 0
    @assert all(x -> x > 0 && x <= number_of_rows, rows)
    @assert all(x -> x > 0 && x <= number_of_columns, columns)

    matrix = zeros(T, number_of_rows, number_of_columns)
    for i in eachindex(rows)
        matrix[rows[i], columns[i]] = values[i]
    end
    return matrix
end
mk_dense_matrix(rows::AbstractVector, columns::AbstractVector, values::AbstractVector) =
    mk_dense_matrix(maximum(rows), maximum(columns), rows, columns, values)

