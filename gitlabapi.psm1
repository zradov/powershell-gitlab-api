# A class that represents a GitLab server info.
class ServerInfo {
    # The GitLab server's hostname.
    [string] $Name
    # The GitLab server's IP address.
    [string] $IP
    # An access token for authenticating with the GitLab API.
    [string] $AccessToken

    ServerInfo([string] $name, [string] $ip, [string] $accessToken) {
        $this.Name = $name
        $this.IP = $ip
        $this.AccessToken = $accessToken
    }
}

class FailedAPIRequestException: System.Exception {
    [string] $StatusCode

    FailedAPIRequestException([string] $message, [string] $statusCode) : base ($message) {
        $this.StatusCode = $statusCode
    }
}

enum ApiEndpointType {
    NewProtectedBranch
    GetProtectedBranches
    RemoveProtectedBranch
    GetProjects
    GetProject
    GetGroups
    GetGroupProjects
    GetMergeRequests
    OpenMergeRequest
    GetMergeRequestChanges
    RemoveMergeRequests
    GetRawFile
    GetBranchesDiffs
    GetUsers
    GetCommits
}

Function Get-ApiUrl {
    <#
        .SYNOPSIS
            The function returns the URL of the GitLab API endpoint.

        .PARAMETER Type
            The type of API endpoint to return.

        .PARAMETER ApiArgs
            The arguments required when creating the API endpoint URL.

        .PARAMETER Port
            The port number of the GitLab server.

        .PARAMETER Protocol
            The protocol to use for the API endpoint.

        .OUTPUTS
            The URL of the GitLab API endpoint.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ApiEndpointType] $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [HashTable] $ApiArgs,

        [string] $Port = 80,

        [string] $Protocol = "http"
    )

    $customArgs = [PSCustomObject]$ApiArgs

    switch ($Type) {
        NewProtectedBranch {
            $encodedBranchName = [Uri]::EscapeDataString($customArgs.Name)
            $queryString = "name=$encodedBranchName&push_access_level=$($customArgs.AccessLevel)" +
                "&merge_access_level=$($customArgs.AccessLevel)&allow_force_push=$($customArgs.ForcePush)"
            $apiUrl = "projects/$($customArgs.ProjectId)/protected_branches?$queryString"
        }
        RemoveProtectedBranch {
            $encodedBranchName = [Uri]::EscapeDataString($customArgs.Name)
            $apiUrl = "projects/$($customArgs.ProjectId)/protected_branches/$encodedBranchName"
        }
        GetProtectedBranches { $apiUrl = "projects/$($customArgs.ProjectId)/protected_branches" }
        GetProjects { $apiUrl = "projects" }
        GetProject {
            $encodedProjectName = [Uri]::EscapeDataString($customArgs.ProjectName)
            $apiUrl = "projects/$encodedProjectName"
            
        }
        GetGroups { $apiUrl = "groups" }
        GetGroupProjects {
            $encodedGroupId = if ($customArgs.GroupId -match "^\d+$") { $customArgs.GroupId } else { 
                [Uri]::EscapeDataString($customArgs.GroupId) 
            }
            $apiUrl = "groups/$encodedGroupId/projects"
        }
        GetMergeRequests {
            $encodedTargetBranch = [Uri]::EscapeDataString($customArgs.Target)
            $apiUrl = "projects/$($customArgs.ProjectId)/merge_requests?state=$($customArgs.State)&target_branch=$encodedTargetBranch"
            if ($customArgs.Source) {
                $encodedSourceBranch = [Uri]::EscapeDataString($customArgs.Source)
                $apiUrl += "&source_branch=$encodedSourceBranch"
            }
        }
        OpenMergeRequest {
            $encodedProjectId = [Uri]::EscapeDataString($customArgs.ProjectId)
            $apiUrl = "projects/$encodedProjectId/merge_requests/$($customArgs.MergeRequestId)?state_event=reopen"
        }
        GetRawFile {
            $encodedFilePath = [Uri]::EscapeDataString($customArgs.FilePath)
            $encodedBranchName = [Uri]::EscapeDataString($customArgs.Branch)
            $encodedProjectId = [Uri]::EscapeDataString($customArgs.ProjectId)
            $apiUrl = "projects/$encodedProjectId/repository/files/$encodedFilePath/raw?ref=$encodedBranchName"
        }
        GetMergeRequestChanges {
            $apiUrl = "projects/$($customArgs.ProjectId)/merge_requests/$($customArgs.MergeRequestId)/changes"
        }
        RemoveMergeRequests {
            $encodedProjectName = [Uri]::EscapeDataString($customArgs.Project)
            $apiUrl = "projects/$encodedProjectName/merge_requests/$($customArgs.MergeRequestId)"
        }
        GetBranchesDiffs {
            $encodedProject = [Uri]::EscapeDataString($customArgs.Project)
            $encodedSource = [Uri]::EscapeDataString($customArgs.Source)
            $encodedTarget = [Uri]::EscapeDataString($customArgs.Target)
            $apiUrl = "projects/$encodedProject/repository/compare?from=$encodedSource&to=$encodedTarget"
        }
        GetUsers { $apiUrl = "users" }
        GetCommits {
            $apiUrl = "projects/$($customArgs.ProjectId)/repository/commits?ref_name=$($customArgs.Branch)"
        }
        default {
            throw "Unsupported API endpoint type: $Type"
        }
    }

    $apiUrl = "$Protocol`://$($customArgs.Server):$Port/api/v4/$apiUrl"

    return $apiUrl
}

