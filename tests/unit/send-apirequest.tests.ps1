Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Send-ApiRequest" {
    InModuleScope gitlabapi {
        BeforeAll {
            # Common variables
            $Type = "GetProjects"
            $ApiArgs = @{
                Server = "gitlab.example.com"
                Project = "example/project"
            }
            $AccessToken = "fakeAccessToken"
            $MaxPages = 2
            $Raw = $true
            $AsBytes = $true

            # Mock Get-ApiUrl function
            Mock Get-ApiUrl {
                return "https://gitlab.example.com/api/v4/projects/example%2Fproject/something"
            }

            # Mock Get-HttpMethod function
            Mock Get-HttpMethod {
                return "GET"
            }

            # Mock Invoke-WebRequest function
            Mock Invoke-WebRequest {
                return @{
                    Content = '[{"data": "value"}]'
                    Headers = @{
                        "X-Next-Page" = @("")
                    }
                }
            }
        }

        It "should call Get-ApiUrl with correct parameters" {
            Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken

            Assert-MockCalled Get-ApiUrl -Exactly -Times 1 -Scope It -ParameterFilter {
                $Type -eq $Type -and $ApiArgs -eq $ApiArgs
            }
        }

        It "should call Get-HttpMethod with correct parameters" {
            Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken

            Assert-MockCalled Get-HttpMethod -Exactly -Times 1 -Scope It -ParameterFilter {
                $Type -eq $Type
            }
        }

        It "should call Invoke-WebRequest with correct parameters" {
            Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken

            Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter {
                $Headers["PRIVATE-TOKEN"] -eq $AccessToken -and
                $Uri -eq "https://gitlab.example.com/api/v4/projects/example%2Fproject/something" -and
                $Method -eq "GET"
            }
        }

        It "should return raw content when Raw switch is specified" {
            $result = Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken -Raw

            $result | Should -Be '[{"data": "value"}]'
        }

        It "should return content as bytes when AsBytes switch is specified" {
            Mock -CommandName Invoke-WebRequest -MockWith {
                return @{
                    RawContentStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes("raw content"))
                    Headers = @{
                        "X-Next-Page" = @("")
                    }
                }
            }

            $result = Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken -Raw -AsBytes

            $result | Should -Be ([System.Text.Encoding]::UTF8.GetBytes("raw content"))
        }

        It "should handle pagination correctly" {
            Mock -CommandName Invoke-WebRequest -MockWith {
                param ($Uri)
                if ($Uri -like "*page=2") {
                    return @{
                        Content = '[{"data": "value2"}]'
                        Headers = @{
                            "X-Next-Page" = @("")
                        }
                    }
                } else {
                    return @{
                        Content = '[{"data": "value1"}]'
                        Headers = @{
                            "X-Next-Page" = @("2")
                        }
                    }
                }
            }

            $result = Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken

            "$([PSCustomObject]$result[0])" | Should -Be "$([PSCustomObject]@{data = 'value1'})"
            "$([PSCustomObject]$result[1])" | Should -Be "$([PSCustomObject]@{data = 'value2'})"
        }

        It "should throw FailedAPIRequestException on error" {
            Mock -CommandName Invoke-WebRequest -MockWith {
                throw [FailedAPIRequestException]::new("API request failed", [System.Net.HttpStatusCode]::InternalServerError)
            }

            { Send-ApiRequest -Type $Type -ApiArgs $ApiArgs -AccessToken $AccessToken } | Should -Throw "API request failed"
        }
    }
}