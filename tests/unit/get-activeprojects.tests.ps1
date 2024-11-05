Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-ActiveProjects" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $Server = "gitlab.example.com"
            $AccessToken = "fakeAccessToken"
            $Days = 4
            $MaxProjects = 5

            # Mock Get-Projects function
            Mock Get-Projects {
                return @(
                    [PSCustomObject]@{ id = 1; name = "Project1"; last_activity_at = (Get-Date).AddDays(-1) },
                    [PSCustomObject]@{ id = 2; name = "Project2"; last_activity_at = (Get-Date).AddDays(-3) },
                    [PSCustomObject]@{ id = 3; name = "Project3"; last_activity_at = (Get-Date).AddDays(-2) },
                    [PSCustomObject]@{ id = 4; name = "Project4"; last_activity_at = (Get-Date).AddDays(-5) },
                    [PSCustomObject]@{ id = 5; name = "Project5"; last_activity_at = (Get-Date).AddDays(-4) }
                )
            }
        }

        It "should call Get-Projects with correct parameters" {
            Get-ActiveProjects -Server $Server -AccessToken $AccessToken -Days $Days -MaxProjects $MaxProjects

            Assert-MockCalled Get-Projects -Exactly -Times 1 -Scope It -ParameterFilter {
                $Server -eq $Server -and
                $AccessToken -eq $AccessToken
            }
        }

        It "should return the correct number of active projects" {
            $result = Get-ActiveProjects -Server $Server -AccessToken $AccessToken -Days $Days -MaxProjects $MaxProjects

            $result | Should -HaveCount 3
        }

        It "should return projects sorted by last activity date in descending order" {
            $result = Get-ActiveProjects -Server $Server -AccessToken $AccessToken -Days $Days -MaxProjects $MaxProjects

            $result[0].name | Should -Be "Project1"
            $result[1].name | Should -Be "Project3"
            $result[2].name | Should -Be "Project2"
        }

        It "should handle errors gracefully" {
            Mock Get-Projects {
                throw "API request failed"
            }
            Mock Write-Error {}

            $result = Get-ActiveProjects -Server $Server -AccessToken $AccessToken -Days $Days `
                -MaxProjects $MaxProjects -ErrorAction SilentlyContinue -ErrorVariable Error

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-Error -Exactly 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while retrieving active projects: API request failed"
            }
        }
    }
}