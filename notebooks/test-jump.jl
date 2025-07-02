#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # Using AOCoptimizer from JuMP

using Revise
using MathOptInterface
using JuMP
using AOCoptimizer

AOCoptimizer.init()

model = Model(AOCoptimizer.MOI.Optimizer[])
@variable(model, x, Bin)
@variable(model, y, Bin)
@variable(model, -1 <= z <= 1)
@objective(model, Min, x + y * z)

# The following will solve with default settings,
# using 60sec as timeout value.
optimize!(model)

@show termination_status(model)
@show objective_value(model)
@show value(x)
@show value(y)
@show value(z)
