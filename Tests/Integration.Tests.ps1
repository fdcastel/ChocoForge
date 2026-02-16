Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Integration: GitHub API (read-only)' {
    InModuleScope 'ChocoForge' {
        BeforeDiscovery {
            $script:skipGitHub = -not $env:APIKEY_GITHUB
            if ($script:skipGitHub) {
                Write-Warning 'APIKEY_GITHUB not set. Skipping GitHub integration tests.'
            }
        }

        It 'Fetches real releases from GitHub' -Skip:$skipGitHub {
            $releases = Find-GitHubReleases -RepositoryOwner 'fdcastel' -RepositoryName 'qemu-img-windows-x64'
            $releases | Should -Not -BeNullOrEmpty
            $releases.Count | Should -BeGreaterThan 0
            $releases[0].tag_name | Should -Not -BeNullOrEmpty
        }

        It 'Resolves real releases with version pattern' -Skip:$skipGitHub {
            $releases = Find-GitHubReleases -RepositoryOwner 'fdcastel' -RepositoryName 'qemu-img-windows-x64'
            $expanded = $releases | Resolve-GitHubReleases -VersionPattern 'v(\d+\.\d+\.\d+)$' -AssetPattern '\.zip$'
            $expanded | Should -Not -BeNullOrEmpty
            foreach ($r in $expanded) {
                $r.version | Should -Not -BeNullOrEmpty
                $r.assets | Should -Not -BeNullOrEmpty
            }
        }

        It 'Reads and resolves real qemu-img configuration' -Skip:$skipGitHub {
            $configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            $config.versions | Should -Not -BeNullOrEmpty
            $config.versions.Count | Should -BeGreaterThan 0
            $config.sources.github.publishedVersions | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Integration: GitHub Packages (publish/delete cycle)' {
    InModuleScope 'ChocoForge' {
        BeforeDiscovery {
            $script:skipGitHub = -not $env:APIKEY_GITHUB
            if ($script:skipGitHub) {
                Write-Warning 'APIKEY_GITHUB not set. Skipping GitHub Packages integration tests.'
            }
        }

        It 'Builds, publishes, and cleans up a package on GitHub Packages' -Skip:$skipGitHub {
            $configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            # Pick the latest version
            $latestVersion = $config.versions | Select-Object -First 1
            $latestVersion | Should -Not -BeNullOrEmpty

            $nuspecPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.nuspec"
            $sourceUrl = $config.sources.github.url

            # Build the package
            $packagePath = $latestVersion | Build-ChocolateyPackage -NuspecPath $nuspecPath
            $packagePath | Should -Not -BeNullOrEmpty
            Test-Path $packagePath | Should -Be $true

            # Publish with -Force (in case it already exists)
            $published = Publish-ChocolateyPackage -Path $packagePath -SourceUrl $sourceUrl -ApiKey $env:APIKEY_GITHUB -Force
            $published | Should -Not -BeNullOrEmpty

            # Verify it's now published
            $publishedVersions = Find-ChocolateyPublishedVersions -PackageName 'qemu-img' -SourceUrl $sourceUrl -User 'fdcastel' -Password $env:APIKEY_GITHUB
            $publishedVersions | Should -Contain $latestVersion.version

            # Clean up: delete the version we just published
            $owner = 'fdcastel'
            $headers = @{ 'Authorization' = "Bearer $($env:APIKEY_GITHUB)" }
            $versionsUrl = "https://api.github.com/users/$owner/packages/nuget/qemu-img/versions"
            $response = Invoke-RestMethod -Uri $versionsUrl -Headers $headers -Verbose:$false
            $versionId = $response | Where-Object { $_.name -eq $latestVersion.version.ToString() } | Select-Object -ExpandProperty 'id'
            if ($versionId) {
                $null = Invoke-RestMethod -Uri "$versionsUrl/$versionId" -Headers $headers -Method Delete -Verbose:$false
                Write-VerboseMark "Cleaned up test package version $($latestVersion.version) from GitHub Packages."
            }
        }
    }
}

Describe 'Integration: GitLab Packages (publish/delete cycle)' {
    InModuleScope 'ChocoForge' {
        BeforeDiscovery {
            $script:skipGitLab = -not $env:APIKEY_GITLAB
            if ($script:skipGitLab) {
                Write-Warning 'APIKEY_GITLAB not set. Skipping GitLab Packages integration tests.'
            }
        }

        It 'Builds, publishes, and cleans up a package on GitLab' -Skip:$skipGitLab {
            $configPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $config = Read-ForgeConfiguration -Path $configPath | Resolve-ForgeConfiguration

            # Pick the latest version
            $latestVersion = $config.versions | Select-Object -First 1
            $latestVersion | Should -Not -BeNullOrEmpty

            $nuspecPath = "$PSScriptRoot/assets/qemu-img-package/qemu-img.nuspec"
            $sourceUrl = $config.sources.gitlab.url
            $gitlabUser = $config.sources.gitlab.username

            # Build the package
            $packagePath = $latestVersion | Build-ChocolateyPackage -NuspecPath $nuspecPath
            $packagePath | Should -Not -BeNullOrEmpty
            Test-Path $packagePath | Should -Be $true

            # Publish to GitLab
            $published = Publish-ChocolateyPackage -Path $packagePath -SourceUrl $sourceUrl -ApiKey $env:APIKEY_GITLAB
            $published | Should -Not -BeNullOrEmpty

            # Verify it's now published
            $publishedVersions = Find-ChocolateyPublishedVersions -PackageName 'qemu-img' -SourceUrl $sourceUrl -User $gitlabUser -Password $env:APIKEY_GITLAB
            $publishedVersions | Should -Contain $latestVersion.version

            # Clean up: delete the package from GitLab
            # GitLab API: DELETE /api/v4/projects/:id/packages/:package_id
            $projectId = '70655681'
            $headers = @{ 'PRIVATE-TOKEN' = $env:APIKEY_GITLAB }
            $packagesUrl = "https://gitlab.com/api/v4/projects/$projectId/packages?package_type=nuget&package_name=qemu-img"
            $packages = Invoke-RestMethod -Uri $packagesUrl -Headers $headers -Verbose:$false
            $pkgToDelete = $packages | Where-Object { $_.version -eq $latestVersion.version.ToString() }
            if ($pkgToDelete) {
                foreach ($pkg in $pkgToDelete) {
                    $null = Invoke-RestMethod -Uri "https://gitlab.com/api/v4/projects/$projectId/packages/$($pkg.id)" -Headers $headers -Method Delete -Verbose:$false
                    Write-VerboseMark "Cleaned up test package version $($latestVersion.version) from GitLab."
                }
            }
        }
    }
}

Describe 'Integration: Full Sync-ForgePackage E2E' {
    InModuleScope 'ChocoForge' {
        BeforeDiscovery {
            $script:skipSync = -not ($env:APIKEY_GITHUB -and $env:APIKEY_GITLAB)
            if ($script:skipSync) {
                Write-Warning 'APIKEY_GITHUB and/or APIKEY_GITLAB not set. Skipping Sync E2E test.'
            }
        }

        It 'Syncs a package to GitHub and GitLab (skipping Chocolatey)' -Skip:$skipSync {
            # Use the tmp/chocolatey-packages qemu-img which has all 3 sources configured
            # But APIKEY_CHOCOLATEY is not set, so Chocolatey source will be skipped
            $forgePath = "$PSScriptRoot/../tmp/chocolatey-packages/qemu-img/qemu-img.forge.yaml"
            
            # Sync should succeed — Chocolatey will be skipped, GitHub and GitLab will be synced
            { Sync-ForgePackage -Path $forgePath -Verbose } | Should -Not -Throw
        }
    }
}
