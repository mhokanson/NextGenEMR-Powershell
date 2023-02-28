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
		[parameter(Mandatory = $false)][ValidateSet('username', 'email', 'firstname', 'lastname')] [string]$identifier,
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
			Write-Verbose "Exact matching enabled"
			switch ($identifier) {
				"username" { $query += "`nWHERE um.login_id = @identity" }
				"email" { $query += "`nWHERE um.email_login_id = @identity" }
				"firstname" { $query += "`nWHERE um.first_name = @identity" }
				"lastname" { $query += "`nWHERE um.last_name = @identity" }
				default { Write-Error "Unable to use `"-Exact`" without an identifier" }
			}
		}
		$false {
			Write-Verbose "Exact matching not enabled"
			switch ($identifier) {
				"username" { $query += "`nWHERE um.login_id LIKE '%'+@identity+'%'" }
				"email" { $query += "`nWHERE um.email_login_idLIKE '%'+@identity+'%'" }
				"firstname" { $query += "`nWHERE um.first_nameLIKE '%'+@identity+'%'" }
				"lastname" { $query += "`nWHERE um.last_nameLIKE '%'+@identity+'%'" }
				default {
					$query += @"
					WHERE um.login_id LIKE '%'+@identity+'%'
					OR um.email_login_id LIKE '%'+@identity+'%'
					OR um.last_name LIKE '%'+@identity+'%'
					OR um.first_name LIKE '%'+@identity+'%'
"@
    }
			}
		}
	}

	$queryObj = @{
		SqlInstance  = $moduleVars.databaseServer
		Database     = $moduleVars.database
		Query        = $query
		SqlParameter = @{
			identity = $identity
		}
	}

	Write-Verbose "About to execute user lookup on identity $identity"
	$userObj = Invoke-DbaQuery @queryObj
	


	# if multiple user objects are returned we need to query for additional details in a loop
	foreach ($user in $userObj) {

		$app_launcher_apps_queryObj = @{
			SqlInstance  = $moduleVars.databaseServer
			Database     = $moduleVars.database
			Query        = @"
	SELECT a.app_name
	FROM application a
	INNER JOIN application_access aa
			ON a.app_id = aa.app_id
	WHERE aa.user_id = @user_id
"@
			SqlParameter = @{
				user_id = $user.user_id
			}
		}
		# Set an empty array to ensure an array is returned
		$user | Add-Member -NotePropertyName "appLauncherApps" -NotePropertyValue @()
		# Add applications to the array
		Write-Verbose "About to execute lookup of app launcher entries for user $($user.username)"
		Invoke-DbaQuery @app_launcher_apps_queryObj | ForEach-Object { $user.appLauncherApps += $_.app_name }
	




		$group_membership_queryObj = @{
			SqlInstance  = $moduleVars.databaseServer
			Database     = $moduleVars.database
			Query        = @"
	SELECT sg.group_name
	FROM user_group_xref ugx
	INNER JOIN security_groups sg
			ON ugx.group_id = sg.group_id
	WHERE ugx.user_id = @user_id
"@
			SqlParameter = @{
				user_id = $user.user_id
			}
		}
		# Set an empty array to ensure an array is returned
		$user | Add-Member -NotePropertyName "securityGroups" -NotePropertyValue @()
		# Add applications to the array
		Write-Verbose "About to execute lookup of security group membership for user $($user.username)"
		Invoke-DbaQuery @group_membership_queryObj | ForEach-Object { $user.securityGroups += $_.group_name }


		$user_prefs_queryObj = @{
			SqlInstance  = $moduleVars.databaseServer
			Database     = $moduleVars.database
			Query        = @"
	SELECT
		enterprise_id,
		practice_id,
		item_name,
		item_value
	FROM user_pref
	WHERE user_id = @user_id
"@
			SqlParameter = @{
				user_id = $user.user_id
			}
		}

		# Set an empty array to ensure an array is returned
		$userPrefsList = @()
		Write-Verbose "About to execute lookup of EHR settings for user $($user.username)"
		$userPrefsResults = Invoke-DbaQuery @user_prefs_queryObj
		foreach ($pref in $userPrefsResults) {
			$userPrefsList += [PSCustomObject]@{
				enterprise_id = $pref.enterprise_id
				practice_id   = $pref.practice_id
				item_name     = $pref.item_name
				item_value    = $pref.item_value
			}
		}
	
		$user | Add-Member -NotePropertyName "userPrefs" -NotePropertyValue $userPrefsList
		




		$userMRDefaults_queryObj = @{
			SqlInstance  = $moduleVars.databaseServer
			Database     = $moduleVars.database
			Query        = @"
	SELECT
		enterprise_id,
		practice_id,
		provider_id,
		location_id,
		use_last_doc_ind,
		use_last_loc_ind,
		table_contents,
		patient_search_ind,
		change_case_ind,
		imply_wildcard_ind
	FROM mrdefaults
	WHERE user_id = @user_id
"@
			SqlParameter = @{
				user_id = $user.user_id
			}
		}

		
		$userMRDefaults = Invoke-DbaQuery @userMRDefaults_queryObj -As PSObject

		$user | Add-Member -NotePropertyName "mrdefaults" -NotePropertyValue $userMRDefaults
	}
	return $userObj | Select-Object user_id, first_name, last_name, username, email_login_id, delete_ind, last_logon_date, appLauncherApps, securityGroups, userPrefs, mrdefaults
}
