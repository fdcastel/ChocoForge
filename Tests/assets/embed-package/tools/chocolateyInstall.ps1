$ErrorActionPreference = 'Stop'

$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

# This is an embedded package - installer is included in the .nupkg
$file = Get-Item "$toolsDir\*.zip"

$packageArgs = @{
  PackageName    = 'test-embed'
  UnzipLocation  = $toolsDir
  File64bit      = $file
}
Get-ChocolateyUnzip @packageArgs
