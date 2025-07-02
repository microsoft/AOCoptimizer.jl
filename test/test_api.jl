#=
test_api.jl

Unit tests for the interface provides in the api module
=#

module TestAPI

using Test
using Dates
using Distributions
using LinearAlgebra
using Random
using AOCoptimizer
using AOCoptimizer.api

include("utils.jl")

const aoc = AOCoptimizer

# AOCoptimizer.init()

const api = AOCoptimizer.api

function _make_cycle_graph(n::Integer)
    # Create a cycle graph with n nodes
    graph = zeros(Float32, (n, n))
    edges = [(i, (i % n) + 1) for i in 1:n]
    for (i, j) in edges
        graph[i, j] = 1.0
        graph[j, i] = 1.0
    end
    return graph
end

function _make_random_quadratic(n::Integer)
    uniform = Uniform(-1.0, 1.0)
    quadratic = zeros(Float32, (n, n))
    rand!(uniform, quadratic)
    quadratic = (quadratic + quadratic') / 2.0  # Make it symmetric
    quadratic = Float32.(quadratic)
    quadratic[diagind(quadratic)] .= 0.0
    return quadratic
end

@testset verbose=verbose "Test max cut API" begin
    @testset "Test cycle graph" begin
        n = 6
        graph = _make_cycle_graph(n)
        seed = 1234

        # Make sure to compile the code first
        api.compute_max_cut(graph, seed, 10)
        results = api.compute_max_cut(graph, seed, 10)

        @test results.Cut == 6.0
        @test results.Hamiltonian == -6.0
        @test results.Assignment == [1, -1, 1, -1, 1, -1] ||
              results.Assignment == [-1, 1, -1, 1, -1, 1]

        @test length(results.Group1) == 3
        @test length(results.Group2) == 3

        if 1 in results.Group1
            g1 = results.Group1
            g2 = results.Group2
        else
            g1 = results.Group2
            g2 = results.Group1
        end

        @test 1 in g1
        @test 2 in g2
        @test 3 in g1
        @test 4 in g2
        @test 5 in g1
        @test 6 in g2
    end
end

@testset verbose=verbose "Test Ising API" begin
    @testset "Test simple graph without field" begin
        n = 6
        graph = -_make_cycle_graph(n)
        seed = 123

        result = api.compute_ising(graph, nothing, seed, 10)
        @test result.Hamiltonian ≈ -6.0
        @test length(result.Assignment) == n
        @test all(x -> x in [-1, 1], result.Assignment)
        @test sum(result.Assignment) == 0
    end

    @testset "Test simple graph with field" begin
        n = 6
        graph = -_make_cycle_graph(n)
        field = rand(eltype(graph), n)
        seed = 111

        result = api.compute_ising(graph, field, seed, 10)
        @test length(result.Assignment) == n
        @test all(x -> x in [-1, 1], result.Assignment)
    end
end

@testset verbose=verbose "Test Mixed Ising API" begin
    @testset "Test simple mixed Ising without field and all binary" begin
        n = 6
        graph = -_make_cycle_graph(n)
        seed = 124

        result = api.compute_mixed_ising(graph, nothing, nothing, seed, 10)
        @test result.Hamiltonian ≈ -6.0
        @test length(result.Assignment) == n
        @test all(x -> x in [-1, 1], result.Assignment)
        @test sum(result.Assignment) == 0
    end

    @testset "Test simple graph with field and all binary" begin
        n = 6
        graph = -_make_cycle_graph(n)
        field = rand(eltype(graph), n)
        seed = 110

        result = api.compute_mixed_ising(graph, field, nothing, seed, 10)
        @test length(result.Assignment) == n
        @test all(x -> x in [-1, 1], result.Assignment)
    end

    @testset "Test simple mixed Ising with continuous variables and no external field" begin
        n = 6
        graph = -_make_cycle_graph(n)
        seed = 112

        continuous = zeros(Bool, n)

        continuous[collect(filter(isodd, 1:n))] .= true
        result = api.compute_mixed_ising(graph, nothing, continuous, seed, 10)
        @test length(result.Assignment) == n
        @test all(x -> -1 <= x <= 1, result.Assignment[continuous])
        @test all(x -> x in [-1, 1], result.Assignment[continuous .== false])
    end

    @testset "Test simple mixed Ising with continuous variables and external field" begin
        n = 6
        graph = -_make_cycle_graph(n)
        field = rand(eltype(graph), n)
        seed = 100

        continuous = zeros(Bool, n)

        continuous[collect(filter(isodd, 1:n))] .= true
        result = api.compute_mixed_ising(graph, field, continuous, seed, 10)
        @test length(result.Assignment) == n
        @test all(x -> -1 <= x <= 1, result.Assignment[continuous])
        @test all(x -> x in [-1, 1], result.Assignment[continuous .== false])
    end

end

@testset verbose=verbose "Test QUMO API" begin
    @testset "Test positive QUMO" begin
        n = 6
        graph = _make_random_quadratic(n)
        field = Float32.((rand(eltype(graph), n) .- 0.5) * 2)
        seed = 13

        continuous = zeros(Bool, n)

        continuous[collect(filter(isodd, 1:n))] .= true
        result = api.compute_qumo_positive(aoc.MAXIMIZATION, graph, field, continuous, seed, 10)
        @test length(result.Assignment) == n
        @test all(x -> 0 <= x <= 1, result.Assignment[continuous])
        @test all(x -> x in [0, 1], result.Assignment[continuous .== false])
    end

    @testset "Test QUMO" begin
        n = 6
        graph = _make_random_quadratic(n)
        field = Float32.((rand(eltype(graph), n) .- 0.5) * 2)
        seed = 13

        continuous = zeros(Bool, n)

        continuous[collect(filter(isodd, 1:n))] .= true
        result = api.compute_qumo(aoc.MAXIMIZATION, graph, field, continuous, seed, 10)
        @test length(result.Assignment) == n
        @test all(x -> -1 <= x <= 1, result.Assignment[continuous])
        @test all(x -> x in [0, 1], result.Assignment[continuous .== false])
    end
end

end
