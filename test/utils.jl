#=
utils.jl

Utility functions for simplifying common runtime tasks.
Observe that this file will be included multiple times,
so it should not contain any definitions.

=#

#=
If user passes the "--verbose" flag or sets the
"JULIA_TESTING_VERBOSE" environment variable,
then we set the verbose flag to true, and print
more detailed information related to unit tests.
=#

if (@isdefined verbose) == false
    verbose = false

    if "--verbose" in ARGS
        verbose = true
        deleteat!(ARGS, findall(x -> x == "--verbose", ARGS))
    end
    if "JULIA_TESTING_VERBOSE" in keys(ENV)
        verbose = true
    end
end
