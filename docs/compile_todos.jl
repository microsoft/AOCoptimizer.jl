#=
compile_todos.jl

Collect all the TODOs from the code base and add them
to a markdown document in the developer folder.
=#

module TodoHelper

using Compat

@compat public create_todo_markdown

function _source_code_root()
    """
    Get all files in the given path.
    """
    canonical_package_name = uppercase("AOCoptimizer.jl")
    path = nothing
    if isdefined(Base, :AOCoptimizer)
        path = dirname(Base.AOCoptimizer.__path__)
    else
        current = dirname(@__FILE__)
        previous = nothing
        while current != "" && !endswith(uppercase(current), canonical_package_name) && current != previous
            previous = current
            current = dirname(current)
        end

        path = current
    end

    return path
end

const _excluded_files = map(lowercase, [
    "compile_todos.jl",
    "Get-TodoItems.ps1",
]) |> Set

function _find_all_files(path::String = _source_code_root())
    to_examine = Vector{String}()
    for (root, _, files) in walkdir(path)
        root_canonical = lowercase(root)
        if contains(root_canonical, ".git") || contains(root_canonical, "build")
            continue
        end

        files_to_add = filter(
            x -> begin
            x = lowercase(x)

            (endswith(x, ".jl") || endswith(x, ".md") || endswith(x, ".ps1")) &&
                x ∉ _excluded_files
        end, files)

        append!(to_examine, map(x -> joinpath(root, x), files_to_add))
    end
    return to_examine
end

const _todos_re = r"TODO:\s*(?<header>[^\r\n]+)(?:\r?\n(?<body>(?:(?!\s*\r?\n).*\r?\n?)*)?)"

struct _TodoItems
    filename::AbstractString
    line::Int
    offset::Int
    header::AbstractString
    body::AbstractString
end

function _find_todos(filename::AbstractString; canonical_file_name::Union{Nothing,AbstractString}=nothing)::Vector{_TodoItems}
    if !isfile(filename)
        @warn "File $filename does not exist; skipping."
        return Vector{_TodoItems}()
    end

    todos = Vector{_TodoItems}()
    lines = readlines(filename)
    text = join(lines, "\n")

    line_offsets = cumsum(length.(lines) .+ 1) # get the line number of each line

    filename = canonical_file_name === nothing ? filename : canonical_file_name

    for m in eachmatch(_todos_re, text)
        header = m[:header]
        body = haskey(m, :body) ? m[:body] : ""
        line_number = findfirst(x -> x >= m.match.offset, line_offsets) + 1

        push!(todos, _TodoItems(
            filename, line_number, m.match.offset,
            strip(header), strip(body),
        ))
    end

    return todos
end

function _append_to_markdown(todos::Vector{_TodoItems}, io::IO=stdout)
    """
    Create a markdown file with all the TODOs in the code base.
    """

    for todo in todos
        write(io, "- Title: **", todo.header, "**\n\n")
        println(io, "  *Line ", todo.line, " of " , todo.filename, " [offset: ", todo.offset, "]*\n")
        if todo.body != ""
            write(io, "  Notes: ", todo.body, "\n")
        end
        write(io, "\n\n\n\n")
    end
end

function _create_todo_markdown(path::String = _source_code_root(), io::IO=stdout)
    """
    Create a markdown file with all the TODOs in the code base.
    """

    write(io, "# TODOs\n\n")
    inputs = _find_all_files(path)

    common_path_chars = length(path)
    for filename in inputs
        todos = _find_todos(filename)
        if isempty(todos)
            continue
        end

        write(io, "## Filename: ", filename[common_path_chars+2:end], "\n\n")
        _append_to_markdown(todos, io)
    end
end

function create_todo_markdown(path::AbstractString = joinpath(_source_code_root(), "docs", "src", "developer", "TODOs.md"))
    """
    Create a markdown file with all the TODOs in the code base.
    """

    open(path, "w") do io
        _create_todo_markdown(_source_code_root(), io)
    end
end

create_todo_markdown()

end # module