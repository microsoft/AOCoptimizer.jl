#=
test_metrics.jl

Unit tests for computations of hamiltonians and max-cuts
=#

module TestMetrics

using Test
using AOCoptimizer: hamiltonian, graph_cut_from_hamiltonian

include("utils.jl")

#= Observe the negative sign:
connected nodes i, j repel each other when w_{i,j} > 0
=#
const graph_01 = -[
    0 1 0 0
    1 0 0 0
    0 0 0 1
    0 0 1 0
]


@testset verbose=verbose "Metrics tests" begin

    @testset "Test simple Hamiltonian" begin
        @test hamiltonian(graph_01, [ 0;  0;  0;  0]) == 0
        @test hamiltonian(graph_01, [ 1; -1; 1;  -1]) == -2
        @test hamiltonian(graph_01, [ 1;  1; 1;   1]) == 2
        @test hamiltonian(graph_01, [-1; -1; -1; -1]) == 2
    end

    @testset "Test conversions to graph cut" begin
        # Need to negate the graph weights, since the original matrix
        # was created for the hamiltonian function
        @test graph_cut_from_hamiltonian(-graph_01, -2) == 2
        @test graph_cut_from_hamiltonian(2 * 2, -2) == 2
    end

end # testset

end # module TestMetrics