# Pester 5 test for Get-GitHubReleases
Describe 'Get-GitHubReleases' {
    BeforeAll {
        # Dot-source the function and its dependency
        . "$PSScriptRoot/../Private/Write-VerboseMark.ps1"
        . "$PSScriptRoot/../Private/Get-GitHubReleases.ps1"
    }

    It 'Returns releases for repository' {
        $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird' -Verbose
        Write-VerboseMark -Message "Releases retrieved: $($releases.Count)"
        $releases | ConvertTo-Json -depth 20 | Out-File c:\temp\t.json
    }
}