Function New-ProtectedBranch {
    <#
        .SYNOPSIS
            This function creates a new protected branch and returns a boolean indicating the success of the operation.

        .PARAMETER Server
            The GitLab server's hostname or IP address.

        .PARAMETER ProjectId
            The unique identifier of the GitLab project where the new protected branch will be created.

        .PARAMETER Name
            The protected branch name.

        .PARAMETER AccessToken
            The GitLab API authentication token.

        .PARAMETER AccessLevel
            The protected branch access level.

            0  => No access
            30 => Developer access
            40 => Maintainer access
            60 => Admin access

        .PARAMETER ForcePush
            Should force push be allowed on the new protected branch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet("0", "30", "40", "60")]
        [string] $AccessLevel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [switch] $ForcePush
    )

    try {
        $apiUrl = Get-ApiUrl -Type NewProtectedBranch -ApiArgs @{
            Name = $Name;
            AccessLevel = $AccessLevel;
            ForcePush = if ($ForcePush) { "true" } else { "false" }; 
            Server = $Server;
            ProjectId = $ProjectId;
        }
        
        Write-Verbose "Creating the protected branch '$Name' in the project with ID '$ProjectId'."
        
        $response = Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = $AccessToken } -Method POST `
            -Uri $apiUrl -UseBasicParsing -SkipCertificateCheck

        if ($response.StatusCode -match "2\d\d") {
            Write-Verbose "Protected branch '$Name' created successfully with status code '$($response.StatusCode)'"
            return $true
        } else {
            Write-Error "Failed to create the protected branch '$Name' with error status code '$($response.StatusCode)'"
            return $false
        }
    } catch {
        Write-Error "An error occurred: $_"
        return $false
    }
}

Function Remove-ProtectedBranch {
    <#
        .SYNOPSIS
            The function deletes a protected branch and returns a boolean value indicating whether the operation was successful.
        
        .PARAMETER Server
            The GitLab server's hostname or IP address.
        
        .PARAMETER ProjectId
            The unique ID of the GitLab project from which the protected branch will be removed.

        .PARAMETER Name
            The name of the protected branch to be deleted.

        .PARAMETER AccessToken
            The access token for authenticating with the GitLab API.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken
    )

    try {
        $apiUrl = Get-ApiUrl -Type RemoveProtectedBranch -ApiArgs @{
            Name = $Name
            Server = $Server
            ProjectId = $ProjectId
        }

        Write-Verbose "Removing the protected branch '$Name' in the project with ID $ProjectId."
        
        $response = Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = $AccessToken } -Method DELETE `
            -Uri $apiUrl -UseBasicParsing -SkipCertificateCheck

        if ($response.StatusCode -match "2\d\d") {
            Write-Verbose "Successfully deleted the protected branch '$Name', status code: $($response.StatusCode)"
            return $true
        } else {
            Write-Error "Failed to delete the protected branch '$Name', status code: $($response.StatusCode)"
            return $false
        }
    } catch {
        Write-Error "An error occurred: $_"
        return $false
    }
}

Function Protect-Branches {
    <#
        .SYNOPSIS
            Protects the branch with the given name in the specified GitLab projects.

        .DESCRIPTION
            This function manages the protected branches list in specified GitLab projects. It supports parameters to include or exclude specific projects before performing the protected branch check.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.
        
        .PARAMETER Name
            The name of the branch to add to or remove from the protected branches list.

        .PARAMETER AccessToken
            The access token for authenticating with the GitLab API.
   
        .PARAMETER Include
            A list of GitLab projects or repositories to include in the protected branch check. Supports "*" wildcard for all projects.

        .PARAMETER Exclude
            A list of GitLab projects or repositories to exclude from the protected branch check. Does not support "*" wildcard.
        
        .PARAMETER AccessLevel
            The access level for the new protected branch, applied to both push and merge access levels.

        .PARAMETER ForcePush
            Indicates whether force push should be allowed on the new protected branch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [ValidateScript({ ($_ -is [string] -and $_ -ne "*") -or ($_ -is [array] -and "*" -notin $_) })]
        [object] $Include = "*",

        [ValidateScript({ ($_ -is [string] -and $_ -ne "*") -or ($_ -is [array] -and "*" -notin $_) -or $_ -eq [String]::Empty })]
        [object] $Exclude = [String]::Empty,

        [ValidateSet("0", "30", "40", "60")]
        [string] $AccessLevel = 40,

        [switch] $ForcePush
    )

    $ErrorActionPreference = "Stop"

    try {
        $projects = Get-Projects -Server $Server -AccessToken $AccessToken -Include $Include -Exclude $Exclude

        $totalProtectedBranchesCreated = 0
        $totalProtectedBranchesUpdated = 0

        foreach ($project in $projects) {
            $projectId = $project.id
            $projectFullPath = $project.path_with_namespace
            $protectedBranches = Send-ApiRequest -Type GetProtectedBranches -AccessToken $AccessToken `
                -ApiArgs @{ Server = $Server; ProjectId = $projectId }

            Write-Verbose "There are $($protectedBranches.Count) protected branch(es) in '$projectFullPath' project."
            $targetBranch = $protectedBranches | Where-Object { $_.name -eq $Name } | Select-Object -First 1

            if (!$targetBranch) {
                Write-Verbose "Adding branch protection to branch '$Name' in project '$projectFullPath'."
                New-ProtectedBranch -Server $Server -ProjectId $projectId -Name $Name `
                    -AccessLevel $AccessLevel -AccessToken $AccessToken -ForcePush:$ForcePush
                $totalProtectedBranchesCreated += 1
                continue
            }

            Write-Verbose "Checking permissions on the branch '$Name'."

            $branchPushAccessLevel = $targetBranch.push_access_levels.access_level
            $branchMergeAccessLevel = $targetBranch.merge_access_levels.access_level
            $branchForcePushAllowed = $targetBranch.allow_force_push

            if ($branchPushAccessLevel -eq $AccessLevel -and $branchMergeAccessLevel -eq $AccessLevel -and `
                $branchForcePushAllowed -ne $AllowForcePush) {
                Write-Verbose "No permission update is required on the branch '$Name'."
                continue
            }

            Write-Verbose "The branch '$Name' permissions not matching expected access level, fixing them."
            Remove-ProtectedBranch -Server $Server -ProjectId $projectId -Name $Name -AccessToken $AccessToken
            New-ProtectedBranch -Server $Server -Name $Name -ProjectId $projectId `
                -AccessToken $AccessToken -AccessLevel $AccessLevel -ForcePush:$ForcePush
            $totalProtectedBranchesUpdated += 1
        }

        Write-Verbose "Total protected branches created: $totalProtectedBranchesCreated"
        Write-Verbose "Total protected branches updated: $totalProtectedBranchesUpdated"
    } catch {
        Write-Error "An error occurred: $_"
    }
}

