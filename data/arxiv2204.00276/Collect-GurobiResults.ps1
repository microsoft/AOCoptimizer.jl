<#
.SYNOPSIS
    Collects results from Gurobi solution files and generates a CSV report.

.DESCRIPTION
    This script processes Gurobi solution files in JSON format and extracts relevant information such as the graph name, size, metric, and objective values. It generates a CSV report summarizing the results.
    The result found by Gurobi can be of two types. If the solution matched the upper bound,
    then the solution is optimal, and it is recorded in the "Best" property. Otherwise, the
    solution is a heuristic; in this case, we record both the heuristic value and the
    upper bound in the "Heuristic" and "UpperBound" properties, respectively. Often, the
    computed upper bound is quite loose. For the upper bound, we keep the entire value,
    which may be a fractional number, even though the floor of that value would have been
    a slightly better upper bound.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$InputFile = @(Get-ChildItem -Path (Join-Path $PSScriptRoot -ChildPath "gurobi") -Filter "*.sol.json" | Select-Object -ExpandProperty FullName),

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "results-gurobi.csv"
)

$results = @()
foreach ($file in $InputFile) {
    $graph = [System.IO.Path]::GetFileNameWithoutExtension($file).Replace(".sol", "")
    $graph_size = $graph.Split("-")[1]

    Write-Verbose "Processing $graph (of size $graph_size)"
    $json = Get-Content -Path $file -Raw | ConvertFrom-Json
    $objective = $json.SolutionInfo.ObjVal
    $bound = $json.SolutionInfo.ObjBound

    if ($graph.StartsWith("MaxCut-")) {
        $metric = "GraphCut"
    } elseif ($graph.StartsWith("SK-")) {
        $metric = "Ising"
    } else {
        Write-Warning -Message "Unknown graph type: $graph; skipping."
        continue
    }

    if ($objective -eq $bound) {
        $results += [PSCustomObject]@{
            Graph = $graph;
            Size = $graph_size;
            Metric = $metric;
            Property = "Best";
            Value = $objective
        }
    } else {
        $results += [PSCustomObject]@{
            Graph = $graph;
            Size = $graph_size;
            Metric = $metric;
            Property = "Heuristic";
            Value = $objective
        }
        $results += [PSCustomObject]@{
            Graph = $graph;
            Size = $graph_size;
            Metric = $metric;
            Property = "UpperBound";
            Value = $bound
        }
    }
}

if (Test-Path -Path $OutputFile -PathType Leaf) {
    Write-Warning -Message "Output file already exists. Deleting $OutputFile."
    Remove-Item -Path $OutputFile -Force
}
$results | Export-Csv -Path $OutputFile -NoTypeInformation -Force -NoClobber -UseQuotes AsNeeded
