Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Get-Sha256FromUrlWithCache' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            # The function caches into $env:TEMP/ChocoForge-HashCache.json. Point TEMP at a
            # scratch directory so tests neither read nor clobber the real cache.
            $script:realTemp = $env:TEMP
            $script:sandbox = Join-Path ([System.IO.Path]::GetTempPath()) "chocoforge-cache-test-$([Guid]::NewGuid())"
            New-Item -ItemType Directory -Path $script:sandbox -Force | Out-Null
            $env:TEMP = $script:sandbox
            $script:cacheFile = Join-Path $script:sandbox 'ChocoForge-HashCache.json'

            # Stand in for the download: write known bytes so the hash is predictable.
            Mock Invoke-WebRequest {
                Set-Content -Path $OutFile -Value 'known-content' -NoNewline
            }
        }

        AfterEach {
            $env:TEMP = $script:realTemp
            if (Test-Path $script:sandbox) { Remove-Item -Recurse -Force $script:sandbox }
        }

        It 'Downloads and hashes on a cache miss' {
            $hash = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'

            $hash | Should -Match '^[0-9a-f]{64}$'
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
        }

        It 'Returns the hash of the actual content' {
            $expected = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes('known-content'))) -Algorithm SHA256).Hash.ToLower()
            Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip' | Should -Be $expected
        }

        It 'Writes the cache file' {
            $null = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'
            Test-Path $script:cacheFile | Should -BeTrue

            $cache = Get-Content $script:cacheFile -Raw | ConvertFrom-Json -AsHashtable
            $cache.Keys | Should -Contain 'https://example.com/file.zip'
        }

        It 'Serves a second request from cache without downloading again' {
            $first = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'
            $second = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'

            $second | Should -Be $first
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly   # still only the first call
        }

        It 'Re-downloads once the cached entry is older than 24 hours' {
            $stale = @{
                'https://example.com/file.zip' = @{
                    sha256    = 'stalehash'
                    timestamp = (Get-Date).AddHours(-25).ToString('o')
                }
            }
            $stale | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cacheFile

            $hash = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'

            $hash | Should -Not -Be 'stalehash'
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
        }

        It 'Prunes expired entries for other URLs when writing' {
            $seed = @{
                'https://example.com/expired.zip' = @{ sha256 = 'old'; timestamp = (Get-Date).AddHours(-48).ToString('o') }
                'https://example.com/fresh.zip'   = @{ sha256 = 'new'; timestamp = (Get-Date).AddMinutes(-5).ToString('o') }
            }
            $seed | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cacheFile

            $null = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'

            $cache = Get-Content $script:cacheFile -Raw | ConvertFrom-Json -AsHashtable
            $cache.Keys | Should -Not -Contain 'https://example.com/expired.zip'   # pruned
            $cache.Keys | Should -Contain 'https://example.com/fresh.zip'          # retained
            $cache.Keys | Should -Contain 'https://example.com/file.zip'           # just added
        }

        It 'Drops entries with an unparseable timestamp' {
            $seed = @{
                'https://example.com/corrupt.zip' = @{ sha256 = 'x'; timestamp = 'not-a-date' }
            }
            $seed | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cacheFile

            $null = Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip'

            $cache = Get-Content $script:cacheFile -Raw | ConvertFrom-Json -AsHashtable
            $cache.Keys | Should -Not -Contain 'https://example.com/corrupt.zip'
        }

        It 'Recovers from a corrupt cache file instead of throwing' {
            Set-Content -Path $script:cacheFile -Value 'this is not json {{{'

            { Get-Sha256FromUrlWithCache -Url 'https://example.com/file.zip' } | Should -Not -Throw
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly
        }

        It 'Trims surrounding whitespace from the URL' {
            $withSpace = Get-Sha256FromUrlWithCache -Url '  https://example.com/file.zip  '
            $cache = Get-Content $script:cacheFile -Raw | ConvertFrom-Json -AsHashtable

            $cache.Keys | Should -Contain 'https://example.com/file.zip'
            $withSpace | Should -Match '^[0-9a-f]{64}$'
        }
    }
}