Function Unprotect-Branches {
    <#
        .SYNOPSIS
            Adds or removes a branch from the protected branches list in specified GitLab projects.

        .DESCRIPTION
            This function manages the protected branches list in specified GitLab projects. It supports parameters to include or exclude specific projects before performing the protected branch check.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.
        
        .PARAMETER Name
            The name of the branch to add to or remove from the protected branches list.

        .PARAMETER AccessToken
            The access token for authenticating with the GitLab API.
   
        .PARAMETER Include
            A list of GitLab projects or repositories to include in the protected branch check. Supports "*" wildcard for all projects.

        .PARAMETER Exclude
            A list of GitLab projects or repositories to exclude from the protected branch check. Does not support "*" wildcard.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [ValidateScript({ ($_ -is [string] -and $_ -ne "*") -or ($_ -is [array] -and "*" -notin $_) })]
        [object] $Include = "*",

        [ValidateScript({ ($_ -is [string] -and $_ -ne "*") -or ($_ -is [array] -and "*" -notin $_) -or $_ -eq [String]::Empty })]
        [object] $Exclude = [String]::Empty
    )

    $ErrorActionPreference = "Stop"

    try {
        $projects = Get-Projects -Server $Server -AccessToken $AccessToken -Include $Include -Exclude $Exclude
        $totalProtectedBranchesRemoved = 0

        foreach ($project in $projects) {
            $projectFullPath = $project.path_with_namespace
            $protectedBranches = Send-ApiRequest -AccessToken $AccessToken -Type GetProtectedBranches `
                -ApiArgs @{ Server = $Server; ProjectId = $project.id } `
                
            Write-Verbose "Found $($protectedBranches.Count) protected branch(es) in the project '$projectFullPath'."
            $targetBranch = $protectedBranches | Where-Object { $_.name -eq $Name } | Select-Object -First 1

            if ($targetBranch) {
                Write-Verbose "Removing branch protection from branch '$Name' in the project '$projectFullPath'."
                Remove-ProtectedBranch -Server $Server -ProjectId $project.id -Name $Name -AccessToken $AccessToken
                $totalProtectedBranchesRemoved += 1
            }
        }

        Write-Verbose "Total protected branches removed: $totalProtectedBranchesRemoved"
    } catch {
        Write-Error "An error occurred: $_"
    }
}

Function Get-Groups {
    <#
        .SYNOPSIS
            The function returns info about GitLab groups.

        .PARAMETER Server
            The GitLab server's hostname or IP address.

        .PARAMETER AccessToken
            The access token for authenticating with the GitLab API.
        
        .OUTPUTS
            An objects array containing info about the GitLab groups.

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken
    )

    $groupsInfo = Send-ApiRequest -Type GetGroups -ApiArgs @{ Server = $Server } -AccessToken $AccessToken

    return ,$groupsInfo
}

