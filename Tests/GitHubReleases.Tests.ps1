Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'GitHubReleases (3-number versions)' {
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
                [version]$r.version -ge [version]'5.0.0' | Should -Be $true
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
                [version]$r.version -lt [version]'5.0.0' | Should -Be $true
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

Describe 'GitHubReleases (4-number versions)' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/firebird-odbc-mocks/github-releases.json" -Raw | ConvertFrom-Json
            }
        }

        It 'Returns releases for repository' {
            $releases = Find-GitHubReleases -RepositoryOwner 'fdcastel' -RepositoryName 'firebird-odbc-driver-repack'
            $releases | Should -Not -BeNullOrEmpty
            Write-VerboseMark -Message "Releases retrieved: $($releases.Count)"
        }

        It 'Expands releases with 4-number versions' {
            $releases = Find-GitHubReleases -RepositoryOwner 'fdcastel' -RepositoryName 'firebird-odbc-driver-repack'
            $versionPattern = 'v(\d+\.\d+\.\d+\.\d+)$'
            $assetsPattern = 'Firebird_ODBC_[\d.]+_(?<arch>[^.]+)\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version | Should -Not -BeNullOrEmpty
                # Version should be a version object (not semver)
                $r.version.GetType().Name | Should -BeIn @('Version', 'SemanticVersion')
                # Should have 4 numbers
                $r.version.ToString() -match '^\d+\.\d+\.\d+\.\d+$' | Should -Be $true
            }
        }

        It 'Filters releases with 4-number versions by minimum version' {
            $releases = Find-GitHubReleases -RepositoryOwner 'fdcastel' -RepositoryName 'firebird-odbc-driver-repack'
            $versionPattern = 'v(\d+\.\d+\.\d+\.\d+)$'
            $assetsPattern = 'Firebird_ODBC_[\d.]+_(?<arch>[^.]+)\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern -MinimumVersion '3.0.1.0'

            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                [version]$r.version -ge [version]'3.0.1.0' | Should -Be $true
            }
        }

        It 'Transposes assets by arch property for 4-number versions' {
            $releases = Find-GitHubReleases -RepositoryOwner 'fdcastel' -RepositoryName 'firebird-odbc-driver-repack'
            $versionPattern = 'v(\d+\.\d+\.\d+\.\d+)$'
            $assetsPattern = 'Firebird_ODBC_[\d.]+_(?<arch>[^.]+)\.exe$'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern $versionPattern -AssetPattern $assetsPattern -TransposeProperty 'arch'

            $expanded | Should -Not -BeNullOrEmpty
            
            foreach ($r in $expanded) {
                $r.assets.Keys | Should -Not -BeNullOrEmpty
                $r.assets.Keys | Should -Contain 'x64'
                $r.assets.Keys | Should -Contain 'Win32'
                
                foreach ($k in $r.assets.Keys) {
                    $r.assets[$k].PSObject.Properties.Name | Should -Not -Contain 'arch'
                }
            }
        }
    }
}
