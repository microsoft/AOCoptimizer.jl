#=
walls.jl

Implements functionality related to enforcing that spins
do not exceed upper and lower bounds.

The methods defined below are assumed to be used internally,
hence, there are limited checks on the inputs, i.e., they
are assumed to be called with already validated inputs.

The main method implemented is `enforce_inelastic_wall!`,
which enforces the spins to be within specified
`lower` and `upper` bounds.

See notes in [generated code for clamping](../../notebooks/clamping_generated_code.jl)
for more detailed notes on how to optimize the code here.

=#
