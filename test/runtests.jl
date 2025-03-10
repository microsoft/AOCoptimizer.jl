using AOCoptimizer
using JET
using Test

disable_jet = false
disable_aqua = false

if "--no-jet" in ARGS
    disable_jet = true
    deleteat!(ARGS, findall(x -> x == "--no-jet", ARGS))
end
if "DISABLE_JET" in keys(ENV)
    disable_jet = true
end

if "--no-aqua" in ARGS
    disable_aqua = true
    deleteat!(ARGS, findall(x -> x == "--no-aqua", ARGS))
end
if "DISABLE_AQUA" in keys(ENV)
    disable_aqua = true
end

include("utils.jl")

@testset verbose=true "AOCoptimizer tests" begin

    include("test_qubo.jl")
    include("test_qumo_mixed_ising.jl")

end

if !disable_jet
    @testset "static analysis with JET.jl" begin
        @test isempty(
            JET.get_reports(report_package(AOCoptimizer, target_modules = (AOCoptimizer,))),
        )
    end
end

if !disable_aqua
    @testset "QA with Aqua" begin
        import Aqua
        Aqua.test_all(AOCoptimizer; ambiguities = false)
        # testing separately, cf https://github.com/JuliaTesting/Aqua.jl/issues/77
        Aqua.test_ambiguities(AOCoptimizer)
    end
end
