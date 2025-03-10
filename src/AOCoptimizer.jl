# Copyright (c) 2025: Microsoft Research, Ltd.
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE file or at https://opensource.org/licenses/MIT.

"""
`AOCoptimizer` is a Julia package for solving `QUBO` (Quadratic Unconstrained Binary Optimization) and
`QUMO` (Quadratic Unconstrained Binary Optimization) problems.
"""
module AOCoptimizer

using Compat

@compat public Direction, MINIMIZATION, MAXIMIZATION
@compat public CancellationToken, create_cancellation_token, is_cancelled, cancel!

"""
    Direction

An enum of possible values for the direction of optimization.
The optimizer can either minimize (`MINIMIZATION`) or
maximize (`MAXIMIZATION`) the objective function.
"""
@enum Direction begin
    MINIMIZATION
    MAXIMIZATION
end

include("threading.jl")
include("runtime_utils.jl")
include("qubo.jl")

include("precompile.jl")

end # module
