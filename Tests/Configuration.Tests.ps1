Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Configuration tests' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/github-releases.json" -Raw | ConvertFrom-Json
            }
            Mock Invoke-Chocolatey {
                Write-Warning $PesterBoundParameters 
                $mockFile = if ($PesterBoundParameters.Arguments[5].StartsWith('https://community.chocolatey.org/api/v2/')) {
                    "chocolatey-packages.txt"
                } else {
                    "github-packages.txt"
                }
                [PSCustomObject]@{
                    ExitCode = 0
                    StdOut   = Get-Content "$PSScriptRoot/assets/$mockFile" -Raw
                    StdErr   = ''
                }
            }
        }

        It 'Loads and validates the firebird sample configuration without error' {
            $config = Read-ForgeConfiguration -Path "$PSScriptRoot/assets/firebird.forge.yaml" -Verbose
            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'firebird'
            $config.releases.source | Should -Match '^https://github.com/FirebirdSQL/firebird'
            $config.releases.flavors.Keys | Should -Contain 'current'
            $config.targets.Keys | Should -Contain 'community'
            $config.replacements | Should -Not -BeNullOrEmpty
        }

        It 'Enriches the firebird configuration with assets and targets' {
            $config = Read-ForgeConfiguration -Path "$PSScriptRoot/assets/firebird.forge.yaml"
            $result = Resolve-ForgeConfiguration -Configuration $config

            $result.assets | Should -Not -BeNullOrEmpty
            $result.assets.Length | Should -Be 14

            $result.targets | Should -Not -BeNullOrEmpty
            $result.targets.Keys.Count | Should -Be 2

            $result.targets.community.missingVersions.Length | Should -Be 7
            $result.targets.community.publishedVersions.Length | Should -Be 7

            $result.targets.github.publishedVersions.Length | Should -Be 6
            $result.targets.github.missingVersions.Length | Should -Be 8
        }
    }
}
