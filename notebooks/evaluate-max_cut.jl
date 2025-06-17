#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}

#= # Evaluate solver  performance on MaxCut problems.

Input problems are from the G-Set library. For many of these problems,
the optimal solution is known; for the rest, there are best-known solutions.

Notice: please download the input files in the `../data/GSet` directory,
e.g., by running the `download.ps1` script in that directory.

=#

using Revise
using CUDA
using CSV
using DataFrames
using Dates
using JSON
using LinearAlgebra
using SparseArrays
using UUIDs
using AOCoptimizer
using AOCoptimizer.Solver
using AOCoptimizer.Environment: local_system_info

CUDA.allowscalar(false)
AOCoptimizer.init()

results_csv = joinpath(@__DIR__, "evaluate-max_cut.csv");
experiment_id = uuid4();

results = DataFrame(
    Instance = String[],
    Timeout = Second[],
    # Algorithm = String[],
    MaxCut = Float32[],
    BestKnown = Float32[],
    Ratio = Float32[],
    DSTime = String[],
    DSExperiments = Int32[],
    SuccessRate = Float32[],
    OpsToSolution = Float32[],
    TimeToSolution = Float32[],
    TotalNumberOfSamples = Int32[],
    ExperimentId = UUID[],
    Timestamp = DateTime[]
)


T = Float32;
engine = AOCoptimizer.Solver.EngineCuda(0)

input_path = joinpath(@__DIR__, "..", "data", "GSet");

reference_file = joinpath(input_path, "reference.csv");
baseline = CSV.read(reference_file, DataFrame);

const g_set_pattern = r"^G\d+$";
function is_input_file(filename)
    topology = basename(filename)
    if occursin(g_set_pattern, topology)
        return true
    end
    return false
end

function estimate_processing_time(graph_size::Int)
    timeout = 100;
    if graph_size >= 5000
        timeout = 300
    end
    if graph_size >= 10000
        timeout = 600
    end
    return Second(timeout)
end

filenames = readdir(input_path, join=true) |> filter(is_input_file);

for filename in filenames
    # filename = filenames[1]
    graph_name = basename(filename)
    graph = AOCoptimizer.FileFormats.read_graph_matrix(filename)
    graph = T.(graph)

    timeout = estimate_processing_time(size(graph, 1))

    sol = AOCoptimizer.Solver.solve(T, -graph, timeout; engine=engine)
    perf = AOCoptimizer.Solver.get_solver_results_summary(sol)
    max_cut = AOCoptimizer.graph_cut_from_hamiltonian(graph, perf.obj_best_found)

    best_known = baseline[baseline.Instance .== graph_name .&& baseline.Algorithm .== "BestKnown", :].Value
    @assert length(best_known) < 2 "No best known solution found for $graph_name"
    if !isempty(best_known)
        best_known_value = best_known[1]
    else
        best_known_value = NaN
    end

    ratio_to_best_known = max_cut / best_known_value

    stats = AOCoptimizer.Solver.extract_runtime_information(sol)
    summary = AOCoptimizer.Solver.get_solver_results_summary(sol)

    push!(results, Dict(
        :Instance => graph_name,
        :Timeout => timeout,
        # :Algorithm => "AOCoptimizer",
        :MaxCut => max_cut,
        :BestKnown => best_known_value,
        :Ratio => ratio_to_best_known,
        :DSTime => stats[:deep_search][:duration],
        :DSExperiments => stats[:deep_search][:total_experiments],
        :SuccessRate => summary.success_rate,
        :OpsToSolution => summary.num_operations_to_solution,
        :TimeToSolution => summary.time_to_solution,
        :TotalNumberOfSamples => summary.num_samples_total,
        :ExperimentId => experiment_id,
        :Timestamp => Dates.now()
    ))

    # Write to temporary CSV file
    if !isfile(results_csv)
        CSV.write(results_csv, results; writeheader=true)
    else
        CSV.write(results_csv, results; append=true)
    end
end

# Summary of results:
println(results)

# and in JSON format
JSON.json(results, 4) |> println

# ## System information
#
# System configuration
configuration = Dict(
    :Engine => string(engine),
    :DataType => string(T),
)
println(JSON.json(configuration, 4))

# The benchmark was run on the following system:
info = local_system_info()
println(JSON.json(info, 4))

# The benchmark was completed at the following date and time:
datetime = Dates.now()
println("Benchmark completed at: ", datetime)
