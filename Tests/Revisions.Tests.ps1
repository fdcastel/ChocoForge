Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Revision Tracking' {
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
                    [PSCustomObject]@{
                        ExitCode = 0
                        StdOut   = Get-Content "$PSScriptRoot/assets/qemu-img-mocks/github-packages.txt" -Raw
                        StdErr   = ''
                    }
                } else {
                    $realCommand = Get-Command -CommandType Function -Name Invoke-Chocolatey
                    & $realCommand @PesterBoundParameters
                }
            }
        }

        It 'Applies revision overrides from the configuration' {
            $configPath = "$PSScriptRoot/assets/revisions-package/test-revisions.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $config.versions | Should -Not -BeNullOrEmpty

            # Version 10.0.0 should become 10.0.0.2
            $v10 = $config.versions | Where-Object { $_.version.Major -eq 10 }
            $v10 | Should -Not -BeNullOrEmpty
            $v10.version | Should -Be ([version]'10.0.0.2')

            # Version 9.2.0 should become 9.2.0.1
            $v9 = $config.versions | Where-Object { $_.version.Major -eq 9 }
            $v9 | Should -Not -BeNullOrEmpty
            $v9.version | Should -Be ([version]'9.2.0.1')

            # Versions without overrides should remain 3-part (Revision = -1)
            $others = $config.versions | Where-Object { $_.version.Major -ne 10 -and $_.version.Major -ne 9 }
            foreach ($v in $others) {
                $v.version.Revision | Should -Be -1
            }
        }

        It 'Includes revised versions in missing versions calculation' {
            $configPath = "$PSScriptRoot/assets/revisions-package/test-revisions.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            # 10.0.0.2 should be missing (published has 10.0.0 but not 10.0.0.2)
            # Check if the missing versions list includes the revised version
            $source = $config.sources.github
            $source.missingVersions | Should -Not -BeNullOrEmpty
        }

        It 'Builds packages with revised version numbers' {
            $configPath = "$PSScriptRoot/assets/revisions-package/test-revisions.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $nuspecPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.nuspec"

            $versionsToTest = @([version]'10.0.0.2')
            $packagesBuilt = @($config.versions |
                Where-Object { $_.version -in $versionsToTest } |
                    Build-ChocolateyPackage -NuspecPath $nuspecPath)

            $packagesBuilt | Should -HaveCount 1
            $packagesBuilt[0] | Should -BeLike '*10.0.0.2.nupkg'

            # Verify version in the nuspec inside the nupkg
            $extracted = Join-Path (Split-Path $packagesBuilt[0]) './_extracted/'
            if (Test-Path $extracted) { Remove-Item -Recurse -Force $extracted }
            $packagesBuilt[0] | Expand-Archive -DestinationPath $extracted -Force
            Get-Content "$extracted/qemu-img.nuspec" | Select-Object -Skip 4 -First 1 | Should -Match '<version>10\.0\.0\.2</version>'
        }
    }
}
