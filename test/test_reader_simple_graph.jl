#=
test_reader_simple_graph.jl

Unit tests for reading simple graph files.

! It is not possible to run this file in isolation
  This file requires the CodecBzip2 package which is a dependency in the test environment,
  but not of the main package. Therefore, invocation of this file outside of the test
  environment will fail, unless the CodecBzip2 package is installed in the global environment.

=#

module TestReaderSimpleGraph

using Test
using CodecBzip2
using AOCoptimizer.FileFormats: FileNotFoundException, read_graph_matrix

include("utils.jl")

_gset_directory = joinpath(@__DIR__, "..", "data", "GSet")

function _read_gset_graph(filename::AbstractString)
    if !_is_test_file_present(filename)
        return nothing
    end

    _process_input_file(_gset_directory, filename) do stream
        return read_graph_matrix(stream)
    end
end

@testset verbose=verbose "Simple graph reader tests" begin

    @testset "Reading single topology - G1" begin
        graph = _read_gset_graph("G1.bz2")
        if graph === nothing
            return
        end

        nodes, nodes_b = size(graph)
        @test nodes == nodes_b
        @test nodes == 800
        @test sum(sum(graph)) == (2 * 19176)
    end

    @testset "Read all input files" begin
        for filename in readdir(_gset_directory)
            if startswith(filename, "G") == false
                continue
            end

            @debug "Processing " filename
            graph = _read_gset_graph(filename)
            if graph === nothing
                @debug "Skipping file " filename " as it is not present"
                continue
            end

            nodes, nodes_b = size(graph)
            @test nodes > 0
            @test nodes == nodes_b

            _process_input_file(_gset_directory, filename) do f
                header = strip(chomp(readline(f)))
                fields = split(header)

                @test length(fields) == 2
                number_of_nodes = parse(Int, fields[1])
                number_of_edges = parse(Int, fields[2])
                @test number_of_nodes == nodes
                @test number_of_edges > 0
            end
        end
    end

end

end # module TestReaderSimpleGraph
