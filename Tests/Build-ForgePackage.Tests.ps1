Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Build-ForgePackage' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Expand-EnvironmentVariables { 'fake-api-key' }

            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/qemu-img-mocks/github-releases.json" -Raw | ConvertFrom-Json
            }

            Mock Invoke-Chocolatey {
                if ($PesterBoundParameters.Arguments[0] -eq 'search') {
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
                    $realCommand = Get-Command -CommandType Function -Name Invoke-Chocolatey
                    & $realCommand @PesterBoundParameters
                }
            }

            $script:configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
        }

        Context 'delegation and version selection' {
            BeforeEach {
                # Build-ChocolateyPackage is covered by its own tests; here we assert what
                # Build-ForgePackage hands to it.
                # Return a marker path rather than packing for real; separator-agnostic so the
                # assertions below do not depend on Join-Path's platform separator.
                Mock Build-ChocolateyPackage {
                    $version = $Context.version.ToString()
                    "OUT:qemu-img.$version.nupkg"
                }
            }

            It 'Builds the requested version and returns its package path' {
                $result = Build-ForgePackage -Path $script:configPath -Version '10.0.0'
                $result | Should -Be 'OUT:qemu-img.10.0.0.nupkg'
                Should -Invoke Build-ChocolateyPackage -Times 1 -Exactly
            }

            It 'Builds every requested version' {
                $result = @(Build-ForgePackage -Path $script:configPath -Version '10.0.0', '9.2.0')
                $result | Should -HaveCount 2
                Should -Invoke Build-ChocolateyPackage -Times 2 -Exactly
            }

            It 'Throws when a requested version is not in the configuration' {
                { Build-ForgePackage -Path $script:configPath -Version '99.0.0' } |
                    Should -Throw "*'99.0.0' is not available*"
            }

            It 'Validates every version before building any of them' {
                # 10.0.0 is valid, 99.0.0 is not: nothing should be built.
                { Build-ForgePackage -Path $script:configPath -Version '10.0.0', '99.0.0' } | Should -Throw
                Should -Invoke Build-ChocolateyPackage -Times 0 -Exactly
            }

            It 'Applies -RevisionNumber as the fourth version segment' {
                $result = Build-ForgePackage -Path $script:configPath -Version '10.0.0' -RevisionNumber 5
                $result | Should -Be 'OUT:qemu-img.10.0.0.5.nupkg'
            }

            It 'Leaves the version three-part when no revision is given' {
                $result = Build-ForgePackage -Path $script:configPath -Version '10.0.0'
                $result | Should -Be 'OUT:qemu-img.10.0.0.nupkg'
            }

            It 'Derives the nuspec path from the configuration file it actually read' {
                $null = Build-ForgePackage -Path $script:configPath -Version '10.0.0'
                Should -Invoke Build-ChocolateyPackage -Times 1 -Exactly -ParameterFilter {
                    $NuspecPath -like '*qemu-img.nuspec'
                }
            }

            It 'Auto-discovers the configuration when given a directory' {
                $result = Build-ForgePackage -Path "$PSScriptRoot/assets/qemu-img-package" -Version '10.0.0'
                $result | Should -Be 'OUT:qemu-img.10.0.0.nupkg'
            }

            It 'Does not request embedding when the configuration omits it' {
                $null = Build-ForgePackage -Path $script:configPath -Version '10.0.0'
                Should -Invoke Build-ChocolateyPackage -Times 1 -Exactly -ParameterFilter {
                    -not $Embed
                }
            }

            It 'Requests embedding when the configuration sets releases.embed' {
                $null = Build-ForgePackage -Path "$PSScriptRoot/assets/embed-package/test-embed.forge.yaml" -Version '10.0.0'
                Should -Invoke Build-ChocolateyPackage -Times 1 -Exactly -ParameterFilter {
                    $Embed.IsPresent
                }
            }
        }

        Context 'WhatIf' {
            It 'Does not run choco pack' {
                $null = Build-ForgePackage -Path $script:configPath -Version '10.0.0' -WhatIf
                Should -Invoke Invoke-Chocolatey -Times 0 -Exactly -ParameterFilter {
                    $Arguments[0] -eq 'pack'
                }
            }
        }

        Context 'end to end (real choco pack)' {
            It 'Produces a .nupkg on disk for the requested version' {
                $result = Build-ForgePackage -Path $script:configPath -Version '9.2.0'

                $result | Should -BeLike '*qemu-img.9.2.0.nupkg'
                Test-Path $result | Should -BeTrue
            }
        }
    }
}
