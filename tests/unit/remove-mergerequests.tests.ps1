Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Remove-MergeRequests" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $Server = "gitlab.example.com"
            $Project = "example/project"
            $MergeRequestIds = @(1, 2, 3)
            $AccessToken = "fake-token"

            # Mock Send-ApiRequest function
            Mock -CommandName Send-ApiRequest -MockWith {
                param ($Type, $AccessToken, $Raw, $ApiArgs)
                return $null
            }
        }

        It "should call Send-ApiRequest with correct parameters for each merge request ID" {
            Remove-MergeRequests -Server $Server -Project $Project -MergeRequestIds $MergeRequestIds -AccessToken $AccessToken

            foreach ($mergeRequestId in $MergeRequestIds) {
                Assert-MockCalled -CommandName Send-ApiRequest -Exactly -Times 1 -Scope It -ParameterFilter {
                    $Type -eq "RemoveMergeRequests" -and
                    $AccessToken -eq $AccessToken -and
                    $Raw -eq $true -and
                    $ApiArgs.Server -eq $Server -and
                    $ApiArgs.Project -eq $Project -and
                    $ApiArgs.MergeRequestId -eq $mergeRequestId
                }
            }
        }

        It "should handle errors during merge request removal" {
            Mock -CommandName Send-ApiRequest -MockWith {
                throw "API request failed"
            }
            Mock -CommandName Write-Error -MockWith {
                param ($ErrorMessage)
                return $null
            }

            Remove-MergeRequests -Server $Server -Project $Project -MergeRequestIds $MergeRequestIds `
                -AccessToken $AccessToken
        
            Assert-MockCalled -CommandName Write-Error -Exactly 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while removing merge requests: API request failed"
            }
        }
    }
}