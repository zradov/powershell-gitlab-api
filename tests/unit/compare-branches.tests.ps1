Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Compare-Branches" {
    InModuleScope gitlabapi {
        BeforeAll {
            $Server = "gitlab.example.com"
            $Project = "example/project"
            $Source = "source-branch"
            $Target = "target-branch"
            $AccessToken = "fakeAccessToken"

            Mock -CommandName Send-ApiRequest -MockWith {
                param ($Type, $AccessToken, $ApiArgs)
                return @{
                    commits = @(1, 2, 3)
                }
            }
        }

        It "should return the number of commits ahead" {
            $result = Compare-Branches -Server $Server -Project $Project -Source $Source -Target $Target -AccessToken $AccessToken
            $result | Should -Be 3
        }

        It "should return '/' if project or branches do not exist" -Skip {
            Mock Send-ApiRequest {
                throw [FailedAPIRequestException]::new("Not Found", [System.Net.HttpStatusCode]::NotFound)
            }

            $result = Compare-Branches -Server $Server -Project $Project -Source $Source -Target $Target -AccessToken $AccessToken
            $result | Should -Be "/"
        }

        It "should throw an error for other exceptions" -Skip {
            Mock Send-ApiRequest {
                throw [FailedAPIRequestException]::new("API request failed", [System.Net.HttpStatusCode]::InternalServerError)
            }

            { 
                Compare-Branches -Server $Server -Project $Project -Source $Source -Target $Target -AccessToken $AccessToken 
            } | Should -Throw "An error occurred while comparing GitLab branches: API request failed"
        }
    }
}