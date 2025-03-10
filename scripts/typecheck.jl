#=
typecheck.jl

This is a script that uses the JET package to check the type stability of the code.

Call it through the `typecheck.ps1` script.

=#

# using Revise
using ArgParse
using FileWatching: watch_folder
using JET
using Logging
using NPZ
using SnoopCompile

const input_folder = joinpath(@__DIR__, "..", "src")
const input_file = joinpath(input_folder, "AOCoptimizer.jl")

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "-d", "--debug"
        help = "Enable debug logging"
        action = "store_true"

        "--annotate-types"
        help = "Annotate types in the output"
        action = "store_true"

        "--once"
        help = "Run only once"
        action = "store_true"

    end

    return parse_args(s)
end

#= Fixes for the JET package

The following are definitions that are used to fix problems with external packages
that may cause spurious warnings by JET.

There is plenty of type piracy below, but, it is for limited use to make
JET work.

=#

# Fixes for NPZ

Base.iterate(::Nothing) = nothing

NPZ.close(::Nothing) = ()
NPZ.SubString(s::AbstractString, ::Nothing) = s

#=
END OF FIXES
=#

module RunOnce
using JET
using Logging

import JET: match_module

match_module(::Char, ::JET.InferenceErrorReport) = false

function run(arguments)
    @info "Starting analyzer"
    report = report_package("AOCoptimizer"; arguments...)
    display(report)
    @info "Analyzer finished"
end

end # module RunOnce

function main(watch = Ref(true))
    args = parse_commandline()

    debug = get(args, "debug", false)
    once = get(args, "once", false)

    arguments = Dict(
        :analyze_from_definitions => true,
        :concretization_patterns => [],
        :target_modules => "AOCoptimizer",
        :ignored_modules => ["PrecompileTools"],
        # :ignored_modules => ["CUDA", "NPZ"],
    )

    if debug
        arguments[:toplevel_logger] = IOContext(stdout, :JET_LOGGER_LEVEL => 1)
    end

    if once
        RunOnce.run(arguments)
    else
        # watch_file(input_file; arguments...)
        while watch[]
            RunOnce.run(arguments)
            file, event = watch_folder(input_folder)
            @info "Waiting for changes in $input_folder"
            @show file, event
        end
    end
end

main()
