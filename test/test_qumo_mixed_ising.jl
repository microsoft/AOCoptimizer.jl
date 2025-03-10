#= test_qumo_mixed_ising.jl

Tests transformations between QUMO and Mixed Ising representations.

=#

module TestQUMOConversion

using Test
using AOCoptimizer.QUMO: qumo, mixed_ising, convert_to_mixed_ising, convert_to_qumo
using AOCoptimizer.QUMO: convert_positive_qumo_to_mixed_ising, convert_mixed_ising_to_positive_qumo

include("utils.jl")

@testset verbose=verbose "QUMO and Mixed Ising conversions" begin

@testset "Small convert QUMO to Mixed Ising and back" begin
    w = 4.0
    v = 5.0
    simple = [0.0 w; w v]
    q = qumo([true, false], simple)
    i = convert_to_mixed_ising(q)

    @test i.Quadratic == [0 w/2; w/2 v]
    @test i.Field == [0; w]
    @test i.Binary == [true, false]
    @test i.Offset == 0.0

    rq = convert_to_qumo(i)
    rq.Quadratic == q.Quadratic

    @test rq.Field == q.Field
    @test rq.Offset == q.Offset
    @test rq.Binary == q.Binary
end

@testset "Bigger conversion from QUMO to Mixed Ising and back" begin
    T = Float32

    quadratic =
        T.(
            [
                0.0 -11.0/18.0 -1.0/9.0 0.0 0.0 -15.0/9.0
                -11.0/18.0 0.0 -85.0/18.0 -5.0/2.0 -5.0/2.0 -10.0/3.0
                -1.0/9.0 -85.0/18.0 0.0 -5.0/2.0 -5.0/2.0 -10.0/3.0
                0.0 -5.0/2.0 -5.0/2.0 -5.0 0.0 0.0
                0.0 -5.0/2.0 -5.0/2.0 0.0 -5.0 0.0
                -15.0/9.0 -10.0/3.0 -10.0/3.0 0.0 0.0 -5.0
            ]
        )
    continuous = vec([false false false true true true])
    binary = continuous .== false

    mising = mixed_ising(quadratic, nothing, binary)
    mqubo = convert_to_qumo(mising)
    rising = convert_to_mixed_ising(mqubo)

    @test rising.Quadratic == mising.Quadratic
    @test rising.Field == mising.Field
    @test rising.Offset == mising.Offset
end

@testset "Conversion from positive qumo to mixed ising" begin
    T = Float32

    quadratic =
        T.(
            [
                0.0 -11.0/18.0 -1.0/9.0 0.0 0.0 -15.0/9.0
                -11.0/18.0 0.0 -85.0/18.0 -5.0/2.0 -5.0/2.0 -10.0/3.0
                -1.0/9.0 -85.0/18.0 0.0 -5.0/2.0 -5.0/2.0 -10.0/3.0
                0.0 -5.0/2.0 -5.0/2.0 -5.0 0.0 0.0
                0.0 -5.0/2.0 -5.0/2.0 0.0 -5.0 0.0
                -15.0/9.0 -10.0/3.0 -10.0/3.0 0.0 0.0 -5.0
            ]
        )
    continuous = vec([false false false true true true])
    binary = continuous .== false

    q = qumo(binary, quadratic)
    m = convert_positive_qumo_to_mixed_ising(q)
    qr = convert_mixed_ising_to_positive_qumo(m)

    @test q.Sense == qr.Sense
    @test isapprox(q.Quadratic, qr.Quadratic; atol=T(10) * eps(T))
    @test qr.Field === nothing
    @test q.Binary == qr.Binary
    @test isapprox(qr.Offset, 0.0; atol=T(10) * eps(T))

    @test isapprox(q, qr; atol=T(10) * eps(T))
end

end # testset

end # module TestQUMOConversion
