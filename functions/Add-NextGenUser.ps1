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
		[parameter(Mandatory = $true)] [Object[]]$userPrefs
	)

	$moduleVars = Get-NextGenVariables

	# Support -WhatIf output
	if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Creating user: $username")) {
		if($null -ne $(Get-NextGenUser -identity $username -Identifier "username")){
			Write-Error "User already exists. Cannot create new user with supplied username."
			return
		}

		if(($PSBoundParameters.ContainsKey('securityGroup') -or $PSBoundParameters.ContainsKey('securityGroups')) -eq $false) {
			Write-Error "Unable to create user without at least one security group membership."
			return
		}


		$ngpwdhash = Get-NextGenPwdHash $password

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
			@hashed_pwd,
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



		foreach($pref in $userPrefs){
			$user_pref_query = @"
			INSERT INTO user_pref
			(
				enterprise_id,
				practice_id,
				user_id,
				item_name,
				item_value,
				created_by,
				modified_by
			)
			SELECT
				@enterprise_id,
				@practice_id,
				@user_id,
				@item_name,
				@item_value,
				@operator_id,
				@operator_id
"@
			$queryObj = @{
				SqlInstance = $moduleVars.databaseServer
				Database = $moduleVars.database
				Query = $user_pref_query
				SqlParameter = @{
					enterprise_id = $pref.enterprise_id
					practice_id = $pref.practice_id
					user_id = $newUserObj.user_id
					item_name = $pref.item_name
					item_value = $pref.item_value
					operator_id = $moduleVars.operator_id
				}
			}

			Write-Verbose "Adding user_pref '$($pref.item_name)' with value '$($pref.item_value)' for $($newUserObj.user_id) ($($newUserObj.last_name + ', ' + $newUserObj.first_name))"
			Invoke-DbaQuery @queryObj
		}
	}
}