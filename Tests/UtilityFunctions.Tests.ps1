Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Select-ObjectLike' {
    BeforeAll {
        $global:sample = @(
            [PSCustomObject]@{
                html_url = 'https://github.com/FirebirdSQL/firebird/releases/tag/v5.0.2'
                tag_name = 'v5.0.2'
                name = 'Firebird 5.0.2'
                prerelease = $false
                published_at = '2025-02-12T11:19:52Z'
                assets = @(
                    [PSCustomObject]@{
                        name = 'Firebird-5.0.2.1613-0-android-arm32-withDebugSymbols.tar.gz'
                        size = 64526011
                        digest = $null
                        browser_download_url = 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.2/Firebird-5.0.2.1613-0-android-arm32-withDebugSymbols.tar.gz'
                    },
                    [PSCustomObject]@{
                        name = 'Firebird-5.0.2.1613-0-android-arm32.tar.gz'
                        size = 23030688
                        digest = $null
                        browser_download_url = 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.2/Firebird-5.0.2.1613-0-android-arm32.tar.gz'
                    },
                    [PSCustomObject]@{
                        name = 'Firebird-5.0.2.1613-0-android-arm64-large.tar.gz'
                        size = 150000000
                        digest = $null
                        browser_download_url = 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.2/Firebird-5.0.2.1613-0-android-arm64-large.tar.gz'
                    }
                )
            },
            [PSCustomObject]@{
                html_url = 'https://github.com/FirebirdSQL/firebird/releases/tag/v4.0.5'
                tag_name = 'v4.0.5'
                name = 'Firebird 4.0.5'
                prerelease = $false
                published_at = '2024-08-08T14:09:32Z'
                assets = @(
                    [PSCustomObject]@{
                        name = 'Firebird-4.0.5.3140-0-Win32-pdb.exe'
                        size = 12345678
                        digest = $null
                        browser_download_url = 'https://github.com/FirebirdSQL/firebird/releases/download/v4.0.5/Firebird-4.0.5.3140-0-Win32-pdb.exe'
                    }
                )
            },
            [PSCustomObject]@{
                html_url = 'https://github.com/FirebirdSQL/firebird/releases/tag/v3.0.12'
                tag_name = 'v3.0.12'
                name = 'Firebird 3.0.12'
                prerelease = $false
                published_at = '2024-08-08T14:20:47Z'
                assets = @()
            }
        )
    }

    InModuleScope 'ChocoForge' {
        It 'Filters by exact tag name' {
            $filter = @{ tag_name = 'v5.0.2' }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -Not -BeNullOrEmpty
            ($result.tag_name | Where-Object { $_ -ne 'v5.0.2' }) | Should -BeNullOrEmpty
        }

        It 'Filters by prerelease false' {
            $filter = @{ prerelease = $false }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -Not -BeNullOrEmpty
            ($result.prerelease | Where-Object { $_ -ne $false }) | Should -BeNullOrEmpty
        }

        It 'Filters by published_at greater than a date' {
            $filter = @{ published_at = @{ op = 'gt'; value = '2025-01-01' } }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -Not -BeNullOrEmpty
            ($result.published_at | Where-Object { [datetime]$_ -le [datetime]'2025-01-01' }) | Should -BeNullOrEmpty
        }

        It 'Filters by asset name (exact match)' {
            $filter = @{ assets = @{ name = 'Firebird-5.0.2.1613-0-android-arm32.tar.gz' } }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -Not -BeNullOrEmpty
            foreach ($r in $result) {
                ($r.assets | Where-Object { $_.name -eq 'Firebird-5.0.2.1613-0-android-arm32.tar.gz' }) | Should -Not -BeNullOrEmpty
            }
        }

        It 'Filters by asset size greater than 100MB' {
            # Filter releases with HAVE AT LEAST ONE asset larger than 100MB
            $filter = @{ assets = @{ size = @{ op = 'gt'; value = 100000000 } } }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -Not -BeNullOrEmpty
            foreach ($r in $result) {
                ($r.assets | Where-Object { $_.size -gt 100000000 }) | Should -Not -BeNullOrEmpty
            }
        }

        It 'Filters by regex on tag_name' {
            $filter = @{ tag_name = @{ op = 'match'; value = '^v5\.' } }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -Not -BeNullOrEmpty
            foreach ($r in $result) {
                $r.tag_name | Should -Match '^v5\.'
            }
            ($result.tag_name | Where-Object { $_ -notmatch '^v5\.' }) | Should -BeNullOrEmpty
        }

        It 'Returns nothing for non-matching filter' {
            $filter = @{ tag_name = 'nonexistent' }
            $result = Select-ObjectLike -InputObject $global:sample -Filter $filter
            $result | Should -BeNullOrEmpty
        }
    }
}
