#=
workspace.jl

Definitions for auxiliary buffers used by the sampler.
=#

"""
    Workspace{<:Real}

A workspace contains all the temporaries that the sampler needs.
The temporaries are allocated once and can be reused for multiple
samples. Use the `make_workspace` function to create a workspace,
and the `initialize_workspace` to initialize it between re-uses.

All the matrices below have dimensions equal to the
`number of variables` x `number of experiments`.
The `annealing` vector has length equal to the number of experiments.
"""
struct Workspace{T<:Real}
    x::AbstractMatrix{T}
    y::AbstractMatrix{T}
    spins::AbstractMatrix{T}
    fields::AbstractMatrix{T}
    annealing::AbstractVector{T}
end

Adapt.@adapt_structure(Workspace)
KernelAbstractions.get_backend(wks::Workspace) =
    KernelAbstractions.get_backend(wks.x)


"""
    _dispose(workspace::Workspace)

This function serves mostly as a marker to indicate that the workspace
is not used anymore and can be disposed of.
"""
_dispose(::Workspace) = return

TSampler = Distribution{Univariate,Continuous}
IsingSampler::TSampler = Distributions.Uniform(-1, 1)
BinarySampler::TSampler = Distributions.Uniform(0, 1)
IsingBoundedSampler(bound::Real)::TSampler = Distributions.Uniform(-bound, bound)
IsingInverseSizeSampler(size::Integer)::TSampler =
    Distributions.Uniform(-1 / sqrt(size), 1 / sqrt(size))

"""
    initialize_workspace!(
        rng::AbstractRNG,
        workspace::Workspace{T},
        annealing::AbstractVector{T},
        sampler::TSampler
    ) where {T<:Real}

Initializes a workspace by assigning random values to the initial spins.
Caller must also pass the initial values for the annealing terms
(typically, from the Setup{T} structure), and the sampler
for the initial values to use.
"""
function initialize_workspace!(
    rng::AbstractRNG,
    workspace::Workspace{T},
    annealing::AbstractVector{T},
    sampler::TSampler,
) where {T<:Real}

    # We do not need to zero the following temporaries here,
    # but it may protect against errors.
    fill!(workspace.y, zero(T))
    fill!(workspace.spins, zero(T))
    fill!(workspace.fields, zero(T))

    copyto!(workspace.annealing, annealing)
    rand!(rng, sampler, workspace.x)
end

"""
    make_workspace(problem::Problem, setup::Setup, number_of_samples::Integer)::Workspace
    make_workspace(problem::Problem, setup::Setup)::Workspace

Creates a workspace, i.e., a collection of temporary buffers, to be used by the sampler.
"""
function make_workspace end

function make_workspace(
    problem::Problem{T,TEval},
    setup::Setup{T},
    number_of_samples::Integer,
)::Workspace{T} where {T<:Real,TEval<:Real}
    @assert number_of_samples > 0

    n = problem.Size
    m = number_of_samples

    dims = (n, m)
    x = similar(setup.Gradient, dims)
    y = similar(setup.Gradient, dims)
    spins = similar(setup.Gradient, dims)
    fields = similar(setup.Gradient, dims)
    annealing = similar(setup.Annealing, (m,))

    wks = Workspace{T}(x, y, spins, fields, annealing)

    return wks
end

function make_workspace(
    problem::Problem{T,TEval},
    setup::Setup{T},
)::Workspace{T} where {T<:Real,TEval<:Real}

    # We assume that everything computed in the setup will be computed in parallel.
    batch_size = length(setup.Annealing)
    return make_workspace(problem, setup, batch_size)
end
