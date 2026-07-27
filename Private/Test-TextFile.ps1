function Test-TextFile {
    <#
    .SYNOPSIS
        Determines whether a file can be safely read and rewritten as UTF-8 text.

    .DESCRIPTION
        Attempts a strict UTF-8 decode of the file contents. Files that fail to decode contain
        bytes that a text round-trip would replace with U+FFFD, corrupting them, and must be
        copied verbatim instead of being passed through template expansion.

        A NUL-byte scan is not sufficient here: a file such as 0xFF 0xFE 0x80 contains no NUL
        yet is still not valid UTF-8.

    .PARAMETER Path
        Full path to the file to test.

    .EXAMPLE
        Test-TextFile -Path './tools/chocolateyInstall.ps1'

        Returns $true for a normal script file.

    .OUTPUTS
        System.Boolean. True when the file decodes cleanly as UTF-8.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $encoding = [System.Text.UTF8Encoding]::new($false, $true)   # throwOnInvalidBytes
    try {
        $null = $encoding.GetString($bytes)
        return $true
    } catch [System.Text.DecoderFallbackException] {
        return $false
    }
}
