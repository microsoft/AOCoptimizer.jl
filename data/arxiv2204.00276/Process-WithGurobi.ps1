<#
.SYNOPSIS
    This script processes MPS files using Gurobi and generates a CSV report.

.DESCRIPTION
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$InputFile = @(Get-ChildItem -Path $PSScriptRoot\problems -Filter "*.mps" | Select-Object -ExpandProperty FullName),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1)]
    [int]$TimeLimit = 600,

    [switch]
    $Force = $false
)


foreach ($file in $InputFile) {
    # Get the file name without extension
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $filePath = [System.IO.Path]::GetDirectoryName($file)

    $solutionPath = Join-Path -Path $filePath -ChildPath "$fileName.sol.json"
    $logFilePath = Join-Path -Path $filePath -ChildPath "$fileName.log"

    $timeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Write-Verbose "Processing $fileName (starting at $timeStamp)"
    if (Test-Path -Path $solutionPath -PathType Leaf) {
        if ($Force) {
            Write-Warning -Message "Solution file already exists. Deleting $solutionPath."
            Remove-Item -Path $solutionPath -Force
            Remove-Item -Path $logFilePath -Force
        } else {
            Write-Warning -Message "Solution file already exists. Skipping $fileName."
            continue
        }
    }

    if (Test-Path -Path $logFilePath -PathType Leaf) {
        Write-Warning -Message "Log file already exists. Deleting $logFilePath."
        Remove-Item -Path $logFilePath -Force
    }

    gurobi_cl.exe ResultFile=$solutionPath JSONSolDetail=1 LogFile="$logFilePath" TimeLimit=$TimeLimit $file
    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message "Gurobi failed to process $fileName. Exit code: $LASTEXITCODE"
        break
    }

    if (-not (Test-Path $solutionPath)) {
        Write-Error -Message "Solution file $solutionPath not found for problem $fileName."
    }
    if (-not (Test-Path $logFilePath)) {
        Write-Error -Message "Log file $logFilePath not found for problem $fileName."
    }
}