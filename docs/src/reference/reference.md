<!-- markdownlint-disable MD041 -->
```@meta
CurrentModule = AOCoptimizer
DocTestSetup = quote
    import AOCoptimizer as AOC
end
DocTestFilters = [r"AOCoptimizer|AOC"]
```
<!-- markdownlint-enable MD041 -->

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
