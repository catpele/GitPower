<#
	.SYNOPSIS PowerShell Module for Active Directory and GitHub API Automation
	
	.DESCRIPTION
	This module provides a number of tools for helping to automate the provisioning, editing and removal
	of GitHub users from your GitHub Organisation, as well as some reporting functions.
	
	It's aimed at small businesses who want to manage and automate provisioning without a GitHub Enterprise
	account or SAML/SSO infrastructure. I'd always recommend a dedicated SSO app (ADFS, etc) where possible.
		
	The user's GitHub username is stored in an Active Directory attribute (Default: 'info'). For the brave,
	I'd	recommend creating a custom AD user attibute by editing the schema to make it obvious to future
	administrators what the attribute is storing (ie. 'contoso-github-username').
	
	You'll need a GitHub API Token for most of the functions in this module to work. I'd highly recommend
	creating a dedicated 'service' user account in your organisation for this or using an OAuth ID and
	Secret so any scripts are not reliant on a named user.
#>


# Script Variables

$script:gitHubApi = "https://api.github.com"
$script:powerHubConfig = "$PSScriptRoot\powerHubConfig.txt"


<#
	IMPORT CONFIG CHECK
	-------------------
	
	Checks to see if a config file exists when the module is imported. If there is an existing config it pulls the details in. 
	If not, it offers to set one up.
#>

if (!(Test-Path $script:powerHubConfig))
{
	Write-Host "`nWelcome to powerHub!`n"
	Write-Host "No configuration file was found.`nIn order to use the functions in this module we'll need your GitHub organisation and an API Token`n"
	$option = Read-Host "Would you like to enter these now?(y/n)"
	
	if ($option -eq "y")
	{
		$apiToken = Read-Host "Paste your GitHub API Token here" 
		$org = Read-Host "Enter your GitHub organisation name"
		New-Item $script:powerHubConfig -Value "APIToken:$apiToken`nOrganisation:$org" -Type File
		
		# Get API Token from config
		$apiTokenString = Select-String $script:powerHubConfig -Pattern "APIToken"
		$apiTokenDelimiter = $apiTokenString.Line.IndexOf(":")
		$script:gitHubAPIToken = $apiTokenString.Line.Substring($apiTokenDelimiter+1)
		
		# Get organisation from config
		$orgString = Select-String $script:powerHubConfig -Pattern "Organisation"
		$orgDelimiter = $orgString.Line.IndexOf(":")
		$script:gitHubOrganisation = $orgString.Line.Substring($orgDelimiter+1)
	}
	else
	{
		Write-Host "Skipping. You can create the config file later by using New-powerHubConfig"
	}
}
else
{
	# Get API Token from config
	$apiTokenString = Select-String $script:powerHubConfig -Pattern "APIToken"
	$apiTokenDelimiter = $apiTokenString.Line.IndexOf(":")
	$script:gitHubAPIToken = $apiTokenString.Line.Substring($apiTokenDelimiter+1)
	
	# Get organisation from config
	$orgString = Select-String $script:powerHubConfig -Pattern "Organisation"
	$orgDelimiter = $orgString.Line.IndexOf(":")
	$script:gitHubOrganisation = $orgString.Line.Substring($orgDelimiter+1)
}


function Get-powerHubConfig
{
	<#
		.SYNOPSIS Gets the existing value for the GitHubApiToken stored in $PSScriptRoot\ApiToken.txt
	#>
	
	if (Test-Path $script:powerHubConfig)
	{
		Write-Output "`nConfig file exists, change it using New-powerHubConfig`n"
		Get-Content $script:powerHubConfig
		Write-Output "`n"
	}
	else
	{
		$option = Read-Host "No config file present, would you like to create one?"
		
		if ($option -eq "y")
		{
			$apiToken = Read-Host "Paste your GitHub API Token here" 
			$org = Read-Host "Enter your GitHub organisation name"
			New-Item $script:powerHubConfig -Value "APIToken:$apiToken`nOrganisation:$org" -Type File
			
			# Get API Token from config
			$apiTokenString = Select-String $script:powerHubConfig -Pattern "APIToken"
			$apiTokenDelimiter = $apiTokenString.Line.IndexOf(":")
			$script:gitHubAPIToken = $apiTokenString.Line.Substring($apiTokenDelimiter+1)
			
			# Get organisation from config
			$orgString = Select-String $script:powerHubConfig -Pattern "Organisation"
			$orgDelimiter = $orgString.Line.IndexOf(":")
			$script:gitHubOrganisation = $orgString.Line.Substring($orgDelimiter+1)
		}
		else
		{
			Write-Host "Skipping. You can create the config file later by using New-powerHubConfig"
		}
	}
}

function New-powerHubConfig
{
	<#
		.SYNOPSIS Replaces the GitHub config saved in $PSScriptRoot\powerHubConfig.txt
		
		.PARAMETER apiToken
		Paste the API token you create from your GitHub account in here.
		
		.PARAMETER gitHubOrganisation
		The name of your GitHub organisation
	#>
	
	param
	(
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		$apiToken,
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		$gitHubOrganisation
	)
	
	if (Test-Path $script:powerHubConfig)
	{
		$option = Read-Host "Do you want to replace the existing configuration?(y/n)"
		if ($option -eq 'y')
		{
			New-Item $script:powerHubConfig -Value "APIToken:$apiToken`nOrganisation:$gitHubOrganisation" -Type File -Force
		}
		else {exit}
	}
	else
	{
		New-Item $script:powerHubConfig -Value "APIToken:$apiToken`nOrganisation:$gitHubOrganisation" -Type File
	}
}

