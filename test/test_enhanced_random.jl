#=
test_enhanced_random.jl

Unit tests for the enhanced random heuristic

=#

module TestEnhancedRandom

using Test
using Dates
using AOCoptimizer: CancellationToken
using AOCoptimizer.RuntimeUtils: run_for
using AOCoptimizer.Algorithms.EnhancedRandom: search

include("utils.jl")

#= Observe the negative sign:
connected nodes i, j repel each other when w_{i,j} > 0
=#
const interactions_01 = Float32.(-[
    0 1 0 0
    1 0 0 0
    0 0 0 1
    0 0 1 0
])

function _mk_solver(interactions::AbstractMatrix, seed::Integer)

    function solve(ctx::CancellationToken)
        # @debug "Starting solver at $(now())"
        # @debug "Graph: $interactions"
        # @debug "Context: $ctx"
        result = search(seed, interactions, ctx)
        # @debug "Solver finished at $(now())"
        return result
    end

    return solve
end

@testset verbose=verbose "Enhanced random tests" begin

    @testset "Test simple Hamiltonian" begin
        seed = 1234

        results = run_for(
            _mk_solver(interactions_01, seed),
            Second(2);
            threads=2,
        )

        @test length(results) == 2
        for i in 1:2
            objective = results[i][1]
            assignment = results[i][2]
            @test objective ≈ -2.0
            @test length(assignment) == 4
            @test assignment[1] * assignment[2] == -1
            @test assignment[3] * assignment[4] == -1
        end
    end

end # testset

end # TestEnhancedRandom