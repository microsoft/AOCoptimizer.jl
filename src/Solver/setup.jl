#=
setup.jl

This file defines structs and auxiliary methods for setting up the parameter
space for the solver. I.e., the set of annealing, gradient and momentum factors
that will be used to solve the problem.
=#

"""
    _find_and_display_negative_values(x::AbstractVector{T}; max_to_print=5) where {T<:Real}

Internal method used for debugging purposes. It finds negative values in the vector `x`.
"""
function _find_and_display_negative_values(x::AbstractVector{T}; max_to_print=5) where {T<:Real}
    indices = findall(x .< zero(T))
    if length(indices) == 0
        return
    end

    number_of_negative_values = length(indices)
    if length(indices) > max_to_print
        indices = indices[1:max_to_print]
        extra = "..."
    else
        extra = ""
    end

    return "$(number_of_negative_values) negative values: $(x[indices])$extra in $(indices)$extra"
end

"""
    Setup{T<:Real}

This structure holds the configuration parameters that will be used in the solver.
The `Annealing`, `Gradient`, and `Momentum` vectors must all have the same length;
for each index `i`, the `i`-th element of each vector corresponds to the parameters
for the `i`-th experiment. The `dt` parameter is the time step used in the solver.
"""
struct Setup{T<:Real}
    Annealing::AbstractVector{T}
    Gradient::AbstractVector{T}
    Momentum::AbstractVector{T}
    dt::T

    function Setup(
        annealing::AbstractVector{T},
        gradient::AbstractVector{T},
        momentum::AbstractVector{T},
        dt::T,
    ) where {T<:Real}
        @assert length(annealing) == length(gradient)
        @assert length(annealing) == length(momentum)
        @assert all(annealing .>= zero(T)) "Annealing must be non-negative: $(_find_and_display_negative_values(gradient))"
        @assert all(gradient .>= zero(T)) "Gradient must be non-negative: $(_find_and_display_negative_values(gradient))"
        @assert all(momentum .>= zero(T)) "Momentum must be non-negative: $(_find_and_display_negative_values(momentum))"
        @assert dt > zero(T)
        @assert get_backend(annealing) == get_backend(gradient) == get_backend(momentum)

        new{T}(annealing, gradient, momentum, dt)
    end

    function Setup(
        annealing::AbstractVector{T},
        gradient::AbstractVector{T},
        momentum::T,
        dt::T,
    ) where {T<:Real}
        n = length(annealing)
        return Setup(annealing, gradient, fill(momentum, n), dt)
    end

    function Setup{T}(
        annealing::AbstractVector{<:Real},
        gradient::AbstractVector{<:Real},
        momentum::AbstractVector{<:Real},
        dt::Real,
    ) where {T<:Real}
        return Setup(
            convert(Vector{T}, annealing),
            convert(Vector{T}, gradient),
            convert(Vector{T}, momentum),
            T(dt),
        )
    end

    function Setup{T}(
        annealing::AbstractVector{<:Real},
        gradient::AbstractVector{<:Real},
        momentum::Real,
        dt::Real,
    ) where {T<:Real}
        n = length(annealing)
        return Setup(annealing, gradient, fill(momentum, n), dt)
    end

end

Adapt.@adapt_structure(Setup)
KernelAbstractions.get_backend(setup::Setup) =
    get_backend(setup.Annealing)

Base.length(setup::Setup) = length(setup.Annealing)

function Base.view(setup::Setup{T}, range::UnitRange{Int}) where {T<:Real}
    return Setup{T}(
        view(setup.Annealing, range),
        view(setup.Gradient, range),
        view(setup.Momentum, range),
        setup.dt,
    )
end

function Base.getindex(setup::Setup{T}, index::Integer) where {T<:Real}
    # The vectors in setup may reside in GPU. Hence, indexing for just
    # one element generates a warning. To avoid it, we bring the arrays
    # to cpu and then do the indexing.
    return Setup{T}(
        [Array(setup.Annealing)[index]],
        [Array(setup.Gradient)[index]],
        [Array(setup.Momentum)[index]],
        setup.dt,
    )
end

function Base.getindex(setup::Setup{T}, range::UnitRange{<:Integer}) where {T<:Real}
    return Setup{T}(
        copy(setup.Annealing[range]),
        copy(setup.Gradient[range]),
        copy(setup.Momentum[range]),
        setup.dt,
    )
end

function Base.getindex(setup::Setup{T}, range::AbstractVector{<:Integer}) where {T<:Real}
    return Setup{T}(
        copy(setup.Annealing[range]),
        copy(setup.Gradient[range]),
        copy(setup.Momentum[range]),
        setup.dt,
    )
end

function Base.show(io::IO, setup::Setup{T}) where {T<:Real}
    compact = get(io, :compact, false)

    if compact
        number_of_items_to_show = 4
    else
        number_of_items_to_show = 20
    end

    len = length(setup)
    if len > number_of_items_to_show
        if compact
            extra = "..."
        else
            extra = ", ..."
        end
    else
        extra = ""
    end

    if len >= 1000000
        lenstr = @sprintf("%-.2fM", len / 1000000)
    elseif len >= 1000
        lenstr = @sprintf("%-.2fK", len / 1000)
    else
        lenstr = @sprintf("%d", len)
    end

    v(vec::AbstractVector{T}) = first(vec, number_of_items_to_show)

    context = IOContext(io, :limit => true, :compact => compact, :displaysize => (1, 4))
    if compact
        print(
            context,
            "[$lenstr, dt=$(setup.dt)]: $(v(setup.Annealing))$extra, $(v(setup.Gradient))$extra, $(v(setup.Momentum))$extra",
        )
    else
        print(
            context,
            "Setup of length=$lenstr with dt=$(setup.dt) (of $(typeof(setup.Annealing))):\n",
        )
        print(context, "  Annealing : $(v(setup.Annealing))$extra\n")
        print(context, "  Gradient  : $(v(setup.Gradient))$extra\n")
        print(context, "  Momentum  : $(v(setup.Momentum))$extra\n")
    end
