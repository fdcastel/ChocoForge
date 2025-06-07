function Publish-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$TargetUrl,

        [string]$ApiKey,

        [switch]$Force
    )

    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Package file not found: $Path"
        }

        $chocoArguments = @(
            'push', $Path, '--source', $TargetUrl,
            '--skip-compatibility-checks', '--limit-output'
        )
        if ($ApiKey) {
            $chocoArguments += @('--api-key', $ApiKey)
        }

        Write-VerboseMark -Message "Pushing package '$Path' to '$TargetUrl'..."
        $result = Invoke-Chocolatey -Arguments $chocoArguments
        if ($result.ExitCode -eq 0) {
            Write-VerboseMark -Message "Successfully published $Path to $TargetUrl"
            return $Path
        }

        if ($result.StdOut -match '409 \(Conflict\)' -and $Force) {
            # GitHub only: force push logic
            if (-not $TargetUrl.StartsWith('https://nuget.pkg.github.com')) {
                throw 'Force push not supported for this target.'
            }

            $packageName, $version = ([System.IO.Path]::GetFileNameWithoutExtension($Path)).Split('.', 2)
            $owner = ($TargetUrl -replace '^https://nuget.pkg.github.com/', '') -replace '/.*', ''

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

            Write-VerboseMark -Message "Successfully published $packageName to $TargetUrl after force."
            return $Path
        }

        throw "choco push failed for $($packageName): $($result.StdOut)"
    }
}