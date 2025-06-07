Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Configuration tests' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/github-releases.json" -Raw | ConvertFrom-Json
            }
            Mock Invoke-Chocolatey {
                if ($PesterBoundParameters.Arguments[0] -eq 'search') {
                    # mock choco search
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
                } else {
                    # Call real Invoke-Chocolatey with bound parameters
                    $realCommand = Get-Command -CommandType Function -Name Invoke-Chocolatey
                    & $realCommand @PesterBoundParameters
                }
            }
        }

        It 'Loads and validates the firebird sample configuration without error' {
            $config = Read-ForgeConfiguration -Path "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml" -Verbose
            $config | Should -Not -BeNullOrEmpty
            $config.package | Should -Be 'firebird'
            $config.releases.source | Should -Match '^https://github.com/FirebirdSQL/firebird'
            $config.releases.flavors.Keys | Should -Contain 'current'
            $config.targets.Keys | Should -Contain 'community'
        }

        It 'Enriches the firebird configuration with assets and targets' {
            $config = Read-ForgeConfiguration -Path "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"
            $result = Resolve-ForgeConfiguration -Configuration $config

            $result.versions | Should -Not -BeNullOrEmpty
            $result.versions.Length | Should -Be 12  # Minimum version should filter out 3.0.8 and 3.0.9

            $result.targets | Should -Not -BeNullOrEmpty
            $result.targets.Keys.Count | Should -Be 2

            $result.targets.community.missingVersions.Length | Should -Be 6
            $result.targets.community.publishedVersions.Length | Should -Be 7

            $result.targets.github.missingVersions.Length | Should -Be 7
            $result.targets.github.publishedVersions.Length | Should -Be 6

            $result | ConvertTo-Json -Depth 20 > /temp/ttt.json
        }

        It 'Creates a Chocolatey package from a nuspec and context' {
            $versionsToTest = @('5.0.1', '3.0.10')

            $nuspecPath = "$PSScriptRoot/assets/firebird-package/firebird.nuspec"
            $configPath = "$PSScriptRoot/assets/firebird-package/firebird.forge.yaml"

            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration
            $context = $config.versions | Where-Object { $_.version -in $versionsToTest }

            $result = New-ChocolateyPackage -NuspecPath $nuspecPath -Context $context

            foreach ($version in $versionsToTest) {
                $extracted = "$env:TEMP/chocoforge/firebird/$version/_extracted"
                if (Test-Path $extracted) {
                    Remove-Item -Recurse -Force $extracted
                }

                # Check substitutions in the nupkg
                $nupkg = "$env:TEMP/chocoforge/firebird/$version/firebird.$version.nupkg"
                Expand-Archive -Path $nupkg -DestinationPath $extracted -Force
                Get-Content "$extracted/firebird.nuspec" | Select-Object -Skip 4 -First 1 | Should -Match "<version>$version</version>"
                Get-Content "$extracted/tools/chocolateyinstall.ps1" | Select-Object -Skip 6 -First 1 | Should -Match "version = '$version'"

                $result | Where-Object { $_ -match "firebird.$version.nupkg" } | Should -Not -BeNullOrEmpty
            }
        }        
    }
}
