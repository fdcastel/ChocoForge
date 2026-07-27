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

        It 'Copies binary files in tools/ through the build byte-for-byte' {
            # Template expansion is a text round-trip; binaries must bypass it entirely.
            $srcDir = Join-Path $env:TEMP 'chocoforge-binary-test-src'
            if (Test-Path $srcDir) { Remove-Item -Recurse -Force $srcDir }
            New-Item -ItemType Directory -Path (Join-Path $srcDir 'tools') -Force | Out-Null

            Copy-Item "$PSScriptRoot/assets/embed-package/test-embed.nuspec" (Join-Path $srcDir 'test-embed.nuspec')
            Copy-Item "$PSScriptRoot/assets/embed-package/tools/chocolateyInstall.ps1" (Join-Path $srcDir 'tools/chocolateyInstall.ps1')
            # The nuspec declares a legal\** file entry, so the folder has to be present.
            Copy-Item "$PSScriptRoot/assets/embed-package/legal" (Join-Path $srcDir 'legal') -Recurse

            # Bytes that are not valid UTF-8; a text round-trip turns each into U+FFFD.
            $binaryPath = Join-Path $srcDir 'tools/payload.bin'
            $originalBytes = [byte[]]@(0x4D, 0x5A, 0x90, 0x00, 0xFF, 0xFE, 0x00, 0x01, 0x80, 0xC3, 0xA9)
            [System.IO.File]::WriteAllBytes($binaryPath, $originalBytes)
            $originalHash = (Get-FileHash -Path $binaryPath -Algorithm SHA256).Hash

            $ctx = [PSCustomObject]@{ version = [version]'1.0.0' }
            $packageBuilt = $ctx | Build-ChocolateyPackage -NuspecPath (Join-Path $srcDir 'test-embed.nuspec')
            $packageBuilt | Should -Not -BeNullOrEmpty

            # List what the .nupkg really holds, so a packaging change reports the contents
            # rather than a bare "expected True".
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::OpenRead($packageBuilt)
            try {
                $entries = @($archive.Entries | ForEach-Object { $_.FullName })
            } finally {
                $archive.Dispose()
            }

            $extractDir = Join-Path $env:TEMP 'chocoforge-binary-test-out'
            if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
            Expand-Archive -Path $packageBuilt -DestinationPath $extractDir -Force

            $extractedBinary = Join-Path $extractDir 'tools/payload.bin'
            Test-Path $extractedBinary | Should -BeTrue -Because "the package should contain tools/payload.bin; it holds: $($entries -join ', ')"
            (Get-FileHash -Path $extractedBinary -Algorithm SHA256).Hash | Should -Be $originalHash
            [System.IO.File]::ReadAllBytes($extractedBinary).Count | Should -Be $originalBytes.Count

            Remove-Item -Recurse -Force $srcDir, $extractDir
        }

        It 'Places files correctly when the source path is an 8.3 short name' {
            # Get-ChildItem reports canonical paths. If the relative path were computed by
            # character offset against a caller-supplied short path, entries would land under a
            # truncated folder name (tools/ols/...), which is what $env:TEMP does on CI runners.
            $srcDir = Join-Path $env:TEMP 'ChocoForge ShortName Test'
            if (Test-Path -LiteralPath $srcDir) { Remove-Item -LiteralPath $srcDir -Recurse -Force }
            New-Item -ItemType Directory -Path (Join-Path $srcDir 'tools') -Force | Out-Null

            Copy-Item "$PSScriptRoot/assets/embed-package/test-embed.nuspec" (Join-Path $srcDir 'test-embed.nuspec')
            Copy-Item "$PSScriptRoot/assets/embed-package/tools/chocolateyInstall.ps1" (Join-Path $srcDir 'tools/chocolateyInstall.ps1')
            Copy-Item "$PSScriptRoot/assets/embed-package/legal" (Join-Path $srcDir 'legal') -Recurse

            # Address the same directory through its 8.3 alias.
            $fso = New-Object -ComObject Scripting.FileSystemObject
            $shortDir = $fso.GetFolder($srcDir).ShortPath
            $shortDir | Should -Not -Be $srcDir -Because 'the probe needs a genuinely different path form'

            $ctx = [PSCustomObject]@{ version = [version]'1.0.0' }
            $packageBuilt = $ctx | Build-ChocolateyPackage -NuspecPath (Join-Path $shortDir 'test-embed.nuspec')

            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::OpenRead($packageBuilt)
            try {
                $entries = @($archive.Entries | ForEach-Object { $_.FullName })
            } finally {
                $archive.Dispose()
            }

            $entries | Should -Contain 'tools/chocolateyInstall.ps1' -Because "entries were: $($entries -join ', ')"
            $entries | Should -Contain 'legal/VERIFICATION.txt' -Because "entries were: $($entries -join ', ')"

            Remove-Item -LiteralPath $srcDir -Recurse -Force
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
