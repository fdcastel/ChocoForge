Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Embedded Installer Support' {
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

        It 'Reads embed flag from configuration' {
            $configPath = "$PSScriptRoot/assets/embed-package/test-embed.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath

            $config.releases.embed | Should -Be $true
        }

        It 'Copies and renders legal folder contents' {
            $configPath = "$PSScriptRoot/assets/embed-package/test-embed.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            # Build WITHOUT embed (skip download) — just test that legal/ folder is rendered
            $nuspecPath = "$PSScriptRoot/assets/embed-package/test-embed.nuspec"
            $versionsToTest = @($config.versions | Select-Object -First 1)
            $versionsToTest | Should -Not -BeNullOrEmpty

            $packageBuilt = $versionsToTest | Build-ChocolateyPackage -NuspecPath $nuspecPath

            $packageBuilt | Should -Not -BeNullOrEmpty

            # Extract and verify VERIFICATION.txt was included and rendered
            $extractDir = Join-Path $env:TEMP 'chocoforge-embed-test'
            if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
            Expand-Archive -Path $packageBuilt -DestinationPath $extractDir -Force

            $verFile = Join-Path $extractDir 'legal/VERIFICATION.txt'
            Test-Path $verFile | Should -Be $true

            $verContent = Get-Content $verFile -Raw
            # Should have the download URL rendered (not template placeholder)
            $verContent | Should -Not -Match '\{\{assets\.browser_download_url\}\}'
            $verContent | Should -Match 'https://'

            # Clean up
            Remove-Item -Recurse -Force $extractDir
        }

        It 'Downloads assets into tools when -Embed is specified' {
            $configPath = "$PSScriptRoot/assets/embed-package/test-embed.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $nuspecPath = "$PSScriptRoot/assets/embed-package/test-embed.nuspec"
            $versionsToTest = @($config.versions | Select-Object -First 1)
            $versionsToTest | Should -Not -BeNullOrEmpty

            # Mock Invoke-WebRequest to avoid actual downloads
            Mock Invoke-WebRequest {
                # Create a dummy file at the OutFile path
                Set-Content -Path $OutFile -Value 'dummy-content'
            }

            $packageBuilt = $versionsToTest | Build-ChocolateyPackage -NuspecPath $nuspecPath -Embed

            $packageBuilt | Should -Not -BeNullOrEmpty

            # Verify that Invoke-WebRequest was called (download was attempted)
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly

            # Extract and check embedded file exists in tools/
            $extractDir = Join-Path $env:TEMP 'chocoforge-embed-test-dl'
            if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
            Expand-Archive -Path $packageBuilt -DestinationPath $extractDir -Force

            # There should be files in tools/ beyond the install script
            $toolsFiles = Get-ChildItem (Join-Path $extractDir 'tools') -File
            $toolsFiles.Count | Should -BeGreaterThan 1

            # .zip assets should NOT have .ignore files
            $ignoreFiles = Get-ChildItem (Join-Path $extractDir 'tools') -Filter '*.ignore' -File
            $ignoreFiles.Count | Should -Be 0

            Remove-Item -Recurse -Force $extractDir
        }

        It 'Creates .ignore files for embedded .exe assets to prevent shimming' {
            $configPath = "$PSScriptRoot/assets/embed-package/test-embed.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $nuspecPath = "$PSScriptRoot/assets/embed-package/test-embed.nuspec"

            # Take the first version's context and override assets with .exe URLs
            $ctx = $config.versions | Select-Object -First 1
            $ctx | Add-Member -NotePropertyName 'assets' -NotePropertyValue @{
                x64   = [PSCustomObject]@{ browser_download_url = 'https://example.com/Installer_x64.exe'; sha256 = 'abc123' }
                Win32 = [PSCustomObject]@{ browser_download_url = 'https://example.com/Installer_Win32.exe'; sha256 = 'def456' }
            } -Force

            # Mock Invoke-WebRequest to create dummy .exe files
            Mock Invoke-WebRequest {
                Set-Content -Path $OutFile -Value 'dummy-exe-content'
            }

            $packageBuilt = $ctx | Build-ChocolateyPackage -NuspecPath $nuspecPath -Embed

            $packageBuilt | Should -Not -BeNullOrEmpty

            # Extract the package
            $extractDir = Join-Path $env:TEMP 'chocoforge-embed-test-ignore'
            if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
            Expand-Archive -Path $packageBuilt -DestinationPath $extractDir -Force

            $toolsDir = Join-Path $extractDir 'tools'

            # Both .exe files should exist
            Test-Path (Join-Path $toolsDir 'Installer_x64.exe') | Should -Be $true
            Test-Path (Join-Path $toolsDir 'Installer_Win32.exe') | Should -Be $true

            # Both .ignore files should exist
            Test-Path (Join-Path $toolsDir 'Installer_x64.exe.ignore') | Should -Be $true
            Test-Path (Join-Path $toolsDir 'Installer_Win32.exe.ignore') | Should -Be $true

            # No .ignore file for non-.exe files (e.g., the install script)
            Test-Path (Join-Path $toolsDir 'chocolateyInstall.ps1.ignore') | Should -Be $false

            Remove-Item -Recurse -Force $extractDir
        }
    }
}
