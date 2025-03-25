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

    if ($objective -eq $bound) {
        $results += [PSCustomObject]@{
            Graph = $graph;
            Size = $graph_size;
            Metric = "GraphCut";
            Property = "MaxCut";
            Value = $objective
        }
    } else {
        $results += [PSCustomObject]@{
            Graph = $graph;
            Size = $graph_size;
            Metric = "GraphCut";
            Property = "Heuristic";
            Value = $objective
        }
        $results += [PSCustomObject]@{
            Graph = $graph;
            Size = $graph_size;
            Metric = "GraphCut";
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
