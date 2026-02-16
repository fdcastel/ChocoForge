Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Resolve-GitHubReleases (unit tests)' {
    InModuleScope 'ChocoForge' {
        BeforeAll {
            # Minimal release fixtures for pure unit testing (no file I/O)
            $script:releases = @(
                [PSCustomObject]@{
                    tag_name     = 'v5.0.2'
                    name         = 'Release 5.0.2'
                    html_url     = 'https://github.com/owner/repo/releases/tag/v5.0.2'
                    prerelease   = $false
                    published_at = '2025-02-12T11:19:52Z'
                    assets       = @(
                        [PSCustomObject]@{ name = 'app-x64.exe'; size = 100; digest = $null; browser_download_url = 'https://example.com/app-x64.exe' },
                        [PSCustomObject]@{ name = 'app-x86.exe'; size = 80; digest = $null; browser_download_url = 'https://example.com/app-x86.exe' },
                        [PSCustomObject]@{ name = 'app-src.tar.gz'; size = 50; digest = $null; browser_download_url = 'https://example.com/app-src.tar.gz' }
                    )
                },
                [PSCustomObject]@{
                    tag_name     = 'v4.0.1'
                    name         = 'Release 4.0.1'
                    html_url     = 'https://github.com/owner/repo/releases/tag/v4.0.1'
                    prerelease   = $false
                    published_at = '2024-06-01T00:00:00Z'
                    assets       = @(
                        [PSCustomObject]@{ name = 'app-x64.exe'; size = 90; digest = $null; browser_download_url = 'https://example.com/v4-x64.exe' },
                        [PSCustomObject]@{ name = 'app-x86.exe'; size = 70; digest = $null; browser_download_url = 'https://example.com/v4-x86.exe' }
                    )
                },
                [PSCustomObject]@{
                    tag_name     = 'v3.0.5'
                    name         = 'Release 3.0.5'
                    html_url     = 'https://github.com/owner/repo/releases/tag/v3.0.5'
                    prerelease   = $false
                    published_at = '2023-01-15T00:00:00Z'
                    assets       = @(
                        [PSCustomObject]@{ name = 'app-x64.exe'; size = 60; digest = $null; browser_download_url = 'https://example.com/v3-x64.exe' }
                    )
                },
                [PSCustomObject]@{
                    tag_name     = 'nightly-2025-01-01'
                    name         = 'Nightly build'
                    html_url     = 'https://github.com/owner/repo/releases/tag/nightly-2025-01-01'
                    prerelease   = $true
                    published_at = '2025-01-01T00:00:00Z'
                    assets       = @()
                }
            )
        }

        It 'Extracts version from tag_name using VersionPattern' {
            $result = $script:releases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$'
            $result | Should -HaveCount 3
            $result[0].version | Should -Be ([version]'5.0.2')
            $result[1].version | Should -Be ([version]'4.0.1')
            $result[2].version | Should -Be ([version]'3.0.5')
        }

        It 'Skips releases that do not match VersionPattern' {
            $result = $script:releases | Resolve-GitHubReleases -VersionPattern 'v(5\.\d+\.\d+)$'
            $result | Should -HaveCount 1
            $result[0].version | Should -Be ([version]'5.0.2')
        }

        It 'Filters by MinimumVersion' {
            $result = $script:releases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -MinimumVersion '4.0.0'
            $result | Should -HaveCount 2
            $result[0].version | Should -Be ([version]'5.0.2')
            $result[1].version | Should -Be ([version]'4.0.1')
        }

        It 'Filters assets by AssetPattern' {
            $result = $script:releases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -AssetPattern '\.exe$'
            $result | Should -HaveCount 3
            # v5.0.2 should have 2 .exe assets (not the .tar.gz)
            $result[0].assets | Should -HaveCount 2
        }

        It 'Adds named capture groups as asset properties' {
            $result = $script:releases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -AssetPattern 'app-(?<arch>x64|x86)\.exe$'
            $result | Should -HaveCount 3
            foreach ($r in $result) {
                foreach ($a in $r.assets) {
                    $a.arch | Should -BeIn @('x64', 'x86')
                }
            }
        }

        It 'Transposes assets by named property' {
            $result = $script:releases | Resolve-GitHubReleases -VersionPattern 'v(5\.\d+\.\d+)$' -AssetPattern 'app-(?<arch>x64|x86)\.exe$' -TransposeProperty 'arch'
            $result | Should -HaveCount 1
            $result[0].assets.Keys | Should -Contain 'x64'
            $result[0].assets.Keys | Should -Contain 'x86'
            # Transposed property should be removed from assets
            $result[0].assets['x64'].PSObject.Properties.Name | Should -Not -Contain 'arch'
            $result[0].assets['x86'].PSObject.Properties.Name | Should -Not -Contain 'arch'
        }

        It 'Transposes by a non-arch property correctly' {
            # Build releases with a different named capture group
            $testReleases = @(
                [PSCustomObject]@{
                    tag_name     = 'v1.0.0'
                    name         = 'Test'
                    html_url     = 'https://example.com'
                    prerelease   = $false
                    published_at = '2025-01-01T00:00:00Z'
                    assets       = @(
                        [PSCustomObject]@{ name = 'pkg-linux.tar.gz'; size = 10; digest = $null; browser_download_url = 'https://example.com/linux.tar.gz' },
                        [PSCustomObject]@{ name = 'pkg-windows.zip'; size = 20; digest = $null; browser_download_url = 'https://example.com/windows.zip' }
                    )
                }
            )
            $result = $testReleases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -AssetPattern 'pkg-(?<platform>linux|windows)\.' -TransposeProperty 'platform'
            $result | Should -HaveCount 1
            $result[0].assets.Keys | Should -Contain 'linux'
            $result[0].assets.Keys | Should -Contain 'windows'
            $result[0].assets['linux'].PSObject.Properties.Name | Should -Not -Contain 'platform'
        }

        It 'Skips releases with no matching assets and warns' {
            $noMatchReleases = @(
                [PSCustomObject]@{
                    tag_name     = 'v1.0.0'
                    name         = 'Test'
                    html_url     = 'https://example.com'
                    prerelease   = $false
                    published_at = '2025-01-01T00:00:00Z'
                    assets       = @(
                        [PSCustomObject]@{ name = 'readme.txt'; size = 1; digest = $null; browser_download_url = 'https://example.com/readme.txt' }
                    )
                }
            )
            $result = $noMatchReleases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -AssetPattern '\.exe$' 3>&1
            # The function warns and skips — result should be empty or contain just the warning
            $warnings = $result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Handles 4-part versions' {
            $fourPartReleases = @(
                [PSCustomObject]@{
                    tag_name     = 'v2.0.1.5'
                    name         = 'Test'
                    html_url     = 'https://example.com'
                    prerelease   = $false
                    published_at = '2025-01-01T00:00:00Z'
                    assets       = @()
                }
            )
            $result = $fourPartReleases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+\.\d+)$'
            $result | Should -HaveCount 1
            $result[0].version | Should -Be ([version]'2.0.1.5')
        }

        It 'Returns all releases when no VersionPattern given' {
            $result = $script:releases | Resolve-GitHubReleases
            $result | Should -HaveCount 4
        }
    }
}
