Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Initialize-Repository" {
    InModuleScope gitlabapi {
        BeforeAll {
            $repoUrl = "https://gitlab.example.com/group/project.git"
            $accessToken = "fake-token"
            $guid = "00000000-0000-0000-0000-000000000000"
            $clonedPath = [IO.Path]::Combine("path", "to", "cloned", "repo")
            $shallow = $true
            $clonedPathWithGuid = Join-Path -Path $clonedPath -ChildPath $guid
        }

        BeforeEach {
            Mock Invoke-Expression {
                return "result"
            }

            Mock New-Guid {
                return [PSCustomObject]@{ Guid = $guid }
            }

            Mock git {
                param ($args)
                if ($args -contains "rev-parse") {
                    return "true"
                } elseif ($args -contains "clone") {
                    return "result"
                }
                $Global:LASTEXITCODE = 1
            }
        }

        Context "When initializing a repository" {
            It "should validate the repository URL" {
                $invalidUrl = "invalid-url"
                Mock Write-Error {}

                $result = Initialize-Repository -Url $invalidUrl -AccessToken $accessToken -ClonedPath $clonedPath -Shallow:$shallow `
                    -ErrorAction SilentlyContinue -ErrorVariable err

                $result | Should -Be $null
                Assert-MockCalled Write-Error -Exactly 1 -Scope It
            }

            It "should return the cloned path if the directory already contains a Git repository" {
                Mock git {
                    $Global:LASTEXITCODE = 0
                }

                $result = Initialize-Repository -Url $repoUrl -AccessToken $accessToken -ClonedPath $clonedPath -Shallow:$shallow
                
                $result | Should -Be $clonedPath
            }

            It "should clone the repository with correct parameters" {
                Mock Invoke-Expression {
                    $global:LASTEXITCODE = 0
                }

                $result = Initialize-Repository -Url $repoUrl -AccessToken $accessToken -ClonedPath $clonedPath -Shallow:$shallow
                
                Assert-MockCalled Invoke-Expression -Exactly 1 -Scope It -ParameterFilter {
                    $Command -eq "git clone -c core.longpaths=true -c http.sslVerify=false --depth 1 https://oauth2:$accessToken@gitlab.example.com/group/project.git '$clonedPathWithGuid'"
                }
            }

            It "should return the cloned repository path" {
                Mock Invoke-Expression {
                    $global:LASTEXITCODE = 0
                }

                $result = Initialize-Repository -Url $repoUrl -AccessToken $accessToken `
                    -ClonedPath $clonedPath -Shallow:$shallow
                
                $result | Should -BeOfType "System.String"
                $result | Should -Be "$clonedPathWithGuid"
            }

            It "should handle errors gracefully" {
                Mock Invoke-Expression {
                    throw "An error occurred"
                }
                Mock Write-Error {}

                $result = Initialize-Repository -Url $repoUrl -AccessToken $accessToken -ClonedPath $clonedPath `
                    -Shallow:$shallow -ErrorAction SilentlyContinue -ErrorVariable err
                
                $result | Should -Be $null
            }
        }
    }
}