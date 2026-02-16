Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Expand-EnvironmentVariables' {
    InModuleScope 'ChocoForge' {
        It 'Expands a single environment variable' {
            $env:TEST_CHOCOFORGE_VAR = 'hello'
            try {
                $result = Expand-EnvironmentVariables -InputString '${TEST_CHOCOFORGE_VAR}'
                $result | Should -Be 'hello'
            } finally {
                Remove-Item env:TEST_CHOCOFORGE_VAR
            }
        }

        It 'Expands multiple environment variables' {
            $env:TEST_CF_A = 'foo'
            $env:TEST_CF_B = 'bar'
            try {
                $result = Expand-EnvironmentVariables -InputString '${TEST_CF_A} and ${TEST_CF_B}'
                $result | Should -Be 'foo and bar'
            } finally {
                Remove-Item env:TEST_CF_A
                Remove-Item env:TEST_CF_B
            }
        }

        It 'Returns null for unset environment variable' {
            # Ensure var doesn't exist
            Remove-Item env:TEST_CF_NONEXISTENT -ErrorAction SilentlyContinue
            $result = Expand-EnvironmentVariables -InputString '${TEST_CF_NONEXISTENT}'
            $result | Should -BeNullOrEmpty
        }

        It 'Leaves strings without variables unchanged' {
            $result = Expand-EnvironmentVariables -InputString 'no variables here'
            $result | Should -Be 'no variables here'
        }

        It 'Leaves plain text around variables intact' {
            $env:TEST_CF_KEY = 'secret'
            try {
                $result = Expand-EnvironmentVariables -InputString 'prefix-${TEST_CF_KEY}-suffix'
                $result | Should -Be 'prefix-secret-suffix'
            } finally {
                Remove-Item env:TEST_CF_KEY
            }
        }

        It 'Does not expand variables without braces' {
            $env:TEST_CF_NO = 'value'
            try {
                $result = Expand-EnvironmentVariables -InputString '$TEST_CF_NO'
                $result | Should -Be '$TEST_CF_NO'
            } finally {
                Remove-Item env:TEST_CF_NO
            }
        }
    }
}
