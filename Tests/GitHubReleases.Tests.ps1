Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Get-GitHubReleases' {
    InModuleScope 'ChocoForge' {
        Mock Invoke-RestMethod {
            Get-Content "$PSScriptRoot/assets/github-releases.json" -Raw | ConvertFrom-Json
        } -ModuleName 'Microsoft.PowerShell.Utility'

        It 'Returns releases for repository' {
            $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            Write-VerboseMark -Message "Releases retrieved: $($releases.Count)"
        }

        It 'Filters Firebird releases by tag_name regex' {
            $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $filter = @{ tag_name = @{ op = 'match'; value = '^R3' } }
            $filtered = Select-ObjectLike -InputObject $releases -Filter $filter
            $filtered.Count | Should -Be 6
        }

        It 'Expands and filters Firebird v5+ releases by version' {
            $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $expanded = $releases | Expand-GitHubReleases -VersionPattern 'v([\d.]+)' -MinimumVersion '5.0.0'
            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version | Should -Match '^5\.'
                [version]$r.version -ge [version]'5.0.0' | Should -Be $true
            }
            $expanded | ConvertTo-Json -depth 20 | Out-File c:\temp\t.json
        }
    }
}
