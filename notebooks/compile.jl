using Literate

notebooks = [
    "benchmark-clamping.jl",
    "benchmark-nonlinearity.jl",
    "benchmark-sampler.jl",
    "benchmark-exploration.jl",
    "benchmark-solver.jl",
    "evaluate-max_cut.jl"
]

for notebook in notebooks
    Literate.markdown(notebook, "."; flavor = Literate.QuartoFlavor())
end
