Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Write-ForgeConfiguration' {
    InModuleScope 'ChocoForge' {
        BeforeAll {
            function New-TestConfiguration {
                param($PublishedVersions, $MissingVersions, $SkipReason)
                $source = [ordered]@{ url = 'https://example.com/api/v2' }
                $source | Add-Member -MemberType NoteProperty -Name 'publishedVersions' -Value $PublishedVersions -Force
                $source | Add-Member -MemberType NoteProperty -Name 'missingVersions' -Value $MissingVersions -Force
                $source | Add-Member -MemberType NoteProperty -Name 'skipReason' -Value $SkipReason -Force

                [PSCustomObject]@{
                    package  = 'testpkg'
                    versions = @([PSCustomObject]@{ version = [version]'1.0.0'; flavor = 'current' })
                    sources  = [ordered]@{ mysource = $source }
                    releases = [ordered]@{ flavors = [ordered]@{ current = [ordered]@{} } }
                }
            }
        }

        It 'Reports a source whose versions could not be queried as unknown, not as published' {
            # $null publishedVersions means "never queried" - distinct from @() meaning "queried, nothing there".
            $config = New-TestConfiguration -PublishedVersions $null -MissingVersions @() -SkipReason 'Environment variable APIKEY_X not set.'
            $output = ($config | Write-ForgeConfiguration 6>&1 | Out-String)

            $output | Should -Not -Match 'All versions published'
            $output | Should -Match 'unknown'
        }

        It 'Reports a genuinely fully-published source as published' {
            $config = New-TestConfiguration -PublishedVersions @([version]'1.0.0') -MissingVersions @() -SkipReason $null
            $output = ($config | Write-ForgeConfiguration 6>&1 | Out-String)

            $output | Should -Match 'All versions published'
        }

        It 'Reports a queried but empty source as not published' {
            $config = New-TestConfiguration -PublishedVersions @() -MissingVersions @([version]'1.0.0') -SkipReason $null
            $output = ($config | Write-ForgeConfiguration 6>&1 | Out-String)

            $output | Should -Match 'Not published on this source'
            $output | Should -Not -Match 'All versions published'
        }

        It 'Shows the skip reason when one is present' {
            $config = New-TestConfiguration -PublishedVersions $null -MissingVersions @() -SkipReason 'No API key in the configuration file'
            $output = ($config | Write-ForgeConfiguration 6>&1 | Out-String)

            $output | Should -Match 'No API key in the configuration file'
        }
    }
}
