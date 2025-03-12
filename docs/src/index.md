# `AOCoptimizer.jl`

Welcome to the documentation of the [`AOCoptimizer.jl`](https://github.com/microsoft/AOCoptimizer.jl)
Julia package.
`AOCoptimizer.jl` is a package for solving **Quadratic Unconstrained Mixed Optimization** (`QUMO`) problems.

## The `QUMO` Abstraction

`QUMO` is a new abstraction designed for expressing practical optimization problems that
aligns seamlessly with innovative hardware solutions
(e.g., [Project `AOC`](https://www.microsoft.com/en-us/research/project/aoc/)).
`QUMO` broadens the scope of the established models often referred to as
[Ising](https://en.wikipedia.org/wiki/Ising_model),
[Max-Cut](https://en.wikipedia.org/wiki/Maximum_cut),
or [Quadratic Unconstrained Binary Optimization (QUBO)](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization),
by allowing continuous variables alongside binary variables.
The `QUMO` extension allows a more natural expression of problems involving both continuous
and binary (decision) variables, eliminating the need for the binarization of continuous variables
that increases problem size. In addition, `QUMO` efficiently integrates inequality constraints by
introducing a single continuous slack variable for each constraint. Hence, the `QUMO` abstraction
represents practical problems using fewer variables and by staying closer to the original problem
formulation, it often yields better solutions than `QUBO`.

Formally, `QUMO` seeks an assignment to `N` variables
``{\bf x}={\left[{x_1, \ldots,  x_N}\right]}^T`` of the objective:

```math
  \min_{{\bf x}}\: -\frac{1}{2} {\bf x}^T \cdot {\bf Q} \cdot {\bf x} - {\bf q}^T\cdot {\bf x} =
  \min_{{\bf x}}\: -\frac{1}{2} \sum_{i=1}^N {Q_{ii} x^2_i} -
  \frac{1}{2}\sum_{\substack{i,j=1 \\ i \neq j}}^N {Q_{ij}x_{i}x_{j}} - \sum_{i=1}^N {q_{i} x_{i}}
```

for a given matrix ``{\bf Q}`` and vector ``{\bf q}`` representing the problem.
The variables can be either binary, i.e., ``x_i \in \{0, 1\}``,
or continuous in the (closed) range, i.e., ``x_i \in \left[-1, 1\right]``,
while the matrix ``{\bf Q}`` is symmetric, i.e., ``Q_{ij} = Q_{ji}``.
We do not require semi-definiteness or convexity for the input problem.
The diagonal entries of ``{\bf Q}`` are zero for the binary variables,
as quadratic terms of the form ``Q_{ii} x_i^2`` are equivalent to
``Q_{ii} x_i`` and, hence,
can be incorporated into the relevant linear terms by updating ``q_i``
accordingly, i.e., ``q_i \leftarrow q_i + 0.5\cdot Q_{ii}`` and then ``Q_{ii} \leftarrow 0``.

For more details on the `QUMO` and related abstractions,
please refer to the [abstractions](background/abstractions.md) section of the documentation.

## Installation and Usage

In a nutshell, you can install the package using the Julia package manager:

```julia
] add https://github.com/microsoft/AOCoptimizer.jl
# or
using Pkg
Pkg.add(url="https://github.com/microsoft/AOCoptimizer.jl", rev="main")
```

After successful installation, you can use the package by loading it:

```julia
# if you want to use CUDA, first uncomment the following line to load CUDA.jl
# using CUDA
using AOCoptimizer
```

TODO: Add a simple example in the code above

For more detailed installation instructions and related problems,
please refer to the [installation](manual/installation.md) section of the documentation.
