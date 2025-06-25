#=
FileFormats.jl


=#

module FileFormats

using Compat
using SparseArrays

@compat public FileNotFoundException
@compat public GraphIOException, read_graph_matrix, read_directed_graph_matrix

"""
    FileNotFoundException(filename::AbstractString, message::AbstractString)

Exception thrown when a file does not exist.
"""
struct FileNotFoundException <: Exception
    filename::String
    message::String

    FileNotFoundException(filename::AbstractString, message::AbstractString) =
        new(filename, message)
    FileNotFoundException(filename::AbstractString) =
        new(filename, "File `$filename` not found")
end

include("simple-graph.jl")
include("qio.jl")

end # module FileFormats