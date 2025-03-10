[CmdletBinding()]
param(
    # Ignore the QA tests
    [switch]$NoAqua,

    # Ignore the Jet tests
    [switch]$NoJet,

    [string[]]$Tests = @(),

    [switch]$DisableReResolve
)

$ErrorActionPreference = "Stop"
$projectDir = $PSScriptRoot

$arguments = @()
if ($NoAqua) {
    $arguments += "--no-aqua"
}
if ($NoJet) {
    $arguments += "--no-jet"
}
if ($Tests.Count -gt 0) {
    $arguments += $Tests
}

$test_args = $arguments | ForEach-Object -Process { "`"$_`"" }
$test_args_string = $test_args -join "; "

if ($DisableReResolve) {
    $allow_reresolve = "false"
} else {
    $allow_reresolve = "true"
}

$commands = "using Pkg`r`n"

if ($arguments.Count -eq 0) {
    $commands += "Pkg.test(; allow_reresolve=$allow_reresolve)`r`n"
} else {
    $commands += "Pkg.test(; allow_reresolve=$allow_reresolve, test_args=[$test_args_string])`r`n"
}

Write-Verbose -Message "Will execute commands:`r`n$commands"
julia --project=$projectDir -e $commands
