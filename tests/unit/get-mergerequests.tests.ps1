Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-MergeRequests" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $accessToken = "fake-token"
            $projects = @("group/project1", "group/project2")
            $targetBranch = "main"
            $sourceBranch = "feature"
            $state = "opened"
            $dateTimeFormat = "MM\/dd\/yyyy HH:mm:ss"
        }

        BeforeEach {
            Mock Get-Projects {
                return @(
                    [PSCustomObject]@{ id = 1; path = "project1"; path_with_namespace="group/project1"; http_url_to_repo = "https://$server/group/project1" },
                    [PSCustomObject]@{ id = 2; path = "project2"; path_with_namespace="group/project2"; http_url_to_repo = "https://$server/group/project2" }
                )
            }

            Mock Send-ApiRequest {
                if ($ApiArgs.ProjectId -eq 1) {
                    return @(
                        [PSCustomObject]@{ iid = 1; source_branch = "feature"; target_branch = "main"; project_id = 1; state = "opened"; web_url = "https://$server/group/project1/merge_requests/1"; created_at = "01/01/2022 12:00:00" }
                    )
                } elseif ($ApiArgs.ProjectId -eq 2) {
                    return @(
                        [PSCustomObject]@{ iid = 2; source_branch = "feature"; target_branch = "main"; project_id = 2; state = "opened"; web_url = "https://$server/group/project2/merge_requests/2"; created_at = "01/02/2022 12:00:00" }
                    )
                }
            }
        }

        Context "When retrieving merge requests" {
            It "should call Get-Projects with correct parameters" {
                Get-MergeRequests -Server $server -Projects $projects -Target $targetBranch -AccessToken $accessToken `
                    -Source $sourceBranch -State $state -DateTimeFormat $dateTimeFormat
                
                Assert-MockCalled Get-Projects -Exactly 1 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    "$Include" -eq "$projects" -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should call Send-ApiRequest with correct parameters" {
                Get-MergeRequests -Server $server -Projects $projects -Target $targetBranch -AccessToken $accessToken -Source $sourceBranch -State $state -DateTimeFormat $dateTimeFormat
                
                Assert-MockCalled Send-ApiRequest -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "GetMergeRequests" -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -in @(1, 2) -and
                    $ApiArgs.Target -eq $targetBranch -and
                    $ApiArgs.State -eq $state -and
                    $ApiArgs.Source -eq $sourceBranch -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should return the correct merge requests information" {
                $result = Get-MergeRequests -Server $server -Projects $projects -Target $targetBranch -AccessToken $accessToken -Source $sourceBranch -State $state -DateTimeFormat $dateTimeFormat
                
                $result.Count | Should -Be 2
                $result[0].MergeRequestId | Should -Be 1
                $result[0].Source | Should -Be "feature"
                $result[0].Target | Should -Be "main"
                $result[0].ProjectId | Should -Be 1
                $result[0].ProjectUrl | Should -Be "https://gitlab.example.com/group/project1"
                $result[0].ProjectName | Should -Be "project1"
                $result[0].ProjectFullName | Should -Be "group/project1"
                $result[0].State | Should -Be "opened"
                $result[0].Url | Should -Be "https://gitlab.example.com/group/project1/merge_requests/1"
                $result[0].CreatedAt | Should -Be "01/01/2022 12:00:00"
                $result[1].MergeRequestId | Should -Be 2
                $result[1].Source | Should -Be "feature"
                $result[1].Target | Should -Be "main"
                $result[1].ProjectId | Should -Be 2
                $result[1].ProjectUrl | Should -Be "https://gitlab.example.com/group/project2"
                $result[1].ProjectName | Should -Be "project2"
                $result[1].ProjectFullName | Should -Be "group/project2"
                $result[1].State | Should -Be "opened"
                $result[1].Url | Should -Be "https://gitlab.example.com/group/project2/merge_requests/2"
                $result[1].CreatedAt | Should -Be "01/02/2022 12:00:00"
            }

            It "should handle errors gracefully" {
                Mock Send-ApiRequest {
                    throw "An error occurred"
                }

                $result = Get-MergeRequests -Server $server -Projects $projects -Target $targetBranch `
                    -AccessToken $accessToken -Source $sourceBranch -State $state -DateTimeFormat $dateTimeFormat `
                    -ErrorAction SilentlyContinue -ErrorVariable err

                $result | Should -Be $null
            }
        }
    }
}