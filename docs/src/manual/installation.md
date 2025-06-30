# Installation

## Prerequisites

In case you don't have Julia installed, please refer to the
[Julia installation guide](https://julialang.org/install/).
(Although the easiest way is to use the Julia installer directly,
it's better to follow the instructions from the installation guide.)

If you have not used Julia before, you may want to create a new
project from which you will use the `AOCoptimizer` package.
Start Julia in your working directory with `julia`and run the following commands
(they will create a new directory called `MyProject`, and initialize
the project in it):

```julia
using Pkg
Pkg.generate("MyProject")
```

(A better way to create a new project is by using the
[PkgSkeleton.jl](https://github.com/tpapp/PkgSkeleton.jl) package.

If you want to use CUDA, you will also need to make sure that
the drivers for your GPU are installed and that the CUDA Toolkit
is available on your system. You can find the installation instructions
on the [NVIDIA CUDA Toolkit page](https://developer.nvidia.com/cuda-downloads).

## Adding `AOCoptimizer.jl` to your project

(If you have just created a new project, with the instructions above,
make sure to `cd` into the `MyProject` directory first and then start Julia
with `julia --project`, or alternatively activate the new project from
inside Julia with `Pkg.activate("MyProject")`.)

Add the `AOCoptimizer` package to your project by running the following command
(make sure you have used `using Pkg` first):

```julia
Pkg.add(url="https://github.com/microsoft/AOCoptimizer.jl")
```

If the above does not work with the error
`ERROR: invalid git HEAD (reference 'refs/head/master' not found)`
please try the following:

```julia
Pkg.dev(url="https://github.com/microsoft/AOCoptimizer.jl#main")
```

If you also want to use `CUDA` or `JuMP`,
you should also install the corresponding packages.
For the case of `CUDA`, run:

```julia
Pkg.add("CUDA")
```

For `JuMP`, run:

```julia
Pkg.add("JuMP")
Pkg.add("MathOptInterface")
```

Verify that the `AOCoptimizer` package is installed correctly by running:

```julia
Pkg.test("AOCoptimizer")
```

## Adding `AOCoptimizer.jl` as a dependency to your project

The approach described in the previous section works for projects
that either add the `Manifest.toml` file to the repository (in general not recommended),
or for projects that don't use version control at all. The reason is that
the `URL` of the `AOCoptimizer` package doesn't appear in the `Project.toml` file,
hence, creating problems for other developers who want to use the project
that depends on `AOCoptimizer`.

Instead, for such projects manually modify your `Project.toml` file to contain
the following statements:

```toml
[deps]
AOCoptimizer = "ba4aa9bd-6938-48c2-966f-258481ba1c4a"

[sources]
AOCoptimizer = {url = "https://github.com/microsoft/AOCoptimizer.jl"}
```