Function Get-GroupProjects {
    <#
        .SYNOPSIS
            Retrieves information about all GitLab projects within a specified group.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER AccessToken
            The access token used for authenticating with the GitLab API.

        .PARAMETER GroupId
            The unique identifier or name of the GitLab group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $GroupId
    )

    try {
        Write-Verbose "Retrieving info about projects belonging to a group with Id '$GroupId'."

        $groupProjects = Send-ApiRequest -AccessToken $AccessToken -Type GetGroupProjects `
            -ApiArgs @{ Server = $Server; GroupId = $GroupId }

        return $groupProjects
    } catch {
        Write-Error "An error occurred while retrieving group projects: $_"
        return $null
    }
}
    
Function Get-Projects {
    <#
        .SYNOPSIS
            Fetches information about all or specific GitLab projects.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER AccessToken
            The access token used to authenticate with the GitLab API.

        .PARAMETER Include
            Determines which GitLab projects to include in the results.
            Can use the "*" wildcard to match all projects or an array of specific project names.
            Project names should follow the format PROJECT_GROUP/PROJECT_NAME.

        .PARAMETER Exclude
            Determines which GitLab projects to exclude from the results.
            Cannot use the "*" wildcard.
            Project names should follow the format PROJECT_GROUP/PROJECT_NAME.

        .OUTPUTS
            An array of objects containing details about the GitLab projects that meet the specified criteria.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [ValidateScript({ $_ -is [string] -or $_ -is [array] })]
        [object] $Include = "*",

        [ValidateScript({ ($_ -eq [String]::Empty -or $_ -is [string] -or $_ -is [array]) -and $_ -ne "*" })]
        [object] $Exclude = [String]::Empty
    )

    try {
        $allProjects = @()

        if ($Include -eq "*") {
            Write-Verbose "Retrieving all projects from $apiUrl."
            $allProjects = Send-ApiRequest -Type GetProjects -ApiArgs @{ Server = $Server } -AccessToken $AccessToken
        } else {
            Write-Verbose "Retrieving specified projects from $apiUrl."
            foreach ($projectName in $Include) {
                $project = Send-ApiRequest -AccessToken $AccessToken -Type GetProject `
                    -ApiArgs @{ ProjectName = $projectName; Server = $Server } 

                if ($project) {
                    $allProjects += $project
                } else {
                    Write-Verbose "Project '$projectName' not found."
                }
            }
        }
        Write-Verbose "Found $($allProjects.Count) projects."
        $selectedProjects = $allProjects | Where-Object {
            ($Include -eq "*" -or $_.path_with_namespace -in $Include) -and `
                ($Exclude -eq [String]::Empty -or $_.path_with_namespace -notin $Exclude)
        }
        Write-Verbose "Selected $($selectedProjects.Count) projects."

        return $selectedProjects
    } catch {
        Write-Error "An error occurred while retrieving GitLab projects: $_"
        return $null
    }
}
    
Function Get-MergeRequests {
    <#
        .SYNOPSIS
            Fetches information about all merge requests within specified GitLab projects.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER Projects
            An array of GitLab projects to look for merge requests.
            Project names should follow the format PROJECT_GROUP/PROJECT_NAME.

        .PARAMETER Target
            The target branch for the merge requests.

        .PARAMETER AccessToken
            The access token used to authenticate with the GitLab API.

        .PARAMETER Source
            The source branch for the merge requests.

        .PARAMETER State
            The current status of the merge requests.

        .PARAMETER DateTimeFormat
            The format of the date and time in the merge request.

        .OUTPUTS
            An array of objects representing merge requests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [array] $Projects,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [string] $Source = [String]::Empty,

        [string] $State = "opened",

        [string] $DateTimeFormat = "MM\/dd\/yyyy HH:mm:ss"
    )

    try {
        $mergeRequests = @()
        $projectsInfo = Get-Projects -Server $Server -Include $Projects -AccessToken $AccessToken

        if ($projectsInfo) {
            foreach ($project in $projectsInfo) {
                $projectFullName = $project.path_with_namespace
                Write-Verbose "Fetching information about the merge requests in the '$projectFullName' project."
                $data = Send-ApiRequest -AccessToken $AccessToken -Type GetMergeRequests -ApiArgs @{ 
                    Server = $Server; 
                    ProjectId = $project.id; 
                    Target = $Target; 
                    State = $State; 
                    Source = $Source 
                }

                if ($data) {
                    foreach ($mr in $data) {
                        $mergeRequests += [PSCustomObject]@{
                            MergeRequestId  = $mr.iid
                            Source          = $mr.source_branch
                            Target          = $mr.target_branch
                            ProjectId       = $mr.project_id
                            ProjectUrl      = $project.http_url_to_repo
                            ProjectName     = $project.path
                            ProjectFullName = $projectFullName
                            State           = $mr.state
                            Url             = $mr.web_url
                            CreatedAt       = [System.DateTime]::ParseExact(
                                $mr.created_at, $DateTimeFormat, $null).ToString($DateTimeFormat)
                        }
                    }
                }
            }
        }

        return $mergeRequests
    } catch {
        Write-Error "An error occurred while retrieving merge requests: $_"
        return $null
    }
}
    
Function Open-MergeRequests {
    <#
        .SYNOPSIS
            Changes the state of merge requests in the specified repositories to "reopen".

        .PARAMETER Server
            GitLab server's hostname or IP address.

        .PARAMETER Projects
            A list of GitLab projects to search for merge requests.
            Project names should follow the format PROJECT_GROUP/PROJECT_NAME.

        .PARAMETER Target
            The target branch for the merge requests.

        .PARAMETER AccessToken
            The access token used to authenticate with the GitLab API.

        .PARAMETER Source
            The source branch for the merge requests.

        .PARAMETER State
            The current state of the merge requests that need to be reopened.

        .OUTPUTS
            An array of objects with details about the merge requests that have been reopened.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [array] $Projects,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [string] $Source = [String]::Empty,

        [string] $State = "closed"
    )

    try {
        $mergeRequests = Get-MergeRequests -Server $Server -Projects $Projects `
            -Target $Target -Source $Source -AccessToken $AccessToken -State $State

        if ($mergeRequests) {
            foreach ($mergeRequest in $mergeRequests) {
                $apiUrl = Get-ApiUrl -Type OpenMergeRequest -ApiArgs @{
                    Server = $Server; 
                    ProjectId = $mergeRequest.ProjectId; 
                    MergeRequestId = $mergeRequest.MergeRequestId
                }
                Write-Verbose "Reopening merge request ID '$($mergeRequest.MergeRequestId)' in project '$($mergeRequest.ProjectId)'."
                Send-ApiRequest -AccessToken $AccessToken -Type OpenMergeRequest -ApiArgs @{
                    Server = $Server; 
                    ProjectId = $mergeRequest.ProjectId; 
                    MergeRequestId = $mergeRequest.MergeRequestId
                } | Out-Null
            }
        }

        return $mergeRequests
    } catch {
        Write-Error "An error occurred while reopening merge requests: $_"
        return $null
    }
}

Function Initialize-Repository {
    <#
        .SYNOPSIS
            Clones a specified Git repository into a designated directory.

        .PARAMETER Url
            The URL of the Git repository to be cloned.

        .PARAMETER AccessToken
            The access token used for authentication with the GitLab API.

        .PARAMETER ClonedPath
            The full path to the directory where the Git repository will be cloned.

        .PARAMETER Shallow
            Specifies whether to perform a shallow clone of the repository.

        .OUTPUTS
            A string representing the full path to the cloned repository.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Url,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $AccessToken,

        [string] $ClonedPath = $env:TEMP,

        [switch] $Shallow
    )

    try {
        $output = git -C "$ClonedPath" rev-parse --is-inside-work-tree 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Verbose -Message "$ClonedPath already contains a Git repository."
            return "$ClonedPath"
        }

        Write-Verbose -Message "Validating the repository URL."
        if ($Url -notmatch "(http[s]?://)(.*)") {
            throw "Repository URL '$Url' is not valid."
        }

        $repoUri = "$($matches[1])oauth2:$AccessToken@$($matches[2])"

        $repoPathWithId = Join-Path -Path $ClonedPath -ChildPath (New-Guid).Guid

        $shallowCloneOptions = if ($Shallow) { "--depth 1" } else { "" }

        Write-Verbose -Message "Repo URI: $repoUri"
        Write-Verbose -Message "Cloning repository $Url to $repoPathWithId."
        
        $result = Invoke-Expression -Command "git clone -c core.longpaths=true -c http.sslVerify=false $shallowCloneOptions $repoUri '$repoPathWithId'"

        if ($LASTEXITCODE -gt 0) {
            throw $result
        }

        return "$repoPathWithId"
    } catch {
        Write-Error "An error occurred: $_"
        return $null
    }
}

