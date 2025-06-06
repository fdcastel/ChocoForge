function Get-GitHubReleases {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepositoryOwner,
        [Parameter(Mandatory = $true)]
        [string]$RepositoryName
    )

    $uri = "https://api.github.com/repos/$($RepositoryOwner)/$($RepositoryName)/releases"
    Write-VerboseMark -Message "Querying GitHub API for releases: $uri"

    try {
        $headers = @{ 'User-Agent' = 'ChocoForge-Module' }
            
        # Uses GitHub access token from environment variable if available
        [string]$githubAccessToken = $env:GITHUB_ACCESS_TOKEN
        if ($githubAccessToken) {
            Write-VerboseMark "- Using authenticated GitHub API requests"
            $headers['Authorization'] = "Bearer $githubAccessToken"
        }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        # Debug only
        # $response | ConvertTo-Json -Depth 20 | Out-File -Encoding utf8 -FilePath "$PSScriptRoot/../Tests/assets/github-releases.json" -Force
        Write-VerboseMark -Message "- Received $($response.Count) releases from GitHub API."

        $result = $response | Select-Object `
            'html_url',
        'tag_name',
        'name',
        'prerelease',
        'published_at',
        @{ Name = 'assets'; Expression = { @($_.assets | Select-Object -Property name, size, digest, browser_download_url) } }
        return $result
    }
    catch {
        [string]$errorMessage = $_.Exception.Message
        if ($errorMessage -like "*rate limit*") {
            Write-Warning "GitHub API rate limit exceeded. Please wait and try again later, or set GITHUB_ACCESS_TOKEN environment variable to increase rate limits."
        } 
        throw "Failed to fetch GitHub releases for '$($uri): $errorMessage"
    }
}
