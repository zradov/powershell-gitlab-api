Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-Commits" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $Server = "https://gitlab.example.com"
            $AccessToken = "fakeAccessToken"
            $ProjectId = 123
            $Branch = "main"
            $MaxCommits = 10
            $PageSize = 20

            # Mock Send-ApiRequest function
            Mock Send-ApiRequest {
                param ($Type, $AccessToken, $MaxPages, $ApiArgs)
                return @(
                    @{ id = "commit1"; message = "Commit 1" },
                    @{ id = "commit2"; message = "Commit 2" },
                    @{ id = "commit3"; message = "Commit 3" }
                )
            }
        }

        It "should call Send-ApiRequest with correct parameters" {
            Get-Commits -Server $Server -AccessToken $AccessToken -ProjectId $ProjectId -Branch $Branch -MaxCommits $MaxCommits -PageSize $PageSize

            Assert-MockCalled Send-ApiRequest -Exactly -Times 1 -Scope It -ParameterFilter {
                $Type -eq "GetCommits" -and
                $AccessToken -eq $AccessToken -and
                $MaxPages -eq [Math]::Ceiling($MaxCommits / $PageSize) -and
                $ApiArgs.Server -eq $Server -and
                $ApiArgs.ProjectId -eq $ProjectId -and
                $ApiArgs.Branch -eq $Branch
            }
        }

        It "should return the correct number of commits" {
            $result = Get-Commits -Server $Server -AccessToken $AccessToken -ProjectId $ProjectId -Branch $Branch -MaxCommits $MaxCommits -PageSize $PageSize

            $result | Should -HaveCount 3
        }

        It "should handle errors gracefully" {
            Mock Send-ApiRequest {
                throw "API request failed"
            }
            Mock Write-Error {}

            $result = Get-Commits -Server $Server -AccessToken $AccessToken -ProjectId $ProjectId -Branch $Branch `
                -MaxCommits $MaxCommits -PageSize $PageSize -ErrorAction SilentlyContinue -ErrorVariable Error

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-Error -Exactly 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while retrieving commits: API request failed"
            }
        }
    }
}