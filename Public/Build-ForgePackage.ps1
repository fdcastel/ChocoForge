<#
.SYNOPSIS
    Builds one or more Chocolatey packages from a forge.yaml file and a specific version.

.DESCRIPTION
    Reads the Forge configuration from the specified path, resolves available versions, and builds a Chocolatey package for each version specified.
    The package version can include an optional revision number as the 4th segment. The function never publishes the package, only builds it.
    Returns the full path of each built package.

.PARAMETER Path
    Path to the forge.yaml file. Defaults to the current directory.

.PARAMETER Version
    One or more versions to build. Must match versions available in the configuration.

.PARAMETER RevisionNumber
    Optional. The revision number to use as the 4th segment of the package version. Defaults to 0.

.EXAMPLE
    Build-ForgePackage -Path './myapp.forge.yaml' -Version 1.2.3
    Builds the Chocolatey package for version 1.2.3 with revision 0.

.EXAMPLE
    Build-ForgePackage -Path './myapp.forge.yaml' -Version 1.2.3,1.2.4 -RevisionNumber 5
    Builds packages for versions 1.2.3 and 1.2.4, each with revision 5.

.NOTES
    Supports -WhatIf and -Verbose for safe and traceable execution.
#>
function Build-ForgePackage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Path = '.',

        [Parameter(Mandatory = $true)]
        [version[]]$Version,

        [Parameter(Mandatory = $false)]
        [int]$RevisionNumber = 0
    )

    begin {
        Write-VerboseMark 'Reading Forge configuration.'
        $script:config = Read-ForgeConfiguration -Path $Path | Resolve-ForgeConfiguration

        $script:availableVersions = $script:config.Versions
        Write-VerboseMark "Available versions: $($availableVersions.version -join ', ')"

        foreach ($ver in $Version) {
            $selectedVersion = $availableVersions | Where-Object { $_.version -eq $ver }
            if (-not $selectedVersion) {
                throw "Version '$ver' is not available in the configuration."
            }
        }

        $script:nuspecPath = $Path -replace '.forge.yaml$', '.nuspec'
        Write-VerboseMark "Nuspec path resolved: $($nuspecPath)"
    }

    process {
        foreach ($ver in $Version) {
            $selectedVersion = $availableVersions | Where-Object { $_.version -eq $ver }

            if ($PSCmdlet.ShouldProcess("Build package for version $($selectedVersion.version), revision $RevisionNumber")) {
                Write-VerboseMark "Building package for version: $($selectedVersion.version), revision: $RevisionNumber"

                if ($RevisionNumber) {
                    $packageVersion = [version]::new($($selectedVersion.version.Major), $($selectedVersion.version.Minor), $($selectedVersion.version.Build), $RevisionNumber)

                    # Update selectedVersion object with the updated package version
                    $selectedVersion | Add-Member -MemberType NoteProperty -Name 'version' -Value $packageVersion -Force
                }

                $packageBuiltPath = $selectedVersion | Build-ChocolateyPackage -NuspecPath $nuspecPath -Verbose:$VerbosePreference
                if (-not $packageBuiltPath) {
                    throw "Failed to build the Chocolatey package for version '$($selectedVersion.version)'."
                }
                Write-VerboseMark "Package built at: $($packageBuiltPath)"
                Write-Output $packageBuiltPath
            } else {
                Write-VerboseMark "WhatIf: Would build package for version: $($selectedVersion.version), revision: $RevisionNumber"
            }
        }
    }
}
