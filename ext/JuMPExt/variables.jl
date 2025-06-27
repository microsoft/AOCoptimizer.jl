#=
variables.jl
=#

"""
    Variable{T}

A struct representing a variable in the optimization problem
as it can be used in the AOCoptimizer. All variables should
have upper and lower bounds. This is trivial for binary variables,
but for continuous, the user should specify the bounds (or,
they should be easy to infer from the constraints---not implemented yet).
"""
struct Variable{T}
    type::Symbol
    lower::Union{T,Nothing}
    upper::Union{T,Nothing}

    function Variable{T}(type::Symbol; lower::Union{T,Nothing} = nothing, upper::Union{T,Nothing} = nothing) where T
        @assert type ∈ (:continuous, :binary)

        if type === :binary
            @assert isnothing(lower) && isnothing(upper)

            lower = zero(T)
            upper = one(T)
        else # type === :continuous
            if !isnothing(lower) && !isnothing(upper)
                @assert lower <= upper
            end
        end

        return new{T}(type, lower, upper)
    end
end

const VariableInfo{T} = Dict{VI,Variable{T}}

function is_bounded(v::Variable)
    return !isnothing(v.lower) && !isnothing(v.upper)
end

#

raw"""
    _scaling(l::V, u::V, L::V, U::V) where {T,V<:AbstractVector{T}}

Let ``\mathbf{y} \in [l, u] \subseteq \mathbb{R}^{n}`` be a vector of variables
in the original model and ``\mathbf{Y} \in [L, U] \subseteq \mathbb{R}^{n}``
the corresponding vector in the solver's frame of reference.

Then,

```math
\begin{align*}
  \mathbf{Y} &= \mathbf{L} + (\mathbf{y} - \mathbf{l}) \odot (\mathbf{U} - \mathbf{L}) \odiv (\mathbf{u} - \mathbf{l}) \\
             &= \mathbf{L} - \mathbf{l} \odot (\mathbf{U} - \mathbf{L}) \odiv (\mathbf{u} - \mathbf{l}) + \mathbf{y} \odot (\mathbf{U} - \mathbf{L}) \odiv (\mathbf{u} - \mathbf{l})
\end{align*}
```

Therefore, the linear transformation ``\mathbf{Y} = \mathbf{A} \mathbf{y} + \mathbf{b}`` is given by

```math
\begin{align*}
  \mathbf{A} &= \text{diag}\left(\frac{\mathbf{U} - \mathbf{L}}{\mathbf{u} - \mathbf{l}}\right) \\
  \mathbf{b} &= \mathbf{L} - \mathbf{l} \odot \frac{\mathbf{U} - \mathbf{L}}{\mathbf{u} - \mathbf{l}}
\end{align*}
```

"""
function _scaling(l::V, u::V, L::V, U::V) where {T,V<:AbstractVector{T}}
    #=
    We only need that `u .!= l`. If `u .== l`, then the best is to simplify the problem,
    but this should not happen here.
    In principle, we could allow `u_i < l_i` or `U_i < L_i`, for some i's,
    but this sounds counter-intuitive.
    =#
    @assert all(u .> l)
    @assert all(U .> L)

    S = (u - l) ./ (U - L)
    M = (u+l) / T(2) - S .* (U + L) / T(2)
    A = Diagonal(S)

    return (A, M)
end

function _scaling(info::VariableInfo{T}, vmap::Dict{VI,Int}) where {T}
    n = length(vmap)
    l = zeros(T, n)
    u = zeros(T, n)
    L = Vector{T}(undef, n)
    U = Vector{T}(undef, n)

    for (vi, i) in vmap
        v = info[vi]

        @assert is_bounded(v)

        l[i] = v.lower
        u[i] = v.upper

        if v.type === :binary
            L[i] = zero(T)
            U[i] = one(T)
        else # v.type === :continuous
            L[i] = -one(T)
            U[i] = one(T)
        end
    end

    return _scaling(l, u, L, U)
end

