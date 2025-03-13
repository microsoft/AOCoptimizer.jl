#=
simple-graph.jl

Read simple text file that contain undirected graphs.
The files have the following format:

-----------------------------------
<#nodes> <#edges>
<node A> <node B> <edge weight>
........ ........ .............
-----------------------------------

There are no comments or other complications in those files.
The G-Set dataset use this format.
=#

"""
Exception thrown when encountering errors in parsing files
"""
struct GraphIOException <: Exception
    msg::AbstractString
end

"""
    read_graph_matrix(io)

Read an undirected graph from an I/O stream.

The format of the file should be:

```
number_of_vertices number_of_edges
endpoint_A_of_edge_1 endpoint_B_of_edge_1 weight_of_edge_1
endpoint_A_of_edge_2 endpoint_B_of_edge_2 weight_of_edge_2
....
```
"""
function read_graph_matrix(io::IO)::AbstractMatrix{Float64}

    if eof(io)
        @error "Reached end of stream before reading matrix; aborting operation"
        throw(EOFError())
    end

    # header_re = r"(\d+)\s+(\d+)"

    header = strip(chomp(readline(io)))
    fields = split(header)
    if length(fields) != 2
        @error "Expected two fields in the header; aborting" number_of_fields = length(fields)
        throw(GraphIOException("Expected two fields in the header"))
    end

    dimensions = map(x -> parse(Int, x), fields)
    vertices = dimensions[1]
    edges = dimensions[2]
    if vertices <= 0
        @error "Number of vertices must be positive; aborting" vertices
        throw(GraphIOException("Number of vertices must be positive"))
    end
    if edges < 0
        @error "Number of edges cannot be negative; aborting" edges
        throw(GraphIOException("Number of edges cannot be negative"))
    end

    i = zeros(Int, edges)
    j = zeros(Int, edges)
    v = zeros(Float64, edges)

    for position in range(1, stop = edges)
        if eof(io)
            @error "Premature end of file; aborting" position
            throw(GraphIOException("Premature end of file before reading all edges"))
        end

        entries = split(readline(io))
        i[position] = parse(Int, entries[1])
        j[position] = parse(Int, entries[2])
        v[position] = parse(Float64, entries[3])
    end

    matrix = sparse([i; j], [j; i], [v; v])
    return matrix
end

"""
    read_graph_matrix(filename)

Read an undirected graph from a file with name `filename`.
"""
function read_graph_matrix(filename::String)::AbstractMatrix{Float64}
    open(filename) do f
        @debug "Reading graph from file" filename
        return read_graph_matrix(f)
    end
end

function read_fields_vector(io::IO)::AbstractVector{Float64}

    if eof(io)
        @error "Reached end of stream before reading fields; aborting operation"
        throw(EOFError())
    end

    header_re = r"(\d+)\s+(\d+)"

    header = strip(chomp(readline(io)))
    fields = split(header)
    if length(fields) != 2
        @error "Expected two fields in the header; aborting" number_of_fields = length(fields)
        throw(GraphIOException("Expected two fields in the header"))
    end

    vertices = parse(Int, fields[1])
    edges = parse(Int, fields[2])
    if vertices <= 0
        @error "Number of vertices must be positive; aborting" vertices
        throw(GraphIOException("Number of vertices must be positive"))
    end
    if edges < 0
        @error "Number of edges cannot be negative; aborting" edges
        throw(GraphIOException("Number of edges cannot be negative"))
    end

    v = zeros(Float64, vertices)

    for position in range(1, stop = edges)
        if eof(io)
            @error "Premature end of file; aborting" position
            throw(GraphIOException("Premature end of file before reading all edges"))
        end

        entries = split(readline(io))
        i = parse(Int, entries[1])
        v[i] = parse(Float64, entries[2])
    end

    return v
end

function read_fields_vector(filename::String)::AbstractVector{Float64}
    open(filename) do f
        @debug "Reading graph from file" filename
        return read_fields_vector(f)
    end
end

"""
    read_directed_graph_matrix(io)

Read a directed graph from an I/O stream.

The format of the file should be:

```
number_of_vertices number_of_edges
endpoint_A_of_edge_1 endpoint_B_of_edge_1 weight_of_edge_1
endpoint_A_of_edge_2 endpoint_B_of_edge_2 weight_of_edge_2
....
```
"""
function read_directed_graph_matrix(io::IO)::AbstractMatrix{Float64}

    if eof(io)
        @error "Opening empty file; aborting operation"
        throw(EOFError())
    end

    header_re = r"(\d+)\s+(\d+)"

    header = strip(chomp(readline(io)))
    fields = split(header)
    if length(fields) != 2
        @error "Expected two fields in the header; aborting" number_of_fields = length(fields)
        throw(GraphIOException("Expected two fields in the header"))
    end

    dimensions = map(x -> parse(Int, x), fields)
    vertices = dimensions[1]
    edges = dimensions[2]
    if vertices <= 0
        @error "Number of vertices must be positive; aborting" vertices
        throw(GraphIOException("Number of vertices must be positive"))
    end
    if edges < 0
        @error "Number of edges cannot be negative; aborting" edges
        throw(GraphIOException("Number of edges cannot be negative"))
    end

    i = zeros(Int, edges)
    j = zeros(Int, edges)
    v = zeros(Float64, edges)

    for position in range(1, stop = edges)
        if eof(io)
            @error "Premature end of file; aborting" position
            throw(GraphIOException("Premature end of file before reading all edges"))
        end

        entries = split(readline(io))
        i[position] = parse(Int, entries[1])
        j[position] = parse(Int, entries[2])
        v[position] = parse(Float64, entries[3])
    end

    matrix = sparse(i, j, v)
    return matrix
end


"""
    read_directed_graph_matrix(filename)

Read an undirected graph from a file with name `filename`.
"""
function read_directed_graph_matrix(filename::String)::AbstractMatrix{Float64}
    open(filename) do f
        @debug "Reading graph from file" filename
        return read_directed_graph_matrix(f)
    end
end
