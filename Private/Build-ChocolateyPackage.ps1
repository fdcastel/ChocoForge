function Build-ChocolateyPackage {
    <#
    .SYNOPSIS
        Builds one or more Chocolatey packages from a .nuspec file and tools folder, using template substitution for customization.

    .DESCRIPTION
        For each provided context object, this function copies the specified .nuspec file and its sibling ./tools folder to a temporary directory,
        performing template substitution on all files using the context.

        It then runs 'choco pack' to create a Chocolatey package.

        You can optionally specify an output directory for the resulting .nupkg file(s).

        Returns the path to each created .nupkg file.

    .PARAMETER Context
        The context object for template substitutions. Must include a 'version' property. Accepts pipeline input for processing multiple packages in one call.

    .PARAMETER NuspecPath
        Path to the .nuspec file to use as the package template.

    .PARAMETER OutputPath
        Optional. Directory where the resulting .nupkg file will be placed. If not specified, the package is created in a temporary directory.

    .PARAMETER Embed
        Optional switch. When specified, downloads each asset's browser_download_url into the tools directory
        of the package, embedding the installer in the .nupkg. Useful for Chocolatey packages that include
        the installer directly instead of downloading at install time.

    .EXAMPLE
        Build-ChocolateyPackage -Context $ctx -NuspecPath 'Samples/firebird.nuspec' -OutputPath 'out/'

        Creates a Chocolatey package using the provided context and nuspec file, placing the result in the 'out/' directory.

    .EXAMPLE
        $contexts | Build-ChocolateyPackage -NuspecPath 'Samples/firebird.nuspec'

        Builds packages for each context object in the pipeline, using the specified nuspec file.

    .EXAMPLE
        $contexts | Build-ChocolateyPackage -NuspecPath 'app.nuspec' -Embed

        Builds packages with embedded installers downloaded into the tools directory.

    .OUTPUTS
        System.String. The path to the created .nupkg file for each context object.

    .NOTES
        Supports -WhatIf and -Confirm for safe execution.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Context,

        [Parameter(Mandatory)]
        [string]$NuspecPath,

        [string]$OutputPath,

        [switch]$Embed
    )

    begin {
        # Test first: Resolve-Path throws a less helpful error of its own on a missing path.
        if (-not (Test-Path -LiteralPath $NuspecPath)) {
            throw "Nuspec file not found: $NuspecPath"
        }
        $nuspecFull = (Resolve-Path -LiteralPath $NuspecPath).Path

        $nuspecBase = [System.IO.Path]::GetFileNameWithoutExtension($nuspecFull)
        $srcDir = Split-Path -Parent $nuspecFull
        $toolsDir = Join-Path $srcDir 'tools'
        if (-not (Test-Path $toolsDir)) {
            throw "Expected 'tools' folder not found: $toolsDir"
        }
        $legalDir = Join-Path $srcDir 'legal'
        $hasLegalDir = Test-Path $legalDir
        Write-VerboseMark "Legal folder $(if ($hasLegalDir) { 'found' } else { 'not found' }) at: $legalDir"
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

        # Auto-inject legal folder into <files> section if legal folder exists but not already referenced
        if ($hasLegalDir -and $renderedNuspec -match '<files>' -and $renderedNuspec -notmatch 'legal\\') {
            $renderedNuspec = $renderedNuspec -replace '(</files>)', "    <file src=`"legal\**`" target=`"legal`" />`n  `$1"
            Write-VerboseMark 'Auto-injected legal folder into nuspec <files> section.'
        }

        $nuspecDest = Join-Path $tempDir ([System.IO.Path]::GetFileName($nuspecFull))
        Set-Content -Path $nuspecDest -Value $renderedNuspec -NoNewline

        # Render and copy the tools folder, and the legal folder when present (e.g. VERIFICATION.txt)
        $foldersToRender = [ordered]@{ 'tools' = $toolsDir }
        if ($hasLegalDir) {
            $foldersToRender['legal'] = $legalDir
        }

        foreach ($folderName in $foldersToRender.Keys) {
            $srcDirectory = $foldersToRender[$folderName]
            foreach ($file in Get-ChildItem -Path $srcDirectory -Recurse -File) {
                $relPath = $file.FullName.Substring($srcDirectory.Length).TrimStart('/', '\')
                $destPath = Join-Path $tempDir (Join-Path $folderName $relPath)
                $destDir = Split-Path -Parent $destPath
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null

                # Template expansion is a text round-trip, which would replace every byte that is
                # not valid UTF-8 with U+FFFD. Binaries (installers, archives) are copied verbatim.
                if (Test-TextFile -Path $file.FullName) {
                    $content = Get-Content -Raw -LiteralPath $file.FullName
                    $rendered = Expand-Template -Content $content -Context $ctx
                    Set-Content -Path $destPath -Value $rendered -NoNewline
                } else {
                    Write-VerboseMark "Copying binary file without template expansion: $($relPath)"
                    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
                }
            }
            Write-VerboseMark "Copied and rendered '$folderName' folder for version $versionStr."
        }

        # Embed assets: download each asset's browser_download_url into tools/
        if ($Embed) {
            $assetsList = @()
            if ($ctx.PSObject.Properties['assets']) {
                $assetsObj = $ctx.assets
                if ($assetsObj -is [System.Collections.IDictionary]) {
                    # Transposed assets (keyed by arch/platform)
                    foreach ($key in $assetsObj.Keys) {
                        $assetsList += $assetsObj[$key]
                    }
                } elseif ($assetsObj -is [System.Collections.IEnumerable]) {
                    # Array of assets
                    $assetsList = @($assetsObj)
                } else {
                    # Single asset object
                    $assetsList = @($assetsObj)
                }
            }

            $destToolsDir = Join-Path $tempDir 'tools'
            foreach ($asset in $assetsList) {
                if ($asset.browser_download_url) {
                    $fileName = Split-Path $asset.browser_download_url -Leaf
                    $destFile = Join-Path $destToolsDir $fileName
                    Write-VerboseMark "Embedding asset: $fileName"
                    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destFile -UseBasicParsing -Verbose:$false

                    # Create .ignore file for .exe assets to prevent Chocolatey shimming
                    if ($fileName -like '*.exe') {
                        $ignoreFile = "$destFile.ignore"
                        Set-Content -Path $ignoreFile -Value ''
                        Write-VerboseMark "Created shim ignore file: $fileName.ignore"
                    }
                }
            }
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
