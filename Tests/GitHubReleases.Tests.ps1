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
            $versionPattern = 'v(5\.[\d.]+)'
            $assetsPattern = 'Firebird-[\d.]+-\d+-(?<platform>[^-]+)-(?<arch>[^-.]+)(-(?<debug>withDebugSymbols))?\.(?<ext>.+)$'
            $expanded = $releases | Expand-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern #-MinimumVersion '5.0.0' 
            # $expanded | ConvertTo-Json -depth 20 | Out-File '/temp/v5.json'

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version -match '^5\.' | Should -Be $true
                [version]$r.version -ge [version]'5.0.0' | Should -Be $true
            }
        }

        It 'Expands and filters Firebird v3/v4 releases by version' {
            $releases = Get-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $versionPattern = 'v([3-4]\.[\d.]+)'
            $assetsPattern = 'Firebird-[\d.]+-\d+-(?<arch>[^-.]+)(-(?<debug>pdb))?\.exe$'
            $expanded = $releases | Expand-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern #-MinimumVersion '5.0.0' 
            # $expanded | ConvertTo-Json -depth 20 | Out-File '/temp/v4.json'

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version -match '^5\.' | Should -Be $false
                [version]$r.version -lt [version]'5.0.0' | Should -Be $true
            }
        }
    }
}
