#=
test_reader_qio.jl

Unit tests for the QIO format.

! It is not possible to run this file in isolation
  This file requires the CodecBzip2 package which is a dependency in the test environment,
  but not of the main package. Therefore, invocation of this file outside of the test
  environment will fail, unless the CodecBzip2 package is installed in the global environment.

=#

module TestReaderQIO

using Test
using CodecBzip2
using LinearAlgebra
using AOCoptimizer: MINIMIZATION
using AOCoptimizer.FileFormats: FileNotFoundException
using AOCoptimizer.FileFormats.QIO: read_qio

include("utils.jl")

_qio_directory = joinpath(@__DIR__, "..", "data", "QIO")

function _read_rcdp_qubo(filename::AbstractString)
    _process_input_file(_qio_directory, filename) do stream
        return read_qio(stream)
    end
end

function _read_rcdp_qubo(::Type{T}, filename::AbstractString) where {T<:Real}
    _process_input_file(_qio_directory, filename) do stream
        return read_qio(T, stream)
    end
end

@testset verbose=verbose "QIO reader tests" begin

    @testset "Reading dense qubo in FP64" begin
        qubo = _read_rcdp_qubo("RCDP_N10_K36_tau5_5.json.bz2")

        nodes, nodes_b = size(qubo.Terms)
        @test qubo.Info.NumberOfTerms == 360
        @test qubo.Info.NumberOfInteractions == (360 * 359) / 2 + 360
        @test nodes == nodes_b
        @test issymmetric(qubo.Terms)
        @test nodes == 360
        @test qubo.Info.Sense == MINIMIZATION
        @test eltype(qubo.Terms) == Float64
        @test qubo.Info.Objective == -5000.0

        @test qubo.Terms[1, 1] ≈ -471.05806006422929
        @test qubo.Terms[1, 3] ≈ 1049.5924410753319
        @test qubo.Terms[3, 227] ≈ -17.065227121876405
    end

    @testset "Reading dense qubo in FP32" begin
        qubo = _read_rcdp_qubo(Float32, "RCDP_N10_K36_tau5_5.json.bz2")
        @test eltype(qubo.Terms) == Float32
        @test qubo.Info.Objective ≈ Float32(-5000.0)
        @test qubo.Terms[1, 1] ≈ Float32(-471.05806006422929)
        @test qubo.Terms[1, 3] ≈ Float32(1049.5924410753319)
        @test qubo.Terms[3, 227] ≈ Float32(-17.065227121876405)
    end

    @testset "Reading sparse qubo in FP64" begin
        qubo = _read_rcdp_qubo("tile_planting_3D_L_8_p2FP_0.2_p4FP_0.0_inst_1.json.bz2")
        nodes, nodes_b = size(qubo.Terms)
        @test qubo.Info.NumberOfTerms == 512
        @test nodes == nodes_b
        @test nodes == 512
        @test issymmetric(qubo.Terms)
        @test eltype(qubo.Terms) == Float64
        @test qubo.Info.Objective == -808
        @test qubo.Info.Sense == MINIMIZATION

        @test qubo.Terms[1, 8] == -4
        @test qubo.Terms[156, 164] == -4
        @test qubo.Terms[155, 156] == 4
        @test qubo.Terms[446, 446] == 8
    end

end # testset

end # module TestReaderQIO
