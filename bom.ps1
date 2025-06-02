# bom.ps1

<#
.SYNOPSIS
    Create a list of software dependencies for this project
    and write them in a file together with their license.

.PARAMETER All
    If specified, this will create a list of all dependencies,
    including transitive dependencies.

.PARAMETER OutputFile
    The path to the bill of material JSON file.
    Defaults to the bom.json file in the same directory as this script.

.PARAMETER CreateLicenseFiles
    If specified, this will create a license file for each dependency.
    All license files will be created in the LICENSES directory.

.EXAMPLE
    # Generate the bill of material file `bom.json`.
    .\bom.ps1
#>

#
# Description:
#

[CmdletBinding()]
param(
    [switch]
    $All,

    [ValidateNotNullOrEmpty()]
    [string]
    $OutputFile = "bom.json",

    [switch]
    $CreateLicenseFiles
)

Push-Location -Path $PSScriptRoot
$rootDir = Join-Path -Path $PSScriptRoot -ChildPath "scripts"

# We need to update here to capture the latest version of the solver
julia --project=$rootDir -e "using Pkg; Pkg.update()"

if($All) {
    Write-Host "Creating a list of all dependencies"
    julia --project=$rootDir .\scripts\bom.jl --filename $OutputFile --all
} else {
    Write-Host "Creating a list of direct dependencies"
    julia --project=$rootDir .\scripts\bom.jl --filename $OutputFile
}

if ($CreateLicenseFiles) {
    Write-Verbose -Message "Creating license files"
    $bom = Get-Content -Path $OutputFile -Raw | ConvertFrom-Json

    $bom | ForEach-Object -Process {
        $dep = $_
        $name = $dep.name
        $license = $dep.license

        Write-Verbose -Message "Creating license file for $($_.name)"

        $filename = "LICENSE-$name.txt"
        $licenseFile = Join-Path -Path $PSScriptRoot -ChildPath "LICENSES" | Join-Path -ChildPath $filename

        $license | Out-File -FilePath $licenseFile -Encoding ascii
    }
}

Pop-Location