Function Get-RawFile {
    <#
        .SYNOPSIS
            Retrieves a file from a GitLab repository and returns its content.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER ProjectId
            The unique identifier of the GitLab project.

        .PARAMETER Branch
            The branch where the file is located.

        .PARAMETER FilePath
            The path to the file relative to the repository root.

        .PARAMETER AccessToken
            The access token used for authenticating with the GitLab API.

        .OUTPUTS
            An array of bytes representing the file's content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken
    )

    try {
        $result = Send-ApiRequest -Type GetRawFile -AccessToken $AccessToken -Raw -AsBytes -ApiArgs @{
            Server = "$Server";
            FilePath = "$FilePath"; 
            Branch = "$Branch"; 
            ProjectId = "$ProjectId" 
        }

        return $result
    } catch {
        Write-Error "An error occurred while downloading the file: $_"
        return $null
    }
}
    
Function Get-MergeRequestChanges {
    <#
        .SYNOPSIS
            Retrieves a list of file names that have been modified in merge requests.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER Projects
            A list of GitLab projects to search for merge requests.
            Project names should be in the format PROJECT_GROUP/PROJECT_NAME.

        .PARAMETER Target
            The target branch for the merge requests.

        .PARAMETER SourceFilter
            A filter to exclude merge requests from non-feature branches.

        .PARAMETER AccessToken
            The access token used for authentication with the GitLab API.

        .PARAMETER MergeRequestIds
            A list of IDs for specific merge requests.

        .PARAMETER State
            The state of the merge requests to be retrieved.

        .PARAMETER FileFilter
            A filter for the files changed in the merge requests.

        .OUTPUTS
            A list of file names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [array] $Projects,

        [Parameter(Mandatory = $true)]
        [string] $Target,

        [Parameter(Mandatory = $true)]
        [string] $SourceFilter,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken,

        [array] $MergeRequestIds = @(),

        [string] $State = "merged",

        [string] $FileFilter = $null
    )

    try {
        $mergeRequests = Get-MergeRequests -Server $Server -Projects $Projects -Target $Target `
            -AccessToken $AccessToken -State $State
        $changedFiles = @()

        if (!$mergeRequests) {
            Write-Verbose "No merge requests found."
            return $null
        }

        $mergeRequests | Where-Object { $_.Source -ilike "$SourceFilter" -and `
            ($MergeRequestIds.Count -eq 0 -or $_.MergeRequestId -in $MergeRequestIds) } | ForEach-Object {
            $projectFullName = $_.ProjectFullName
            $mergeRequestId = $_.MergeRequestId

            $mergeRequestChanges = Send-ApiRequest -Type GetMergeRequestChanges -AccessToken $AccessToken -ApiArgs @{
                Server = $Server;
                ProjectId = $_.ProjectId;
                MergeRequestId = $_.MergeRequestId
            }

            if ($mergeRequestChanges.overflow) {
                throw "Reached diff size limits in the project '$projectFullName' for the merge request with ID '$mergeRequestId'."
            }

            $mergeRequestChanges.changes | ForEach-Object {
                $newPath = $_.new_path
                if (-not $_.deleted_file -and (!$FileFilter -or ($newPath -ilike $FileFilter))) {
                    Write-Verbose "Adding file '$newPath', project '$projectFullName', merge request ID '$mergeRequestId'."
                    $changedFiles += $newPath
                }
            }
        }

        $uniqueFiles = $changedFiles | Sort-Object | Select-Object -Unique

        return $uniqueFiles
    } catch {
        Write-Error "An error occurred while retrieving merge request changes: $_"
        return $null
    }
}
    
Function Remove-MergeRequests {
    <#
        .SYNOPSIS
            Removes GitLab merge requests with the specified IDs.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER Project
            The unique identifier or full name of the GitLab project.

        .PARAMETER MergeRequestIds
            A list of merge request IDs to be deleted.

        .PARAMETER AccessToken
            The access token used to authenticate with the GitLab API.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [array] $MergeRequestIds,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken
    )

    $ErrorActionPreference = "Stop"

    try {
        foreach ($mergeRequestId in $MergeRequestIds) {
            Write-Verbose "Removing GitLab merge request with ID '$mergeRequestId' in the project '$Project'."
            Send-ApiRequest -Type RemoveMergeRequests -AccessToken $AccessToken -Raw -ApiArgs @{
                Server = $Server;
                Project = $Project;
                MergeRequestId = $mergeRequestId
            } | Out-Null
        }
    } catch {
        Write-Error "An error occurred while removing merge requests: $_"
    }
}
    
Function Compare-Branches {
    <#
        .SYNOPSIS
            Compares two branches within a GitLab project and returns the number of commits 
            by which the target branch is ahead of the source branch.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER Project
            The unique identifier or full name of the GitLab project.

        .PARAMETER Source
            The name of the source branch.

        .PARAMETER Target
            The name of the target branch.

        .PARAMETER AccessToken
            The access token used for authentication with the GitLab API.

        .OUTPUTS
            The number of commits by which the target branch is ahead of the source branch, or "/" if the project or branches do not exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [string] $Source,

        [Parameter(Mandatory = $true)]
        [string] $Target,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken
    )

    $ErrorActionPreference = "Stop"

    try {
        Write-Verbose "Comparing branches '$Source' and '$Target' in project '$Project'."
        $response = Send-ApiRequest -Type GetBranchesDiffs -AccessToken $AccessToken -ApiArgs @{
            Server = $Server;
            Project = $Project;
            Source = $Source;
            Target = $Target
        }
        $commitsCount = $response.commits.Count
    } catch [FailedAPIRequestException] {
        Write-Host "$($_.Exception.StatusCode)"
        if ($_.Exception.StatusCode -eq "NotFound") {
            Write-Verbose "The GitLab project with ID $Project or branches '$Source' or '$Target' do not exist."
            return "/"
        } else {
            throw "An error occurred while comparing GitLab branches: $($_.Exception.Message)"
        }
    }

    return $commitsCount
}

