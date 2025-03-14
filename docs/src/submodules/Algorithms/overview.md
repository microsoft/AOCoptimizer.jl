```@meta
CurrentModule = AOCoptimizer.Algorithms
DocTestSetup = quote
    import AOCoptimizer as AOC
    import AOCoptimizer.Algorithms as Algos
end
DocTestFilters = [r"AOCoptimizer|AOC|Algos"]
```

# AOCoptimizer.Algorithms

## Enhanced Random

This module implements a very simple heuristic for solving Ising and QUMO problems.
It is based on the idea of starting from a random initial solution, and then
iteratively flipping bits in the assignment vector to improve the objective function.
The algorithm evaluated starting points in parallel and (typically) executes
for a specified time limit. The achieved solution can be used as the lowest baseline
that any reasonable algorithm should be able to beat.

A very simple example of how to use it is shown below:

```julia
using AOCoptimizer: CancellationToken
using AOCoptimizer.RuntimeUtils: run_for
using AOCoptimizer.Algorithms.EnhancedRandom: search

function _mk_solver(interactions::AbstractMatrix, seed::Integer)

    function solve(ctx::CancellationToken)
        # @debug "Starting solver at $(now())"
        # @debug "Graph: $interactions"
        # @debug "Context: $ctx"
        result = search(seed, interactions, ctx)
        # @debug "Solver finished at $(now())"
        return result
    end

    return solve
end

interactions = Float32.(-[
    0 1 0 0
    1 0 0 0
    0 0 0 1
    0 0 1 0
])
seed = 1234
time_limit = Second(2)

solver = _mk_solver(interactions, seed)
results = run_for(solver, time_limit; threads=2)

(best_objective, best_index) = findmin(first, results)
best_assignment = results[best_index][2]
println("Best objective: $best_objective")
println("Best (ising) assignment: $best_assignment")
```
