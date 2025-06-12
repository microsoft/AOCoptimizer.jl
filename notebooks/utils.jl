#=
utils.jl

Helper utils and common functions for the notebooks.
=#

using LinearAlgebra
using Random

function create_random_graph(T::Type{<:Real} = Float32, n::Int = 800)
    graph = rand(T, n, n);
    graph = graph + graph';
    graph -= Diagonal(diag(graph));
    graph = -graph;

    # no need to worry about correct computation of the eigenvalue
    # we do not care about the result here
    λ = eigmax(graph);
    graph /= λ;

    return graph
end