[CmdletBinding()]
param (
    [string]$webpageUrl = "https://web.stanford.edu/~yyye/yyye/Gset/",
    [string]$outputDirectory = $PSScriptRoot
)

if (!(Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

# Fetch the webpage content
$response = Invoke-WebRequest -Uri $webpageUrl

# Extract all links starting with "G"
$links = $response.Links | Where-Object { $_.href -match "^G\d+$" }

# Download each file
foreach ($link in $links) {
    $fileUrl = $link.href
    $url = "$webpageUrl$fileUrl"
    $fileName = Split-Path -Leaf $fileUrl

    if (Test-Path -Path (Join-Path $outputDirectory $fileName)) {
        Write-Host "File '$fileName' already exists in '$outputDirectory'; skipping download."
        continue
    }

    $outputPath = Join-Path $outputDirectory $fileName

    # Download the file
    Write-Information -Message "Downloading '$url' and saving to '$outputPath'"
    Invoke-WebRequest -Uri $url -OutFile $outputPath
    Write-Verbose -Message "Downloaded $fileName to $outputDirectory"
}
