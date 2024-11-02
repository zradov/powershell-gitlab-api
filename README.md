![Test Coverage](https://img.shields.io/badge/coverage-47%-red.svg?maxAge=60)

### powershell-gitlab-api

## A Powershell GitLab API wrapper

## Features

The Powershell GitLab API wrapper enables you to:

* create protected branches
* list projects
* list branches
* list users
* retrieve all files containing specific pattern
* get active projects
* retrieve details about merge requests 
* retrieve details about merge requests changes
* get raw file
* reopen closed merge requests
* delete merge requests
* compare branches in a project
* checking branches on two different GitLab servers to verify whether there are differences in commits.

## Installation

The code was developed and tested using PowerShell v7.4.5 (Core Edition) and Pester v5.6.1
The module can be installed by run the following command inside the project folder:
```PowerShell
Import-Module -Name "./gitlabapi.psm1"
```

In case when the command prefix is used the command for importing the module is:

```PowerShell
Import-Module -Name "./gitlabapi.psm1" -Prefix GitLab
```

In the case when the prefix is specified when importing the module, the command would like this e.g. **Get-GitLabUsers** instead of **Get-Users**.

> Specifing the command prefix when importing the module is advisable in order to prevent command name collision.

## Automated Tests

Automated tests are placed inside the **tests** subfolder.
The test code is written using the Pester framework.

To run the tests, including generating the code coverage report, run the following script block from within the project folder:

```PowerShell
$config = New-PesterConfiguration
$config.Run.Path = "./tests/unit"
$config.CodeCoverage.Path = "./gitlabapi.psm1"
$config.CodeCoverage.Enabled = $true

Invoke-Pester -Configuration $config
```


