# ChocoForge Root Module Script

#Requires -Module powershell-yaml

$ErrorActionPreference = 'Stop'

# Import all public/private function files from Functions subfolders
$Public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public/*.ps1') -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private/*.ps1') -ErrorAction SilentlyContinue)

# Dot source the functions
foreach ($import in @($Public + $Private)) {
    try {
        Write-Verbose "Importing function from $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

# A missing powershell-yaml is already fatal: the #Requires above and the manifest's
# RequiredModules both abort the import before any code here could warn about it.

Write-Verbose 'ChocoForge module loaded.'
