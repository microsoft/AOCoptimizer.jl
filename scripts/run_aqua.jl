#=
run_aqua.jl

Run only the Aqua tests.

=#

using AOCoptimizer
import Aqua

AOCoptimizer.init()

Aqua.test_all(AOCoptimizer; ambiguities = false)
Aqua.test_ambiguities(AOCoptimizer)
