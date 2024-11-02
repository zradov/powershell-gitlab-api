Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-Projects" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $accessToken = "fake-token"
        }

        BeforeEach {
            Mock Send-ApiRequest {
                param ($Type, $ApiArgs, $AccessToken)
                if ($Type -eq "GetProjects") {
                    return @(
                        [PSCustomObject]@{ path_with_namespace = "group/project1" },
                        [PSCustomObject]@{ path_with_namespace = "group/project2" }
                    )
                } elseif ($Type -eq "GetProject") {
                    if ($ApiArgs.ProjectName -eq "group/project1") {
                        return [PSCustomObject]@{ path_with_namespace = "group/project1" }
                    } elseif ($ApiArgs.ProjectName -eq "group/project2") {
                        return [PSCustomObject]@{ path_with_namespace = "group/project2" }
                    } else {
                        return $null
                    }
                }
            }
        }

        Context "When retrieving all projects" {
            It "should call Send-ApiRequest with correct parameters" {
                Get-Projects -Server $server -AccessToken $accessToken -Include "*"
                
                Assert-MockCalled Send-ApiRequest -Exactly 1 -Scope It -ParameterFilter {
                    $Type -eq "GetProjects" -and
                    $ApiArgs.Server -eq $server -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should return all projects" {
                $result = Get-Projects -Server $server -AccessToken $accessToken -Include "*"
                
                $result.Count | Should -Be 2
                $result[0].path_with_namespace | Should -Be "group/project1"
                $result[1].path_with_namespace | Should -Be "group/project2"
            }
        }

        Context "When retrieving specified projects" {
            It "should call Send-ApiRequest with correct parameters for each project" {
                Get-Projects -Server $server -AccessToken $accessToken -Include @("group/project1", "group/project2")
                
                Assert-MockCalled Send-ApiRequest -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "GetProject" -and
                    $ApiArgs.Server -eq $server -and
                    $AccessToken -eq $accessToken
                }
            }

            It "should return specified projects" {
                $result = Get-Projects -Server $server -AccessToken $accessToken -Include @("group/project1", "group/project2")
                
                $result.Count | Should -Be 2
                $result[0].path_with_namespace | Should -Be "group/project1"
                $result[1].path_with_namespace | Should -Be "group/project2"
            }

            It "should handle projects not found" {
                $result = Get-Projects -Server $server -AccessToken $accessToken -Include @("group/project1", "group/project3")
                
                $result.Count | Should -Be 1
                $result[0].path_with_namespace | Should -Be "group/project1"
            }
        }

        Context "When excluding projects" {
            It "should exclude specified projects" {
                $result = Get-Projects -Server $server -AccessToken $accessToken -Include "*" -Exclude @("group/project2")
                
                $result.Count | Should -Be 1
                $result[0].path_with_namespace | Should -Be "group/project1"
            }
        }

        Context "When an error occurs" {
            It "should handle errors gracefully" {
                Mock Send-ApiRequest {
                    throw "An error occurred"
                }
                
                $result = Get-Projects -Server $server -AccessToken $accessToken -Include "*" `
                    -ErrorAction SilentlyContinue -ErrorVariable err
                    
                $result | Should -Be $null
            }
        }
    }
}