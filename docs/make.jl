# see documentation at https://juliadocs.github.io/Documenter.jl/stable/

using Documenter, AOCoptimizer

const _PAGES = [
    "Introduction" => [
        "index.md"
    ],
    "Tutorials" => [
        "tutorials/example.md",
    ],
    "Manual" => [
        "manual/manual.md",
        "manual/installation.md",
    ],
    "Background" => [
        "background/abstractions.md",
    ],
    "API Reference" => [
        "reference/reference.md",
    ],
    #=
    "Submodules" => [
        "Utilities" => [
            "Overview" => "submodules/Utilities/overview.md",
            "API Reference" => "submodules/Utilities/reference.md",
        ],
        "Test" => [
            "Overview" => "submodules/Test/overview.md",
            "API Reference" => "submodules/Test/reference.md",
        ],
    ],
    =#
    "Developer Docs" => ["developer/developer.md"],
    "Release notes" => "release_notes.md",
]

# ==============================================================================
#  Modify the release notes
# ==============================================================================

function fix_release_line(
    line::String,
    url::String = " https://github.com/microsoft/AOCoptimizer.jl",
)
    # (#XXXX) -> ([#XXXX](url/issue/XXXX))
    while (m = match(r"\(\#([0-9]+)\)", line)) !== nothing
        id = m.captures[1]
        line = replace(line, m.match => "([#$id]($url/issues/$id))")
    end
    # ## vX.Y.Z -> [vX.Y.Z](url/releases/tag/vX.Y.Z)
    while (m = match(r"\#\# (v[0-9]+.[0-9]+.[0-9]+)", line)) !== nothing
        tag = m.captures[1]
        line = replace(line, m.match => "## [$tag]($url/releases/tag/$tag)")
    end
    return line
end

open(joinpath(@__DIR__, "src", "changelog.md"), "r") do in_io
    open(joinpath(@__DIR__, "src", "release_notes.md"), "w") do out_io
        for line in readlines(in_io; keep = true)
            write(out_io, fix_release_line(line))
        end
    end
end

# ==============================================================================
#  Build the HTML docs
# ==============================================================================

mathengine = MathJax3(Dict(
    :loader => Dict("load" => ["[tex]/physics"]),
    :tex => Dict(
        "inlineMath" => [["\$","\$"], ["\\(","\\)"]],
        "tags" => "ams",
        "packages" => ["base", "ams", "autoload", "physics"],
    ),
))

makedocs(
    modules = [AOCoptimizer],
    format = Documenter.HTML(;
                prettyurls = get(ENV, "CI", nothing) == "true",
                mathengine = mathengine,
    ),
    authors = "Kirill Kalinin (kkalinin@microsoft.com), Christos Gkantsidis (chrisgk@microsoft.com)",
    sitename = "AOCoptimizer.jl",
    pages = _PAGES,
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

# Some setup is needed for documentation deployment, see “Hosting Documentation” and
# deploydocs() in the Documenter manual for more information.
deploydocs(
    repo = "github.com/microsoft/AOCoptimizer.jl.git",
    branch = "gh-pages",
    push_preview = true,
)
