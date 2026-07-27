Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Get-ForgePackage' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Expand-EnvironmentVariables { 'fake-api-key' }

            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/qemu-img-mocks/github-releases.json" -Raw | ConvertFrom-Json
            }

            Mock Invoke-Chocolatey {
                $mockFile = if ($PesterBoundParameters.Arguments[5].StartsWith('https://community.chocolatey.org/api/v2')) {
                    'chocolatey-packages.txt'
                } else {
                    'github-packages.txt'
                }
                [PSCustomObject]@{
                    ExitCode = 0
                    StdOut   = Get-Content "$PSScriptRoot/assets/qemu-img-mocks/$mockFile" -Raw
                    StdErr   = ''
                }
            }

            $script:configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
        }

        It 'Returns the resolved configuration object with -Passthru' {
            $config = Get-ForgePackage -Path $script:configPath -Passthru

            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'qemu-img'
            $config.versions | Should -HaveCount 3
            $config.configurationPath | Should -Match 'qemu-img\.forge\.yaml$'
        }

        It 'Writes a summary to the host when -Passthru is absent' {
            $output = (Get-ForgePackage -Path $script:configPath 6>&1 | Out-String)

            $output | Should -Match 'Package:'
            $output | Should -Match 'qemu-img'
            $output | Should -Match 'Sources:'
            $output | Should -Match 'Flavors:'
        }

        It 'Returns nothing to the pipeline when writing the summary' {
            # The summary goes to the information stream, not the output stream.
            $result = Get-ForgePackage -Path $script:configPath 6>$null
            $result | Should -BeNullOrEmpty
        }

        It 'Auto-discovers the configuration when given a directory' {
            $config = Get-ForgePackage -Path "$PSScriptRoot/assets/qemu-img-package" -Passthru
            $config.package | Should -Be 'qemu-img'
        }

        It 'Reports published and missing versions per source' {
            $config = Get-ForgePackage -Path $script:configPath -Passthru

            # chocolatey-packages.txt lists only 2.3.0 for the community feed.
            $config.sources.community.publishedVersions | Should -Contain ([version]'2.3.0')
            $config.sources.community.missingVersions | Should -HaveCount 2
        }

        It 'Surfaces a plain-text API key as a warning on the source' {
            Mock Expand-EnvironmentVariables { param($InputString) $InputString }

            $config = Get-ForgePackage -Path $script:configPath -Passthru
            $config.sources.community.warningMessage | Should -Match 'plain text'
        }
    }
}
