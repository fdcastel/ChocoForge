function New-ChocolateyPackage {
    <#
    .SYNOPSIS
        Creates one or more Chocolatey packages from a .nuspec file and tools folder, with context-based template substitution.

    .DESCRIPTION
        For each context object (or single object), copies the specified .nuspec file and its sibling ./tools folder to a temp directory, rendering all files with {{ ... }} substitutions from the provided context object. Then runs 'choco pack' in that directory. Optionally outputs to a specified directory.

    .PARAMETER NuspecPath
        Path to the .nuspec file.
    .PARAMETER OutputPath
        Optional output directory for the .nupkg file.
    .PARAMETER Context
        Context object or array of objects for template substitutions (each must have a 'version' property).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NuspecPath,

        [Parameter(Mandatory)]
        [object[]]$Context,

        [string]$OutputPath
    )

    function Convert-Template {
        param([string]$Content, $Context)
        $Content -replace '{{\s*([\w.]+)\s*}}', {
            $expr = $_.Groups[1].Value
            $parts = $expr -split '\.'
            $val = $Context
            foreach ($p in $parts) {
                if ($null -eq $val) { break }
                $val = $val.$p
            }
            if ($null -eq $val) { 
                Write-Warning "Missing context value for '$expr'. Returning empty string."
                return '' 
            } else { 
                return $val.ToString() 
            }
        }
    }

    $nuspecFull = (Resolve-Path -LiteralPath $NuspecPath).Path
    if (-not (Test-Path $nuspecFull)) {
        throw "Nuspec file not found: $nuspecFull"
    }

    $nuspecBase = [System.IO.Path]::GetFileNameWithoutExtension($nuspecFull)
    $srcDir = Split-Path -Parent $nuspecFull
    $toolsDir = Join-Path $srcDir 'tools'
    if (-not (Test-Path $toolsDir)) {
        throw "Expected 'tools' folder not found: $toolsDir"
    }

    $contexts = @($Context)
    $results = @()
    foreach ($ctx in $contexts) {
        if (-not $ctx.PSObject.Properties['version']) {
            throw "Each context object must have a 'version' property."
        }
        $versionStr = $ctx.version.ToString()
        $tempRoot = Join-Path $env:TEMP 'chocoforge'
        $tempDir = Join-Path $tempRoot (Join-Path $nuspecBase $versionStr)
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        # Render nuspec file
        $nuspecContent = Get-Content -Raw -LiteralPath $nuspecFull
        $renderedNuspec = Convert-Template -Content $nuspecContent -Context $ctx
        $nuspecDest = Join-Path $tempDir ([System.IO.Path]::GetFileName($nuspecFull))
        Set-Content -Path $nuspecDest -Value $renderedNuspec -NoNewline

        # Render and copy tools folder recursively
        $srcToolsFiles = Get-ChildItem -Path $toolsDir -Recurse -File
        foreach ($file in $srcToolsFiles) {
            $relPath = $file.FullName.Substring($toolsDir.Length).TrimStart('/','\')
            $destPath = Join-Path $tempDir (Join-Path 'tools' $relPath)
            $destDir = Split-Path -Parent $destPath
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null 
            $content = Get-Content -Raw -LiteralPath $file.FullName
            $rendered = Convert-Template -Content $content -Context $ctx
            Set-Content -Path $destPath -Value $rendered -NoNewline
        }

        # Prepare choco pack args
        $chocoArguments = @('pack', (Join-Path $tempDir ([System.IO.Path]::GetFileName($nuspecFull))))
        if ($OutputPath) {
            $chocoArguments += '--output-directory'
            $chocoArguments += $OutputPath
        }

        Write-VerboseMark -Message "Packing Chocolatey package in $tempDir"
        $result = Invoke-Chocolatey -Arguments $chocoArguments -WorkingDirectory $tempDir
        if ($result.ExitCode -ne 0) {
            throw "choco pack failed for version $($versionStr): $($result.StdErr)"
        }
        Write-VerboseMark -Message "Chocolatey package created successfully for version $versionStr."
        $results += $result.StdOut
    }
    return $results
}
