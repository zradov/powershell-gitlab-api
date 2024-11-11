Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-FilesContainingPattern" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $Server = "https://gitlab.example.com"
            $Repo1Url = "$Server/group/project1.git"
            $Repo2Url = "$Server/group/project2.git"
            $AccessToken = "fakeAccessToken"
            $ClonedRepoPath = "/path/to/repo"
            $IncludeFiles = @("*.txt", "*.log")
            $SearchPatternsArg = @("pattern1", "pattern2")
            $Branches = @("main", "develop")
            $IncludeProjects = "*"
            $ExcludeProjects = @("group/excludedProject")

            Mock Get-Projects {
                return @(
                    [PSCustomObject]@{ path_with_namespace = "group/project1"; http_url_to_repo = $Repo1Url },
                    [PSCustomObject]@{ path_with_namespace = "group/project2"; http_url_to_repo = $Repo2Url }
                )
            }

            Mock Initialize-Repository {
                param ($Url, $AccessToken, $Shallow)
                return $ClonedRepoPath
            }

            Mock Invoke-Expression {
                param ($Command)
                $Global:LASTEXITCODE = 0
                if ("$Command" -eq "git -C '$ClonedRepoPath' branch -r") {
                    return @("origin/main", "origin/develop")
                } elseif ("$Command" -eq "git -C '$clonedRepoPath' checkout $branchToCheck") {
                    return "Switched to branch 'main'"
                }
            }

            Mock Find-PatternInFiles {
                param ($Path, $SearchPatterns, $FilesPattern)
                return @(
                    [PSCustomObject]@{ File = "file1.txt"; Path = "file1.txt"; Pattern = "pattern1"; MatchedLines = @(
                        [PSCustomObject]@{ LineNumber = 1; Line = "This is a line with pattern1" }
                    ) }
                )
            }

            Mock Remove-Item {}
        }

        It "should call Get-Projects with correct parameters" {
            Get-FilesContainingPattern -Server $Server -AccessToken $AccessToken -IncludeFiles $IncludeFiles `
                -SearchPatterns $SearchPatternsArg -Branches $Branches -IncludeProjects $IncludeProjects `
                -ExcludeProjects $ExcludeProjects

            Assert-MockCalled -CommandName Get-Projects -Exactly -Times 1 -Scope It -ParameterFilter {
                $Server -eq $Server -and
                $AccessToken -eq $AccessToken -and
                $Include -eq $IncludeProjects -and
                $Exclude -eq $ExcludeProjects
            }
        }

        It "should call Initialize-Repository with correct parameters" {
            Get-FilesContainingPattern -Server $Server -AccessToken $AccessToken -IncludeFiles $IncludeFiles `
                -SearchPatterns $SearchPatternsArg -Branches $Branches -IncludeProjects $IncludeProjects `
                -ExcludeProjects $ExcludeProjects

            Assert-MockCalled -CommandName Initialize-Repository -Exactly -Times 2 -Scope It -ParameterFilter {
                $Url -in @($Repo1Url, $Repo2Url) -and
                $AccessToken -eq $AccessToken -and
                $Shallow -eq $true
            }
        }

        It "should call Find-PatternInFiles with correct parameters" {
            Get-FilesContainingPattern -Server $Server -AccessToken $AccessToken -IncludeFiles $IncludeFiles `
                -SearchPatterns $SearchPatternsArg -Branches $Branches -IncludeProjects $IncludeProjects `
                -ExcludeProjects $ExcludeProjects

            Assert-MockCalled -CommandName Find-PatternInFiles -Exactly -Times 2 -Scope It -ParameterFilter {
                $Path -eq "$ClonedRepoPath" -and
                "$SearchPatterns" -eq "$SearchPatternsArg" -and
                "$FilesPattern" -eq "$IncludeFiles"
            }
        }

        It "should return the correct data for each project" {
            $result = Get-FilesContainingPattern -Server $Server -AccessToken $AccessToken `
                -IncludeFiles $IncludeFiles -SearchPatterns $SearchPatternsArg -Branches $Branches `
                -IncludeProjects $IncludeProjects -ExcludeProjects $ExcludeProjects

            $result | Should -HaveCount 2

            $result[0].Project | Should -Be "group/project1"
            $result[0].Data | Should -HaveCount 1
            $result[0].Data[0].File | Should -Be "file1.txt"
            $result[0].Data[0].Pattern | Should -Be "pattern1"
            $result[0].Data[0].MatchedLines | Should -HaveCount 1
            $result[0].Data[0].MatchedLines[0].LineNumber | Should -Be 1
            $result[0].Data[0].MatchedLines[0].Line | Should -Be "This is a line with pattern1"

            $result[1].Project | Should -Be "group/project2"
            $result[1].Data | Should -HaveCount 1
            $result[1].Data[0].File | Should -Be "file1.txt"
            $result[1].Data[0].Pattern | Should -Be "pattern1"
            $result[1].Data[0].MatchedLines | Should -HaveCount 1
            $result[1].Data[0].MatchedLines[0].LineNumber | Should -Be 1
            $result[1].Data[0].MatchedLines[0].Line | Should -Be "This is a line with pattern1"
        }

        It "should handle errors gracefully" {
            Mock -CommandName Get-Projects -MockWith {
                throw "An error occurred"
            }
            Mock Write-Error {}

            $result = Get-FilesContainingPattern -Server $Server -AccessToken $AccessToken -IncludeFiles $IncludeFiles `
                -SearchPatterns $SearchPatternsArg -Branches $Branches -IncludeProjects $IncludeProjects `
                -ExcludeProjects $ExcludeProjects -ErrorAction SilentlyContinue -ErrorVariable Error

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-Error -Exactly -Times 1 -Scope It -ParameterFilter {
                "$Message" -eq "An error occurred while searching for files containing patterns: An error occurred"
            }
        }
    }
}