```@meta
DocTestSetup = quote
    using Dates
    using JSON
    using AOCoptimizer
    using AOCoptimizer.Solver
end
```

# Examples

## Solving a simple MaxCut problem using the Ising formulation

The following is a simple example of using the `AOC` optimizer to
solve a MaxCut problem. Searching for the maximum cut of a graph
can be converted to an Ising optimization problem
(by negating the adjacency matrix of the graph and searching
for the spin assignment that minimized the Hamiltonian);
it is also equivalent to a Quadratic Unconstrained Binary Optimization (QUBO) problem
(transformation not shown here).

```@example MaxCut
using Dates
using JSON
using AOCoptimizer
using AOCoptimizer: graph_cut_from_hamiltonian
using AOCoptimizer.Solver: solve, find_best, get_solver_results_summary

# Necessary to explicitly initialize the AOCoptimizer package
AOCoptimizer.init()

graph = Float32.([
    0 1 0 0 1
    1 0 1 0 0
    0 1 0 1 0
    0 0 1 0 1
    1 0 0 1 0
])

# observe that we optimize the negative of the adjacency matrix of the graph
sol = solve(Float32, -graph, Second(10))
best = find_best(sol)
cut = graph_cut_from_hamiltonian(graph, best.Objective)
println("Energy: ", best.Objective, "; Cut: ", cut)
println("Assignment: ", best.Vars)
println("Group 1: ", findall(best.Vars .== 1))
println("Group 2: ", findall(best.Vars .== -1))
```

More statistics reported as follows:

```@example MaxCut
println(JSON.json(get_solver_results_summary(sol), 4));
```

Detailed measurements are collected in the `sol` object:

```@example MaxCut
println("Number of solver iterations in deep search: ", length(sol[:deep_search].results))
if length(sol[:deep_search].results) > 0
    println("Sample set of measurements:")
    lx = min(10, size(sol[:deep_search].results[1].Measurements, 1))
    ly = min(10, size(sol[:deep_search].results[1].Measurements, 2))
    show(stdout, MIME"text/plain"(), sol[:deep_search].results[1].Measurements[1:lx, 1:ly])
end
```

## Solving a simple Mixed-Ising problem

The following is a simple example of solving a Mixed-Ising problem.
The first three variables are either -1 or 1 (spin variables),
while the last four variables are continuous (in the range ``[-1, 1]``).

```@example MixedIsing
using Dates
using AOCoptimizer
using AOCoptimizer.Solver: solve, find_best

AOCoptimizer.init()

number_of_binaries = 3

Q = Float32.([
       0.0 -234.0   2.0 -180.0  122.0  172.0  -48.0
    -234.0    0.0 -40.0  -72.0   88.0  124.0  -82.0
       2.0  -40.0   0.0   10.0  -56.0  -40.0  -82.0
    -180.0  -72.0  10.0 -214.0  130.0   68.0  -86.0
     122.0   88.0 -56.0  130.0 -150.0  -88.0   32.0
     172.0  124.0 -40.0   68.0  -88.0 -168.0  -88.0
     -48.0  -82.0 -82.0  -86.0   32.0  -88.0 -246.0
])

q = Float32.([
        1,
        135,
        -119,
        101,
        -139,
        -14,
        145
])

sol = solve(Float32, Q, q, number_of_binaries, Second(10))
best = find_best(sol)
```

The values of the binaries are:

```@example MixedIsing
println("Binaries: ", best.Vars[1:number_of_binaries])
```

The values of the continuous variables are:

```@example MixedIsing
println("Continuous: ", best.Vars[number_of_binaries+1:end])
```

## Solving a simple `QUMO` problem

```@example QUMO
using Dates
using AOCoptimizer
using AOCoptimizer.Solver: solve_qumo, find_best

AOCoptimizer.init()

number_of_binaries = 3

Q = [
    0.0  -936.0     8.0  -360.0   244.0   344.0   -96.0
 -936.0     0.0  -160.0  -144.0   176.0   248.0  -164.0
    8.0  -160.0     0.0    20.0  -112.0   -80.0  -164.0
 -360.0  -144.0    20.0  -214.0   130.0    68.0   -86.0
  244.0   176.0  -112.0   130.0  -150.0   -88.0    32.0
  344.0   248.0   -80.0    68.0   -88.0  -168.0   -88.0
  -96.0  -164.0  -164.0   -86.0    32.0   -88.0  -246.0
]

q = [
  930.0
 1366.0
  -86.0
  585.0
 -447.0
 -526.0
  569.0
]

sol = solve_qumo(Float32, Q, q, number_of_binaries, Second(10))
best = find_best(sol)
```

The values of the binaries are:

```@example QUMO
println("Binaries: ", best.Vars[1:number_of_binaries])
```

The values of the continuous variables are:

```@example QUMO
println("Continuous: ", best.Vars[number_of_binaries+1:end])
```
