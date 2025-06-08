function Build-ChocolateyPackage {
    <#
    .SYNOPSIS
        Creates one or more Chocolatey packages from a .nuspec file and tools folder, with context-based template substitution.

    .DESCRIPTION
        For each context object (or single object), copies the specified .nuspec file and its sibling ./tools folder to a temp directory, rendering all files (including all files in the tools folder, recursively) with {{ ... }} substitutions from the provided context object. Then runs 'choco pack' in that directory. Optionally outputs to a specified directory.
        
        Returns the path to the created .nupkg file.

    .PARAMETER Context
        Context object for template substitutions (must have a 'version' property). Accepts pipeline input.

    .PARAMETER NuspecPath
        Path to the .nuspec file.

    .PARAMETER OutputPath
        Optional output directory for the .nupkg file.

    .EXAMPLE
        Build-ChocolateyPackage -Context $ctx -NuspecPath 'Samples/firebird.nuspec' -OutputPath 'out/'

    .NOTES
        - Renders all files in the tools folder recursively with template substitution.
        - Throws if required files/folders are missing or if choco pack fails.
        - Returns the path to the created .nupkg file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Context,

        [Parameter(Mandatory)]
        [string]$NuspecPath,

        [string]$OutputPath
    )

    begin {
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
    }

    process {
        $ctx = $Context
        if (-not $ctx.PSObject.Properties['version']) {
            throw "Each context object must have a 'version' property."
        }

        $versionStr = $ctx.version.ToString()
        $tempRoot = Join-Path $env:TEMP 'chocoforge'
        $tempDir = Join-Path $tempRoot (Join-Path $nuspecBase $versionStr)

        $expectedOutputPath = $OutputPath ? $OutputPath : $tempDir
        $expectedPackageName = Join-Path $expectedOutputPath "$nuspecBase.$versionStr.nupkg"
        if (-not $PSCmdlet.ShouldProcess($expectedPackageName, 'Build Chocolatey package')) {
            # Return simulated package path. No need to output verbose messages in WhatIf mode.
            return $expectedPackageName
        }

        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        # Render nuspec file
        $nuspecContent = Get-Content -Raw -LiteralPath $nuspecFull
        $renderedNuspec = Expand-Template -Content $nuspecContent -Context $ctx
        $nuspecDest = Join-Path $tempDir ([System.IO.Path]::GetFileName($nuspecFull))
        Set-Content -Path $nuspecDest -Value $renderedNuspec -NoNewline

        # Render and copy tools folder recursively
        $srcToolsFiles = Get-ChildItem -Path $toolsDir -Recurse -File
        foreach ($file in $srcToolsFiles) {
            $relPath = $file.FullName.Substring($toolsDir.Length).TrimStart('/', '\')
            $destPath = Join-Path $tempDir (Join-Path 'tools' $relPath)
            $destDir = Split-Path -Parent $destPath
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null 
            $content = Get-Content -Raw -LiteralPath $file.FullName
            $rendered = Expand-Template -Content $content -Context $ctx
            Set-Content -Path $destPath -Value $rendered -NoNewline
        }

        # Prepare choco pack args
        $tempNuspec = Join-Path $tempDir ([System.IO.Path]::GetFileName($nuspecFull))
        $chocoArguments = @('pack', $tempNuspec, '--limit-output')
        if ($OutputPath) {
            $chocoArguments += '--output-directory'
            $chocoArguments += $OutputPath
        }

        Write-VerboseMark -Message "Packing Chocolatey package in $tempDir"
        $result = Invoke-Chocolatey -Arguments $chocoArguments -WorkingDirectory $tempDir
        if ($result.ExitCode -ne 0) {
            throw "choco pack failed for version $($versionStr): $($result.StdOut)"
        }

        # Extract the filename from the output
        if ($result.StdOut -match "Successfully created package '([^']+)'") {
            $fileName = $Matches[1]
            Write-VerboseMark -Message "Chocolatey package '$fileName' created."
            return $fileName
        } else {
            throw 'Unexpected output from "choco pack": No package path found in message.'
        }
    }
}
