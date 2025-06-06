@{
    # Module manifest for ChocoForge
    # Version number of this module.
    ModuleVersion = '0.3.0'

    # ID used to uniquely identify this module
    GUID = '7f005d9d-c6f1-4373-82bf-ad91aacb97ea'

    # Author of this module
    Author = 'F.D.Castel'

    # Company or vendor of this module
    CompanyName = ''

    # Copyright statement for this module
    Copyright = '(c) F.D.Castel. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'ChocoForge is a PowerShell module to automate Chocolatey package updates, inspired by Chocolatey AU but with a focus on YAML configuration and immutable build processes.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.5'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''
    
    # Script module or binary module file associated with this manifest.
    RootModule = 'ChocoForge.psm1' # Or ModuleToProcess for older PowerShell versions

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @('powershell-yaml')

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are part of this module, processed in order
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in ModuleToProcess
    NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    # FunctionsToExport = @()

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata.
    PrivateData = @{

        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Export-ModuleMember.
    # DefaultCommandPrefix = ''
}
