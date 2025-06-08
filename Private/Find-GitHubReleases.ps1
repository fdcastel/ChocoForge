<#
    .SYNOPSIS
        Queries the GitHub API for releases for a given repository.

    .DESCRIPTION
        Fetches all releases for the specified GitHub repository using the GitHub REST API. Uses the GITHUB_ACCESS_TOKEN environment variable for authentication if available, increasing rate limits. Returns a list of release objects with selected fields and asset information. Provides verbose output for debugging. Throws on errors and warns if the GitHub API rate limit is exceeded.

    .PARAMETER RepositoryOwner
        The owner (user or organization) of the GitHub repository.

    .PARAMETER RepositoryName
        The name of the GitHub repository.

    .EXAMPLE
        Find-GitHubReleases -RepositoryOwner 'firebird' -RepositoryName 'firebird'

    .NOTES
        - Uses GITHUB_ACCESS_TOKEN from the environment for authenticated requests if available.
        - Returns release objects with selected fields and asset info.
        - Warns if the GitHub API rate limit is exceeded.
        - Uses Write-VerboseMark for verbose output.
        - Throws on errors.
#>
function Find-GitHubReleases {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RepositoryOwner,

        [Parameter(Mandatory)]
        [string]$RepositoryName
    )

    $uri = "https://api.github.com/repos/$($RepositoryOwner)/$($RepositoryName)/releases"
    Write-VerboseMark -Message "Querying GitHub API for releases: $uri"

    try {
        $headers = @{ 'User-Agent' = 'ChocoForge-Module' }
            
        # Uses GitHub access token from environment variable if available
        [string]$githubAccessToken = $env:GITHUB_ACCESS_TOKEN
        if ($githubAccessToken) {
            Write-VerboseMark '- Using authenticated GitHub API requests'
            $headers['Authorization'] = "Bearer $githubAccessToken"
        }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Verbose:$false
        Write-VerboseMark -Message "- Received $($response.Count) releases from GitHub API."

        $result = $response | Select-Object @(
            'html_url',
            'tag_name',
            'name',
            'prerelease',
            'published_at',
            @{ Name = 'assets'; Expression = { @($_.assets | Select-Object -Property name, size, digest, browser_download_url) } }
        )
        return $result
    } catch {
        [string]$errorMessage = $_.Exception.Message
        if ($errorMessage -like '*rate limit*') {
            Write-Warning 'GitHub API rate limit exceeded. Please wait and try again later, or set GITHUB_ACCESS_TOKEN environment variable to increase rate limits.'
        } 
        throw "Failed to fetch GitHub releases for '$($uri): $errorMessage"
    }
}
