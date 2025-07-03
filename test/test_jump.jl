#=
test_jump.jl

Unit tests for the JuMP extension of AOCoptimizer.
=#

module TestJump

using Test
using JuMP
using MathOptInterface
using AOCoptimizer

include("utils.jl")

# AOCoptimizer.init()
AOCoptimizer.MOI.init()

const aoc_moi = AOCoptimizer.MOI

@testset verbose=verbose "Test simple JuMP problems" begin
    @testset "Test simple QUMO" begin
        model = Model(aoc_moi.Optimizer[])

        @variable(model, x, Bin)
        @variable(model, y, Bin)
        @variable(model, -1 <= z <= 1)
        @objective(model, Min, x + y * z)

        optimize!(model)

        @test value(x) == 0
        @test value(y) == 1
        @test value(z) ≈ -1
        @test objective_value(model) ≈ -1
    end

    @testset "Test continuous only" begin
        model = Model(aoc_moi.Optimizer[])
        @variable(model, -1 <= z <= 1)
        @objective(model, Min, (z - 0.25)^2)

        optimize!(model)

        @test isapprox(objective_value(model), 0, atol=1e-6)
        @test isapprox(value(z), 0.25, atol=1e-6)
    end

    @testset "Test two continuous" begin
        model = Model(AOCoptimizer.MOI.Optimizer[])
        @variable(model, -1 <= x <= 1)
        @variable(model, -1 <= y <= 1)
        @objective(model, Min, (x - 0.2) * (y - 0.2))

        optimize!(model)

        @test objective_value(model) ≈ -0.96
        @test value(x) * value(y) ≈ -1
    end
end

@testset verbose=verbose "Test JuMP conversions" begin
    @testset "Compute objective function correctly" begin
        model = Model(aoc_moi.Optimizer[])
        @variable(model, x, Bin)
        @variable(model, y, Bin)
        @variable(model, -1 <= z <= 5)
        @objective(model, Min, x - y * z)

        optimize!(model)

        @test value(x) ∈ [0, 1]
        @test value(y) ∈ [0, 1]
        @test -1 ≤ value(z) ≤ 5
        @test objective_value(model) ≈ value(x) - value(y) * value(z)
    end
end

end # module