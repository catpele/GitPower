<#
	.SYNOPSIS PowerShell Module for Active Directory and GitHub API Automation
	
	.DESCRIPTION
	This module provides a number of tools for helping to automate the provisioning, editing and removal
	of GitHub users from your GitHub Organisation, as well as some reporting functions.
	
	It's aimed at small businesses who want to manage and automate provisioning without a GitHub Enterprise
	account or SAML/SSO infrastructure. I'd always recommend a dedicated SSO app (ADFS, etc) where possible.
		
	The user's GitHub username is stored in an Active Directory attribute (Default: 'info'). For the brave,
	I'd recommend creating a custom AD user attibute by editing the schema to make it obvious to future
	administrators what the attribute is storing (ie. 'contoso-github-username').
	
	You'll need a GitHub API Token for most of the functions in this module to work. I'd highly recommend
	creating a dedicated 'service' user account in your organisation for this or using an OAuth ID and
	Secret so any scripts are not reliant on a named user.
#>


<#

	.SYNOPSIS Invites GitHub users to your GitHub organisation.

	.DESCRIPTION
	Invite GitHub users to your GitHub organisation and store their login name in AD under the 'info' attribute.

	.PARAMETER gitHubOrganisation
	The name of the GitHub organisation that you want to invite new users to.
	
	.PARAMETER gitHubUsername
	The GitHub username that you want to invite to your organisation.
	
	.PARAMETER gitHubAPIToken
	Required to make changes to your organisation. You can obtain an API Token for your GitHub user account
	via the following methods:
	
	.PARAMETER ADUsername
	The username in Active Directory that you want to be associated with the GitHub username.
	
	.EXAMPLE
	Add-GitHubUser -GitHubOrganisation 'Contoso' -GitHubUsername 'contoso-geoff' -ADUsername 'geoff' -GitHubAPIToken 'xxxxxxxxxxxxxxxxxxxxxxxxxxx'
#>

function Add-GitHubUser
{
	param
	(
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		[string]
		$gitHubOrganisation,
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		[string]		
		$ADUsername,
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		[string]
		$gitHubUsername,
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		[string]
		$gitHubAPIToken
	)
	
	Write-Output "This script adds a giffgaffer's GitHub account to the giffgaff GitHub organisation and stores their GitHub username in AD within the 'giffgaff-GitHub-Username' attribute"

$gitHubApi = "https://api.github.com"

#Invites the GitHub user to the Organisation
$gitHubURL = $gitHubApi + "/orgs/" + $gitHubOrganisation + "/memberships/" + $gitHubUsername + "?access_token=" + $gitHubAPIToken
Write-Output "Calling GitHub's API at $gitHubURL"
Invoke-RestMethod -Uri $gitHubURL -Method Put


#Adds their GitHub username to the 'info' AD Attribute
Set-ADUser $ADUsername -Replace @{'info'="$GitUser"} 

# Obtains a current list of users
Write-Output "--- The following users were added and their 'info' attribute set ---"
Get-ADUser $ADUsername -Property 'info' | Select Name,'info'
}
