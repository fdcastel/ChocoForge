Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Configuration' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/github-releases.json" -Raw | ConvertFrom-Json
            }
            Mock Invoke-Chocolatey {
                if ($PesterBoundParameters.Arguments[0] -eq 'search') {
                    # mock choco search
                    $mockFile = if ($PesterBoundParameters.Arguments[5].StartsWith('https://community.chocolatey.org/api/v2')) {
                        'chocolatey-packages.txt'
                    } else {
                        'github-packages.txt'
                    }
                    [PSCustomObject]@{
                        ExitCode = 0
                        StdOut   = Get-Content "$PSScriptRoot/assets/$mockFile" -Raw
                        StdErr   = ''
                    }
                } else {
                    # Call real Invoke-Chocolatey with bound parameters
                    $realCommand = Get-Command -CommandType Function -Name Invoke-Chocolatey
                    & $realCommand @PesterBoundParameters
                }
            }
        }

        It 'Loads and validates the firebird sample configuration without error' {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath

            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'firebird'
            $config.releases.source | Should -Match '^https://github.com/FirebirdSQL/firebird'
            $config.releases.flavors.Keys | Should -Contain 'current'
            $config.targets.Keys | Should -Contain 'community'
        }

        It 'Enriches the firebird configuration with assets and targets' {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $config.versions | Should -Not -BeNullOrEmpty
            $config.versions.Length | Should -Be 12  # Minimum version should filter out 3.0.8 and 3.0.9

            $config.targets | Should -Not -BeNullOrEmpty
            $config.targets.Keys.Count | Should -Be 2

            $expectedCommunityVersions = Get-Content "$PSScriptRoot/assets/chocolatey-packages.txt" |
                ForEach-Object { [version]($_.Split('|')[1]) }
            $config.targets.community.publishedVersions | Should -Be $expectedCommunityVersions
            $config.targets.community.missingVersions.Length | Should -Be 6

            $expectedGitHubVersions = Get-Content "$PSScriptRoot/assets/github-packages.txt" |
                ForEach-Object { [version]($_.Split('|')[1]) }
            $config.targets.github.publishedVersions | Should -Be $expectedGitHubVersions
            $config.targets.github.missingVersions.Length | Should -Be 7
        }

        It 'Creates a Chocolatey package from a nuspec and context' {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $versionsToTest = @('5.0.1', '3.0.10')

            $nuspecPath = "$PSScriptRoot/assets/firebird-package/firebird.nuspec"

            $packagesBuilt = $config.versions | 
                Where-Object { $_.version -in $versionsToTest } |
                    Build-ChocolateyPackage -NuspecPath $nuspecPath | 
                        ForEach-Object { 
                            $extracted = Join-Path (Split-Path $_) './_extracted/'
                            if (Test-Path $extracted) {
                                Remove-Item -Recurse -Force $extracted
                            }

                            # Check substitutions in the nupkg
                            $_ | Expand-Archive -DestinationPath $extracted -Force

                            $_, $version = ([System.IO.Path]::GetFileNameWithoutExtension($_)).Split('.', 2)
                            Get-Content "$extracted/firebird.nuspec" | Select-Object -Skip 4 -First 1 | Should -Match "<version>$version</version>"
                            Get-Content "$extracted/tools/chocolateyinstall.ps1" | Select-Object -Skip 6 -First 1 | Should -Match "version = '$version'"

                            return $_
                        }

            $packagesBuilt.Count | Should -Be 2
        }
    }
}
