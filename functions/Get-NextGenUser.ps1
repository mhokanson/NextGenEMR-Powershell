function Get-NextGenUser {
	<#
		.SYNOPSIS
			Take a user identifier and return details about that account from NextGen EHR.
			Similar to Get-ADUser from the Active Directory module
	 
		.PARAMETER identity
			The user identifier to search for
	 
		.PARAMETER identifier
			If a search of a specific identifier is desired it can be set here.
			Available options are:
			* username
			* email
			* firstname
			* lastname
	 
		.PARAMETER exact
			Default is to search with wildcards around the identity value. Use the 'exact' flag to override this and look for an exact match.
	 
		.EXAMPLE
			Get-NextGenUser -identity "test" returns all users with "test" found in their username, email address, first name, or last name.
		#>
	Param(
		[parameter(Mandatory = $true)] [string]$identity,
		[parameter(Mandatory = $false)][ValidateSet('username','email','firstname','lastname')] [string]$identifier,
		[parameter(Mandatory = $false)] [switch]$exact = $false
	)

	$moduleVars = Get-NextGenVariables

	$query = @"
		SELECT
			user_id,
			first_name,
			last_name,
			login_id AS [username],
			email_login_id,
			delete_ind,
			ISNULL(STUFF(STUFF(last_logon_date,7,0,'-'),5,0,'-'),'9999-12-31') AS last_logon_date
		FROM user_mstr um
"@
	switch ($exact) {
		$true {
			switch($identifier) {
				"username" {$query += "`nWHERE um.login_id = @identity"}
				"email" {$query += "`nWHERE um.email_login_id = @identity"}
				"firstname" {$query += "`nWHERE um.first_name = @identity"}
				"lastname" {$query += "`nWHERE um.last_name = @identity"}
				default {Write-Error "Unable to use `"-Exact`" without an identifier"}
			}
		}
		$false {
			switch($identifier) {
				"username" {$query += "`nWHERE um.login_id LIKE '%'+@identity+'%'"}
				"email" {$query += "`nWHERE um.email_login_idLIKE '%'+@identity+'%'"}
				"firstname" {$query += "`nWHERE um.first_nameLIKE '%'+@identity+'%'"}
				"lastname" {$query += "`nWHERE um.last_nameLIKE '%'+@identity+'%'"}
				default {$query += @"
					WHERE um.login_id LIKE '%'+@identity+'%'
					OR um.email_login_id LIKE '%'+@identity+'%'
					OR um.last_name LIKE '%'+@identity+'%'
					OR um.first_name LIKE '%'+@identity+'%'
"@}
			}
		}
	}



	$queryObj = @{
		SqlInstance = $moduleVars.databaseServer
		Database = $moduleVars.database
		Query = $query
		SqlParameter = @{
			identity = $identity
		}
	}
	



	return Invoke-DbaQuery @queryObj
}
