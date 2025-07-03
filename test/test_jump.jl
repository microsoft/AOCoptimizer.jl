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
const MOI = MathOptInterface

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

#=
=#

const OPTIMIZER = MOI.instantiate(
    MOI.OptimizerWithAttributes(
        aoc_moi.Optimizer[],
        MOI.Silent()       => true,
        MOI.TimeLimitSec() => 1.0,
    ),
)

const BRIDGED = MOI.instantiate(
    MOI.OptimizerWithAttributes(
        aoc_moi.Optimizer[],
        MOI.Silent()       => true,
        MOI.TimeLimitSec() => 1.0,
    ),
    with_bridge_type = Float64,
)

const CONFIG = MOI.Test.Config(
    # Modify tolerances as necessary.
    atol = 1e-6,
    rtol = 1e-6,
    # Use MOI.LOCALLY_SOLVED for local solvers.
    optimal_status = MOI.LOCALLY_SOLVED,
    # Pass attributes or MOI functions to `exclude` to skip tests that
    # rely on this functionality.
    exclude = Any[MOI.VariableName, MOI.delete],
)

function run_moi_tests()
    MOI.Test.runtests(
        BRIDGED,
        CONFIG,
        exclude = [
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",

            "test_HermitianPSDCone_",
            "test_NormNuclearCone_",
            "test_NormSpectralCone_",
            "test_basic_ScalarAffineFunction_",
            "test_basic_ScalarQuadraticFunction_",
            "test_basic_ScalarNonlinearFunction_",
            "test_basic_Vector",

            "test_linear_",
            "test_nonlinear_",
            "test_conic_",
            "test_quadratic_",
            "test_constraint_",
            "test_objective_",
            "test_multiobjective_",
            "test_cpsat_",
            "test_infeasible_",
            "test_modification_",
            "test_solve_",

            r"test_variable_solve.*bound",
        ],
        # This argument is useful to prevent tests from failing on future
        # releases of MOI that add new tests. Don't let this number get too far
        # behind the current MOI release though. You should periodically check
        # for new tests to fix bugs and implement new features.
        exclude_tests_after = v"1.28.1",
    )

    return nothing
end

@testset "MathOptInterface Test Suite" begin
    run_moi_tests()
end

end # module