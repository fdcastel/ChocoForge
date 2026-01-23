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
        $allVersions += $versions | Add-Member -MemberType NoteProperty -Name 'flavor' -Value $flavorName -PassThru
    }

    # Flatten, sort by version descending and add to configuration
    $allVersions = $allVersions | Sort-Object -Property version -Descending
    $Configuration | Add-Member -NotePropertyName 'versions' -NotePropertyValue $allVersions -Force
    Write-VerboseMark -Message "Added $($allVersions.Count) versions to configuration."

    # Query all chocolatey sources
    foreach ($sourceName in $Configuration.sources.Keys) {
        $source = $Configuration.sources[$sourceName]

        $findArguments = @{
            PackageName = $Configuration.package
            SourceUrl   = $source.url
        }

        if ($source.url.StartsWith('https://nuget.pkg.github.com')) {
            # GitHub requires username and password (api key).

            # GitHub username is always the owner from the URL.
            $userName = ($source.url -replace '^https://nuget.pkg.github.com/', '') -replace '/.*', ''

            $password = Expand-EnvironmentVariables $source.apiKey
            if (-not $password) {
                throw "GitHub source '$sourceName' requires the environment variable $($source.apiKey) to be set."
            }

            $findArguments['User'] = $userName
            $findArguments['Password'] = $password
        }

        if ($source.url.StartsWith('https://gitlab.com')) {
            # GitLab requires username and password (api key).

            $userName = $source.username
            if (-not $userName) {
                throw "GitLab source '$sourceName' requires a username to be set in the configuration."
            }

            $password = Expand-EnvironmentVariables $source.apiKey
            if (-not $password) {
                throw "GitLab source '$sourceName' requires the environment variable $($source.apiKey) to be set."
            }

            $findArguments['User'] = $source.username
            $findArguments['Password'] = Expand-EnvironmentVariables $source.apiKey
        }

        $source.publishedVersions = Find-ChocolateyPublishedVersions @findArguments

        # Find missing versions: those in allVersions but not in publishedVersions.
        #   When comparing versions, treat Revision=-1 as a wildcard that matches any Revision value.
        $source.missingVersions = $allVersions.version | Where-Object {
            $releaseVersion = [version]$_
            $isPublished = $false
            
            foreach ($pubVersion in $source.publishedVersions) {
                # Compare Major, Minor, Build
                if ($pubVersion.Major -eq $releaseVersion.Major -and 
                    $pubVersion.Minor -eq $releaseVersion.Minor -and 
                    $pubVersion.Build -eq $releaseVersion.Build) {
                    
                    # If either has Revision=-1, treat it as a wildcard match
                    if ($pubVersion.Revision -eq -1 -or $releaseVersion.Revision -eq -1) {
                        $isPublished = $true
                        break
                    }
                    
                    # Both have explicit Revision values, must match exactly
                    if ($pubVersion.Revision -eq $releaseVersion.Revision) {
                        $isPublished = $true
                        break
                    }
                }
            }
            
            -not $isPublished
        }

        Write-VerboseMark -Message "Queried source '$sourceName' for package info. Found $($source.publishedVersions.Count) published versions, $($source.missingVersions.Count) missing versions."

        # Skip sources that have no API key available for publishing
        $resolvedApiKey = $null
        $skipReason = $null
        $warningMessage = $null
        if ($source.apiKey) {
            $resolvedApiKey = Expand-EnvironmentVariables $source.apiKey
            if (-not $resolvedApiKey) {
                Write-VerboseMark "Source '$($sourceName)' environment variable $($source.apiKey) is not set. Skipping publishing."
                $skipReason = "Environment variable $($source.apiKey) not set."
            } elseif ($resolvedApiKey -eq $source.apiKey) {
                Write-VerboseMark "Source '$($sourceName)' has an API key stored in plain text in the configuration file (not recommended). Please consider using and environment variable instead."
                $warningMessage = 'API key stored in plain text in the configuration file (not recommended).'
            }
        } else {
            Write-VerboseMark "Source '$($sourceName)' does not have an API key configured. Skipping publishing."
            $skipReason = 'No API key in the configuration file'
        }

        $source | Add-Member -MemberType NoteProperty -Name 'resolvedApiKey' -Value $resolvedApiKey -Force
        $source | Add-Member -MemberType NoteProperty -Name 'skipReason' -Value $skipReason -Force
        $source | Add-Member -MemberType NoteProperty -Name 'warningMessage' -Value $warningMessage -Force
    }

    Write-VerboseMark -Message 'Resolve-ForgeConfiguration completed.'
    return $Configuration
}
