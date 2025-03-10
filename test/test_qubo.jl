#=
test_qubo.jl

Unit tests for QUBO related methods

=#

module TestQUBO

using Test
using Random
using AOCoptimizer.QUBO: evaluate, qubo, _random, increase!, decrease!

include("utils.jl")

@testset verbose=verbose "QUBO tests" begin

    @testset "Objective function for 2x2" begin
        m = [
            2 -1
            -1 3
        ]

        @test evaluate(m, vec([1 1])) == 4
        @test evaluate(m, vec([1 0])) == 2
        @test evaluate(m, vec([0 1])) == 3
        @test evaluate(m, vec([0 0])) == 0
    end

    @testset "Objective function for 3x3" begin
        m = [
            2 -1 -2
            -1 1 -4
            -2 -4 3
        ]

        @test evaluate(m, vec([1 1 1])) == -1
        @test evaluate(m, vec([1 1 0])) == 2
        @test evaluate(m, vec([1 0 1])) == 3
        @test evaluate(m, vec([1 0 0])) == 2
        @test evaluate(m, vec([1 0 0])) == 2
        @test evaluate(m, vec([0 1 1])) == 0
        @test evaluate(m, vec([0 1 0])) == 1
        @test evaluate(m, vec([0 0 1])) == 3
        @test evaluate(m, vec([0 0 0])) == 0
    end

    @testset "Increasing QUBO objective" begin
        rng = Xoshiro(12)
        n = 10
        terms = randn(n, n)
        terms = terms + terms'

        q = qubo(terms)
        x = _random(rng, terms)

        best = evaluate(q, x)
        order = vec([4 3 1 5 9 8 6 7 2])

        while increase!(x, terms, order)
            current = evaluate(q, x)
            @test current > best
            best = current
        end
    end

    @testset "Decreasing QUBO objective" begin
        rng = Xoshiro(12)
        n = 10
        terms = randn(n, n)
        terms = terms + terms'

        q = qubo(terms)
        x = _random(rng, terms)

        best = evaluate(q, x)
        order = vec([4 3 1 5 9 8 6 7 2])

        while decrease!(x, terms, order)
            current = evaluate(q, x)
            @test current < best
            best = current
        end
    end

end # testset

end # module
