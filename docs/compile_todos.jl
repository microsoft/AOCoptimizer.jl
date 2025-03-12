#=
compile_todos.jl

Collect all the TODOs from the code base and add them
to a markdown document in the developer folder.
=#


function _source_code_root()
    """
    Get all files in the given path.
    """
    path = nothing
    if isdefined(Base, :AOCoptimizer)
        path = dirname(Base.AOCoptimizer.__path__)
    else
        current = dirname(@__FILE__)
        previous = nothing
        while current != "" && !endswith(current, "AOCoptimizer.jl") && current != previous
            previous = current
            current = dirname(current)
        end

        path = current
    end

    return path
end

# DOES NOT WORK:
function _find_all_files(path::String = _source_code_root())
    files = []
    for (root, _, files) in walkdir(path)
        if contains(root, ".git") || contains(root, "build")
            continue
        end

        for file in files
            if endswith(file, ".jl") || endswith(file, ".md") || endswith(file, ".ps1")
                if file == "Get-TodoItems.ps1"
                    continue
                end
                push!(files, joinpath(root, file))
            end
        end
    end
    return files
end

_find_all_files()

function compile_todos(source::String, destination_folder::String, destination_file::String = "todos.md")
    """
    Compile all TODOs from the source code into a markdown document.
    """
    re = r"TODO:\s*(?<header>[^\r\n]+)(?:\r?\n(?<body>(?:(?!\s*\r?\n).*\r?\n?)*)?)"
    # Read the source code
    lines = readlines(source)

    # Find all TODOs
    todos = []
    for (i, line) in enumerate(lines)
        if occursin(r"#\s*TODO", line)
            push!(todos, (i, line))
        end
    end

    # Create a markdown document
    md = "# TODOs\n\n"
    for (i, line) in todos
        md *= "## Line $i\n$line\n\n"
    end

    return md
end