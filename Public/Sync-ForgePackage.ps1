function Sync-ForgePackage {
    <#
    .SYNOPSIS
        Builds and publishes missing Chocolatey packages for all targets defined in a ChocoForge YAML configuration.

    .DESCRIPTION
        Reads and resolves a ChocoForge YAML configuration file using Read-ForgeConfiguration and Resolve-ForgeConfiguration. For each target, builds and publishes any missing package versions, skipping targets with a skipReason. Provides verbose output for all major steps and displays a summary of published and skipped targets. Throws on unexpected errors or if no packages are built when expected.

    .PARAMETER Path
        Path to the YAML configuration file. If not provided, auto-discovery is handled by Read-ForgeConfiguration.

    .EXAMPLE
        Sync-ForgePackage -Path 'Samples/firebird.forge.yaml'

    .NOTES
        - Displays a summary of published and skipped targets.
        - Throws on unexpected errors or if no packages are built.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )
    $config = Read-ForgeConfiguration -Path $Path | Resolve-ForgeConfiguration

    $skippedTargets = $config.targets.Keys | Where-Object { $config.targets[$_].skipReason }
    Write-VerboseMark "Skipped targets: $($skippedTargets -join ', ')"

    $allVersionsToPublish = $config.targets.Keys |
        Where-Object { -not $config.targets[$_].skipReason } |
            ForEach-Object { $config.targets[$_].missingVersions } |
                Select-Object -Unique

    $packagesBuilt = @()
    $packagesPublished = @()
    if ($allVersionsToPublish) {
        Write-VerboseMark "Building packages for versions: $($allVersionsToPublish -join ', ')"
        
        $nuspecPath = $Path -replace '.forge.yaml$', '.nuspec'
        Write-VerboseMark "Nuspec path resolved: $($nuspecPath)"

        $packagesBuilt = $config.versions |
            Where-Object { $allVersionsToPublish -contains $_.version } |
                Build-ChocolateyPackage -NuspecPath $nuspecPath
        if (-not $packagesBuilt) {
            throw 'Unexpected return: No packages were built.'
        }
        Write-VerboseMark "Packages built: $($packagesBuilt.Count)"

        foreach ($targetName in $config.targets.Keys) {
            $target = $config.targets[$targetName]
            
            if ($target.skipReason) {
                Write-VerboseMark "Skipping target '$($targetName)'. Reason: $($target.skipReason)"
                continue
            }

            Write-VerboseMark "Publishing packages for target: $($targetName)"

            foreach ($version in $target.missingVersions) {
                $packageBuilt = $packagesBuilt | Where-Object { $_ -like "*.$($version).nupkg" }
                if (-not $packageBuilt) {
                    throw "Unexpected: No built package found for version $($version)."
                }

                Write-VerboseMark "Publishing '$($packageBuilt)' to '$($targetName)'..."
                $packagePublished = Publish-ChocolateyPackage -Path $packageBuilt -TargetUrl $target.url -ApiKey $target.resolvedApiKey
                $packagesPublished += $packagePublished
            }
        }
    } else {
        Write-VerboseMark 'No versions to publish. Nothing to do.'
    }
    
    # Display operation summary
    Write-Host ''
    $statusColor = if ($skippedTargets) { 'Yellow' } else { 'Green' }
    if ($allVersionsToPublish) {
        Write-Host 'Published ' -ForegroundColor $statusColor -NoNewline
        Write-Host $packagesPublished.Count -ForegroundColor Magenta -NoNewline
        Write-Host ' new packages.' -ForegroundColor $statusColor
    } else {
        Write-Host 'No versions to publish.' -ForegroundColor $statusColor
    }
    if ($skippedTargets) {
        Write-Host '  - Skipped targets: ' -NoNewline
        Write-Host "$($skippedTargets -join ', ')" -ForegroundColor Cyan
    }
}
