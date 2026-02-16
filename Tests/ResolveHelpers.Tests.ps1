Import-Module "$PSScriptRoot/../ChocoForge.psd1" -Force

Describe 'Compare-PublishedVersions' {
    InModuleScope 'ChocoForge' {
        It 'Returns versions not in published list' {
            $release = @([version]'1.0.0', [version]'2.0.0', [version]'3.0.0')
            $published = @([version]'1.0.0', [version]'2.0.0')

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -HaveCount 1
            $missing | Should -Be ([version]'3.0.0')
        }

        It 'Returns empty when all versions are published' {
            $release = @([version]'1.0.0', [version]'2.0.0')
            $published = @([version]'1.0.0', [version]'2.0.0')

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -BeNullOrEmpty
        }

        It 'Returns all when none are published' {
            $release = @([version]'1.0.0', [version]'2.0.0')
            $published = @()

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -HaveCount 2
        }

        It 'Treats Revision=-1 as wildcard (release without revision matches published)' {
            # Release version 5.0.1 (3-part, Revision=-1) matches published 5.0.1.0
            $release = @([version]'5.0.1')
            $published = @([version]'5.0.1.0')

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -BeNullOrEmpty
        }

        It 'Treats published Revision=-1 as wildcard' {
            # Published 5.0.1 (Revision=-1) matches release 5.0.1.2
            $release = @([version]'5.0.1.2')
            $published = @([version]'5.0.1')

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -BeNullOrEmpty
        }

        It 'Does not match different revisions when both are explicit' {
            $release = @([version]'5.0.1.2')
            $published = @([version]'5.0.1.1')

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -HaveCount 1
            $missing | Should -Be ([version]'5.0.1.2')
        }

        It 'Handles 4-part versions correctly' {
            $release = @([version]'2.0.1.5', [version]'2.0.1.6')
            $published = @([version]'2.0.1.5')

            $missing = Compare-PublishedVersions -ReleaseVersions $release -PublishedVersions $published
            $missing | Should -HaveCount 1
            $missing | Should -Be ([version]'2.0.1.6')
        }
    }
}

Describe 'Resolve-SourceCredentials' {
    InModuleScope 'ChocoForge' {
        BeforeEach {
            Mock Expand-EnvironmentVariables { 'fake-key' }
        }

        It 'Resolves GitHub credentials from URL' {
            $source = [PSCustomObject]@{
                url    = 'https://nuget.pkg.github.com/fdcastel/index.json'
                apiKey = '${APIKEY_GITHUB}'
            }
            $creds = Resolve-SourceCredentials -Source $source -SourceName 'github'
            $creds.User | Should -Be 'fdcastel'
            $creds.Password | Should -Be 'fake-key'
        }

        It 'Resolves GitLab credentials with username' {
            $source = [PSCustomObject]@{
                url      = 'https://gitlab.com/api/v4/projects/123/packages/nuget/index.json'
                apiKey   = '${APIKEY_GITLAB}'
                username = 'myuser'
            }
            $creds = Resolve-SourceCredentials -Source $source -SourceName 'gitlab'
            $creds.User | Should -Be 'myuser'
            $creds.Password | Should -Be 'fake-key'
        }

        It 'Returns empty credentials for Chocolatey community source' {
            $source = [PSCustomObject]@{
                url    = 'https://community.chocolatey.org/api/v2'
                apiKey = '${APIKEY_CHOCOLATEY}'
            }
            $creds = Resolve-SourceCredentials -Source $source -SourceName 'community'
            $creds.Keys | Should -HaveCount 0
        }

        It 'Throws when GitLab username is missing' {
            $source = [PSCustomObject]@{
                url    = 'https://gitlab.com/api/v4/projects/123/packages/nuget/index.json'
                apiKey = '${APIKEY_GITLAB}'
            }
            { Resolve-SourceCredentials -Source $source -SourceName 'gitlab' } | Should -Throw '*requires a username*'
        }
    }
}

Describe 'Resolve-SourcePublishingStatus' {
    InModuleScope 'ChocoForge' {
        It 'Sets resolvedApiKey when environment variable is set' {
            Mock Expand-EnvironmentVariables { 'resolved-key' }
            $source = [PSCustomObject]@{ apiKey = '${SOME_KEY}' }
            Resolve-SourcePublishingStatus -Source $source -SourceName 'test'

            $source.resolvedApiKey | Should -Be 'resolved-key'
            $source.skipReason | Should -BeNullOrEmpty
        }

        It 'Sets skipReason when environment variable is not set' {
            Mock Expand-EnvironmentVariables { $null }
            $source = [PSCustomObject]@{ apiKey = '${MISSING_KEY}' }
            Resolve-SourcePublishingStatus -Source $source -SourceName 'test'

            $source.resolvedApiKey | Should -BeNullOrEmpty
            $source.skipReason | Should -Match 'not set'
        }

        It 'Warns when API key is plain text (not an env var reference)' {
            Mock Expand-EnvironmentVariables { param($InputString) $InputString }
            $source = [PSCustomObject]@{ apiKey = 'plaintext-key' }
            Resolve-SourcePublishingStatus -Source $source -SourceName 'test'

            $source.resolvedApiKey | Should -Be 'plaintext-key'
            $source.warningMessage | Should -Match 'plain text'
        }

        It 'Sets skipReason when no apiKey configured' {
            $source = [PSCustomObject]@{}
            Resolve-SourcePublishingStatus -Source $source -SourceName 'test'

            $source.skipReason | Should -Match 'No API key'
        }
    }
}
