Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-MergeRequestChanges" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $accessToken = "fake-token"
            $projects = @("group/project1", "group/project2")
            $targetBranch = "main"
            $sourceFilter = "feature*"
            $mergeRequestIds = @()
            $state = "merged"
            $fileFilter = "*.xml"
            $mergeRequests = @(
                [PSCustomObject]@{ MergeRequestId = 1; ProjectId = 1; ProjectFullName = "group/project1"; Source = "feature1"; Target = "main" },
                [PSCustomObject]@{ MergeRequestId = 2; ProjectId = 2; ProjectFullName = "group/project2"; Source = "feature2"; Target = "main" }
            )
            $mergeRequestChanges = @{
                changes = @(
                    [PSCustomObject]@{ new_path = "file1.xml"; deleted_file = $false },
                    [PSCustomObject]@{ new_path = "file2.txt"; deleted_file = $false }
                )
            }
        }

        BeforeEach {
            Mock Get-MergeRequests {
                return $mergeRequests
            }

            Mock Send-ApiRequest {
                return $mergeRequestChanges
            }
        }

        Context "When retrieving merge request changes" {
            It "should call Get-MergeRequests with correct parameters" {
                Get-MergeRequestChanges -Server $server -Projects $projects -Target $targetBranch -SourceFilter $sourceFilter `
                    -AccessToken $accessToken -MergeRequestIds $mergeRequestIds -State $state -FileFilter $fileFilter
                
                Assert-MockCalled Get-MergeRequests -Exactly 1 -Scope It -ParameterFilter {
                    $Server -eq $server -and
                    "$Projects" -eq "$projects" -and
                    $Target -eq $targetBranch -and
                    $AccessToken -eq $accessToken -and
                    $State -eq $state
                }
            }

            It "should call Send-ApiRequest with correct parameters" {
                Get-MergeRequestChanges -Server $server -Projects $projects -Target $targetBranch -SourceFilter $sourceFilter `
                    -AccessToken $accessToken -MergeRequestIds $mergeRequestIds -State $state -FileFilter $fileFilter
                
                Assert-MockCalled Send-ApiRequest -Exactly 2 -Scope It -ParameterFilter {
                    $Type -eq "GetMergeRequestChanges" -and
                    $AccessToken -eq $accessToken -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.ProjectId -in @(1, 2) -and
                    $ApiArgs.MergeRequestId -in @(1, 2)
                }
            }

            It "should return the correct list of changed files" {
                $result = Get-MergeRequestChanges -Server $server -Projects $projects -Target $targetBranch -SourceFilter $sourceFilter `
                    -AccessToken $accessToken -MergeRequestIds $mergeRequestIds -State $state -FileFilter $fileFilter
                
                $result.Count | Should -Be 1
                $result | Should -Be "file1.xml"
            }

            It "should handle errors gracefully" {
                Mock Send-ApiRequest {
                    throw "An error occurred"
                }
                $result = Get-MergeRequestChanges -Server $server -Projects $projects -Target $targetBranch -SourceFilter $sourceFilter `
                    -AccessToken $accessToken -MergeRequestIds $mergeRequestIds -State $state -FileFilter $fileFilter `
                    -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -Be $null
            }
        }
    }
}