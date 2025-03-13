# Project

The [Analog Optical Computer (AOC)](https://www.microsoft.com/en-us/research/project/aoc/) project is building
an analog optical computer that has the potential to accelerate AI inference and hard optimization workloads by 100x.
To achieve this, we rely on a physical system to embody the computations and
step away from several fundamentally limiting aspects of digital computing
avoiding the separation of compute from memory,
operating on both continuous and binary data and adopting asynchronous operation that
allows the computer to operate at the “speed of light”.
It is built using commodity optical and electronic technologies that are low cost and scalable,
showing the potential of analog optical computing in the post-Moore Law’s era.

A key aspect of AOC is its hardware and abstraction have been co-designed with the target applications, i.e.,
the families of optimization and ML algorithms, to take advantage of the computer’s strengths
while accommodating its shortcoming and non-idealities.
As part of the co-design, we are developing a set of algorithms that are tailored to the AOC hardware.
We hope that this will enable the community to explore the potential of analog optical computing,
to develop new algorithms and applications, and to inform the design of future analog optical computers.

This repository contains the implementation of AOC-inspired algorithms
targetting optimization and control problems.
The algorithms are implemented in the [Julia](https://julialang.org/) programming language and
make use of modern computing capabilities (GPU acceleration, vectorization, etc.)
to enable the exploration of the potential of analog optical computing for problems of non-trivial size.
In their simplest form, they present an idealized (i.e., noise-free), scalable version of the AOC hardware.

_TODO_: Add reference for citations

## Getting started

Install the package as follows:

```julia
] add https://github.com/microsoft/AOCoptimizer.jl
# or
using Pkg
Pkg.add(url="https://github.com/microsoft/AOCoptimizer.jl", rev="main")
```

After successful installation, the following should work:

```julia
# if you want to use CUDA, first uncomment the following line to load CUDA.jl
# using CUDA
using AOCoptimizer
```

To further check the installation, run the following command (it may take a while to finish):

```julia
] test AOCoptimizer
# or
using Pkg
Pkg.test("AOCoptimizer")
```

More details on installation and basic usage can be found in the
[docs](https://microsoft.github.io/AOCoptimizer.jl),
in particular in the [installation](https://microsoft.github.io/AOCoptimizer.jl/dev/manual/installation/) and
in the [example](https://microsoft.github.io/AOCoptimizer.jl/dev/tutorials/example/).

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

<!-- Tidyverse lifecycle badges, see https://www.tidyverse.org/lifecycle/ Uncomment or delete as needed. -->
![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)
<!--
![lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)
![lifecycle](https://img.shields.io/badge/lifecycle-stable-green.svg)
![lifecycle](https://img.shields.io/badge/lifecycle-retired-orange.svg)
![lifecycle](https://img.shields.io/badge/lifecycle-archived-red.svg)
![lifecycle](https://img.shields.io/badge/lifecycle-dormant-blue.svg)
-->
[![build](https://github.com/microsoft/AOCoptimizer.jl/workflows/CI/badge.svg)](https://github.com/microsoft/AOCoptimizer.jl/actions?query=workflow%3ACI)
<!-- travis-ci.com badge, uncomment or delete as needed, depending on whether you are using that service. -->
<!-- [![Build Status](https://travis-ci.com/microsoft/AOCoptimizer.jl.svg?branch=master)](https://travis-ci.com/microsoft/AOCoptimizer.jl) -->
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://microsoft.github.io/AOCoptimizer.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://microsoft.github.io/AOCoptimizer.jl/dev)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
