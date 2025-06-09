function Invoke-Chocolatey {
    <#
    .SYNOPSIS
        Runs the Chocolatey CLI with specified arguments and returns output and exit code.

    .DESCRIPTION
        Executes the Chocolatey (choco.exe) command-line tool with the provided arguments. 
        
        Captures standard output, standard error, and exit code. Optionally sets the working directory. 
        
        Returns a custom object with ExitCode, StdOut, and StdErr properties.

    .PARAMETER Arguments
        The arguments to pass to choco.exe as a string array.

    .PARAMETER WorkingDirectory
        Optional. The working directory for the choco process.

    .EXAMPLE
        Invoke-Chocolatey -Arguments @('push', 'my.nupkg', '--source', 'https://nuget.pkg.github.com/owner/index.json')
        
        Runs 'choco push' to publish a package to a custom source.

    .OUTPUTS
        PSCustomObject
        An object with ExitCode, StdOut, and StdErr properties containing the results of the Chocolatey command.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [string]$WorkingDirectory
    )

    $chocoExe = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoExe) {
        throw 'Chocolatey executable (choco.exe) not found. Please ensure Chocolatey is installed and in your PATH.'
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $chocoExe.Source
    $psi.Arguments = [string]::Join(' ', $Arguments)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Close() # Prevents stdin usage
    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
    }
}
