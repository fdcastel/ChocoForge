Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Expand-Template' {
    InModuleScope 'ChocoForge' {
        It 'Replaces a simple placeholder' {
            $result = Expand-Template -Content 'Hello, {{name}}!' -Context @{ name = 'World' }
            $result | Should -Be 'Hello, World!'
        }

        It 'Replaces a placeholder with spaces around name' {
            $result = Expand-Template -Content 'Hello, {{ name }}!' -Context @{ name = 'World' }
            $result | Should -Be 'Hello, World!'
        }

        It 'Replaces nested dot-notation placeholder' {
            $ctx = @{ user = @{ name = 'Alice' } }
            $result = Expand-Template -Content 'Hi, {{user.name}}' -Context $ctx
            $result | Should -Be 'Hi, Alice'
        }

        It 'Replaces deeply nested placeholder' {
            $ctx = @{ a = @{ b = @{ c = 'deep' } } }
            $result = Expand-Template -Content '{{a.b.c}}' -Context $ctx
            $result | Should -Be 'deep'
        }

        It 'Replaces missing placeholder with empty string' {
            $result = Expand-Template -Content 'x={{missing}}y' -Context @{}
            $result | Should -Be 'x=y'
        }

        It 'Replaces missing nested placeholder with empty string' {
            $result = Expand-Template -Content '{{a.b.c}}' -Context @{ a = @{} }
            $result | Should -Be ''
        }

        It 'Replaces multiple placeholders in one string' {
            $ctx = @{ first = 'John'; last = 'Doe' }
            $result = Expand-Template -Content '{{first}} {{last}}' -Context $ctx
            $result | Should -Be 'John Doe'
        }

        It 'Leaves content without placeholders unchanged' {
            $result = Expand-Template -Content 'No placeholders here' -Context @{ name = 'X' }
            $result | Should -Be 'No placeholders here'
        }

        It 'Converts non-string values to string' {
            $ctx = @{ count = 42 }
            $result = Expand-Template -Content 'Items: {{count}}' -Context $ctx
            $result | Should -Be 'Items: 42'
        }

        It 'Handles version objects correctly' {
            $ctx = [PSCustomObject]@{ version = [version]'5.0.1' }
            $result = Expand-Template -Content 'v{{version}}' -Context $ctx
            $result | Should -Be 'v5.0.1'
        }

        It 'Extracts sha256 from digest property' {
            $ctx = @{
                asset = [PSCustomObject]@{
                    digest               = 'sha256:abcdef1234567890'
                    browser_download_url = 'https://example.com/file.zip'
                }
            }
            $result = Expand-Template -Content '{{asset.sha256}}' -Context $ctx
            $result | Should -Be 'abcdef1234567890'
        }

        It 'Calls Get-Sha256FromUrlWithCache when no digest but has URL' {
            Mock Get-Sha256FromUrlWithCache { return 'computed_hash_value' }

            $ctx = @{
                asset = [PSCustomObject]@{
                    browser_download_url = 'https://example.com/file.zip'
                }
            }
            $result = Expand-Template -Content '{{asset.sha256}}' -Context $ctx
            $result | Should -Be 'computed_hash_value'
            Should -Invoke Get-Sha256FromUrlWithCache -Times 1
        }

        It 'Returns empty string for sha256 when no digest and no URL' {
            $ctx = @{ asset = [PSCustomObject]@{} }
            $result = Expand-Template -Content '{{asset.sha256}}' -Context $ctx
            $result | Should -Be ''
        }

        It 'Handles transposed asset hashtable with nested access' {
            $ctx = @{
                assets = @{
                    x64 = [PSCustomObject]@{
                        browser_download_url = 'https://example.com/x64.exe'
                        name                 = 'app-x64.exe'
                    }
                    x86 = [PSCustomObject]@{
                        browser_download_url = 'https://example.com/x86.exe'
                        name                 = 'app-x86.exe'
                    }
                }
            }
            $result = Expand-Template -Content '{{assets.x64.browser_download_url}}' -Context $ctx
            $result | Should -Be 'https://example.com/x64.exe'
        }

        It 'Handles concatenation pattern for fallback assets' {
            # When first asset is missing, second should provide the value
            $ctx = @{
                assets = @{
                    Win32 = [PSCustomObject]@{
                        browser_download_url = 'https://example.com/win32.exe'
                    }
                }
            }
            $result = Expand-Template -Content '{{assets.x86.browser_download_url}}{{assets.Win32.browser_download_url}}' -Context $ctx
            $result | Should -Be 'https://example.com/win32.exe'
        }
    }
}
