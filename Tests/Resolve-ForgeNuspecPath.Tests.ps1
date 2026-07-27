Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Resolve-ForgeNuspecPath' {
    InModuleScope 'ChocoForge' {
        It 'Maps a .forge.yaml path to its sibling .nuspec' {
            Resolve-ForgeNuspecPath -ConfigurationPath 'C:/packages/firebird/firebird.forge.yaml' |
                Should -Be 'C:/packages/firebird/firebird.nuspec'
        }

        It 'Preserves the directory, including spaces' {
            Resolve-ForgeNuspecPath -ConfigurationPath 'C:/My Packages/qemu-img/qemu-img.forge.yaml' |
                Should -Be 'C:/My Packages/qemu-img/qemu-img.nuspec'
        }

        It 'Only rewrites the trailing extension, not earlier occurrences' {
            Resolve-ForgeNuspecPath -ConfigurationPath 'C:/forge.yaml.d/app.forge.yaml' |
                Should -Be 'C:/forge.yaml.d/app.nuspec'
        }

        It 'Treats the dots as literals, not regex wildcards' {
            # An unescaped '.forge.yaml$' would also match this and silently produce 'appX.nuspec'.
            { Resolve-ForgeNuspecPath -ConfigurationPath 'C:/pkg/appXforgeYyaml' } | Should -Throw '*expected a file named*'
        }

        It 'Throws when the path is not a .forge.yaml file' {
            { Resolve-ForgeNuspecPath -ConfigurationPath 'C:/pkg/something.txt' } | Should -Throw '*expected a file named*'
        }

        It 'Throws for a bare directory path' {
            { Resolve-ForgeNuspecPath -ConfigurationPath 'C:/pkg' } | Should -Throw '*expected a file named*'
        }

        It 'Matches the extension case-insensitively' {
            Resolve-ForgeNuspecPath -ConfigurationPath 'C:/pkg/App.Forge.Yaml' | Should -Be 'C:/pkg/App.nuspec'
        }

        It 'Agrees with the path Read-ForgeConfiguration reports' {
            $config = Read-ForgeConfiguration -Path "$PSScriptRoot/assets/qemu-img-package/qemu-img.forge.yaml"
            $nuspec = Resolve-ForgeNuspecPath -ConfigurationPath $config.configurationPath

            Test-Path $nuspec | Should -BeTrue
            (Split-Path $nuspec -Leaf) | Should -Be 'qemu-img.nuspec'
        }
    }
}
