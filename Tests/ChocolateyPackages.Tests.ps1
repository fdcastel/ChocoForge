Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Get-ChocolateyPackages' {
    InModuleScope 'ChocoForge' {
        It 'Returns all versions for a package from the default source' {
            Mock Invoke-Chocolatey {
                [PSCustomObject]@{
                    ExitCode = 0
                    StdOut = Get-Content "$PSScriptRoot/assets/chocolatey-packages.txt" -Raw
                    StdErr = ''
                }
            }
            $result = Get-ChocolateyPackages -PackageName 'firebird'
            $result | Should -Not -BeNullOrEmpty
            $result.Length | Should -Be 7
            $result.Version | Should -Contain ([version]'5.0.2')
            $result.Version | Should -Contain ([version]'3.0.10.1000')
            $result.Version | Should -Not -Contain ([version]'3.0.10')
        }
    }
}
