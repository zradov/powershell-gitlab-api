Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-Groups" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $accessToken = "fake-token"
        }

        BeforeEach {
            Mock Send-ApiRequest {
                return @(
                    [PSCustomObject]@{ id = 1; name = "group1" },
                    [PSCustomObject]@{ id = 2; name = "group2" }
                )
            }
        }

        Context "When retrieving GitLab groups" {
            It "should call Send-ApiRequest with correct parameters" {
                Get-Groups -Server $server -AccessToken $accessToken
                Assert-MockCalled Send-ApiRequest -Exactly 1 -Scope It -ParameterFilter {
                    $Type -eq "GetGroups" -and
                    $ApiArgs.Server -eq $server -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should return the correct groups information" {
                $result = Get-Groups -Server $server -AccessToken $accessToken
                $result.Count | Should -Be 2
                $result[0].id | Should -Be 1
                $result[1].id | Should -Be 2
                $result[0].name | Should -Be "group1"
                $result[1].name | Should -Be "group2"
            }
        }
    }
}