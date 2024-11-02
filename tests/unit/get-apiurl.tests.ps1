Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-ApiUrl" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $port = 443
            $protocol = "https"
        }
                
        Context "NewProtectedBranch" {
            It "should return the correct URL for creating a new protected branch" {
                $args = @{
                    Server = $server
                    ProjectId = 123
                    Name = "feature-branch"
                    AccessLevel = 40
                    ForcePush = $false
                }

                $expectedUrl = "$protocol`://$server`:$port/api/v4/projects/123/protected_branches?name=feature-branch&push_access_level=40&merge_access_level=40&allow_force_push=False"
                $result = Get-ApiUrl -Type NewProtectedBranch -ApiArgs $args -Port $port -Protocol $protocol
                $result | Should -Be $expectedUrl
            }
        }

        Context "RemoveProtectedBranch" {
            It "should return the correct URL for removing a protected branch" {
                $args = @{
                    Server = $server
                    ProjectId = 123
                    Name = "feature-branch"
                }
                
                $expectedUrl = "$protocol`://$server`:$port/api/v4/projects/123/protected_branches/feature-branch"
                $result = Get-ApiUrl -Type RemoveProtectedBranch -ApiArgs $args -Port $port -Protocol $protocol
                $result | Should -Be $expectedUrl
            }
        }

        Context "GetProjects" {
            It "should return the correct URL for getting projects" {
                $args = @{
                    Server = $server
                }
                $expectedUrl = "$protocol`://$server`:$port/api/v4/projects"
                $result = Get-ApiUrl -Type GetProjects -ApiArgs $args -Port $port -Protocol $protocol
                $result | Should -Be $expectedUrl
            }
        }

        Context "GetGroupProjects" {
            It "should return the correct URL for getting group projects" {
                $args = @{
                    Server = $server
                    GroupId = "my-group"
                }
                $expectedUrl = "$protocol`://$server`:$port/api/v4/groups/my-group/projects"
                $result = Get-ApiUrl -Type GetGroupProjects -ApiArgs $args -Port $port -Protocol $protocol
                $result | Should -Be $expectedUrl
            }
        }

        Context "GetMergeRequests" {
            It "should return the correct URL for getting merge requests" {
                $args = @{
                    Server = $server
                    ProjectId = 123
                    Target = "main"
                    State = "opened"
                }
                $expectedUrl = "$protocol`://$server`:$port/api/v4/projects/123/merge_requests?state=opened&target_branch=main"
                $result = Get-ApiUrl -Type GetMergeRequests -ApiArgs $args -Port $port -Protocol $protocol
                $result | Should -Be $expectedUrl
            }
        }

        Context "GetCommits" {
            It "should return the correct URL for getting commits" {
                $args = @{
                    Server = $server
                    ProjectId = 123
                    Branch = "main"
                }
                $expectedUrl = "$protocol`://$server`:$port/api/v4/projects/123/repository/commits?ref_name=main"
                $result = Get-ApiUrl -Type GetCommits -ApiArgs $args -Port $port -Protocol $protocol
                $result | Should -Be $expectedUrl
            }
        }
    }
}