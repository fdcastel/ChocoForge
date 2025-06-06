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
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        Write-VerboseMark -Message "Received $($response.Count) releases from GitHub API. Filtering output."

        $filtered = foreach ($release in $response) {
            [PSCustomObject]@{
                html_url     = $release.html_url
                tag_name     = $release.tag_name
                name         = $release.name
                prerelease   = $release.prerelease
                published_at = $release.published_at
                assets       = @($release.assets | ForEach-Object {
                    [PSCustomObject]@{
                        name                 = $_.name
                        size                 = $_.size
                        digest               = $_.digest
                        browser_download_url = $_.browser_download_url
                    }
                })
            }
        }
        return $filtered
    } catch {
        Write-VerboseMark -Message "Failed to query GitHub API: $($_.Exception.Message)"
        return $null
    }
}