Function Get-HttpMethod {
    <#
        .SYNOPSIS
            The function returns the HTTP method for the specified API endpoint type.

        .PARAMETER Type
            The type of the API endpoint.

        .OUTPUTS
            The HTTP method for the specified API endpoint type.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ApiEndpointType] $Type
    )

    switch -Regex ($Type) {
        "^Get" { return "GET" }
        "^Open" { return "PUT" }
        "^Remove" { return "DELETE" }
    }
}

Function Send-ApiRequest {
    <#
        .SYNOPSIS
            Retrieves data from a GitLab API endpoint.
            Iterates over the specified number of pages and returns all data.

        .PARAMETER Type
            The type of API endpoint to return.

        .PARAMETER ApiArgs
            The data required for creating the API endpoint URL.

        .PARAMETER AccessToken
            The access token used for API authentication.

        .PARAMETER MaxPages
            The maximum number of pages to iterate over.
            If not specified, the function will iterate over all pages.

        .PARAMETER Raw
            Indicates whether the API request returns a single result or multiple results.
            When specified, the API response will contain either a single result or no results at all.

        .PARAMETER AsBytes
            Indicates whether to convert the API response content to an array of bytes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ApiEndpointType] $Type,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [HashTable] $ApiArgs,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken,

        [int] $MaxPages = [Int32]::MaxValue,

        [switch] $Raw,

        [switch] $AsBytes
    )

    $ErrorActionPreference = "Stop"

    # PowerShell by default uses TLS 1.0, which is not supported by GitLab.
    # This line forces newer versions of the TLS protocols to be used.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

    $data = $null
    $currentApiUrl = Get-ApiUrl -Type $Type -ApiArgs $ApiArgs
    $httpMethod = Get-HttpMethod -Type $Type
    $accessTokenPreview = $AccessToken.Substring(0, 10) + "*" * ($AccessToken.Length - 10)

    Write-Verbose "API Url: $currentApiUrl"
    Write-Verbose "HTTP method: $HttpMethod"
    Write-Verbose "Access-Token (preview): $accessTokenPreview"

    try {
        do {
            $response = Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = $AccessToken; "Accept" = "application/json" } `
                -Uri $currentApiUrl -Method $HttpMethod -UseBasicParsing -SkipCertificateCheck

            # In case of raw data request, just return the response content and exit the function.
            if ($Raw) {
                if ($AsBytes) {
                    $data = $response.RawContentStream.ToArray()
                } else {
                    $data = $response.Content
                }
                break
            }

            Write-Verbose "Response content: $($response.Content)"
            
            $jsonData = ConvertFrom-Json -InputObject $response.Content

            if ($jsonData -is [Array]) {
                $data += $jsonData
            } else {
                $data += @($jsonData)
            }

            if (!$response.Headers["X-Next-Page"]) {
                break
            }

            $nextPage = [int]$response.Headers["X-Next-Page"][0]

            Write-Verbose "Next page: $nextPage"

            if ($nextPage) {
                if ($currentApiUrl -ilike "*?page=*") {
                    $currentApiUrl = $currentApiUrl -replace "\?page=\d*", "?page=$nextPage"
                } else {
                    if ($currentApiUrl.Contains("?")) {
                        $currentApiUrl = $currentApiUrl + "&page=$nextPage"
                    } else {
                        $currentApiUrl = $currentApiUrl + "?page=$nextPage"
                    }
                }
            }

            Write-Verbose "Current API endpoint after updating the page number: $currentApiUrl"
        } while ($nextPage -and $nextPage -le $MaxPages)
    } catch {
        throw [FailedAPIRequestException]::new($_.Exception.Message, $_.Exception.Response.StatusCode)
    }

    return $data
}
    
Function Get-Users {
    <#
        .SYNOPSIS
            Retrieves a dictionary of GitLab servers and their users.

        .PARAMETER Servers
            An array of GitLab servers.

        .PARAMETER State
            The state of the users to include in the results. Users in other states will be excluded.

        .PARAMETER Ignore
            An array of usernames to be ignored.

        .OUTPUTS
            A dictionary mapping GitLab servers to their users.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ServerInfo[]] $Servers,

        [string] $State = "active",

        [string[]] $Ignore = @()
    )

    $allUsers = @{}

    Write-Verbose "Fetching information about users from GitLab servers."

    foreach ($server in $Servers) {
        try {
            $users = Send-ApiRequest -Type GetUsers -AccessToken $server.AccessToken -ApiArgs @{ Server = $server.IP }

            $filteredUsers = $users | Where-Object {
                $_.state -eq $State -and -not ($Ignore | ForEach-Object { $_ -ilike $_.username })
            } | Select-Object -Property name, username

            Write-Verbose "Fetched users from server: $($server.IP), total users: $($filteredUsers.Count)"

            $filteredUsers = $filteredUsers | ForEach-Object { $_.name = $_.name.Trim(); $_ }
            $filteredUsers = $filteredUsers | Sort-Object -Property username -Unique

            $allUsers[$server.Name] = $filteredUsers
        } catch {
            Write-Error "An error occurred while fetching users from server: $($server.IP). Error: $_"
        }
    }

    return $allUsers
}

Function Get-Commits {
    <#
        .SYNOPSIS
            Fetches a specified number of commits from a GitLab project.

        .PARAMETER Server
            The URL of the GitLab server, including the protocol (http or https) and the domain name or IP address.

        .PARAMETER AccessToken
            The access token used for API authentication.

        .PARAMETER ProjectId
            The unique identifier of the GitLab project.

        .PARAMETER Branch
            The branch name. Defaults to "master".

        .PARAMETER MaxCommits
            The maximum number of commits to retrieve. Defaults to 10.

        .PARAMETER PageSize
            The number of commits to retrieve per page. Defaults to 20.

        .OUTPUTS
            An array of commits.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken,

        [Parameter(Mandatory = $true)]
        [int] $ProjectId,

        [string] $Branch = "main",

        [int] $MaxCommits = 10,

        [int] $PageSize = 20
    )

    try {
        $maxPages = [Math]::Ceiling($MaxCommits / $PageSize)

        $commits = Send-ApiRequest -Type GetCommits -AccessToken $AccessToken -MaxPages $maxPages -ApiArgs @{
            Server = $Server;
            ProjectId = $ProjectId;
            Branch = $Branch
        }
        $commits = $commits | Select-Object -First $MaxCommits

        return $commits
    } catch {
        Write-Error "An error occurred while retrieving commits: $_"
        return $null
    }
}
   
Function Test-CommitsSync {
    <#
        .SYNOPSIS
            Verifies whether branches on two different GitLab servers differ regarding commits.

        .PARAMETER Source
            A source server info.

        .PARAMETER Target
            A target server info.

        .PARAMETER Branches
            A list of GitLab branches to compare for differences.

        .PARAMETER IncludeRepos
            A list of GitLab repositories to include in the branches comparison.

        .OUTPUTS
            An array of unsynchronized commits.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ServerInfo] $Source,

        [Parameter(Mandatory = $true)]
        [ServerInfo] $Target,

        [string[]] $Branches = @("main"),

        [object] $IncludeRepos = "*"
    )

    try {
        $sourceProjects = Get-Projects -Server $Source.Name -AccessToken $Source.AccessToken -Include $IncludeRepos
        $targetProjects = Get-Projects -Server $Target.Name -AccessToken $Target.AccessToken -Include $IncludeRepos
    } catch {
        Write-Error "An error occurred while retrieving projects: $_"
        return
    }

    $unsyncedCommits = @()

    foreach ($sourceProject in $sourceProjects) {
        $targetProject = $targetProjects | Where-Object { $_.path_with_namespace -eq $sourceProject.path_with_namespace }
        if (-not $targetProject) {
            Write-Verbose "Skipping project $($sourceProject.path_with_namespace) that is not found on target server."
            continue
        }

        foreach ($branch in $Branches) {
            Write-Verbose "Looking for different commits in the project '$($targetProject.path_with_namespace)' for the branch '$branch'."

            try {
                $sourceCommit = Get-Commits -Server $Source.Name -AccessToken $Source.AccessToken `
                    -ProjectId $sourceProject.id -Branch $branch -MaxCommits 1
                $targetCommit = Get-Commits -Server $Target.Name -AccessToken $Target.AccessToken `
                    -ProjectId $targetProject.id -Branch $branch -MaxCommits 1
            } catch {
                Write-Error "An error occurred while retrieving commits: $_"
                continue
            }

            if ($sourceCommit.id -ne $targetCommit.id) {
                Write-Verbose "The commit with ID '$($sourceCommit.id)' does not exist in the project '$($targetProject.path_with_namespace)' on the server '$($Target.Name)'."
                $unsyncedCommits += [PSCustomObject]@{
                    Project     = $sourceProject.path_with_namespace
                    Author      = $sourceCommit.author_name
                    BranchName  = $branch
                    CommitID    = $sourceCommit.id
                    Date        = $sourceCommit.authored_date
                }
            } else {
                Write-Verbose "Commits verification successful for the branch '$branch' in the project '$($targetProject.path_with_namespace)'."
            }
        }
    }

    Write-Verbose "Unsynced commits total: $($unsyncedCommits.Count)"

    return ,$unsyncedCommits
}
    
Function Get-ActiveProjects {
    <#
        .SYNOPSIS
            Fetches a specified number of the most recently active projects.

        .PARAMETER Server
            The hostname or IP address of the GitLab server.

        .PARAMETER AccessToken
            The access token used for authentication with the GitLab server.

        .PARAMETER Days
            The number of days to look back to find the most active projects.

        .PARAMETER MaxProjects
            The maximum number of projects to retrieve.

        .OUTPUTS
            An array of the most recently active projects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken,

        [int] $Days = 2,

        [int] $MaxProjects = [Int32]::MaxValue
    )

    try {
        Write-Verbose "Retrieving projects from GitLab server $Server."
        $projects = Get-Projects -Server $Server -AccessToken $AccessToken

        $dateThreshold = (Get-Date).AddDays(-$Days)
        Write-Verbose "Filtering projects with activity after $dateThreshold."

        $activeProjects = $projects | Where-Object {
            $_.last_activity_at -gt $dateThreshold
        } | Sort-Object -Property last_activity_at -Descending

        $activeProjects = $activeProjects | Select-Object -First $MaxProjects

        return $activeProjects
    } catch {
        Write-Error "An error occurred while retrieving active projects: $_"
        return $null
    }
}
    
Function Find-PatternInFiles {
    <#
        .SYNOPSIS
            Scans specified files for lines containing the specified patterns.

        .PARAMETER Path
            The full path to the directory where the files will be searched.

        .PARAMETER SearchPatterns
            A list of regex patterns to look for within the files.

        .PARAMETER FilesPattern
            A list of file names or patterns to include in the search.

        .OUTPUTS
            A collection of objects with details about the files containing data with the specified patterns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $SearchPatterns,

        [Parameter(Mandatory = $true)]
        [string[]] $FilesPattern
    )

    $data = @()

    try {
        foreach ($filePattern in $FilesPattern) {
            $files = Get-ChildItem -Path $Path -Filter $filePattern -Recurse -File -Force
            Write-Verbose "Found $($files.Count) files matching the filter $filePattern."

            foreach ($file in $files) {
                foreach ($pattern in $SearchPatterns) {
                    $matchInfos = Get-ChildItem -Path $file.FullName | Select-String -Pattern $pattern -AllMatches

                    if ($matchInfos.Count -gt 0) {
                        Write-Verbose "Found $($matchInfos.Count) match(es) for pattern '$pattern' in the file '$($file.FullName)'."
                        $matchedLines = $matchInfos | ForEach-Object {
                            [PSCustomObject]@{
                                LineNumber = $_.LineNumber
                                Line       = $_.Line.Trim()
                            }
                        }
                        $data += [PSCustomObject]@{
                            File         = $file.Name
                            Path         = [System.IO.Path]::GetRelativePath($Path, $file.FullName)
                            Pattern      = $pattern
                            MatchedLines = $matchedLines
                        }
                    }
                }
            }
        }
    } catch {
        Write-Error "An error occurred while searching for PII data: $_"
    }

    return $data
}
    
Function Get-FilesContainingPattern {
    <#
        .SYNOPSIS
            Scans specified GitLab projects for files containing specified pattern.

        .PARAMETER Server
             The GitLab server's hostname or IP address.

        .PARAMETER AccessToken
            The access token used for authentication with the GitLab API.

        .PARAMETER IncludeFiles
            A list of file names or patterns to include in the search.

        .PARAMETER SearchPatterns
            A list of regex patterns to search for within the files.

        .PARAMETER Branches
            A list of GitLab branches to search within each repository.
            The first branch in the list that exists in a repository will be used as the default branch for the repository checkout.

        .PARAMETER IncludeProjects
            A list of GitLab projects to include in the search.
            Can contain the "*" wildcard to match all projects or an array of specific project names.
            Project names should follow the format PROJECT_GROUP/PROJECT_NAME.

        .PARAMETER ExcludeProjects
            A list of GitLab projects to exclude from the search.
            Cannot contain the "*" wildcard.
            Project names should follow the format PROJECT_GROUP/PROJECT_NAME.

        .OUTPUTS
            A collection of objects with details about the files containing the specified pattern.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken,

        [Parameter(Mandatory = $true)]
        [string[]] $IncludeFiles,

        [Parameter(Mandatory = $true)]
        [string[]] $SearchPatterns,

        [string[]] $Branches = @("main"),

        [ValidateScript({ ($_ -is [string] -and $_ -eq "*") -or ($_ -is [array] -and "*" -notin $_) })]
        [object] $IncludeProjects = "*",

        [ValidateScript({ ($_ -is [string] -and $_ -ne "*") -or ($_ -is [array] -and "*" -notin $_) -or $_ -eq [String]::Empty })]
        [object] $ExcludeProjects = [String]::Empty
    )

    try {
        $projects = Get-Projects -Server $Server -AccessToken $AccessToken -Include $IncludeProjects -Exclude $ExcludeProjects

        if (!$projects) {
            Write-Verbose "No projects found on the GitLab server '$Server'."
            return
        }

        $piiDataPerProject = @()

        $projects | ForEach-Object -Begin { $index = 1; $projectsCount = $projects.Count } -Process {
            Write-Verbose "Searching for PII data in the project '$($_.path_with_namespace)'."
            $clonedRepoPath = Initialize-Repository -Url "$($_.http_url_to_repo)" -AccessToken $AccessToken -Shallow
            $availableBranches = git -C "$clonedRepoPath" branch -r | ForEach-Object { $_.Trim() }
            $branchToCheck = $Branches | Where-Object { "origin/$_" -in $availableBranches } | Select-Object -First 1

            try {
                if (!$branchToCheck) {
                    Write-Verbose "Branches $Branches not found in the project '$($_.path_with_namespace)'."
                    return
                }

                Write-Verbose "Found branch $branchToCheck, checking out."
                $output = git -C "$clonedRepoPath" checkout "$branchToCheck" 2>&1
                if ($LASTEXITCODE -gt 0) { throw $output }

                $data = Find-PatternInFiles -Path "$clonedRepoPath" -SearchPatterns $SearchPatterns -FilesPattern $IncludeFiles
                if ($data) {
                    Write-Verbose "Found $($data.Count) lines in files found in the project '$($_.path_with_namespace)'."
                    $dataPerProject += [PSCustomObject]@{
                        Project = $_.path_with_namespace
                        Data = $data
                    }
                } else {
                    Write-Verbose "No files containing the specified patterns found in the project '$($_.path_with_namespace)'."
                }
            } finally {
                Write-Verbose "Removing cloned repo $clonedRepoPath."
                Remove-Item -Path "$clonedRepoPath" -Recurse -Force
                Write-Verbose "Total projects processed: $([Math]::Round($index / $projectsCount, 4) * 100)%"
                $index += 1
            }
        }

        return $dataPerProject
    } catch {
        Write-Error "An error occurred while searching for files containing patterns: $_"
    }
}

Export-ModuleMember -Function New-ProtectedBranch
Export-ModuleMember -Function Get-Projects
Export-ModuleMember -Function Get-Branches
Export-ModuleMember -Function Get-Commits
Export-ModuleMember -Function Get-Users
Export-ModuleMember -Function Get-FilesContainingPattern
Export-ModuleMember -Function Get-ActiveProjects
Export-ModuleMember -Function Get-MergeRequests
Export-ModuleMember -Function Get-MergeRequestChanges
Export-ModuleMember -Function Get-RawFile
Export-ModuleMember -Function Open-MergeRequests
Export-ModuleMember -Function Remove-MergeRequests
Export-ModuleMember -Function Test-CommitsSync
Export-ModuleMember -Function Compare-Branches