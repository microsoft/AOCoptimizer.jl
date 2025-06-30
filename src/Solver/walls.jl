#=
walls.jl

Implements functionality related to enforcing that spins
do not exceed upper and lower bounds.

The methods defined below are assumed to be used internally,
hence, there are limited checks on the inputs, i.e., they
are assumed to be called with already validated inputs.

The main method implemented is `enforce_inelastic_wall!`,
which enforces the spins to be within specified
`lower` and `upper` bounds.

=#

@kernel function _enforce_inelastic_wall_kernel!(
    x::AbstractArray{T,N},
    upper = T(1.0),
    lower = T(-1.0)
) where {T<:Real,N}
    I = @index(Global)
    @inbounds begin
        if x[I] > upper
            x[I] = upper
        elseif x[I] < lower
            x[I] = lower
        end
    end
end

@kernel function _enforce_inelastic_wall_kernel!(
    x::AbstractArray{T,N},
    y::AbstractArray{T,N},
    upper = T(1.0),
    lower = T(-1.0)
) where {T<:Real,N}
    I = @index(Global)
    @inbounds begin
        if x[I] > upper
            x[I] = upper
            y[I] = zero(T)
        elseif x[I] < lower
            x[I] = lower
            y[I] = zero(T)
        end
    end
end

function _enforce_inelastic_wall!(
    backend::Backend,
    x::AbstractArray{T,N},
    upper = T(1.0),
    lower = T(-1.0)
) where {T<:Real,N}
    kernel = _enforce_inelastic_wall_kernel!(backend)
    kernel(x, upper, lower, ndrange = size(x))
    synchronize(backend)
    return nothing
end

function _enforce_inelastic_wall!(
    kernel::KernelAbstractions.Kernel,
    x::AbstractArray{T,N},
    upper = T(1.0),
    lower = T(-1.0)
) where {T<:Real,N}
    kernel(x, upper, lower, ndrange = size(x))
    synchronize(backend)
    return nothing
end

# For CPU backends, we prefer just to use SIMD but not
# multithreading; we use multithreading in the outer
# loop.

@inline function _enforce_inelastic_wall!(
    ::CPU,
    x::AbstractArray{T,N},
    upper = T(1.0),
    lower = T(-1.0)
) where {T<:Real,N}
    @simd for index in range(1, length = length(x))
        @inbounds begin
            if x[index] > upper
                x[index] = upper
            elseif x[index] < lower
                x[index] = lower
            end
        end
    end

    return nothing
end

@inline function _enforce_inelastic_wall!(
    ::CPU,
    y::AbstractArray{T,N},
    x::AbstractArray{T,N},
    upper = T(1.0),
    lower = T(-1.0)
) where {T<:Real,N}
    @assert length(x) == length(y)

    @simd for index in range(1, length = length(x))
        @inbounds if x[index] > upper
            x[index] = upper
            y[index] = zero(T)
        elseif x[index] < lower
            x[index] = lower
            y[index] = zero(T)
        end
    end

    return nothing
end

"""
    enforce_inelastic_wall!(x::AbstractArray{T,N}, upper::T, lower::T) where {T<:Real,N}
    enforce_inelastic_wall!(x::AbstractArray{T,N}, y::AbstractArray{T,N}, upper::T, lower::T) where {T<:Real,N}

Enforces that the elements of `x` are within the specified `lower` and `upper` bounds.
If `y` is provided, it is modified to zero for the corresponding elements for which
`x` exceeds the bounds.
"""
@inline enforce_inelastic_wall!(x::AbstractArray{T,N}, upper::T, lower::T) where {T<:Real,N} =
    _enforce_inelastic_wall!(get_backend(x), x, upper, lower)
@inline enforce_inelastic_wall!(x::AbstractArray{T,N}, y::AbstractArray{T,N}, upper::T, lower::T) where {T<:Real,N} =
    _enforce_inelastic_wall!(get_backend(x), x, y, upper, lower)


"""
    @make_wall(name, lower, upper)

Creates functions that enforce an inelastic wall
for a given `name`, with specified `lower` and `upper` bounds.
"""
macro make_wall(name, lower, upper)
    @assert lower <= upper "Lower bound must be less than or equal to upper bound"

    return quote
        @inline function $(esc(name))(x::AbstractArray{T,N}) where {T<:Real,N}
            enforce_inelastic_wall!(x, T($upper), T($lower))
            return nothing
        end
        @inline function $(esc(name))(
            x::AbstractArray{T,N},
            y::AbstractArray{T,N}
        ) where {T<:Real,N}
            enforce_inelastic_wall!(x, y, T($upper), T($lower))
            return nothing
        end
    end
end

@make_wall(enforce_inelastic_wall_ising!, -1, 1)
@make_wall(enforce_inelastic_wall_positive!, 0, 1)
