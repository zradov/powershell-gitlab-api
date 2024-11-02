Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Remove-ProtectedBranch" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $projectId = 123
            $branchName = "feature-branch"
            $accessToken = "fake-token"
            $apiUrl = "https://gitlab.example.com/api/v4/projects/123/protected_branches/feature-branch"
        }

        BeforeEach {
            Mock Get-ApiUrl {
                return $apiUrl
            }

            Mock Invoke-WebRequest {
                return @{
                    StatusCode = 204
                }
            }
        }

        Context "When removing a protected branch" {
            It "should call Get-ApiUrl with correct parameters" {
                Remove-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName -AccessToken $accessToken
                Assert-MockCalled Get-ApiUrl -Exactly 1 -Scope It -ParameterFilter {
                    $Type -eq "RemoveProtectedBranch" -and
                    $ApiArgs.Name -eq $branchName -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -eq $projectId
                }
            }

            It "should call Invoke-WebRequest with correct parameters" {
                Remove-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName -AccessToken $accessToken
                Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter {
                    $Headers["PRIVATE-TOKEN"] -eq $accessToken -and
                    $Method -eq "DELETE" -and
                    $Uri -eq $apiUrl
                }
            }

            It "should return true when the branch is removed successfully" {
                $result = Remove-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName -AccessToken $accessToken
                $result | Should -Be $true
            }

            It "should return false when the branch removal fails" {
                Mock Invoke-WebRequest {
                    return @{
                        StatusCode = 400
                    }
                }
                $result = Remove-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName `
                    -AccessToken $accessToken -ErrorVariable err -ErrorAction SilentlyContinue
                $result | Should -Be $false
            }

            It "should return false when an exception occurs" {
                Mock Invoke-WebRequest {
                    throw "An error occurred"
                }
                $result = Remove-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName `
                    -AccessToken $accessToken -ErrorVariable err -ErrorAction SilentlyContinue
                $result | Should -Be $false
            }
        }
    }
}