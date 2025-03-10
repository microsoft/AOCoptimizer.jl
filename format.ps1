# format.ps1
# Automatically (re-)format the Julia code

[CmdletBinding()]
param()

Push-Location -Path $PSScriptRoot

$code = @"
using JuliaFormatter;
JuliaFormatter.format(".")
"@

$rootDir = Join-Path -Path $PSScriptRoot -ChildPath "scripts"

$changes = $code | julia --project=$rootDir
if ($changes -ieq "true") {
    Write-Verbose -Message "No files changed"
} else {
    Write-Warning -Message "Files Modified"
}

Pop-Location