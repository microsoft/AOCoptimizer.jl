```@meta
CurrentModule = AOCoptimizer
DocTestSetup = quote
    import AOCoptimizer as AOC
    import AOCoptimizer.Solver as Solver
    import AOCoptimizer.api as API
end
DocTestFilters = [r"AOCoptimizer|AOC"]
```

# Reference

## Generic

```@docs
AOCoptimizer
```

```@docs
Direction
```

## Metrics

```@docs
hamiltonian
```

```@docs
graph_cut_from_hamiltonian
```

## Runtime system

```@docs
Environment.local_system_info
```

## Multi-threading

```@docs
CancellationToken
```

```@docs
RuntimeUtils.RuntimeException
```

```@docs
create_cancellation_token
```

```@docs
cancel!
```

```@docs
is_cancelled
```

```@docs
RuntimeUtils.run_for
```

## QUBO

```@docs
QUBO.qubo
```

```@docs
QUBO.size
```

```@docs
QUBO.evaluate
```

```@docs
QUBO._random
```

```@docs
QUBO.greedy_random
```

```@docs
QUBO.increase!
```

```@docs
QUBO.decrease!
```

## QUMO

```@docs
QUMO.mixed_ising
```

```@docs
QUMO.qumo
```

```@docs
Base.isapprox
```

```@docs
QUMO.number_of_variables
```

```@docs
QUMO.convert_mixed_ising_to_positive_qumo
```

```@docs
QUMO.convert_positive_qumo_to_mixed_ising
```

```@docs
QUMO.convert_to_qumo
```

```@docs
QUMO.convert_to_mixed_ising
```

## Solver

### Energy computations

```@docs
Solver.calculate_energies!
```

```@docs
Solver.calculate_energies
```

```@docs
Solver.count_min_energy_hits
```

### Non-linearities and walls

```@docs
Solver.@make_non_linearity
```

```@docs
Solver.non_linearity_tanh!
```

```@docs
Solver.non_linearity_sign!
```

```@docs
Solver.non_linearity_binary!
```

```@docs
Solver.@make_wall
```

```@docs
Solver.enforce_inelastic_wall!
```

### Samplers

```@docs
Solver.@make_sampler
```

```@docs
Solver.sample_mixed_ising!
```

```@docs
Solver.sample_qumo!
```

```@docs
Solver.sample_positive_qumo!
```

```@docs
Solver.SamplerTracer.Periodic
```

```@docs
Solver.SamplerTracer.SamplerWithPlan
```

```@docs
Solver.sample_qumo_with_tracer!
```

```@docs
Solver.sample_mixed_ising_with_tracer!
```

### Exploration

```@docs
Solver.@make_exploration
```

```@docs
Solver.explore_mixed_ising
```

```@docs
Solver.explore_qumo
```

```@docs
Solver.explore_positive_qumo
```

```@docs
Solver.ExplorationResult
```

```@docs
Solver.Collector.BestFound
```

```@docs
Solver.Collector.BestSolutionState
```

### Solver initialization

```@docs
Solver.AbstractProblem
```

```@docs
Solver.Problem
```

```@docs
Solver.make_annealing_delta
```

```@docs
Solver.Setup
```

```@docs
Solver.make_empty_setup
```

```@docs
Solver.make_setup
```

```@docs
Solver.Workspace
```

```@docs
Solver.make_workspace
```

```@docs
Solver.initialize_workspace!
```

```@docs
Solver.ConfigurationSpace
```

```@docs
Solver.sample_configuration_space
```

### Main solver methods and analysis of results

```@docs
Solver.TEnergyObservations
```

```@docs
Solver.@make_solver
```

```@docs
Solver.solve_mixed_ising
```

```@docs
Solver.solve_qumo
```

```@docs
Solver.solve_positive_qumo
```

```@docs
Solver.get_solver_results_summary
```

```@docs
Solver.find_best
```

```@docs
Solver.search_for_best_configuration
```

```@docs
Solver.extract_runtime_information
```

### Internal

The following internal methods are not intended for direct use.

```@docs
Solver._widen_for_eval
```

```@docs
Solver._find_and_display_negative_values
```


```@docs
Solver._get_time_to_solution
```

```@docs
Solver._get_num_operations_to_solution
```

```@docs
Solver._are_all_diags_zero
```

```@docs
Solver._MAX_NUMBER_OF_CPU_THREADS
```

```@docs
Solver._dispose
```

```@docs
Solver._optimal_batch_size
```

```@docs
Solver.Collector._default_best_assignment_collector
```

## `API`

The `AOCoptimizer.api` module contains simplified (and rigid) interfaces to the solver.
They're easier to use than the normal interfaces, but they don't give access to most configuration parameters.

```@docs
api.adjust_inputs_to_engine
```

```@docs
api.GraphCutResult
```

```@docs
api.compute_max_cut
```

```@docs
api.IsingResult
```

```@docs
api.compute_ising
```

```@docs
api.compute_mixed_ising
```

```@docs
api.compute_qumo_positive
```

```@docs
api.compute_qumo
```
