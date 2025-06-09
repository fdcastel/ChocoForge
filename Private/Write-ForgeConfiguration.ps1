function Write-ForgeConfiguration {
    <#
    .SYNOPSIS
        Writes a summary of the Forge configuration object to the host, with colorized output for easy reading.

    .DESCRIPTION
        Displays key information about the resolved Forge configuration, including package name, sources, publishing status, flavors, and version details. 
        
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

        Write-Host 'Sources:' -ForegroundColor Gray
        $sources = $Configuration.sources
        $sourceNames = $sources.Keys

        foreach ($sourceName in $sourceNames) {
            $source = $sources[$sourceName]

            Write-Host '  - ' -ForegroundColor Gray -NoNewline
            Write-Host "$sourceName" -ForegroundColor Cyan -NoNewline
            Write-Host ': ' -ForegroundColor Gray -NoNewline
            
            if ($source.missingVersions) {
                if ($Configuration.versions.Count -eq $source.missingVersions.Count) {
                    Write-Host 'Not published on this source' -ForegroundColor DarkGray -NoNewline
                } else {
                    Write-Host 'Some missing versions' -ForegroundColor Yellow -NoNewline
                }
            } else {
                Write-Host 'All versions published' -ForegroundColor Green -NoNewline
            }
            Write-Host ''

            if ($source.skipReason) {
                Write-Host '    - ' -ForegroundColor Gray -NoNewline
                Write-Host "$($source.skipReason)" -ForegroundColor Yellow -NoNewline
                if ($source.missingVersions) {
                    Write-Host ' (cannot publish)' -ForegroundColor DarkRed -NoNewline
                }
                Write-Host ''
            }

            if ($source.warningMessage) {
                Write-Host '    - ' -ForegroundColor Gray -NoNewline
                Write-Host "$($source.warningMessage)" -ForegroundColor DarkYellow
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

            foreach ($sourceName in $sourceNames) {
                $source = $sources[$sourceName]

                Write-Host '    - ' -ForegroundColor Gray -NoNewline
                Write-Host "$sourceName" -ForegroundColor Cyan -NoNewline
                Write-Host ': ' -ForegroundColor Gray -NoNewline

                $flavorSourceVersions = $configuration.versions | Where-Object { ($_.flavor -eq $flavorName) -and ($source.publishedVersions -contains $_.version) }
                $flavorSourceMissingVersions = $configuration.versions | Where-Object { ($_.flavor -eq $flavorName) -and ($source.publishedVersions -notcontains $_.version) }
                $flavorSourceLatestVersion = $flavorSourceVersions.version | Select-Object -First 1

                if ($flavorSourceLatestVersion) {
                    if ($flavorSourceLatestVersion -eq $flavorLatestVersion) {
                        Write-Host "$flavorSourceLatestVersion (up-to-date)" -ForegroundColor Green
                    } else {
                        Write-Host "$flavorSourceLatestVersion (out-of-date)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host 'Not published on this source' -ForegroundColor DarkGray
                }

                if ($flavorSourceMissingVersions) {
                    Write-Host '      - Missing versions: ' -NoNewline -ForegroundColor Gray
                    Write-Host ($flavorSourceMissingVersions.version -join ', ') -ForegroundColor Magenta
                }
            }
            Write-Host ''
        }
    }
}