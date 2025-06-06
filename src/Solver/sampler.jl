#=
sampler.jl

This file implements the main sampler class. It provides efficient
implementations of our version of gradient descent with momentum
and of annealing.

There are a number of dimensions over which the sampler needs to be
efficient both for GPUs and for CPUs:

    - The first dimension is the existence of an external field.

    - The second dimension is the search space for the binary variables.
    This can either be Ising, i.e. {-1, 1}, or binary, i.e. {0, 1}.
    The default is Ising, but in some problems we may use binary.

    - The third dimension is the search space for the continuous variables.
    This can either be [-1, 1] (default) or [0, 1].

It is unclear whether the search space for binary and continuous variables
are independent or not. For now we assume they are independent.

Another design decision has to do with the annealing schedule. The following
constraints apply to this case:

    - We want to be able to run the search process for some time,
    pause it (e.g., to measure performance, debug) and resume it later.

    - Each sampling process can have its own annealing rate. For all parallel
    samplers, this rate can either change (type II, and type III solvers),
    or stay the same (type I). No mix-and-match of solver type is allowed.

    - The annealing factor should always be non-negative. It does not
    need to become zero only at the end of the simulation (although, this
    will be the typical case).

=#

"""
    make_annealing_delta(annealing::AbstractVector, iterations::Integer)
    make_annealing_delta(setup::Setup, iterations::Integer)

Returns a vector of the values to be used for the annealing parameter.
"""
function make_annealing_delta end

function make_annealing_delta(
    annealing::AbstractVector{T},
    iterations::Integer,
)::AbstractVector{T} where {T<:Real}
    @assert iterations > 0
    delta = annealing ./ T(iterations)
    return delta
end

function make_annealing_delta(
    setup::Setup{T},
    iterations::Integer,
)::AbstractVector{T} where {T<:Real}
    @assert iterations > 0
    delta = setup.Annealing / T(iterations)
    return delta
end

epsilon_for_annealing(T::Type{<:Real}) = T(1e-6)
epsilon_for_annealing(::Type{Float16}) = Float16(0.01)
epsilon_for_annealing(::Type{BFloat16}) = BFloat16(0.05)

