function Invoke-Chocolatey {
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