end

"""
    make_empty_setup(setup::Setup{T}, capacity::Integer) where {T<:Real}

Creates an empty `Setup` instance with the same structure as `setup`, but with
`capacity` elements in each vector. The vectors are filled with zeros.
"""
function make_empty_setup end

function make_empty_setup(setup::Setup{T}, capacity::Integer) where {T<:Real}
    dims = (capacity,)

    annealing = similar(setup.Annealing, dims)
    gradient = similar(setup.Gradient, dims)
    momentum = similar(setup.Momentum, dims)

    fill!(annealing, zero(T))
    fill!(gradient, zero(T))
    fill!(momentum, zero(T))

    return Setup(annealing, gradient, momentum, setup.dt)
end


"""
    make_setup(
        annealing::TV,
        gradient::TV,
        momentum::TV,
        dt::T,
        repetitions::Integer,
    ) where {T<:Real,TV<:AbstractVector{T}}
    function make_setup(
        annealing::TV,
        gradient::TV,
        momentum::T,
        dt::T,
        repetitions::Integer,
    ) where {T<:Real,TV<:AbstractVector{T}}
    function make_setup(
        T::Type{<:Real},
        annealing::AbstractVector{<:Real},
        gradient::AbstractVector{<:Real},
        momentum::AbstractVector{<:Real},
        dt::Real,
        repetitions::Integer,
    )
    function make_setup(
        T::Type{<:Real},
        annealing::AbstractVector{<:Real},
        gradient::AbstractVector{<:Real},
        momentum::Real,
        dt::Real,
        repetitions::Integer,
    )
Creates a `Setup` instance with the specified annealing, gradient, and momentum vectors,
repeated `repetitions` times. The `dt` parameter is the time step used in the solver.
If `T` is specified, it converts the vectors to that type.
"""
function make_setup end

function make_setup(
    annealing::TV,
    gradient::TV,
    momentum::TV,
    dt::T,
    repetitions::Integer,
) where {T<:Real,TV<:AbstractVector{T}}
    annealing = repeat(annealing, inner = repetitions)
    gradient = repeat(gradient, inner = repetitions)
    momentum = repeat(momentum, inner = repetitions)
    return Setup(annealing, gradient, momentum, dt)
end

function make_setup(
    annealing::TV,
    gradient::TV,
    momentum::T,
    dt::T,
    repetitions::Integer,
) where {T<:Real,TV<:AbstractVector{T}}
    n = length(annealing)
    momentum = full(momentum, n)
    return make_setup(annealing, gradient, momentum, dt, repetitions)
end

function make_setup(
    T::Type{<:Real},
    annealing::AbstractVector{<:Real},
    gradient::AbstractVector{<:Real},
    momentum::AbstractVector{<:Real},
    dt::Real,
    repetitions::Integer,
)
    return make_setup(T.(annealing), T.(gradient), T.(momentum), T(dt), repetitions)
end

function make_setup(
    T::Type{<:Real},
    annealing::AbstractVector{<:Real},
    gradient::AbstractVector{<:Real},
    momentum::Real,
    dt::Real,
    repetitions::Integer,
)
    momentum_vector = similar(annealing)
    fill!(momentum_vector, momentum)
    return make_setup(T, annealing, gradient, momentum_vector, T(dt), repetitions)
end

function copy_view_to!(dest::Setup{T}, source::Setup{T}) where {T<:Real}
    # This implementation has a number of problems.
    # It completely ignores the capacity of the dest.
    # If the source has fewer elements than the destination,
    # then we will have partial fills.
    #
    if length(dest) != length(source)
        error("Cannot copy view to setup with different lengths: $(length(dest)) != $(length(source))")
    end

    copyto!(dest.Annealing, source.Annealing)
    copyto!(dest.Gradient, source.Gradient)
    copyto!(dest.Momentum, source.Momentum)
end

function expand(setup::Setup{T}, repetitions::Integer) where {T<:Real}
    annealing = repeat(setup.Annealing, inner = repetitions)
    gradient = repeat(setup.Gradient, inner = repetitions)
    momentum = repeat(setup.Momentum, inner = repetitions)

    return Setup(annealing, gradient, momentum, setup.dt)
end

function reorder(setup::Setup{T}, ordering::AbstractVector{Int64}) where {T<:Real}
    dims = (length(ordering),)
    annealing = similar(setup.Annealing, dims)
    gradient = similar(setup.Gradient, dims)
    momentum = similar(setup.Momentum, dims)

    copyto!(annealing, setup.Annealing[ordering])
    copyto!(gradient, setup.Gradient[ordering])
    copyto!(momentum, setup.Momentum[ordering])

    return Setup(annealing, gradient, momentum, setup.dt)
end

function with_momentum_in!(setup::Setup{T}, low::T, high::T) where {T<:Real}
    d = Uniform(low, high)
    rand!(d, setup.Momentum)
end
