#=
utils.jl

Utility methods for the solver.
Should not be called directly.

=#

"""
    to_backend(backend::Backend, x)

Best effort conversion of `x` to the specified `backend`.
"""

abstract type BackendExtension end
struct BackendCuda <: BackendExtension end

_to_cpu(x) = Adapt.adapt(CPU(), x)
