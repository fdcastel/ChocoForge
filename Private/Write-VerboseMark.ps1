function Write-VerboseMark {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Verbose "$Message  [$($MyInvocation.ScriptName):$($MyInvocation.ScriptLineNumber)]"
}
