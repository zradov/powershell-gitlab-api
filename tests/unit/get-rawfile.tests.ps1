Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-RawFile" {
    InModuleScope gitlabapi {
        BeforeAll {
            $server = "gitlab.example.com"
            $projectId = "123"
            $branch = "main"
            $filePath = "path/to/file.txt"
            $accessToken = "fake-token"
            $fileContent = [System.Text.Encoding]::UTF8.GetBytes("Sample file content")
        }

        BeforeEach {
            Mock Send-ApiRequest {
                return $fileContent
            }
        }

        Context "When retrieving a raw file" {
            It "should call Send-ApiRequest with correct parameters" {
                Get-RawFile -Server $server -ProjectId $projectId -Branch $branch -FilePath $filePath -AccessToken $accessToken

                Assert-MockCalled Send-ApiRequest -Exactly 1 -Scope It -ParameterFilter {
                    $Type -eq "GetRawFile" -and
                    $AccessToken -eq $accessToken -and
                    $Raw -eq $true -and
                    $AsBytes -eq $true -and
                    $ApiArgs.Server -eq $server -and
                    $ApiArgs.FilePath -eq $filePath -and
                    $ApiArgs.Branch -eq $branch -and
                    $ApiArgs.ProjectId -eq $projectId
                }
            }

            It "should return the correct file content" {
                $result = Get-RawFile -Server $server -ProjectId $projectId -Branch $branch `
                    -FilePath $filePath -AccessToken $accessToken

                $result | Should -Be $fileContent
            }

            It "should handle errors gracefully" {
                Mock Send-ApiRequest {
                    throw "An error occurred"
                }

                $result = Get-RawFile -Server $server -ProjectId $projectId -Branch $branch -FilePath $filePath `
                    -AccessToken $accessToken -ErrorAction SilentlyContinue -ErrorVariable err

                $result | Should -Be $null
            }
        }
    }
}