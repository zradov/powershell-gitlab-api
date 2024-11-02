Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "New-ProtectedBranch" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $projectId = 123
            $branchName = "feature-branch"
            $accessToken = "fake-token"
            $accessLevel = "40"
            $forcePush = $true
            $apiUrl = "https://gitlab.example.com/api/v4/projects/123/protected_branches?name=feature-branch&push_access_level=40&merge_access_level=40&allow_force_push=true"
        }
        
        Context "When creating a new protected branch" {
            BeforeEach {
                Mock Get-ApiUrl {
                    return $apiUrl
                }

                Mock Invoke-WebRequest {
                    return @{
                        StatusCode = 201
                    }
                }
            }

            It "should call Get-ApiUrl with correct parameters" {
                New-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName -AccessToken $accessToken `
                    -AccessLevel $accessLevel -ForcePush:$forcePush

                Assert-MockCalled Get-ApiUrl -Exactly 1 -Scope It -ParameterFilter {
                    $Type -eq "NewProtectedBranch" -and
                    $ApiArgs.Name -eq $branchName -and
                    $ApiArgs.AccessLevel -eq $accessLevel -and
                    $ApiArgs.ForcePush -eq $forcePush -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -eq $projectId
                }
            }

            It "should call Invoke-WebRequest with correct parameters" {
                New-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter {
                    $Headers["PRIVATE-TOKEN"] -eq $accessToken -and
                    $Method -eq "POST" -and
                    $Uri -eq $apiUrl
                }
            }

            It "should return true when the branch is created successfully" {
                $result = New-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                $result | Should -Be $true
            }

            It "should return false when the branch creation fails" {
                Mock Invoke-WebRequest {
                    return @{
                        StatusCode = 400
                    }
                }
                $result = New-ProtectedBranch -Server $server -ProjectId $projectId -Name $branchName `
                    -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush `
                    -ErrorVariable err -ErrorAction SilentlyContinue
                $result | Should -Be $false
            }

            It "should return false when an exception occurs" {
                Mock Invoke-WebRequest {
                    throw "An error occurred"
                }
                $result = New-ProtectedBranch -Server $server -ProjectId $projectId `
                    -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel `
                    -ForcePush:$forcePush -ErrorVariable err -ErrorAction SilentlyContinue
                $result | Should -Be $false
            }
        }
    }
}