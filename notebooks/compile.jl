using Literate
Literate.markdown("benchmark-clamping.jl", "."; flavor = Literate.QuartoFlavor())
Literate.markdown("benchmark-nonlinearity.jl", "."; flavor = Literate.QuartoFlavor())
