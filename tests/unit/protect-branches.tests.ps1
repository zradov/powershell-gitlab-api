Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Protect-Branches" {
    InModuleScope gitlabapi {
        BeforeAll {    
            $server = "gitlab.example.com"
            $branchName = "feature-branch"
            $accessToken = "fake-token"
            $accessLevel = "40"
            $forcePush = $true
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
                    [PSCustomObject]@{ name = "main"; push_access_levels = @{ access_level = 40 }; merge_access_levels = @{ access_level = 40 }; allow_force_push = $false },
                    [PSCustomObject]@{ name = "develop"; push_access_levels = @{ access_level = 30 }; merge_access_levels = @{ access_level = 30 }; allow_force_push = $false }
                )
            }

            Mock New-ProtectedBranch {
                return $true
            }

            Mock Remove-ProtectedBranch {
                return $true
            }
        }

        Context "When protecting branches" {
            It "should call Get-Projects with correct parameters" {
                Protect-Branches -Server $server -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                Assert-MockCalled Get-Projects -Exactly 1 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should call Send-ApiRequest with correct parameters" {
                Protect-Branches -Server $server -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                Assert-MockCalled Send-ApiRequest -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "GetProtectedBranches" -and
                    $AccessToken -eq $accessToken -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -in @(1, 2)
                }
            }

            It "should call New-ProtectedBranch when branch is not protected" {
                Mock Send-ApiRequest {
                    return @()
                }
                Protect-Branches -Server $server -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                Assert-MockCalled New-ProtectedBranch -Exactly 2 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    $ProjectId -in @(1, 2) -and
                    $Name -eq $branchName -and
                    $AccessToken -eq $accessToken -and
                    $AccessLevel -eq $accessLevel -and
                    $ForcePush -eq $forcePush
                }
            }

            It "should call Remove-ProtectedBranch and New-ProtectedBranch when branch permissions need updating" {
                $branchName = "main"
                $accessLevel = "30"

                Protect-Branches -Server $server -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                
                Assert-MockCalled Remove-ProtectedBranch -Exactly 2 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    $ProjectId -in @(1, 2) -and
                    $Name -eq $branchName -and
                    $AccessToken -eq $accessToken
                }
                Assert-MockCalled New-ProtectedBranch -Exactly 2 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    $ProjectId -in @(1, 2) -and
                    $Name -eq $branchName -and
                    $AccessToken -eq $accessToken -and
                    $AccessLevel -eq $accessLevel -and
                    $ForcePush -eq $forcePush
                }
            }

            It "should not call Remove-ProtectedBranch or New-ProtectedBranch when branch permissions are correct" {
                Mock Send-ApiRequest {
                    return @(
                        [PSCustomObject]@{ name = $branchName; push_access_levels = @{ access_level = 40 }; merge_access_levels = @{ access_level = 40 }; allow_force_push = $true }
                    )
                }
                Protect-Branches -Server $server -Name $branchName -AccessToken $accessToken -AccessLevel $accessLevel -ForcePush:$forcePush
                Assert-MockCalled Remove-ProtectedBranch -Exactly 0 -Scope It
                Assert-MockCalled New-ProtectedBranch -Exactly 0 -Scope It
            }
        }
    }
}