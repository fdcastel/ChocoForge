@{
    # Module manifest for ChocoForge

    # Version number of this module.
    ModuleVersion     = '0.0.0'

    # ID used to uniquely identify this module
    GUID              = '7f005d9d-c6f1-4373-82bf-ad91aacb97ea'

    # Author of this module
    Author            = 'F.D.Castel'

    # Company or vendor of this module
    CompanyName       = ''

    # Copyright statement for this module
    Copyright         = '(c) F.D.Castel. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell toolkit for automating the creation, management, and publishing of Chocolatey packages.'

    FunctionsToExport = @(
        'Build-ForgePackage',
        'Get-ForgePackage',
        'Sync-ForgePackage'
    )

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.4'



    # Script module or binary module file associated with this manifest.
    RootModule        = 'ChocoForge.psm1' # Or ModuleToProcess for older PowerShell versions

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @('powershell-yaml')



    # Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('chocolatey', 'package', 'automation', 'powershell')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/fdcastel/ChocoForge'

            # A URL to an icon representing this module.
            IconUri      = 'https://github.com/fdcastel/ChocoForge/blob/master/docs/ChocoForge-Logo.png'

            # ReleaseNotes of this module
            ReleaseNotes = 'https://github.com/fdcastel/ChocoForge/releases'
        }
    }
}
