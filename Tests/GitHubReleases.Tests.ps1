Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'GitHubReleases' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/firebird-mocks/github-releases.json" -Raw | ConvertFrom-Json
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
            $filtered | Should -HaveCount 6
        }

        It 'Expands and filters Firebird v5+ releases by version' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $versionPattern = 'v(5\.\d+\.\d+)$'
            $assetsPattern = 'Firebird-[\d.]+-\d+-(?<platform>[^-]+)-(?<arch>[^-.]+)(-(?<debug>withDebugSymbols))?\.(?<ext>.+)$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version -match '^5\.' | Should -Be $true
                [semver]$r.version -ge [semver]'5.0.0' | Should -Be $true
            }
        }

        It 'Expands and filters Firebird v3/v4 releases by version' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'
            $versionPattern = 'v([3-4]\.\d+\.\d+)$'
            $assetsPattern = 'Firebird-\d+\.\d+\.\d+\.\d+[-_]\d+[-_](?<arch>[^-_.]+)\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version -match '^5\.' | Should -Be $false
                [semver]$r.version -lt [semver]'5.0.0' | Should -Be $true
            }
        }

        It 'Transposes assets by arch property' {
            $releases = Find-GitHubReleases -RepositoryOwner 'FirebirdSQL' -RepositoryName 'firebird'

            $versionPattern = 'v(5\.\d+\.\d+)$'
            $assetsPattern = 'Firebird-[\d.]+-\d+-windows-(?<arch>[^-_.]+)\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern -TransposeProperty 'arch'

            $expanded | Should -Not -BeNullOrEmpty
            $expanded.assets.x64 | Should -HaveCount 3
            $expanded.assets.x86 | Should -HaveCount 3

            foreach ($r in $expanded) {
                $r.assets.Keys | Should -Not -BeNullOrEmpty
                foreach ($k in $r.assets.Keys) {
                    $r.assets[$k].PSObject.Properties.Name | Should -Not -Contain 'arch'
                }
            }
        }
    }
}
