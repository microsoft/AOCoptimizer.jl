#=
optimize.jl

Run an optimization algorithm (AOC, greedy)
on QUBO, QUMO and Ising problems.

=#

using ArgParse
using Dates
using Logging
using ProgressLogging
using Random
using TerminalLoggers
using YAML

using AOCoptimizer.Environment: local_system_info

const _experiment_id = "f5c296b3-8d48-4865-8ea2-09d4eeebb674"

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--config", "-c"
        help = "Path to the configuration file"
        arg_type = String
        default => "config.yaml"

        "--set", "-s"
        help = "Override settings from config file; each entry should be 'key=value', where key can have multiple layers, e.g. k1.k2"
        arg_type = String
        action => :append_arg
        nargs => '*'

        "--seed"
        help = "Seed to initialize random number generation"
        arg_type = Int

        "--progress"
        help = "Enable progress reporting"
        action = :store_true

        "--input-format"
        help = "Format of input files; typically SimpleGraph (default), QIOInput"
        arg_type = String

        "--invert-weights"
        help = "Interpret weights as having the opposite sign"
        action = :store_true

        "--output", "-o"
        help = "Name of output file; if not given, output will be in standard output"
        arg_type = String

        "--numeric-type"
        help = "Type to use for numeric values; default is Float64"
        arg_type = String
        default => "Float64"

        "--timeout", "-t"
        help = "Timeout for running experiment, in seconds; this overrides the timeout in the configuration file, if present"
        arg_type = Int
        default => 100

        "--id"
        help = "Identifier to use for experiment"
        arg_type = String
        default => _experiment_id

        "--path"
        help = "Common path in filesystem to prepend to input files"
        arg_type = String
        default => ""

        "--debug", "-d"
        help = "Enable debug output"
        action = :store_true

        "inputs"
        help = "filenames to process"
        action = :store_arg
        nargs => '+'
        required = true
    end

    return parse_args(s)
end

@enum InputFormat SimpleGraphFormat QIOInputFormat
@enum NumericType Float64Type Float32Type Float16Type BFloat16Type

struct Configuration
    seed::Int
    timeout::Dates.Period

    invert_weights::Bool
    numeric_type::NumericType
    input_format::InputFormat

    common_path::AbstractString
    inputs::Vector{AbstractString}

    additional::Dict{String, Any}
end

function Base.show(io::IO, c::Configuration)
    print(io, "Configuration:\n")
    print(io, "\tseed: ", c.seed, "\n")
    print(io, "\ttimeout: ", c.timeout, "\n")
    print(io, "\tinvert_weights: ", c.invert_weights, "\n")
    print(io, "\tnumeric_type: ", c.numeric_type, "\n")
    print(io, "\tinput_format: ", c.input_format, "\n")
    print(io, "\tcommon_path: ", c.common_path, "\n")

    if length(c.inputs) == 0
        print(io, "\tinputs: <empty>\n")
        return
    else
        print(io, "\tinputs:\n")

        for input in c.inputs
            print(io, "\t- ", input, "\n")
        end
    end

    if length(c.additional) > 0
        print(io, "\tadditional:\n")

        for (key, value) in c.additional
            print(io, "\t- ", key, ": ", value, "\n")
        end
    end
end

function _empty_configuration()
    return Dict(
        "seed" => Int(rand(UInt16)),
        "timeout" => 100,
        "invert_weights" => false,
        "numeric_type" => Float32Type,
        "input_format" => SimpleGraphFormat,
        "common_path" => "",
        "inputs" => [],
        "additional" => Dict()
    )
end

function _mk_configuration(config::Dict)
    conf = deepcopy(config)
    delete!(conf, "seed")
    delete!(conf, "timeout")
    delete!(conf, "invert_weights")
    delete!(conf, "numeric_type")
    delete!(conf, "input_format")
    delete!(conf, "common_path")
    delete!(conf, "inputs")

    return Configuration(
        config["seed"],
        Dates.Second(config["timeout"]),
        config["invert_weights"],
        config["numeric_type"],
        config["input_format"],
        config["common_path"],
        config["inputs"],
        conf
    )
end

function _process(configuration::Configuration, seed::UInt32, filename::AbstractString)
    @assert isfile(filename) "File $filename does not exist"
    @debug "Processing $filename with seed $seed"

    stats = Dict(
        "seed" => seed,
        "filename" => filename,
    )
    started = now()

    # TODO: Read input file and process; log result
    error("Processing of input files is not implemented yet")

    ended = now()
    elapsed = ended - started

    stats["started"] = started
    stats["ended"] = ended
    stats["elapsed"] = elapsed

    @debug "Processing $filename took $(Dates.seconds(elapsed)) seconds"
end

function main()
    args = parse_commandline()

    verbosity = Logging.Info
    if args["debug"]
        verbosity = Logging.Debug
    end

    if args["progress"]
        global_logger(TerminalLogger(stderr, verbosity; right_justify = 120))
    else
        global_logger(TerminalLogger(stderr, verbosity))
    end

    if isfile(args["config"])
        configuration_file = args["config"]
        @info "Using configuration file: $configuration_file"
        config = YAML.load_file(configuration_file)
    else
        config = _empty_configuration()
    end

    if haskey(args, "set")
        for entry in args["set"]
            key, value = split(entry, "=")
            keys = split(key, ".")
            current = config
            for k in keys[1:end-1]
                if !haskey(current, k)
                    current[k] = Dict()
                end
                current = current[k]
            end
            current[keys[end]] = value
        end
    end

    if haskey(args, "seed") && args["seed"] !== nothing
        config["seed"] = args["seed"]
    end

    if haskey(args, "timeout")
        config["timeout"] = args["timeout"]
    end

    if haskey(args, "invert_weights")
        config["invert_weights"] = args["invert_weights"]
    end

    if haskey(args, "input_format")
        f = uppercase(args["input_format"])
        if f == uppercase("simple")
            config["input_format"] = SimpleGraphFormat
        elseif f == uppercase("qio")
            config["input_format"] = QIOInputFormat
        else
            error("Unknown input format: $args['input_format']")
        end
    end

    if haskey(args, "numeric_type")
        t = uppercase(args["numeric_type"])
        if t == uppercase("Float64")
            config["numeric_type"] = Float64Type
        elseif t == uppercase("Float32")
            config["numeric_type"] = Float32Type
        elseif t == uppercase("Float16")
            config["numeric_type"] = Float16Type
        elseif t == uppercase("BFloat16")
            config["numeric_type"] = BFloat16Type
        else
            error("Unknown numeric type: $args['numeric_type']")
        end
    end

    if haskey(args, "inputs")
        config["inputs"] = args["inputs"]
    end

    configuration = _mk_configuration(config)

    @debug configuration

    environment = local_system_info()
    inputs = configuration.inputs

    rng = Random.MersenneTwister(configuration.seed)

    while !isempty(inputs)
        input = inputs[1]
        inputs = inputs[2:end]

        input = joinpath(configuration.common_path, input)

        if isdir(input)
            files = readdir(input)
            for file in files
                push!(inputs, joinpath(input, file))
            end
            continue
        end

        if !isfile(input)
            @error "Input file not found: $input; skipping"
            continue
        end

        @info "Processing input file: $input"
        seed = rand(rng, UInt32)
        _process(configuration, seed, input)
    end
end

main()