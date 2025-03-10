# see documentation at https://juliadocs.github.io/Documenter.jl/stable/

using Documenter, AOCoptimizer

makedocs(
    modules = [AOCoptimizer],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Kirill Kalinin (kkalinin@microsoft.com), Christos Gkantsidis (chrisgk@microsoft.com)",
    sitename = "AOCoptimizer.jl",
    pages = Any["index.md"],
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
