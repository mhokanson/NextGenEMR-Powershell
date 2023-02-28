function Add-NextGenUser {
	<#
		.SYNOPSIS
			Create a new user account in NextGen EMR.
			Similar to Add-ADUser from the Active Directory module

		.PARAMETER username
			The users username

		.PARAMETER firstname
			The given name of the new user

		.PARAMETER lastname
			The last/family name of the new user

		.PARAMETER email
			The email address of the new user

		.PARAMETER password
			The new users initial password in a SecureString

		.PARAMETER securityGroup
			An security group as displayed in NextGen System Administrator. Without at least one group the user won't be visible in System Administrator.

		.PARAMETER securityGroups
			An array of security groups as displayed in NextGen System Administrator. Without at least one group the user won't be visible in System Administrator.

		.PARAMETER application
			An application to display on the user's NextGen Application Launcher.

		.PARAMETER applications
			An array of applications to display on the user's NextGen Application Launcher.

		.PARAMETER userPrefs
			An array of security groups as displayed in NextGen System Administrator. Without at least one group the user won't be visible in System Administrator.

		.EXAMPLE
			Get-NextGenUser -identity "test" returns all users with "test" found in their username, email address, first name, or last name.
		#>
	[cmdletbinding(SupportsShouldProcess)]
	Param(
		[parameter(Mandatory = $true)] [string]$username,
		[parameter(Mandatory = $true)] [string]$firstname,
		[parameter(Mandatory = $true)] [string]$lastname,
		[parameter(Mandatory = $false)] [string]$email = "",
		[parameter(Mandatory = $true)] [SecureString]$password,
		[parameter(Mandatory = $false)] [string]$application = $null,
		[parameter(Mandatory = $false)] [string[]]$applications = $null,
		[parameter(Mandatory = $false)] [string]$securityGroup = $null,
		[parameter(Mandatory = $false)] [string[]]$securityGroups = $null,
		[parameter(Mandatory = $true)] [Object[]]$userPrefs,
		[parameter(Mandatory = $true)] [Object[]]$mrdefaults
	)

	$moduleVars = Get-NextGenVariables

	# Support -WhatIf output
	if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Creating user: $username")) {
		if($null -ne $(Get-NextGenUser -identity $username -Identifier "username" -exact)){
			Write-Error "User already exists. Cannot create new user with supplied username."
			return
		}

		if(($PSBoundParameters.ContainsKey('securityGroup') -or $PSBoundParameters.ContainsKey('securityGroups')) -eq $false) {
			Write-Error "Unable to create user without at least one security group membership."
			return
		}


		# $ngpwdhash = Get-NextGenPwdHash $($password | ConvertFrom-SecureString)

		$user_mstr_insert_query = @"
		INSERT INTO user_mstr
		(
			enterprise_id,
			practice_id,
			user_id,
			password,
			last_name,
			first_name,
			start_date,
			end_date,
			allow_pswd_change_ind,
			email_login_id,
			login_id,
			privacy_level,
			password_expires_ind,
			force_new_pwd_ind,
			date_pwd_expires,
			delete_ind,
			optik_user_ind,
			created_by,
			modified_by,
			deact_invalid_login_user_ind,
			credentialed_staff_ind,
			credentialed_staff_Med_ind,
			credentialed_staff_Lab_ind,
			credentialed_staff_Diag_ind,
			deact_user_ind
		)
		VALUES
		(
			'00001',
			'0001',
			(SELECT MAX(user_id) + 1 FROM user_mstr),
			null,
			@last_name,
			@first_name,
			'01019999',
			'01019999',
			'Y',
			@email_address,
			@login_id,
			0,
			'Y',
			'Y',
			GETDATE(),
			'N',
			'N',
			@operator_id,
			@operator_id,
			'N',
			'N',
			'N',
			'N',
			'N',
			'N'
		)
"@

		$queryObj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = $user_mstr_insert_query
			SqlParameter = @{
				hashed_pwd = $ngpwdhash
				first_name = $firstname
				last_name = $lastname
				login_id = $username
				email_address = $email
				operator_id = $moduleVars.operator_id
			}
		}

		Invoke-DbaQuery @queryObj



		$newUserObj = Get-NextGenUser -identity $username -Identifier "username" -Exact

		if($null -eq $newUserObj) {
			Write-Error "Failed to create new user"
			return
		}

		Set-NextGenUserPassword -username $username -password $password

		if($PSBoundParameters.ContainsKey('application')) {
		# if($null -ne $application) {
			Add-NextGenUserAppLauncherApp -user_id $newUserObj.user_id -application $application -operator_id $moduleVars.operator_id
		} elseif($PSBoundParameters.ContainsKey('applications')) {
		# } elseif ($null -ne $applications) {
			foreach($app in $applications) {
				Add-NextGenUserAppLauncherApp -user_id $newUserObj.user_id -application $app -operator_id $moduleVars.operator_id
			}
		} else {
			Write-Warning "The new user will have no applications on their NextGen Application Launcher"
		}



		
		if($PSBoundParameters.ContainsKey('securityGroup')) {
			Write-Verbose "Adding user to security group '$securityGroup'"
			Add-NextGenUserToSecurityGroup -user_id $newUserObj.user_id -security_group $securityGroup -operator_id $moduleVars.operator_id
		} else {
			foreach($group in $securityGroups) {
				Write-Verbose "Adding user to security group '$group'"
				Add-NextGenUserToSecurityGroup -user_id $newUserObj.user_id -security_group $group -operator_id $moduleVars.operator_id
			}
		}

		# TODO: Figure out why looping through multiple accounts causes these lines to error out without -Force
		foreach($pref in $userPrefs){
			$pref | Add-Member -NotePropertyName user_id -NotePropertyValue $newUserObj.user_id -Force
			$pref | Add-Member -NotePropertyName created_by -NotePropertyValue $moduleVars.operator_id -Force
			$pref | Add-Member -NotePropertyName modified_by -NotePropertyValue $moduleVars.operator_id -Force
		}

		Write-Verbose "Adding user_pref records"
		$userPrefs | Write-DbaDbTableData -SqlInstance $moduleVars.databaseServer -Database $moduleVars.database -Table "user_pref"
		
		$mrdefault_insert_query = @"
		INSERT INTO mrdefaults
		(
			enterprise_id,
			practice_id,
			user_id,
			provider_id,
			location_id,
			use_last_doc_ind,
			use_last_loc_ind,
			table_contents,
			patient_search_ind,
			change_case_ind,
			imply_wildcard_ind,
			created_by,
			create_timestamp,
			modified_by,
			modify_timestamp
		)
		VALUES
		(
			@enterprise_id,
			@practice_id,
			@user_id,
			@provider_id,
			@location_id,
			@use_last_doc_ind,
			@use_last_loc_ind,
			@table_contents,
			@patient_search_ind,
			@change_case_ind,
			@imply_wildcard_ind,
			@operator_id,
			GETDATE(),
			@operator_id,
			GETDATE()
		)
