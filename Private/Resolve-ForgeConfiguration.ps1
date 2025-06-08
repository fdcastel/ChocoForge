function Resolve-ForgeConfiguration {
    <#
    .SYNOPSIS
        Enriches a Forge configuration object with GitHub release versions and target package info.

    .DESCRIPTION
        Receives the output of Read-ForgeConfiguration, parses the GitHub repository from the configuration, fetches all releases, expands them by all flavors, and queries package info for each target. Adds a 'versions' property (containing all expanded releases) to the configuration object. For each target, queries published package versions and computes missing versions. Uses Write-VerboseMark for verbose/debug output. Throws if the GitHub repository URL is invalid.

    .PARAMETER Configuration
        The configuration object returned by Read-ForgeConfiguration. This object is enriched with a 'versions' property and updated 'targets' info.

    .NOTES
        - Adds a 'versions' property to the configuration, containing all expanded releases.
        - For each target, adds 'publishedVersions' and 'missingVersions' properties.
        - Uses Write-VerboseMark for verbose output.
        - Throws if the GitHub repository URL is invalid.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Configuration
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
            InputObject    = $releases
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
    foreach ($targetName in $Configuration.targets.Keys) {
        $target = $Configuration.targets[$targetName]

        $findArguments = @{
            PackageName = $Configuration.package
            SourceUrl   = $target.url
        }
        if ($target.url.StartsWith('https://nuget.pkg.github.com')) { 
            # GitHub requires username and password (api key).
            $owner = ($target.url -replace '^https://nuget.pkg.github.com/', '') -replace '/.*', ''
            $findArguments['User'] = $owner
            $findArguments['Password'] = Expand-EnvironmentVariables $target.apiKey
        }

        $target.publishedVersions = Find-ChocolateyPublishedVersions @findArguments

        # Find missing versions: those in allVersions but not in publishedVersions.
        $pubVersions = $target.publishedVersions | ForEach-Object { [semver]::new($_.Major, $_.Minor, $_.Build) }
        $target.missingVersions = $allVersions.version | Where-Object { $pubVersions -notcontains $_ }

        Write-VerboseMark -Message "Queried target '$targetName' for package info. Found $($target.publishedVersions.Count) published versions, $($target.missingVersions.Count) missing versions."
    }
    Write-VerboseMark -Message 'Resolve-ForgeConfiguration completed.'

    return $Configuration
}
