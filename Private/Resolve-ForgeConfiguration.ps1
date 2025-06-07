function Resolve-ForgeConfiguration {
    <#
    .SYNOPSIS
        Enriches a Forge configuration object with release assets and target package info.

    .DESCRIPTION
        Receives the output of Read-ForgeConfiguration, fetches GitHub releases, expands them by all flavors, and queries package info for each target. Adds 'assets' and 'targets' properties to the result object.

    .PARAMETER Configuration
        The configuration object returned by Read-ForgeConfiguration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    Write-VerboseMark -Message 'Starting Resolve-ForgeConfiguration.'

    # Parse GitHub repo owner/name from releases.source
    $sourceUrl = $Configuration.releases.source
    if ($sourceUrl -notmatch '^https://github.com/(?<owner>[^/]+)/(?<repo>[^/]+)') {
        throw 'Invalid GitHub repository URL in releases.source.'
    }
    $repoOwner = $Matches['owner']
    $repoName = $Matches['repo']
    Write-VerboseMark -Message "Repository: $($repoOwner)/$($repoName)"

    # Get all releases from GitHub
    $releases = Find-GitHubReleases -RepositoryOwner $repoOwner -RepositoryName $repoName
    Write-VerboseMark -Message "Fetched $($releases.Count) releases from GitHub."

    # Expand all flavors and collect versions
    $allVersions = @()
    foreach ($flavor in $Configuration.releases.flavors.Keys) {
        $versionPattern = $Configuration.releases.flavors[$flavor].versionPattern
        $assetsPattern = $Configuration.releases.flavors[$flavor].assetsPattern
        $minimumVersion = $Configuration.releases.flavors[$flavor].minimumVersion

        # If assetsPattern has a named capture group, transpose by it
        $resolveParameters = @{
            InputObject   = $releases
            VersionPattern = $versionPattern
            AssetPattern   = $assetsPattern
        }
        if ($assetsPattern -match '\(\?<([a-zA-Z_][a-zA-Z0-9_]*)>') {
            $resolveParameters['TransposeProperty'] = $Matches[1]
        }
        if ($minimumVersion) {
            $resolveParameters['MinimumVersion'] = $minimumVersion
        }
        $expanded = Resolve-GitHubReleases @resolveParameters
        $allVersions += $expanded
    }
    # Flatten, sort by version descending
    $allVersions = $allVersions | Sort-Object -Property version -Descending
    $Configuration | Add-Member -NotePropertyName 'versions' -NotePropertyValue $allVersions -Force
    Write-VerboseMark -Message "Added $($allVersions.Count) versions to configuration."

    # Query all chocolatey targets
    $allVersions = $allVersions.version | ForEach-Object { [version]::new($_.Major, $_.Minor, $_.Build) }  # Discard revision (4th element)
    foreach ($targetName in $Configuration.targets.Keys) {
        $target = $Configuration.targets[$targetName]
        $target.publishedVersions = Find-ChocolateyPublishedVersions -PackageName $Configuration.package -SourceUrl $target.url

        # Find missing versions: those in allVersions but not in publishedVersions.
        $pubVersions = $target.publishedVersions | ForEach-Object { [version]::new($_.Major, $_.Minor, $_.Build) }  # Discard revision (4th element)
        $target.missingVersions = $allVersions | Where-Object { $pubVersions -notcontains $_ }

        Write-VerboseMark -Message "Queried target '$targetName' for package info. Found $($target.publishedVersions.Count) published versions, $($target.missingVersions.Count) missing versions."
    }
    Write-VerboseMark -Message 'Resolve-ForgeConfiguration completed.'

    return $Configuration
}
