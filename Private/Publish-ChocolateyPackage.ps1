function Publish-ChocolateyPackage {
    <#
    .SYNOPSIS
        Publishes a Chocolatey package file to a source repository, with optional force-push for GitHub NuGet feeds.

    .DESCRIPTION
        Pushes a .nupkg package to the specified Chocolatey or NuGet repository using choco push. 
        
        Supports GitHub NuGet feeds and can force-push by deleting an existing version if a conflict occurs (409 Conflict) and -Force is specified. 
        
        Returns the path to the published package file.

    .PARAMETER Path
        Path to the .nupkg package file to publish.

    .PARAMETER SourceUrl
        The repository URL to push the package to.

    .PARAMETER ApiKey
        Optional. API key for authenticating with the source repository.

    .PARAMETER Force
        If specified and a 409 Conflict occurs on GitHub, deletes the existing version and retries the push. Only supported for GitHub NuGet feeds.

    .EXAMPLE
        Publish-ChocolateyPackage -Path 'out/firebird.4.0.0.nupkg' -SourceUrl 'https://nuget.pkg.github.com/owner/index.json' -ApiKey $env:GITHUB_TOKEN -Force
        
        Publishes the specified package to a GitHub NuGet feed, force-pushing if a version conflict occurs.

    .OUTPUTS
        System.String
        The path to the published .nupkg package file.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$SourceUrl,

        [string]$ApiKey,

        [switch]$Force
    )

    process {
        $forcedSuffix = if ($Force) { ' (forced)' } else { '' }
        if (-not $PSCmdlet.ShouldProcess($Path, "Publish Chocolatey package to '$SourceUrl'$forcedSuffix")) {
            # Return simulated package path. No need to output verbose messages in WhatIf mode.
            return $Path
        }        

        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Package file not found: $Path"
        }

        $chocoArguments = @(
            'push', $Path, '--source', $SourceUrl, '--limit-output'
        )
        if ($ApiKey) {
            $chocoArguments += @('--api-key', $ApiKey)
        }

        Write-VerboseMark -Message "Pushing package '$Path' to '$SourceUrl'$forcedSuffix..."
        $result = Invoke-Chocolatey -Arguments $chocoArguments
        if ($result.ExitCode -eq 0) {
            Write-VerboseMark -Message "Successfully published $Path to $SourceUrl"
            return $Path
        }

        if ($result.StdOut -match '409 \(Conflict\)' -and $Force) {
            # GitHub only: force push logic
            if (-not $SourceUrl.StartsWith('https://nuget.pkg.github.com')) {
                throw 'Force push not supported for this source.'
            }

            $packageName, $version = ([System.IO.Path]::GetFileNameWithoutExtension($Path)).Split('.', 2)
            $owner = ($SourceUrl -replace '^https://nuget.pkg.github.com/', '') -replace '/.*', ''

            $headers = @{ 'Authorization' = "Bearer $ApiKey" }

            # Get id of this version
            $versionsUrl = "https://api.github.com/users/$owner/packages/nuget/$packageName/versions"
            $response = Invoke-RestMethod -Uri $versionsUrl -Headers $headers -Verbose:$false
            $versionId = $response |
                Where-Object { $_.name -eq $version } |
                    Select-Object -ExpandProperty 'id'

            if (-not $versionId) {
                throw "Unexpected error: Version '$version' not found for package '$packageName'."
            }

            # Delete the version (discard response to not output it to the pipeline)
            $null = Invoke-RestMethod -Uri "$versionsUrl/$versionId" -Headers $headers -Method Delete -Verbose:$false

            # Retry the push
            Write-VerboseMark -Message 'Retrying push after forced removal...'
            $result = Invoke-Chocolatey -Arguments $chocoArguments
            if ($result.ExitCode -ne 0) {
                throw "choco push failed for $packageName after force: $($result.StdOut)"
            }

            Write-VerboseMark -Message "Successfully published $packageName to $SourceUrl after force."
            return $Path
        }

        throw "choco push failed for $($packageName): $($result.StdOut)"
    }
}