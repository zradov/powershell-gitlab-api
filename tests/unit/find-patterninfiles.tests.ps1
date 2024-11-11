Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

# FILE: find-patterninfiles.tests.ps1

Describe "Find-PatternInFiles" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $DirPath = "/testdir"
            $filesInDir = @(
                [PSCustomObject]@{ FullName = "$DirPath/file1.txt"; Name = "file1.txt" }, 
                [PSCustomObject]@{ FullName = "$DirPath/file2.txt"; Name = "file2.txt" },
                [PSCustomObject]@{ FullName = "$DirPath/file1.log"; Name = "file1.log" }
            )
            $txtFiles = $filesInDir[0..1]
            $logFiles = $filesInDir[2..$filesInDir.Count]
            $SearchPatterns = @("pattern1", "pattern2")
            $FilesPattern = @("*.txt", "*.log")

            Mock Get-ChildItem {
                param ($Path, $Filter, $Recurse, $File, $Force)
                if ($Path -eq $DirPath -and $Filter -eq "*.txt") { return $txtFiles }
                if ($Path -eq $DirPath -and $Filter -eq "*.log") { return $logFiles }
                if ($Path -eq "$DirPath/file1.txt") { return @( "file1.txt content" ) }
                if ($Path -eq "$DirPath/file2.txt") { return @( "file2.txt content" ) }
                if ($Path -eq "$DirPath/file1.log") { return @( "file1.log content" ) }
            }
            
            Mock Select-String {
                [CmdletBinding()]
                param(
                    [Parameter(ValueFromPipeline = $true)]
                    $InputObject,
                    $Pattern,
                    [switch]$AllMatches
                )
                if ($InputObject -eq "file1.txt content" -and $Pattern -eq "pattern1") {
                    return @(
                        [PSCustomObject]@{ LineNumber = 1; Line = "line1" },
                        [PSCustomObject]@{ LineNumber = 2; Line = "line2" }
                    )
                } elseif ($InputObject -eq "file2.txt content" -and $Pattern -eq "pattern2") {
                    return @(
                        [PSCustomObject]@{ LineNumber = 3; Line = "line3" }
                    )
                } else {
                    return @()
                }
            }
        }

        It "should call Get-ChildItem to search for files in the target directory" {
            Find-PatternInFiles -Path $DirPath -SearchPatterns $SearchPatterns -FilesPattern $FilesPattern

            $FilesPattern | % { 
                Assert-MockCalled Get-ChildItem -Exactly -Times 1 -Scope It -ParameterFilter {
                    $Path -eq $Path -and
                    $Filter -eq $_ -and 
                    $Recurse -eq $true -and
                    $File -eq $true -and
                    $Force -eq $true
                }
            }
        }

        It "should call Get-ChildItem for each found file to search for lines with matching pattern" {
            Find-PatternInFiles -Path $DirPath -SearchPatterns $SearchPatterns -FilesPattern $FilesPattern

            Write-Host "$($($txtFiles + $logFiles).Count)"

            $($txtFiles + $logFiles) | % {
                Assert-MockCalled Get-ChildItem -Exactly -Times $SearchPatterns.Count -Scope It -ParameterFilter {
                    $Path -eq $_.FullName -and
                    $Filter -eq $null
                }
            }
        }

        It "should call Select-String with correct parameters"  {
            Find-PatternInFiles -Path $DirPath -SearchPatterns $SearchPatterns -FilesPattern $FilesPattern

            Assert-MockCalled Select-String -Exactly -Times $($filesInDir.Count * $SearchPatterns.Count) `
                -Scope It -ParameterFilter {
                $Pattern -in $SearchPatterns
            }
        }

        It "should return the correct matched lines" {
            $result = Find-PatternInFiles -Path $DirPath -SearchPatterns $SearchPatterns -FilesPattern $FilesPattern

            $result | Should -HaveCount 2

            $result[0].File | Should -Be "file1.txt"
            $result[0].Pattern | Should -Be "pattern1"
            $result[0].MatchedLines | Should -HaveCount 2
            $result[0].MatchedLines[0].LineNumber | Should -Be 1
            $result[0].MatchedLines[0].Line | Should -Be "line1"
            $result[0].MatchedLines[1].LineNumber | Should -Be 2
            $result[0].MatchedLines[1].Line | Should -Be "line2"

            $result[1].File | Should -Be "file2.txt"
            $result[1].Pattern | Should -Be "pattern2"
            $result[1].MatchedLines | Should -HaveCount 1
            $result[1].MatchedLines[0].LineNumber | Should -Be 3
            $result[1].MatchedLines[0].Line | Should -Be "line3"
        }

        It "should handle errors gracefully" {
            Mock Get-ChildItem {
                throw "An error occurred"
            }
            Mock Write-Error {}

            $result = Find-PatternInFiles -Path $DirPath -SearchPatterns $SearchPatterns -FilesPattern $FilesPattern

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-Error -Exactly -Times 1 -Scope It -ParameterFilter {
                $Message -eq "An error occurred while searching for PII data: An error occurred"
            }
        }
    }
}