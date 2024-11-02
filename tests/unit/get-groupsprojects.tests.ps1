Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-GroupProjects" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $accessToken = "fake-token"
            $groupId = "my-group"
        }

        BeforeEach {
            Mock Send-ApiRequest {
                return @(
                    [PSCustomObject]@{ id = 1; name = "project1" },
                    [PSCustomObject]@{ id = 2; name = "project2" }
                )
            }
        }

        Context "When retrieving GitLab group projects" {
            It "should call Send-ApiRequest with correct parameters" {
                Get-GroupProjects -Server $server -AccessToken $accessToken -GroupId $groupId
                Assert-MockCalled Send-ApiRequest -Exactly 1 -Scope It -ParameterFilter {
                    $Type -eq "GetGroupProjects" -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.GroupId -eq $groupId -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should return the correct group projects information" {
                $result = Get-GroupProjects -Server $server -AccessToken $accessToken -GroupId $groupId
                $result.Count | Should -Be 2
                $result[0].id | Should -Be 1
                $result[1].id | Should -Be 2
                $result[0].name | Should -Be "project1"
                $result[1].name | Should -Be "project2"
            }

            It "should handle errors gracefully" {
                Mock Send-ApiRequest {
                    throw "An error occurred"
                }
                $result = Get-GroupProjects -Server $server -AccessToken $accessToken `
                    -GroupId $groupId -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -Be $null
            }
        }
    }
}