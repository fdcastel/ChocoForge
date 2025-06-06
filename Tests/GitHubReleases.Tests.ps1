Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Find-GitHubReleases' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/github-releases.json" -Raw | ConvertFrom-Json
            }
        }

        It 'Returns releases for repository' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            Write-VerboseMark -Message "Releases retrieved: $($releases.Count)"
        }

        It 'Filters Firebird releases by tag_name regex' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $filter = @{ tag_name = @{ op = 'match'; value = '^R3' } }
            $filtered = Select-ObjectLike -InputObject $releases -Filter $filter
            $filtered.Count | Should -Be 6
        }

        It 'Expands and filters Firebird v5+ releases by version' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $versionPattern = 'v(5\.[\d.]+)'
            $assetsPattern = 'Firebird-[\d.]+-\d+-(?<platform>[^-]+)-(?<arch>[^-.]+)(-(?<debug>withDebugSymbols))?\.(?<ext>.+)$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern #-MinimumVersion '5.0.0' 

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version -match '^5\.' | Should -Be $true
                [version]$r.version -ge [version]'5.0.0' | Should -Be $true
            }
        }

        It 'Expands and filters Firebird v3/v4 releases by version' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $versionPattern = 'v([3-4]\.[\d.]+)'
            $assetsPattern = 'Firebird-[\d.]+-\d+-(?<arch>[^-.]+)(-(?<debug>pdb))?\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern #-MinimumVersion '5.0.0' 

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version -match '^5\.' | Should -Be $false
                [version]$r.version -lt [version]'5.0.0' | Should -Be $true
            }
        }

        It 'Transposes assets by arch property' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'

            $versionPattern = 'v(5\.\d+\.\d+)$'
            $assetsPattern = 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern -TransposeProperty 'arch'

            $expanded | Should -Not -BeNullOrEmpty
            $expanded.assets.x64.Length | Should -Be 3
            $expanded.assets.x86.Length | Should -Be 3

            foreach ($r in $expanded) {
                $r.assets.Keys | Should -Not -BeNullOrEmpty
                foreach ($k in $r.assets.Keys) {
                    $r.assets[$k].PSObject.Properties.Name | Should -Not -Contain 'arch'
                }
            }
        }
    }
}
