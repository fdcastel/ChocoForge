# Pester 5 test combining Get-GitHubReleases and Select-ObjectLike
Describe 'Get-GitHubReleases + Select-ObjectLike' {
    BeforeAll {
        . "$PSScriptRoot/../Private/Write-VerboseMark.ps1"
        . "$PSScriptRoot/../Private/Get-GitHubReleases.ps1"
        . "$PSScriptRoot/../Private/Select-ObjectLike.ps1"
    }

    It 'Filters Firebird releases by tag_name regex' {
        $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
        $filter = @{ tag_name = @{ op = 'match'; value = '^v5\.' } }
        $filtered = Select-ObjectLike -InputObject $releases -Filter $filter
        Write-VerboseMark -Message "Filtered releases: $($filtered.Count)"
        $filtered | Should -Not -BeNullOrEmpty
        # Assert ALL results are v5 only
        foreach ($r in $filtered) {
            $r.tag_name | Should -Match '^v5\.'
        }
        # Assert no non-v5 releases are present
        ($filtered.tag_name | Where-Object { $_ -notmatch '^v5\.' }) | Should -BeNullOrEmpty
    }

    It 'Filters Firebird releases for assets over 100MB' {
        $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
        $filter = @{ assets = @{ size = @{ op = 'gt'; value = 100000000 } } }
        $filtered = Select-ObjectLike -InputObject $releases -Filter $filter
        Write-VerboseMark -Message "Filtered releases with large assets: $($filtered.Count)"
        $filtered | Should -Not -BeNullOrEmpty
        # Assert ALL returned releases have at least one asset >100MB
        foreach ($r in $filtered) {
            ($r.assets.size | Where-Object { $_ -gt 100000000 }) | Should -Not -BeNullOrEmpty
        }
        # Assert no release is included if it has no asset >100MB
        foreach ($r in $filtered) {
            ($r.assets | Where-Object { $_.size -gt 100000000 }) | Should -Not -BeNullOrEmpty
        }
    }
}
