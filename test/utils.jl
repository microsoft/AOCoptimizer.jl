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

function _process_input_file(process::Function, filepath::AbstractString, filename::AbstractString)
    path = joinpath(filepath, filename)
    if isfile(path) == false
        @error "File not found" filepath filename
        throw(FileNotFoundException(filename))
    end

    open(path) do file
        if endswith(filename, ".bz2")
            stream = Bzip2DecompressorStream(file)
        else
            stream = file
        end
        return process(stream)
    end
end

function _is_test_file_present(filename::AbstractString)
    if !isfile(filename)
        return false
    end

    # get file size
    file_size = filesize(filename)
    if file_size < 512
        # this is a link to the LFS file, but not the file itself
        # hence, the file is not present locally
        return false
    end

    return true
end
