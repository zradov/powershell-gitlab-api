Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Test-CommitsSync" {
    InModuleScope gitlabapi {
        BeforeAll {
            $Source = [ServerInfo]::New("SourceServer", "192.168.1.1", "sourceToken")
            $Target = [ServerInfo]::New("TargetServer", "192.168.1.2", "targetToken")
            $Branches = @("main")
            $IncludeRepos = "*"

            Mock Get-Projects {
                param ($Server, $AccessToken, $Include)
                if ($Server -eq "SourceServer") {
                    return @(
                        [PSCustomObject]@{ id = 1; path_with_namespace = "group/project1" }
                    )
                } elseif ($Server -eq "TargetServer") {
                    return @(
                        [PSCustomObject]@{ id = 1; path_with_namespace = "group/project1" }
                    )
                }
            }

            Mock Get-Commits {
                param ($Server, $AccessToken, $ProjectId, $Branch, $MaxCommits)
                if ($Server -eq "SourceServer") {
                    return [PSCustomObject]@{ id = "commit1"; author_name = "Author1"; authored_date = "2023-01-01T00:00:00Z" }
                } elseif ($Server -eq "TargetServer") {
                    return [PSCustomObject]@{ id = "commit2"; author_name = "Author2"; authored_date = "2023-01-02T00:00:00Z" }
                }
            }
        }

        It "should return an array of unsynchronized commits" {
            $result = Test-CommitsSync -Source $Source -Target $Target -Branches $Branches -IncludeRepos $IncludeRepos

            $result.GetType() | Should -Be "System.Object[]"
            $result | Should -HaveCount 1
            $result[0].Project | Should -Be "group/project1"
            $result[0].Author | Should -Be "Author1"
            $result[0].BranchName | Should -Be "main"
            $result[0].CommitID | Should -Be "commit1"
            $result[0].Date | Should -Be "2023-01-01T00:00:00Z"
        }

        It "should call Get-Projects for both source and target servers" {
            Test-CommitsSync -Source $Source -Target $Target -Branches $Branches -IncludeRepos $IncludeRepos

            Assert-MockCalled Get-Projects -Exactly -Times 2 -Scope It -ParameterFilter {
                $Server -in @("SourceServer", "TargetServer") -and
                $AccessToken -in @("sourceToken", "targetToken") -and
                $Include -eq $IncludeRepos
            }
        }

        It "should call Get-Commits for each project and branch" {
            Test-CommitsSync -Source $Source -Target $Target -Branches $Branches -IncludeRepos $IncludeRepos

            Assert-MockCalled Get-Commits -Exactly -Times 2 -Scope It -ParameterFilter {
                $Server -in @("SourceServer", "TargetServer") -and
                $AccessToken -in @("sourceToken", "targetToken") -and
                $Branch -eq "main"
            }
        }

        It "should handle errors gracefully and continue processing other projects" {
            Mock Get-Projects {
                param ($Server, $AccessToken, $Include)
                if ($Server -eq "SourceServer") {
                    throw "API request failed for SourceServer"
                } elseif ($Server -eq "TargetServer") {
                    return @(
                        [PSCustomObject]@{ id = 1; path_with_namespace = "group/project1" }
                    )
                }
            }
            Mock Write-Error {}


            $result = Test-CommitsSync -Source $Source -Target $Target -Branches $Branches -IncludeRepos $IncludeRepos `
                -ErrorAction SilentlyContinue -ErrorVariable Error

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-Error -Exactly 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while retrieving projects: API request failed for SourceServer"
            }
        }
    }
}