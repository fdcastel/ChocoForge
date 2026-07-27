function Resolve-ForgeConfiguration {
    <#
    .SYNOPSIS
        Enriches a Forge configuration object with GitHub release versions and source package information.

    .DESCRIPTION
        Takes a configuration object from Read-ForgeConfiguration, fetches all releases from the specified GitHub repository, 
        expands them by all flavors, and queries package information for each source. 
        
        Adds a 'versions' property containing all expanded releases to the configuration object. 
        
        For each source, adds published and missing version information, as well as API key and publishing status details. 
        
        Returns the enriched configuration object.

    .PARAMETER Configuration
        The configuration object returned by Read-ForgeConfiguration. This object is enriched with a 'versions' property and updated 'sources' information.

    .EXAMPLE
        $config = Read-ForgeConfiguration -Path 'Samples/firebird.forge.yaml'
        $resolved = Resolve-ForgeConfiguration -Configuration $config
        
        Enriches the configuration with release and source package information.

    .OUTPUTS
        PSCustomObject
        The enriched configuration object, including expanded releases and source publishing information.
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
    foreach ($flavorName in $Configuration.releases.flavors.Keys) {
        $flavor = $Configuration.releases.flavors[$flavorName]

        # If assetsPattern has a named capture group, transpose by it
        $resolveParameters = @{
            InputObject    = $releases
            VersionPattern = $flavor.versionPattern
            AssetPattern   = $flavor.assetsPattern
        }
        if ($flavor.assetsPattern -match '\(\?<([a-zA-Z_][a-zA-Z0-9_]*)>') {
            $resolveParameters['TransposeProperty'] = $Matches[1]
        }
        if ($flavor.minimumVersion) {
            $resolveParameters['MinimumVersion'] = $flavor.minimumVersion
        }

        $versions = Resolve-GitHubReleases @resolveParameters
        
        # Apply revision overrides from flavor configuration
        if ($flavor.revisions) {
            foreach ($ver in $versions) {
                $versionKey = "$($ver.version.Major).$($ver.version.Minor).$($ver.version.Build)"
                if ($flavor.revisions.Contains($versionKey)) {
                    $rev = [int]$flavor.revisions[$versionKey]
                    $newVersion = [version]::new($ver.version.Major, $ver.version.Minor, $ver.version.Build, $rev)
                    $ver | Add-Member -NotePropertyName 'version' -NotePropertyValue $newVersion -Force
                    Write-VerboseMark "Applied revision override: $versionKey -> $newVersion"
                }
            }
        }

        $allVersions += $versions | Add-Member -MemberType NoteProperty -Name 'flavor' -Value $flavorName -PassThru
    }

    # Flatten, sort by version descending and add to configuration
    $allVersions = $allVersions | Sort-Object -Property version -Descending
    $Configuration | Add-Member -NotePropertyName 'versions' -NotePropertyValue $allVersions -Force
    Write-VerboseMark -Message "Added $($allVersions.Count) versions to configuration."

    # Query all chocolatey sources
    foreach ($sourceName in $Configuration.sources.Keys) {
        $source = $Configuration.sources[$sourceName]

        # Resolve API key and publishing status first: it determines whether we can query at all.
        Resolve-SourcePublishingStatus -Source $source -SourceName $sourceName

        $credentials = Resolve-SourceCredentials -Source $source -SourceName $sourceName
        $requiresCredentials = $source.url.StartsWith('https://nuget.pkg.github.com') -or $source.url.StartsWith('https://gitlab.com')

        if ($requiresCredentials -and $credentials.Count -eq 0) {
            # No usable token for an authenticated feed. Leave publishedVersions as $null, which
            # means "not queried" - distinct from @(), which means "queried, nothing published".
            Write-VerboseMark -Message "Source '$sourceName' cannot be queried without credentials. Publishing status is unknown."
            $source | Add-Member -MemberType NoteProperty -Name 'publishedVersions' -Value $null -Force
            $source | Add-Member -MemberType NoteProperty -Name 'missingVersions' -Value @() -Force
            continue
        }

        $findArguments = @{
            PackageName = $Configuration.package
            SourceUrl   = $source.url
        }
        $findArguments += $credentials

        $publishedVersions = @(Find-ChocolateyPublishedVersions @findArguments)

        # Find missing versions: those in allVersions but not in publishedVersions
        $missingVersions = @(Compare-PublishedVersions -ReleaseVersions @($allVersions.version) -PublishedVersions $publishedVersions)

        $source | Add-Member -MemberType NoteProperty -Name 'publishedVersions' -Value $publishedVersions -Force
        $source | Add-Member -MemberType NoteProperty -Name 'missingVersions' -Value $missingVersions -Force

        Write-VerboseMark -Message "Queried source '$sourceName' for package info. Found $($publishedVersions.Count) published versions, $($missingVersions.Count) missing versions."
    }

    Write-VerboseMark -Message 'Resolve-ForgeConfiguration completed.'
    return $Configuration
}
