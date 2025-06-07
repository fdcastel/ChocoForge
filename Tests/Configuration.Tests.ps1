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
            $nuspecPath = "$PSScriptRoot/assets/firebird-package/firebird.nuspec"

            $context = @{
                package = 'firebird'
                version = [version]'5.0.1'
                tag_name = 'v5.0.1'
                html_url = 'https://github.com/FirebirdSQL/firebird/releases/tag/v5.0.1'
                prerelease = $false
                published_at = Get-Date '2024-08-02T06:10:11Z'
                assets = @{
                    x64 = @{
                        name = 'Firebird-5.0.1.1469-0-windows-x64.exe'
                        size = 26108905
                        digest = $null
                        browser_download_url = 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.1/Firebird-5.0.1.1469-0-windows-x64.exe'
                    }
                    x86 = @{
                        name = 'Firebird-5.0.1.1469-0-windows-x86.exe'
                        size = 15200752
                        digest = $null
                        browser_download_url = 'https://github.com/FirebirdSQL/firebird/releases/download/v5.0.1/Firebird-5.0.1.1469-0-windows-x86.exe'
                    }
                }
            }

            $result = New-ChocolateyPackage -NuspecPath $nuspecPath -Context $context
            $result | Should -Match 'Successfully created package'

            $nupkg = "$env:TEMP/chocoforge/firebird/firebird.5.0.1.nupkg"
            $extracted = "$env:TEMP/chocoforge/firebird/_extracted"
            if (Test-Path $extracted) {
                Remove-Item -Recurse -Force $extracted
            }

            # Check substitutions in the nupkg
            Expand-Archive -Path $nupkg -DestinationPath $extracted -Force
            Get-Content "$extracted/firebird.nuspec" | Select-Object -Skip 4 -First 1 | Should -Match '<version>5.0.1</version>'
            Get-Content "$extracted/tools/chocolateyinstall.ps1" | Select-Object -Skip 6 -First 1 | Should -Match "version = '5.0.1'"
        }        
    }
}
