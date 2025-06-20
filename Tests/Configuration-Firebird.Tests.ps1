Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Configuration-Firebird' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Expand-EnvironmentVariables {
                'fake-api-key'
            }

            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/firebird-mocks/github-releases.json" -Raw | ConvertFrom-Json
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
                        StdOut   = Get-Content "$PSScriptRoot/assets/firebird-mocks/$mockFile" -Raw
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
            $config.sources.Keys | Should -Contain 'community'
        }

        It 'Enriches the firebird configuration with assets and sources' {
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $config.versions | Should -Not -BeNullOrEmpty
            $config.versions | Should -HaveCount 12  # Minimum version should filter out 3.0.8 and 3.0.9
            $config.versions | Where-Object { $_.flavor -eq 'v4' } | Should -HaveCount 6

            $config.sources | Should -Not -BeNullOrEmpty
            $config.sources.Keys | Should -HaveCount 3

            $expectedCommunityVersions = Get-Content "$PSScriptRoot/assets/firebird-mocks/chocolatey-packages.txt" |
                ForEach-Object { [version]($_.Split('|')[1]) }
            $config.sources.community.publishedVersions | Should -Be $expectedCommunityVersions
            $config.sources.community.missingVersions | Should -HaveCount 6

            $expectedGitHubVersions = Get-Content "$PSScriptRoot/assets/firebird-mocks/github-packages.txt" |
                ForEach-Object { [version]($_.Split('|')[1]) }
            $config.sources.github.publishedVersions | Should -Be $expectedGitHubVersions
            $config.sources.github.missingVersions | Should -HaveCount 7
        }

        It 'Builds a Chocolatey package with multiple architectures (firebird)' {
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

            $packagesBuilt | Should -HaveCount 2

            Get-Content "$env:TEMP/chocoforge/firebird/5.0.1/_extracted/tools/chocolateyInstall.ps1" | Select-Object -Skip 9 -First 1 | Should -Match "checksum64 = 'dba458a95de9c3a3b297d98601a10dcda95b63bfaee6f72ec4931d6c740bccde'"
            Get-Content "$env:TEMP/chocoforge/firebird/3.0.10/_extracted/tools/chocolateyInstall.ps1" | Select-Object -Skip 10 -First 1 | Should -Match "checksum32 = 'd4c220bbad1eac9d7578979582a2142ae31778126d300cfcd2b91399238fdaf6'"
        }
    }
}