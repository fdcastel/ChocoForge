Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Configuration-qemu-img' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Expand-EnvironmentVariables {
                'fake-api-key'
            }

            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/qemu-img-mocks/github-releases.json" -Raw | ConvertFrom-Json
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
                        StdOut   = Get-Content "$PSScriptRoot/assets/qemu-img-mocks/$mockFile" -Raw
                        StdErr   = ''
                    }
                } else {
                    # Call real Invoke-Chocolatey with bound parameters
                    $realCommand = Get-Command -CommandType Function -Name Invoke-Chocolatey
                    & $realCommand @PesterBoundParameters
                }
            }
        }

        It 'Builds a Chocolatey package (qemu-img)' {
            $configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $nuspecPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.nuspec"

            $packagesBuilt = $config.versions | 
                Build-ChocolateyPackage -NuspecPath $nuspecPath | 
                    ForEach-Object { 
                        $extracted = Join-Path (Split-Path $_) './_extracted/'
                        if (Test-Path $extracted) {
                            Remove-Item -Recurse -Force $extracted
                        }

                        # Check substitutions in the nupkg
                        $_ | Expand-Archive -DestinationPath $extracted -Force

                        $_, $version = ([System.IO.Path]::GetFileNameWithoutExtension($_)).Split('.', 2)
                        Get-Content "$extracted/qemu-img.nuspec" | Select-Object -Skip 4 -First 1 | Should -Match "<version>$version</version>"

                        return $_
                    }

            $packagesBuilt | Should -HaveCount 3

            Get-Content "$env:TEMP/chocoforge/qemu-img/10.0.0/_extracted/tools/chocolateyInstall.ps1" | Select-Object -Skip 8 -First 1 | Should -Match "Checksum64\s*=\s*'f4480d045ead1eda30d775f711e83dac9f36cfe2183f193e775145f86763dd84'"
            Get-Content "$env:TEMP/chocoforge/qemu-img/9.2.0/_extracted/tools/chocolateyInstall.ps1" | Select-Object -Skip 8 -First 1 | Should -Match "Checksum64\s*=\s*'6b961f22ae40760c32dcd13400364885244bc6a6ff301177eefd30b12cf64633'"
            Get-Content "$env:TEMP/chocoforge/qemu-img/2.3.0/_extracted/tools/chocolateyInstall.ps1" | Select-Object -Skip 8 -First 1 | Should -Match "Checksum64\s*=\s*'8dc1c69d9880919cdad8c09126a016262d4a9edf48b87a1ef587914fe4177909'"
        }
    }
}
