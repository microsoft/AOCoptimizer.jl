[CmdletBinding()]
param(
    [switch]
    $SameWindow,

    [string]
    $Version = $null,

    [switch]
    $EnableDebug,

    [switch]
    $Once
)

Push-Location -Path $PSScriptRoot

$rootDir = Join-Path -Path $PSScriptRoot -ChildPath "scripts"

$arguments = @(
    "--project=$rootDir"
    (Join-Path -Path $rootDir -ChildPath "typecheck.jl")
)

if (![string]::IsNullOrWhiteSpace($Version)) {
    Write-Verbose -Message "Setting Julia version to $Version"
    $arguments = @("+$Version") + $arguments
}
if ($EnableDebug) {
    $arguments = $arguments + @("--debug")
}
if ($Once) {
    $arguments = $arguments + @("--once")
    $SameWindow = $true
}

Write-Verbose -Message "Updating Julia packages"
julia --project=$rootDir -e "using Pkg; Pkg.update()"

Write-Verbose -Message "Arguments: $arguments"
$julia = Get-Command julia

if ($SameWindow) {
    julia @arguments
} else {
    Start-Process -FilePath $julia.Source -ArgumentList $arguments
}

Pop-Location
