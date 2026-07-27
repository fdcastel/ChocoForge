Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Sync-ForgePackage' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Invoke-RestMethod {
                Get-Content "$PSScriptRoot/assets/qemu-img-mocks/github-releases.json" -Raw | ConvertFrom-Json
            }

            # SAFETY: publishing is always mocked. A real push to community.chocolatey.org
            # cannot be undone, so no test in this file may reach the network.
            Mock Publish-ChocolateyPackage { $Path }

            # Build-ChocolateyPackage has its own coverage; return predictable paths so the
            # assertions here are about Sync's own build/publish/skip logic.
            Mock Build-ChocolateyPackage {
                $version = $Context.version.ToString()
                Join-Path 'C:/out' "qemu-img.$version.nupkg"
            }

            $script:configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
        }

        Context 'all sources usable' {
            BeforeEach {
                Mock Expand-EnvironmentVariables { 'fake-api-key' }
                Mock Invoke-Chocolatey {
                    if ($PesterBoundParameters.Arguments[0] -ne 'search') {
                        return [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                    }
                    if ($PesterBoundParameters.Arguments -contains '--version') {
                        # The moderation probe. Real choco returns a zero-length string when the
                        # version is not present, so nothing is in moderation here.
                        return [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                    }
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
            }

            It 'Builds only the versions that are missing somewhere' {
                # community has 2.3.0; github and gitlab have nothing. Union of missing = all 3.
                $null = Sync-ForgePackage -Path $script:configPath
                Should -Invoke Build-ChocolateyPackage -Times 3 -Exactly
            }

            It 'Publishes each missing version to each source that needs it' {
                $null = Sync-ForgePackage -Path $script:configPath
                # community already has 2.3.0 so needs 10.0.0 + 9.2.0; github and gitlab need all 3 each.
                Should -Invoke Publish-ChocolateyPackage -Times 8 -Exactly
                Should -Invoke Publish-ChocolateyPackage -Times 2 -Exactly -ParameterFilter {
                    $SourceUrl -like 'https://community.chocolatey.org*'
                }
            }

            It 'Does not publish a version a source already has' {
                $null = Sync-ForgePackage -Path $script:configPath
                Should -Invoke Publish-ChocolateyPackage -Times 0 -Exactly -ParameterFilter {
                    $SourceUrl -like 'https://community.chocolatey.org*' -and $Path -like '*2.3.0.nupkg'
                }
            }

            It 'Auto-discovers the configuration when given a directory' {
                { Sync-ForgePackage -Path "$PSScriptRoot/assets/qemu-img-package" } | Should -Not -Throw
                Should -Invoke Build-ChocolateyPackage -Times 3 -Exactly
            }

            It 'Derives the nuspec path from the configuration it actually read' {
                $null = Sync-ForgePackage -Path $script:configPath
                Should -Invoke Build-ChocolateyPackage -ParameterFilter { $NuspecPath -like '*qemu-img.nuspec' }
            }
        }

        Context 'Chocolatey community moderation' {
            BeforeEach {
                Mock Expand-EnvironmentVariables { 'fake-api-key' }
            }

            It 'Skips publishing when the exact version is already in moderation' {
                Mock Invoke-Chocolatey {
                    if ($PesterBoundParameters.Arguments[0] -ne 'search') {
                        return [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                    }
                    # The per-version moderation probe carries --version; report a hit for it.
                    if ($PesterBoundParameters.Arguments -contains '--version') {
                        return [PSCustomObject]@{ ExitCode = 0; StdOut = 'qemu-img|10.0.0'; StdErr = '' }
                    }
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

                $null = Sync-ForgePackage -Path $script:configPath

                # Nothing goes to the community feed; github and gitlab still receive all 3 each.
                Should -Invoke Publish-ChocolateyPackage -Times 0 -Exactly -ParameterFilter {
                    $SourceUrl -like 'https://community.chocolatey.org*'
                }
                Should -Invoke Publish-ChocolateyPackage -Times 6 -Exactly
            }

            It 'Throws when the moderation probe fails' {
                Mock Invoke-Chocolatey {
                    if ($PesterBoundParameters.Arguments[0] -ne 'search') {
                        return [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                    }
                    if ($PesterBoundParameters.Arguments -contains '--version') {
                        return [PSCustomObject]@{ ExitCode = 1; StdOut = 'network exploded'; StdErr = '' }
                    }
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

                { Sync-ForgePackage -Path $script:configPath } | Should -Throw '*choco search failed*'
            }
        }

        Context 'sources without credentials' {
            BeforeEach {
                # No tokens at all: every source acquires a skipReason.
                Mock Expand-EnvironmentVariables { $null }
                Mock Invoke-Chocolatey {
                    [PSCustomObject]@{
                        ExitCode = 0
                        StdOut   = Get-Content "$PSScriptRoot/assets/qemu-img-mocks/chocolatey-packages.txt" -Raw
                        StdErr   = ''
                    }
                }
            }

            It 'Publishes nothing' {
                $null = Sync-ForgePackage -Path $script:configPath
                Should -Invoke Publish-ChocolateyPackage -Times 0 -Exactly
            }

            It 'Reports the skipped sources' {
                $output = (Sync-ForgePackage -Path $script:configPath 6>&1 | Out-String)
                $output | Should -Match 'Skipped sources'
                $output | Should -Match 'github'
                $output | Should -Match 'gitlab'
            }

            It 'Completes without throwing' {
                { Sync-ForgePackage -Path $script:configPath } | Should -Not -Throw
            }
        }

        Context 'nothing to do' {
            BeforeEach {
                Mock Expand-EnvironmentVariables { 'fake-api-key' }
                # Every source reports all three versions as already published.
                Mock Invoke-Chocolatey {
                    [PSCustomObject]@{
                        ExitCode = 0
                        StdOut   = "qemu-img|10.0.0`nqemu-img|9.2.0`nqemu-img|2.3.0`n"
                        StdErr   = ''
                    }
                }
            }

            It 'Builds nothing and says so' {
                $output = (Sync-ForgePackage -Path $script:configPath 6>&1 | Out-String)

                Should -Invoke Build-ChocolateyPackage -Times 0 -Exactly
                Should -Invoke Publish-ChocolateyPackage -Times 0 -Exactly
                $output | Should -Match 'No versions to publish'
            }
        }
    }
}
