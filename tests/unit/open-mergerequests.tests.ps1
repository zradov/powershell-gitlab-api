Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Open-MergeRequests" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $accessToken = "fake-token"
            $projects = @("group/project1", "group/project2")
            $targetBranch = "main"
            $sourceBranch = "feature"
            $state = "closed"
        }

        BeforeEach {
            Mock Get-MergeRequests {
                return @(
                    [PSCustomObject]@{ MergeRequestId = 1; ProjectId = 1; ProjectFullName = "group/project1" },
                    [PSCustomObject]@{ MergeRequestId = 2; ProjectId = 2; ProjectFullName = "group/project2" }
                )
            }

            Mock Get-ApiUrl {
                param ($Type, $ApiArgs)
                return "https://$server/api/v4/projects/$($ApiArgs.ProjectId)/merge_requests/$($ApiArgs.MergeRequestId)?state_event=reopen"
            }

            Mock Send-ApiRequest {
                return $null
            }
        }

        Context "When reopening merge requests" {
            It "should call Get-MergeRequests with correct parameters" {
                Open-MergeRequests -Server $server -Projects $projects -Target $targetBranch `
                    -AccessToken $accessToken -Source $sourceBranch -State $state
                
                Assert-MockCalled Get-MergeRequests -Exactly 1 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    "$Projects" -eq "$projects" -and
                    $Target -eq $targetBranch -and
                    $Source -eq $sourceBranch -and
                    $AccessToken -eq $accessToken -and
                    $State -eq $state
                }
            }

            It "should call Get-ApiUrl with correct parameters" {
                Open-MergeRequests -Server $server -Projects $projects -Target $targetBranch `
                    -AccessToken $accessToken -Source $sourceBranch -State $state

                Assert-MockCalled Get-ApiUrl -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "OpenMergeRequest" -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -in @(1, 2) -and
                    $ApiArgs.MergeRequestId -in @(1, 2)
                }
            }

            It "should call Send-ApiRequest with correct parameters" {
                Open-MergeRequests -Server $server -Projects $projects -Target $targetBranch `
                    -AccessToken $accessToken -Source $sourceBranch -State $state
                
                Assert-MockCalled Send-ApiRequest -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "OpenMergeRequest" -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -in @(1, 2) -and
                    $ApiArgs.MergeRequestId -in @(1, 2) -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should return the correct merge requests information" {
                $result = Open-MergeRequests -Server $server -Projects $projects -Target $targetBranch `
                    -AccessToken $accessToken -Source $sourceBranch -State $state
                
                $result.Count | Should -Be 2
                $result[0].MergeRequestId | Should -Be 1
                $result[1].MergeRequestId | Should -Be 2
            }

            It "should handle errors gracefully" {
                Mock Send-ApiRequest {
                    throw "An error occurred"
                }
                
                $result = Open-MergeRequests -Server $server -Projects $projects -Target $targetBranch `
                    -AccessToken $accessToken -Source $sourceBranch -State $state -ErrorAction SilentlyContinue `
                    -ErrorVariable err
                
                $result | Should -Be $null
            }
        }
    }
}