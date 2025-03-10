#=
bom.jl

This file compiles a list of all dependencies alongside their versions and License.

=#

# using Revise
using ArgParse
using Pkg
using JSON

struct License
    name::String
    version::String
    license::String
    hash::Union{String,Nothing}
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--all"
        help = "Include all dependencies, including those that are not direct dependencies"
        action = :store_true

        "--filename"
        help = "Filename to write the list of dependencies to"
        arg_type = String
        default = "bom.json"

    end

    return parse_args(s)
end

function main()
    args = parse_commandline()

    should_include_all = haskey(args, "all") && args["all"] == true
    bom_file = args["filename"]

    # Get the list of all dependencies
    all_deps = Pkg.dependencies()
    deps_list = filter(x -> x.name == "AOCoptimizer", collect(values(all_deps)))
    @assert length(deps_list) == 1
    deps = deps_list[1].dependencies

    licenses = []
    for kv in deps
        uuid = kv.first
        package = all_deps[kv.second]
        name = package.name
        version = package.version
        hash = package.tree_hash

        path = package.source
        license = joinpath(path, "LICENSE.md")
        if isfile(license)
            filename = license
        elseif contains(path, "stdlib")
            # Part of the standard library
            # We can ignore
            @info "Ignoring $name, since it appears to be part of the standard library"
            continue
        elseif isfile(joinpath(path, "LICENSE.txt"))
            # Some packages have a different name for the license file
            filename = joinpath(path, "LICENSE.txt")
        elseif isfile(joinpath(path, "LICENSE"))
            # Some packages have a different name for the license file
            filename = joinpath(path, "LICENSE")
        else
            @warn "No license found for $name in $license"
            filename = nothing
        end

        if filename !== nothing
            license = read(filename, String)
            if version === nothing
                ver_str = "<unknown>"
            else
                ver_str = string(version)
            end

            push!(licenses, License(name, ver_str, license, hash))
        end
    end

    content = JSON.json(licenses, 4)

    open(bom_file, "w") do f
        write(f, content)
    end

end

main()
