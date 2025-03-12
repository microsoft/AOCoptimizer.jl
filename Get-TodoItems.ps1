[CmdletBinding()]
param(
    $Path = $PSScriptRoot
)

$regex = 'TODO:\s*(?<header>[^\r\n]+)(?:\r?\n(?<body>(?:(?!\s*\r?\n).*\r?\n?)*)?)'

# Get all files in the current directory and subdirectories
$files = `
    Get-ChildItem -Path $Path -Recurse -File | `
    Where-Object { -not (
        $_.Name -match 'Get-TodoItems.ps1$' -or `
        $_.DirectoryName.Contains('node_modules') -or `
        $_.DirectoryName.Contains('build') `
        ) }


$todos = @()

foreach ($file in $files) {
    $lines = Get-Content -Path $file.FullName
    $content = $lines -join "`n"  # Convert to a single string for multi-line matching

    $file_matches = [regex]::Matches($content, $regex)

    foreach ($match in $file_matches) {
        # Find the line number where "TODO:" starts
        $lineIndex = ($lines | Select-String -Pattern "TODO:" | Select-Object -First 1).LineNumber

        $filename = $file.FullName
        $filename = $filename.Replace($Path, '').TrimStart('\').TrimStart('/')

        $todo = [PSCustomObject]@{
            Filename  = $filename
            Line      = $lineIndex
            Header    = $match.Groups["header"].Value.Trim()
            Body      = $match.Groups["body"].Value.Trim()
        }

        $todos += $todo
    }
}

return $todos
