Import-Module -Name ([IO.Path]::Combine("$PSScriptRoot", "..", "..", "gitlabapi.psm1")) -Force

Describe "Get-HttpMethod" {
    InModuleScope gitlabapi { 
        BeforeAll {
            # Common variables
            $GetType = "GetProject"
            $OpenType = "OpenMergeRequest"
            $RemoveType = "RemoveMergeRequest"
            $UnknownType = "UnknownType"
        }

        It "should return GET for Get type" {
            $result = Get-HttpMethod -Type $GetType
            $result | Should -Be "GET"
        }

        It "should return PUT for Open type" {
            $result = Get-HttpMethod -Type $OpenType
            $result | Should -Be "PUT"
        }

        It "should return DELETE for Remove type" {
            $result = Get-HttpMethod -Type $RemoveType
            $result | Should -Be "DELETE"
        }
    }
}