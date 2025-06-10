#=
utils.jl

Utility methods for the solver.
Should not be called directly.

=#

abstract type BackendExtension end
struct BackendCuda <: BackendExtension end

_to_cpu(x) = Adapt.adapt(CPU(), x)

_similar_vector(x::AbstractArray{T}, l) where {T} = similar(x, l)

"""
    _dispose(x::Any)

This function serves as a marker to indicate that the object `x` is not used anymore
and can be disposed of.
"""
_dispose(::Any) = return