function Get-GitHubOrgMembers
{
	<#
		.SYNOPSIS Gets a full list of current memberships/
		
	#>
	
	$gitHubUrl = $script:gitHubApi + "/orgs/" +$script:gitHubOrganisation + "/members" + "?access_token=" + $script:gitHubApiToken
	Invoke-RestMethod -Uri $gitHubUrl
}

function Add-GitHubUser
{
	<#
		.SYNOPSIS Invites GitHub users to your GitHub organisation.

		.DESCRIPTION
		Invite GitHub users to your GitHub organisation and store their login name in AD under
		a user attribute.
		
		.PARAMETER gitHubUsername
		The GitHub username that you want to invite to your organisation.
		
		.PARAMETER ADUsername
		The username in Active Directory that you want to be associated with the GitHub username.
		
		.EXAMPLE
		Add-GitHubUser -GitHubOrganisation 'Contoso' -GitHubUsername 'contoso-geoff' -ADUsername 'geoff' -GitHubAPIToken 'xxxxxxxxxxxxxxxxxxxxxxxxxxx'
	#>

	param
	(
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		[string]		
		$ADUsername,
		[Parameter(Mandatory=$True)]
		[ValidateNotNull()]
		[string]
		$gitHubUsername
	)
	
	#Invites the GitHub user to the Organisation
	$gitHubURL = $script:gitHubApi + "/orgs/" + $script:gitHubOrganisation + "/memberships/" + $gitHubUsername + "?access_token=" + $script:gitHubApiToken
	Write-Output "Calling GitHub's API at $gitHubURL"
	Invoke-RestMethod -Uri $gitHubURL -Method Put


	#Adds their GitHub username to the 'info' AD Attribute
	Set-ADUser $ADUsername -Replace @{'info'="$GitUser"} 

	# Obtains a current list of users
	Write-Output "--- The following users were added and their 'info' attribute set ---"
	Get-ADUser $ADUsername -Property 'info' | Select Name,'info'
}

function Remove-GitHubUser
{
	<#
		.SYNOPSIS Removes a GitHub user from your GitHub organisation.

		.DESCRIPTION
		Remove a GitHub user from your GitHub organisation and delete their login name from the AD attribute.
		
		.PARAMETER gitHubUsername
		The GitHub username that you want to remove from your organisation.
		
		.PARAMETER ADUsername
		Alternatively you can specifiy the user's AD SamAccountName if they'd been invited to GitHub
		using the New-GitHubUser command previously. This will search their AD account for the
		AD attribute where their GitHub username is stored (Default is 'info')
		
		.EXAMPLE
		Remove-GitHubUser -GitHubUsername 'contoso-geoff'
		Remove-GitHubUser -ADUsername 'geoff'
	#>

	param
	(
		[Parameter(Mandatory=$False)]
		[ValidateNotNull()]
		[string]		
		$ADUsername,
		[Parameter(Mandatory=$False)]
		[ValidateNotNull()]
		[string]
		$gitHubUsername
	)
	
	if (!($ADUsername) -and !($gitHubUsername))
	{
		Write-Output "You must specify either a GitHub username or AD username to remove"
	}
	elseif (($ADUsername) -and !($gitHubUsername))
	{
		Write-Output "Searching for GitHub Username"
		$ADUser = Get-ADUser -Identity $ADUsername -Property SamAccountName,DisplayName,'giffgaff-GitHub-Username'
		$gitHubUsername = $ADUser.'giffgaff-GitHub-Username'
		$gitHubURL = $script:gitHubApi + "/orgs/" + $script:gitHubOrganisation + "/memberships/" + $gitHubUsername + "?access_token=" + $script:gitHubApiToken
		Write-Output "Removing $gitHubUsername from the $gitHubOrganisation organisation on GitHub"
	}
	elseif (($gitHubUsername) -and !($ADUsername))
	{
		Write-Output "Removing $gitHubUsername from the $gitHubOrganisation organisation on GitHub"
		$gitHubURL = $script:gitHubApi + "/orgs/" + $script:gitHubOrganisation + "/memberships/" + $gitHubUsername + "?access_token=" + $script:gitHubApiToken
	}
	else
	{
		Write-Output "Removing $gitHubUsername from the $gitHubOrganisation organisation on GitHub"
		$gitHubURL = $script:gitHubApi + "/orgs/" + $script:gitHubOrganisation + "/memberships/" + $gitHubUsername + "?access_token=" + $script:gitHubApiToken
	}
	
	<#Invites the GitHub user to the Organisation
	$gitHubURL = $script:gitHubApi + "/orgs/" + $script:gitHubOrganisation + "/memberships/" + $gitHubUsername + "?access_token=" + $script:gitHubApiToken
	Write-Output "Calling GitHub's API at $gitHubURL"
	Invoke-RestMethod -Uri $gitHubURL -Method Put


	#Adds their GitHub username to the 'info' AD Attribute
	Set-ADUser $ADUsername -Replace @{'info'="$GitUser"} 

	# Obtains a current list of users
	Write-Output "--- The following users were added and their 'info' attribute set ---"
	Get-ADUser $ADUsername -Property 'info' | Select Name,'info' #>
}
