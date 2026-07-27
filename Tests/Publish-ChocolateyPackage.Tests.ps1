Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Publish-ChocolateyPackage' {
    InModuleScope 'ChocoForge' {
        BeforeAll {
            $script:tempDir = Join-Path $env:TEMP 'chocoforge-test-publish'
            if (Test-Path $script:tempDir) { Remove-Item -Recurse -Force $script:tempDir }
            New-Item -ItemType Directory -Path $script:tempDir | Out-Null
            $script:packagePath = Join-Path $script:tempDir 'mypackage.1.2.3.nupkg'
            Set-Content -Path $script:packagePath -Value 'not-a-real-nupkg'
        }

        AfterAll {
            if (Test-Path $script:tempDir) { Remove-Item -Recurse -Force $script:tempDir }
        }

        It 'Names the package when an ordinary (non-409) push fails' {
            Mock Invoke-Chocolatey {
                [PSCustomObject]@{ ExitCode = 1; StdOut = '500 Internal Server Error'; StdErr = '' }
            }

            { Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl 'https://nuget.pkg.github.com/owner/index.json' -ApiKey 'k' } |
                Should -Throw '*mypackage*'
        }

        It 'Includes the underlying choco output in the failure message' {
            Mock Invoke-Chocolatey {
                [PSCustomObject]@{ ExitCode = 1; StdOut = '500 Internal Server Error'; StdErr = '' }
            }

            { Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl 'https://nuget.pkg.github.com/owner/index.json' -ApiKey 'k' } |
                Should -Throw '*500 Internal Server Error*'
        }

        It 'Returns the package path on success' {
            Mock Invoke-Chocolatey {
                [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            }

            $result = Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl 'https://nuget.pkg.github.com/owner/index.json' -ApiKey 'k'
            $result | Should -Be $script:packagePath
        }

        It 'Rewrites the community repository URL to the push endpoint' {
            Mock Invoke-Chocolatey {
                [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            }

            $null = Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl 'https://community.chocolatey.org/api/v2' -ApiKey 'k'

            Should -Invoke Invoke-Chocolatey -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'https://push.chocolatey.org'
            }
        }

        It 'Throws when the package file does not exist' {
            { Publish-ChocolateyPackage -Path (Join-Path $script:tempDir 'missing.nupkg') -SourceUrl 'https://x' } |
                Should -Throw '*not found*'
        }

        It 'Returns the path without pushing under -WhatIf' {
            Mock Invoke-Chocolatey { [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }

            $result = Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl 'https://x' -WhatIf
            $result | Should -Be $script:packagePath
            Should -Invoke Invoke-Chocolatey -Times 0 -Exactly
        }
    }
}

Describe 'Publish-ChocolateyPackage (-Force after a 409 conflict)' {
    InModuleScope 'ChocoForge' {
        BeforeAll {
            $script:tempDir = Join-Path $env:TEMP 'chocoforge-test-publish-force'
            if (Test-Path $script:tempDir) { Remove-Item -Recurse -Force $script:tempDir }
            New-Item -ItemType Directory -Path $script:tempDir | Out-Null
            $script:packagePath = Join-Path $script:tempDir 'mypackage.1.2.3.nupkg'
            Set-Content -Path $script:packagePath -Value 'not-a-real-nupkg'
            $script:githubUrl = 'https://nuget.pkg.github.com/fdcastel/index.json'
        }

        AfterAll {
            if (Test-Path $script:tempDir) { Remove-Item -Recurse -Force $script:tempDir }
        }

        BeforeEach {
            # First push conflicts, the retry after deletion succeeds.
            $script:pushCount = 0
            Mock Invoke-Chocolatey {
                $script:pushCount++
                if ($script:pushCount -eq 1) {
                    [PSCustomObject]@{ ExitCode = 1; StdOut = 'Response status code does not indicate success: 409 (Conflict).'; StdErr = '' }
                } else {
                    [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                }
            }
            Mock Invoke-RestMethod {
                if ($Method -eq 'Delete') { return $null }
                @(
                    [PSCustomObject]@{ id = 111; name = '1.2.2' },
                    [PSCustomObject]@{ id = 222; name = '1.2.3' }
                )
            }
        }

        It 'Deletes the conflicting version and retries the push' {
            $result = Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl $script:githubUrl -ApiKey 'k' -Force

            $result | Should -Be $script:packagePath
            Should -Invoke Invoke-Chocolatey -Times 2 -Exactly          # original push + retry
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Method -eq 'Delete' }
        }

        It 'Targets the version id matching the package file name' {
            # Version '1.2.3' is parsed from the file name, so id 222 must be the one deleted.
            $null = Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl $script:githubUrl -ApiKey 'k' -Force

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Delete' -and $Uri -like '*/222'
            }
        }

        It 'Builds the versions URL from the package name and repository owner' {
            $null = Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl $script:githubUrl -ApiKey 'k' -Force

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq 'https://api.github.com/users/fdcastel/packages/nuget/mypackage/versions'
            }
        }

        It 'Throws when the conflicting version is not present in the feed' {
            Mock Invoke-RestMethod { @([PSCustomObject]@{ id = 111; name = '9.9.9' }) }

            { Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl $script:githubUrl -ApiKey 'k' -Force } |
                Should -Throw "*Version '1.2.3' not found for package 'mypackage'*"
        }

        It 'Names the package when the retry also fails' {
            Mock Invoke-Chocolatey {
                $script:pushCount++
                if ($script:pushCount -eq 1) {
                    [PSCustomObject]@{ ExitCode = 1; StdOut = '409 (Conflict)'; StdErr = '' }
                } else {
                    [PSCustomObject]@{ ExitCode = 1; StdOut = 'still broken'; StdErr = '' }
                }
            }

            { Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl $script:githubUrl -ApiKey 'k' -Force } |
                Should -Throw '*mypackage after force*'
        }

        It 'Refuses to force-push to a non-GitHub source' {
            { Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl 'https://gitlab.com/api/v4/projects/1/packages/nuget/index.json' -ApiKey 'k' -Force } |
                Should -Throw '*Force push not supported*'
        }

        It 'Does not attempt a forced delete when -Force is absent' {
            { Publish-ChocolateyPackage -Path $script:packagePath -SourceUrl $script:githubUrl -ApiKey 'k' } |
                Should -Throw '*mypackage*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }
}