"@

		$queryObj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = $mrdefault_insert_query
			SqlParameter = @{
				enterprise_id = $mrdefaults.enterprise_id
				practice_id = $mrdefaults.practice_id
				user_id = $newUserObj.user_id
				provider_id = $mrdefaults.provider_id
				location_id = $mrdefaults.location_id
				use_last_doc_ind = $mrdefaults.use_last_doc_ind
				use_last_loc_ind = $mrdefaults.use_last_loc_ind
				table_contents = $mrdefaults.table_contents
				patient_search_ind = $mrdefaults.patient_search_ind
				change_case_ind = $mrdefaults.change_case_ind
				imply_wildcard_ind = $mrdefaults.imply_wildcard_ind
				operator_id = $moduleVars.operator_id
			}
		}

		Write-Verbose "Adding mrdefaults record"
		Invoke-DbaQuery @queryObj
# 		foreach($pref in $userPrefs){
# 			$user_pref_query = @"
# 			INSERT INTO user_pref
# 			(
# 				enterprise_id,
# 				practice_id,
# 				user_id,
# 				item_name,
# 				item_value,
# 				created_by,
# 				modified_by
# 			)
# 			SELECT
# 				@enterprise_id,
# 				@practice_id,
# 				@user_id,
# 				@item_name,
# 				@item_value,
# 				@operator_id,
# 				@operator_id
# "@
# 			$queryObj = @{
# 				SqlInstance = $moduleVars.databaseServer
# 				Database = $moduleVars.database
# 				Query = $user_pref_query
# 				SqlParameter = @{
# 					enterprise_id = $pref.enterprise_id
# 					practice_id = $pref.practice_id
# 					user_id = $newUserObj.user_id
# 					item_name = $pref.item_name
# 					item_value = $pref.item_value
# 					operator_id = $moduleVars.operator_id
# 				}
# 			}

# 			Write-Verbose "Adding user_pref '$($pref.item_name)' with value '$($pref.item_value)' for $($newUserObj.user_id) ($($newUserObj.last_name + ', ' + $newUserObj.first_name))"
# 			Invoke-DbaQuery @queryObj
# 		}
	}
}