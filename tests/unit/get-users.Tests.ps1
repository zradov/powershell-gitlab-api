Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force


Describe "Get-Users" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $Servers = @(
                [ServerInfo]::New("Server1", "192.168.1.1", "token1"),
                [ServerInfo]::New("Server2", "192.168.1.2", "token2")
            )
            $State = "active"
            $Ignore = @("ignoredUser")

            # Mock Send-ApiRequest function
            Mock Send-ApiRequest {
                param ($Type, $AccessToken, $ApiArgs)
                if ($ApiArgs.Server -eq "192.168.1.1") {
                    return @(
                        [PSCustomObject]@{ name = "User 1"; username = "user1"; state = "active" },
                        [PSCustomObject]@{ name = "User 2"; username = "user2"; state = "inactive" }
                    )
                } elseif ($ApiArgs.Server -eq "192.168.1.2") {
                    return @(
                        [PSCustomObject]@{ name = "User 3"; username = "user3"; state = "active" },
                        [PSCustomObject]@{ name = "User 4"; username = "user4"; state = "active" }
                    )
                }
            }
        }

        It "should return a dictionary of servers and their active users" {
            $result = Get-Users -Servers $Servers -State $State -Ignore $Ignore

            "$([PSCustomObject]$result['Server1'])" | Should -Be "$([PSCustomObject]@{ name = 'User 1'; username = 'user1' })"

            $result["Server2"].Length | Should -Be 2
            "$([PSCustomObject]$result["Server2"][0])" | Should -Be "$([PSCustomObject]@{ name = 'User 3'; username = 'user3'; })"
            "$([PSCustomObject]$result["Server2"][1])" | Should -Be "$([PSCustomObject]@{ name = 'User 4'; username = 'user4'; })"
        }

        It "should handle errors gracefully" {
            Mock Send-ApiRequest { throw "API request failed" }
            Mock Write-Error {}

            { Get-Users -Servers $Servers -State $State -Ignore $Ignore } | Should -Not -Throw

            Assert-MockCalled Write-Error -Exactly 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while fetching users from server: 192.168.1.1. Error: API request failed"
            }
            Assert-MockCalled Write-Error -Exactly 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while fetching users from server: 192.168.1.2. Error: API request failed"
            }
        }
    }
}