"""
    @make_sampler(
        name,
        binary_non_linearity,
        walls,
        bias,
        inplace_matrix_vector_multiplication,
        adjust_parameters = nothing,
        per_iteration_callback = nothing
    )

This macro generates a sampler function. The generated functions will be named `name!`.
It will use the functions `binary_non_linearity` and `walls` to apply
the binary non-linearity and the bounds to the variables, respectively.
The `inplace_matrix_vector_multiplication` function will be used to perform
the matrix-vector multiplication in-place, which is crucial for performance.
It allows to subtract a custom `bias` from all variables (typically zero,
but can be non-zero when simulating physical systems).

The caller can also provide two extensibility points:
(A) `adjust_parameters`, which allows to adjust the `gradient` and `momentum`;
(B) `per_iteration_callback`, which allows to run a callback at the end of each iteration.
"""
macro make_sampler(
    # Base name to use for the sampler function.
    # The actual function name will be `$name!`
    # (observe the exclamation mark).
    # ::AbstractString
    name,

    # Function to apply (in-place) the binary non-linearity,
    # element-wise to a matrix(vector) of binary variables.
    # ::Function TV{N} → Unit
    binary_non_linearity,

    # Function to use to apply bounds for all variables.
    # E.g., a typical choice is to limit all values to the range [-1, 1].
    # ::Function T<:Real → T<:Real
    walls,

    # Bias term to use for all variables. This value will be subtracted
    # ::Real
    bias,

    # Function to use that implements the `M ← M * A` operation.
    # ::Function TM{N, M} × TM{N, N} → TM{N, M},
    # where N: number of variables, M: number of experiments
    inplace_matrix_vector_multiplication,

    # Extensibility point that allows to adjust the `gradient` and `momentum`
    # parameters before running the sampling process.
    # The function takes three vectors corresponding to the gradient,
    # momentum, and annealing parameters, and returns two vectors
    # corresponding to the adjusted gradient and momentum.
    # Nothing or Function: TV * TV * TV → TV * TV
    adjust_parameters::Union{Nothing, Function} = nothing,

    # Extensibility point that allows to run a callback
    # at the end of each iteration (e.g., to collect statistics).
    # If a function is provided, it will be called with arguments
    # a user supplied state object, the iteration number, and the current
    # values of the spins; it should not return anything.
    # Nothing or Function: State * Integer * TV → Nothing
    per_iteration_callback::Union{Nothing, Function} = nothing,
)

    name_internal = Symbol("_", name, "_internal", "!")
    name_proper = Symbol(name, "!")

    return quote
        @inline function $(esc(name_internal))(
            # input; size: number_of_nodes x number_of_nodes
            interactions::AbstractMatrix{T},
            # input; either None or vector of size number_of_nodes
            external::Union{Nothing,AbstractVector{T}},
            # input; integer ≤ number_of_nodes
            binaries::Integer,
            # input; vector of size number_of_experiments
            gradient::AbstractVector{T},
            # input; vector of size number_of_experiments
            momentum::AbstractVector{T},
            # input, will change - initial spins, usually random;
            # size: number_of_nodes x number_of_experiments
            x::AbstractMatrix{T},
            # buffer storage - should be zero in the beginning, or equal to x
            # at the output, it will contain the final spins before the non-linearity;
            # size: number_of_nodes x number_of_experiments
            y::AbstractMatrix{T},
            # buffer storage; size: number_of_nodes x number_of_experiments
            fields::AbstractMatrix{T},
            # output; size: number_of_nodes x number_of_experiments
            spins::AbstractMatrix{T},
            # input, will change --- should be zero at the end;
            # size: number_of_experiments
            annealing::AbstractVector{T},
            # input; size: number_of_experiments
            delta::AbstractVector{T},
            # input
            dt::T,
            # input
            iterations::Integer,
            # State for the callback function
            per_iteration_callback_state::Union{Nothing,TIterationCallbackState} = nothing,
        ) where {T<:Real, TIterationCallbackState}

            for i = 1:iterations

                if $adjust_parameters === nothing
                    _annealing = annealing
                    _gradient = gradient
                    _momentum = momentum
                else
                    # We give the opportunity to the caller to adjust the parameters,
                    # e.g., by adding some form of noise.

                    _annealing = annealing

                    # The caller will return fresh vectors for _gradient and _momentum that adjust
                    # those values based on the current gradient and momentum values (e.g., by adding noise).
                    # The caller will adjust the value of annealing in place, i.e. we will observe a different
                    # value of annealing in the next iteration. This seems more natural because the errors
                    # in the annealing will need to be accounting when we adjust the annealing factor by
                    # subtracting delta below.
                    _gradient, _momentum = $adjust_parameters(gradient, momentum, _annealing)
                end

                @inbounds begin
                    @. spins = x
                    $(esc(binary_non_linearity))(@view spins[1:binaries, :])

                    # The mul! seems to work faster than the dot product.
                    # This is the most expensive operation (measured in the CPU)
                    $(esc(inplace_matrix_vector_multiplication))(fields, interactions, spins)
                    # fields .= interactions * spins  --- slower

                    # this is temporary storage
                    @. spins = x

                    #=
                    Update to variables. The rule is (two equivalent forms):
                        @. x += dt * gradient * fields - dt * annealing * x + momentum * (x - y)
                        x .+= dt .* gradient .* fields .- dt .* annealing .* x .+ momentum .* (x .- y)
                    (gradient should be gradient', momentum should be momentum',
                    and annealing should be annealing')

                    The new value of x should be:
                        x + dt * gradient * fields - dt * annealing * x + momentum * (x - y) =>
                        (1 - dt * annealing + momentum) * x + dt * gradients * fields - momentum * y
                    (notice that we require that the corresponding vectors distribute to the arrays
                    they need to update.)

                    Hence, we can rewrite as:
                        x *= (1 - dt * annealing + momentum)
                        x += dt * gradient * fields - momentum * y

                    Below observe that the @. does not work well with the GPU compiler,
                    hence we use the verbose syntax.
                    =#

                    # The expression below fails to compile in some configurations, why?
                    # @. x += dt * gradient' * fields - dt * annealing' * (x - T($bias)) + momentum' * (x - y)
                    # but, the following works fine:
                    # This is the second most expensive operation (measured in the CPU)
                    x .+=
                        dt .* _gradient' .* fields .- dt .* _annealing' .* (x .- T($bias)) .+
                        _momentum' .* (x .- y)

                    #= This is the alternative approach that seems to work better on the CPUs.
                    x .*= T(1.0) .+ momentum' .- dt .* annealing'
                    x .-= momentum' .* y
                    x .+= dt .* gradient' .* fields
                    =#

                    #=
                    Observe here that the energy function is (1/2)*x^T * M * x + E^T * x.
                    When we take derivatives, we get M * x + E.
                    This is why we do not need to account for the (1/2) in the computation above.
                    =#

                    if external !== nothing
                        x .+= dt .* _gradient' .* external
                    end

                    @. y = spins
                    $(esc(walls))(x)

                    _annealing .-= delta

                    # We need to check that the values did not become negative --- it will happen especially with Float16.
                    # The correction below does not seem to impact execution time.
                    _annealing .= max.(_annealing, T(0.0))
                end

                if $per_iteration_callback !== nothing
                    $(esc(per_iteration_callback))(per_iteration_callback_state, i, spins)
                end
            end

            # This is the final state of the spins.
            # Recall, that we have used the spins to store a copy of the x's.
            # Hence, we need to recompute them.
            @. spins = x
            $(esc(binary_non_linearity)).(spins[1:binaries, :])

            return nothing
        end

        function $(esc(name_proper))(
            # input problem; this will not change
            problem::Problem{T, TEval},
            # input that contains gradient, momentum and dt; this will not change
            setup::Setup{T},
            # scratch buffers that will be used to perform the sample; these buffers will change
            workspace::Workspace{T},
            # number of iterations to perform
            iterations::Integer,
            # vector of annealing factor; this will change and at the end typically contains zeros
            # the vector has size equal to the number of experiments to perform
            annealing_delta::AbstractVector{T},
            # State to be passed to the optional callback which is invoked at the end of each iteration
            per_iteration_callback_state::Union{Nothing,TIterationCallbackState}=nothing,
        ) where {T<:Real,TEval<:Real,TIterationCallbackState}

            spins = workspace.spins
            binaries = problem.Binary
            x = workspace.x
            y = workspace.y
            annealing = workspace.annealing
            fields = workspace.fields

            gradient = setup.Gradient
            momentum = setup.Momentum
            dt = setup.dt

            interactions = problem.Interactions
            external = problem.Field

            # Be careful of the dimensions of the matrices and vectors.

            $(esc(name_internal))(
                interactions,
                external,
                binaries,
                gradient,
                momentum,
                x,
                y,
                fields,
                spins,
                annealing,
                annealing_delta,
                dt,
                iterations,
                per_iteration_callback_state,
            )
        end
    end # quote

end # macro

"""
    sampler!(
        problem::Problem{T, TEval},
        setup::Setup{T},
        workspace::Workspace{T},
        iterations::Integer,
        annealing_delta::AbstractVector{T},
        per_iteration_callback_state::Union{Nothing,TIterationCallbackState}=nothing
    ) where {T<:Real, TEval<:Real, TIterationCallbackState}

Sampler for mixed Ising problems.
Arguments include:

- `problem` contains the input problem. The related matrices will not change.
   The computation will be performed using the `T` elementary data-type, but
   the evaluation of the energies will be performed using the `TEval` data-type.

- `setup` contains the setup parameters, such as the gradient, momentum, and dt.
   This will not change during the sampling process.

- `workspace` contains caller-provided scratch buffers that will be used to
  perform the sampling. This buffers will change during the sampling process,
  but the caller should not depend on the values in them after the sampling is done.

- `iterations` is the number of iterations to perform.

- `annealing_delta` is a vector of the annealing factor values to use.
  This vector will change during the sampling process, and at the end
  it will typically contain zeros.

- `per_iteration_callback_state` is an optional state that will be passed to the
  per-iteration callback function, if it is provided. This state can be used to
  collect statistics or to perform other actions at the end of each iteration.
"""
function sampler! end

"""
    sampler_binary!(
        problem::Problem{T, TEval},
        setup::Setup{T},
        workspace::Workspace{T},
        iterations::Integer,
        annealing_delta::AbstractVector{T},
        per_iteration_callback_state::Union{Nothing,TIterationCallbackState}=nothing
    ) where {T<:Real, TEval<:Real, TIterationCallbackState}

Sampler for mixed positive QUMO problems, where the binaries are `{0, 1}` and
the continuous in `[0, 1]`.
Arguments include:

- `problem` contains the input problem. The related matrices will not change.
   The computation will be performed using the `T` elementary data-type, but
   the evaluation of the energies will be performed using the `TEval` data-type.

- `setup` contains the setup parameters, such as the gradient, momentum, and dt.
   This will not change during the sampling process.

- `workspace` contains caller-provided scratch buffers that will be used to
  perform the sampling. This buffers will change during the sampling process,
  but the caller should not depend on the values in them after the sampling is done.

- `iterations` is the number of iterations to perform.

- `annealing_delta` is a vector of the annealing factor values to use.
  This vector will change during the sampling process, and at the end
  it will typically contain zeros.

- `per_iteration_callback_state` is an optional state that will be passed to the
  per-iteration callback function, if it is provided. This state can be used to
  collect statistics or to perform other actions at the end of each iteration.
"""
function sampler_binary! end

"""
    sampler_qumo!(
        problem::Problem{T, TEval},
        setup::Setup{T},
        workspace::Workspace{T},
        iterations::Integer,
        annealing_delta::AbstractVector{T},
        per_iteration_callback_state::Union{Nothing,TIterationCallbackState}=nothing
    ) where {T<:Real, TEval<:Real, TIterationCallbackState}

Sampler for mixed QUMO problems, where the binaries are `{0, 1}` and
the continuous in `[-1, 1]`.
Arguments include:

- `problem` contains the input problem. The related matrices will not change.
   The computation will be performed using the `T` elementary data-type, but
   the evaluation of the energies will be performed using the `TEval` data-type.

- `setup` contains the setup parameters, such as the gradient, momentum, and dt.
   This will not change during the sampling process.

- `workspace` contains caller-provided scratch buffers that will be used to
  perform the sampling. This buffers will change during the sampling process,
  but the caller should not depend on the values in them after the sampling is done.

- `iterations` is the number of iterations to perform.

- `annealing_delta` is a vector of the annealing factor values to use.
  This vector will change during the sampling process, and at the end
  it will typically contain zeros.

- `per_iteration_callback_state` is an optional state that will be passed to the
  per-iteration callback function, if it is provided. This state can be used to
  collect statistics or to perform other actions at the end of each iteration.
"""
function sampler_qumo! end

@make_sampler(sampler, non_linearity_sign!, enforce_inelastic_wall_ising!, 0, mul!)

@make_sampler(sampler_binary,
    non_linearity_binary!,
    enforce_inelastic_wall_binary!,
    0.5,
    mul!
)

@make_sampler(sampler_qumo,
    non_linearity_binary!,
    enforce_inelastic_wall_ising!,
    0.5,
    mul!
)