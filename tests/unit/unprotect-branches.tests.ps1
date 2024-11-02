Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Unprotect-Branches" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $branchName = "feature-branch"
            $accessToken = "fake-token"
        }

        BeforeEach {
            Mock Get-Projects {
                return @(
                    [PSCustomObject]@{ id = 1; path_with_namespace = "group/project1" },
                    [PSCustomObject]@{ id = 2; path_with_namespace = "group/project2" }
                )
            }

            Mock Send-ApiRequest {
                return @(
                    [PSCustomObject]@{ name = "main" },
                    [PSCustomObject]@{ name = "feature-branch" }
                )
            }

            Mock Remove-ProtectedBranch {
                return $true
            }
        }

        Context "When unprotecting branches" {
            It "should call Get-Projects with correct parameters" {
                Unprotect-Branches -Server $server -Name $branchName -AccessToken $accessToken
                Assert-MockCalled Get-Projects -Exactly 1 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should call Send-ApiRequest with correct parameters" {
                Unprotect-Branches -Server $server -Name $branchName -AccessToken $accessToken
                Assert-MockCalled Send-ApiRequest -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "GetProtectedBranches" -and
                    $AccessToken -eq $accessToken -and
                    $ApiArgs.Server -eq $server
                }
            }

            It "should call Remove-ProtectedBranch when branch is protected" {
                Unprotect-Branches -Server $server -Name $branchName -AccessToken $accessToken
                Assert-MockCalled Remove-ProtectedBranch -Exactly 2 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    $ProjectId -in @(1, 2) -and
                    $Name -eq $branchName -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should not call Remove-ProtectedBranch when branch is not protected" {
                Mock Send-ApiRequest {
                    return @(
                        [PSCustomObject]@{ name = "main" }
                    )
                }
                Unprotect-Branches -Server $server -Name $branchName -AccessToken $accessToken
                Assert-MockCalled Remove-ProtectedBranch -Exactly 0 -Scope It
            }
        }
    }
}