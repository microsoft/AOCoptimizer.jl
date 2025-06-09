#=
configuration.jl

A configuration is a a choice of parameters that are used in the solver.
The parameters include the annealing coefficient, the momentum coefficient,
and the gradient coefficient; it does *not* include dt.

Below are method related to defining a configuration space,
and sampling points from that space.

Typically, caller creates a configuration space:

```julia
using IntervalSets

cs = ConfigurationSpace{Float32}(0.01 .. 1.0, 0.01 .. 3.0, 0.9 .. 0.9)
parameters_to_explorer = sample_configuration_space(100, cs)
```

The last will generate 100 uniform configuration points in the region:
0.01-1.0, 0.01-3.0 for the annealing and gradient coefficients;
the momentum coefficient is constant set to 1.0, in this example.

An alternative way is to use:

```julia
parameters_to_explore = sample_configuration_space(100, 100, 0.01, 1.0, 0.01, 1.0)
````

Observe in the last example the absence of the momentum parameter implies that it is
set to 0.9.
=#

"""
    ConfigurationSpace{T<:Real}

Defines a configuration space, i.e., the set of coefficients for the parameters
of the algorithm we are interested in (parameters are annealing, gradient, and momentum
coefficients).
"""
struct ConfigurationSpace{T<:Real}
    Annealing::ClosedInterval{T}
    Gradient::ClosedInterval{T}
    Momentum::ClosedInterval{T}

    function ConfigurationSpace(
        annealing::ClosedInterval{T},
        gradient::ClosedInterval{T},
        momentum::ClosedInterval{T},
    ) where {T<:Real}
        @assert T(0) <= annealing.left <= annealing.right
        @assert T(0) <= gradient.left <= gradient.right
        @assert T(0) <= momentum.left <= momentum.right < T(1.0)

        new{T}(annealing, gradient, momentum)
    end

    function ConfigurationSpace{T}() where {T<:Real}
        annealing = T(0.01) .. T(1.0)
        gradient = T(0.01) .. T(1.0)
        momentum = T(0.9) .. T(0.9)
        new{T}(annealing, gradient, momentum)
    end

    ConfigurationSpace() = ConfigurationSpace{Float32}()
    ConfigurationSpace(
        annealing::ClosedInterval{T},
        gradient::ClosedInterval{T},
    ) where {T<:Real} = ConfigurationSpace(annealing, gradient, T(0.9) .. T(0.9))

    function ConfigurationSpace{T}(
        annealing::ClosedInterval{<:Real},
        gradient::ClosedInterval{<:Real},
        momentum::ClosedInterval{<:Real},
    ) where {T<:Real}
        @assert T(0) <= T(annealing.left) <= T(annealing.right)
        @assert T(0) <= T(gradient.left) <= T(gradient.right)
        @assert T(0) <= T(momentum.left) <= T(momentum.right) < T(1.0)

        new_annealing = T(annealing.left) .. T(annealing.right)
        new_gradient = T(gradient.left) .. T(gradient.right)
        new_momentum = T(momentum.left) .. T(momentum.right)
        new{T}(new_annealing, new_gradient, new_momentum)
    end

    ConfigurationSpace{T}(
        annealing::ClosedInterval{<:Real},
        gradient::ClosedInterval{<:Real},
    ) where {T<:Real} = ConfigurationSpace{T}(annealing, gradient, T(0.9) .. T(0.9))
end

"""
    sample_configuration_space(T, number_of_configurations;
                               annealing::ClosedInterval,
                               gradient::ClosedInterval,
                               momentum::ClosedInterval)

Generates a set of `number_of_configurations` points that sample
the space of valid coefficients for the parameters used by the sampler.
The valid values of coefficients are determined by the intervals
`annealing`, `gradient` and `momentum`.
"""
function sample_configuration_space(
    T::DataType,
    number_of_configurations::Integer;
    annealing::ClosedInterval{<:Real} = 0.01 .. 1.0,
    gradient::ClosedInterval{<:Real} = 0.01 .. 1.0,
    momentum::ClosedInterval{<:Real} = 0.6 .. 0.99,
)
    @assert T <: Real
    @assert number_of_configurations > 0
    @assert 0 <= annealing.left <= annealing.right
    @assert 0 <= gradient.left <= gradient.right
    @assert 0 <= momentum.left <= momentum.right < 1.0

    s = SobolSeq(
        [annealing.left, gradient.left, momentum.left],
        [annealing.right, gradient.right, momentum.right],
    )

    skip(s, number_of_configurations)
    configurations = zeros(T, number_of_configurations, 3)
    for i = 1:number_of_configurations
        c = @view configurations[i, :]
        next!(s, c)
    end

    annealing = @view configurations[:, 1]
    gradient = @view configurations[:, 2]
    momentum = @view configurations[:, 3]

    return annealing, gradient, momentum
end

sample_configuration_space(
    number_of_configurations::Integer,
    space::ConfigurationSpace{T},
) where {T<:Real} = sample_configuration_space(
    T,
    number_of_configurations;
    annealing = space.Annealing,
    gradient = space.Gradient,
    momentum = space.Momentum,
)

sample_configuration_space(
    T::DataType,
    number_of_configurations::Integer,
    annealing_low::Real,
    annealing_high::Real,
    gradient_low::Real,
    gradient_high::Real,
    momentum_low::Real,
    momentum_high::Real,
) = sample_configuration_space(
    T,
    number_of_configurations;
    annealing = annealing_low .. annealing_high,
    gradient = gradient_low .. gradient_high,
    momentum = momentum_low .. momentum_high,
)

sample_configuration_space(
    T::DataType,
    number_of_configurations::Integer,
    annealing_low::Real,
    annealing_high::Real,
    gradient_low::Real,
    gradient_high::Real,
) = sample_configuration_space(
    T,
    number_of_configurations;
    annealing = annealing_low .. annealing_high,
    gradient = gradient_low .. gradient_high,
    momentum = T(0.9) .. T(0.9),
)

function sample_single_configuration!(
    samples::AbstractVector{T},
    low::T,
    high::T,
) where {T<:Real}
    @assert low <= high

    s = SobolSeq(low, high)
    skip(s, length(samples))
    for i = 1:lastindex(samples)
        samples[i] = next!(s)[1]
    end
end

sample_single_configuration!(
    samples::AbstractVector{T},
    low::Real,
    high::Real,
) where {T<:Real} = sample_single_configuration!(samples, T(low), T(high))

function sample_single_configuration(T::DataType, samples::Integer, low::Real, high::Real)
    @assert T <: Real
    @assert T(low) <= T(high)
    result = Vector{T}(undef, samples)
    sample_single_configuration!(result, T(low), T(high))
    return result
end
