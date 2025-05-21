<!-- markdownlint-disable MD041 -->
```@meta
CurrentModule = AOCoptimizer
DocTestSetup = quote
    import AOCoptimizer as AOC
end
DocTestFilters = [r"AOCoptimizer|AOC"]
```
<!-- markdownlint-enable MD041 -->

# Abstractions

In addition to the QUMO abstraction, where the binary variables take the value 0 or 1,
and the continuous variables are in the range ``[-1, 1]``, there are a couple of more variants
that may be useful for specific applications:

- **p-QUMO**: This is a variant of QUMO where the binary variables take the value 0 or 1,
  and the continuous variables are in the range ``[0, 1]`` (i.e., no negative values).
  This is useful for applications where the continuous variables express allocations
  (e.g., in portfolio optimization).

- **mixed-Ising**: This is a variant of QUMO where the binary variables take the value -1 or 1,
  and the continuous variables are in the range ``[-1, 1]``. This is a natural extension of the
  Ising model.

These variants, alongside QUBO, are summarized in the following table:

|                       | Continuous: ``[-1, 1]`` | Continuous: ``[0, 1]`` | No continuous |
| :-------------------- | :---------------------: | :--------------------: | :-----------: |
| **Discrete: 0 or 1**  | QUMO                    | p-QUMO                 | QUBO          |
| **Discrete: -1 or 1** | mixed-Ising             | (n.a.)                 | Ising         |

Internally, by default the solver uses the mixed-Ising representation,
and there is also support for native solving the QUMO representation.
In the absence of continuous variables, the solver is effectively an Ising solver
(via the `solve` function), and a QUBO solver (via the `solve_qumo` function).

TODO: Reference the `solve` and `solve_qumo` functions.

Conversions between the different representations are supported via
[`convert_to_qumo`](@ref AOCoptimizer.QUMO.convert_to_qumo) (of a mixed Ising problem)
[`convert_to_mixed_ising`](@ref AOCoptimizer.QUMO.convert_to_mixed_ising) (of a QUMO problem)
[`convert_positive_qumo_to_mixed_ising`](@ref AOCoptimizer.QUMO.convert_positive_qumo_to_mixed_ising) (of a p-QUMO problem).
Hence, to convert p-QUMO to QUMO, first convert to mixed-Ising, and then to QUMO.

TODO: Provide direct conversion from p-QUMO to QUMO.

Typically, it is better to express the problem in the more natural form,
and then use the existing methods to convert to QUMO or mixed-Ising;
this avoid conversion bugs that are often difficult to track down.
