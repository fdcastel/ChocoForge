function Write-ForgeConfiguration {
    <#
    .SYNOPSIS
        Writes a summary of the Forge configuration object to the host, with colorized output for easy reading.

    .DESCRIPTION
        Displays key information about the resolved Forge configuration, including package name, targets, publishing status, flavors, and version details. 
        
    .PARAMETER Configuration
        The resolved configuration object (output of Resolve-ForgeConfiguration) to display.

    .EXAMPLE
        $resolved = Resolve-ForgeConfiguration -Configuration $config
        Write-ForgeConfiguration -Configuration $resolved
        
        Displays a colorized summary of the resolved configuration and publishing status.

    .OUTPUTS
        None. Writes formatted summary information to the host.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Configuration
    )

    process {
        Write-Host 'Package: ' -NoNewline -ForegroundColor Gray
        Write-Host $Configuration.package -ForegroundColor Cyan
        Write-Host ''

        Write-Host 'Targets:' -ForegroundColor Gray
        $targets = $Configuration.targets
        $targetNames = $targets.Keys

        foreach ($targetName in $targetNames) {
            $target = $targets[$targetName]

            Write-Host '  - ' -ForegroundColor Gray -NoNewline
            Write-Host "$targetName" -ForegroundColor Cyan -NoNewline
            Write-Host ': ' -ForegroundColor Gray -NoNewline
            
            if ($target.missingVersions) {
                if ($Configuration.versions.Count -eq $target.missingVersions.Count) {
                    Write-Host 'Not published on this target' -ForegroundColor DarkGray -NoNewline
                } else {
                    Write-Host 'Some missing versions' -ForegroundColor Yellow -NoNewline
                }
            } else {
                Write-Host 'All versions published' -ForegroundColor Green -NoNewline
            }
            Write-Host ''

            if ($target.skipReason) {
                Write-Host '    - ' -ForegroundColor Gray -NoNewline
                Write-Host "$($target.skipReason)" -ForegroundColor Yellow -NoNewline
                if ($target.missingVersions) {
                    Write-Host ' (cannot publish)' -ForegroundColor DarkRed -NoNewline
                }
                Write-Host ''
            }

            if ($target.warningMessage) {
                Write-Host '    - ' -ForegroundColor Gray -NoNewline
                Write-Host "$($target.warningMessage)" -ForegroundColor DarkYellow
            }
        }

        Write-Host ''
        Write-Host 'Flavors:' -ForegroundColor Gray
        $flavors = $Configuration.releases.flavors
        $flavorNames = $flavors.Keys

        foreach ($flavorName in $flavorNames) {
            Write-Host '  - ' -ForegroundColor Gray -NoNewline
            Write-Host "$flavorName" -ForegroundColor Cyan -NoNewline
            Write-Host ': ' -ForegroundColor Gray

            $flavorVersions = $configuration.versions | Where-Object { $_.flavor -eq $flavorName }
            $flavorLatestVersion = $flavorVersions.version | Select-Object -First 1

            foreach ($targetName in $targetNames) {
                $target = $targets[$targetName]

                Write-Host '    - ' -ForegroundColor Gray -NoNewline
                Write-Host "$targetName" -ForegroundColor Cyan -NoNewline
                Write-Host ': ' -ForegroundColor Gray -NoNewline

                $flavorTargetVersions = $configuration.versions | Where-Object { ($_.flavor -eq $flavorName) -and ($target.publishedVersions -contains $_.version) }
                $flavorTargetMissingVersions = $configuration.versions | Where-Object { ($_.flavor -eq $flavorName) -and ($target.publishedVersions -notcontains $_.version) }
                $flavorTargetLatestVersion = $flavorTargetVersions.version | Select-Object -First 1

                if ($flavorTargetLatestVersion) {
                    if ($flavorTargetLatestVersion -eq $flavorLatestVersion) {
                        Write-Host "$flavorTargetLatestVersion (up-to-date)" -ForegroundColor Green
                    } else {
                        Write-Host "$flavorTargetLatestVersion (out-of-date)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host 'Not published on this target' -ForegroundColor DarkGray
                }

                if ($flavorTargetMissingVersions) {
                    Write-Host '      - Missing versions: ' -NoNewline -ForegroundColor Gray
                    Write-Host ($flavorTargetMissingVersions.version -join ', ') -ForegroundColor Magenta
                }
            }
            Write-Host ''
        }
    }
}