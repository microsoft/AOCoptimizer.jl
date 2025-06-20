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

## Solving a simple `QUMO` problem

```@example QUMO
using AOCoptimizer.Solver
```
