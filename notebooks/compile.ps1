[CmdletBinding()]
param(
    [string[]] $Notebooks = $null
)

$old_number_of_threads = $Env:JULIA_NUM_THREADS
if (-not $old_number_of_threads -or $old_number_of_threads -le 1) {
    Write-Host "JULIA_NUM_THREADS environment variable is not set. Setting it to 12."
    $Env:JULIA_NUM_THREADS=12
} else {
    Write-Host "JULIA_NUM_THREADS is currently set to $Env:JULIA_NUM_THREADS."
}

Write-Verbose "Creating Quarto notebooks"
julia --project compile.jl
if ($LASTEXITCODE -ne 0) {
    Write-Error "Julia compilation failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
} else {
    Write-Host "Julia compilation completed successfully."
}

if (-not (Test-Path "archives")) {
    New-Item -ItemType Directory -Path "archives" | Out-Null
}

$all_notebooks = Get-ChildItem -Path $PSScriptRoot -Filter "*.qmd" | ForEach-Object { $_.BaseName }
if ($null -ne $Notebooks) {
    $all_notebooks = $all_notebooks | Where-Object { $_ -in $Notebooks }
}

foreach($basename in $all_notebooks) {
    $notebook = "$basename.qmd"

    Write-Verbose "Rendering Quarto notebook: $notebook"
    quarto render $notebook --to pdf --pdf-engine=lualatex --metadata=format.pdf.include-in-header.text="\usepackage{fvextra}"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Quarto rendering failed with exit code $LASTEXITCODE when processing $notebook"
        exit $LASTEXITCODE
    } else {
        Write-Host "Quarto rendering completed successfully for $notebook."
    }

    $renderedPdf = "$basename.pdf"
    if (Test-Path $renderedPdf) {
        Write-Host "PDF file created successfully: $renderedPdf"
    } else {
        Write-Error "PDF file was not created: $renderedPdf"
        exit 1
    }

    $datetime = Get-Date -Format "yyyyMMddTHHmmss" -AsUTC
    $archiveName = "archives/$basename-$datetime.pdf"
    Write-Host "Archiving PDF to $archiveName"
    Copy-Item -Path $renderedPdf -Destination $archiveName -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to archive PDF with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    } else {
        Write-Host "PDF archived successfully to $archiveName."
    }
}

$Env:JULIA_NUM_THREADS = $old_number_of_threads