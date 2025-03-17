```@meta
CurrentModule = AOCoptimizer.FileFormats
DocTestSetup = quote
    import AOCoptimizer as AOC
    import AOCoptimizer.FileFormats as FF
end
DocTestFilters = [r"AOCoptimizer|AOC|FF"]
```

# AOCoptimizer.FileFormats

```@docs
FileNotFoundException
```

```@docs
GraphIOException
```

## Simple graph file format

```@docs
read_graph_matrix
```

```@docs
read_directed_graph_matrix
```

## QIO File Format

```@docs
QIO.QIOProblem
```

```@docs
QIO.Ising
```

```@docs
QIO.QUBO
```

```@docs
QIO.Metadata
```

```@docs
QIO.QIOException
```

```@docs
QIO.read_qio
```

```@docs
QIO.is_qubo
```

```@docs
QIO.is_ising
```
