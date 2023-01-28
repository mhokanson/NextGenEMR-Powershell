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
	 
		.PARAMETER securityGroups
			An array of security groups as displayed in NextGen System Administrator. Without at least one group the user won't be visible in System Administrator.
	 
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
		[parameter(Mandatory = $true)] [string[]]$securityGroups,
		[parameter(Mandatory = $true)] [Object[]]$userPrefs
	)

	$moduleVars = Get-NextGenVariables

	# Support -WhatIf output
	if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Creating user: $username")) {

		$insecure_password = [Net.NetworkCredential]::new('', $password).Password
		$salted_string = $username.ToLower() + "nghash" + $insecure_password
		
		# Create a hash for the password value
		$mystream = [IO.MemoryStream]::new([byte[]][char[]]$salted_string)
		$hashString = $(Get-FileHash -InputStream $mystream -Algorithm SHA1).Hash
		
		$ngpwdhash = ""
		# NextGen drops leading zeros from each byte of the hashed password
		for($i = 0; $i -lt $hashString.Length; $i++){
			$byteValue = $hashString.Substring($i,2)
			if($byteValue.Substring(0,1) -eq "0"){
				$ngpwdhash += $byteValue.Substring(1,1)
			} else {
				$ngpwdhash += $byteValue
			}
		
			$i = $i + 1
		}

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

		foreach($security_group in $securityGroups){
			$sg_query = @"
			INSERT INTO user_group_xref
			(
				user_id,
				group_id
			)
			SELECT
				@user_id,
				group_id
			FROM security_groups
			WHERE group_name = @group_desc
"@
			$sg_queryObj = @{
				SqlInstance = $moduleVars.databaseServer
				Database = $moduleVars.database
				Query = $sg_query
				SqlParameter = @{
					user_id = $newUserObj.user_id
					group_desc = $security_group
				}
			}

			Write-Verbose "Adding user $($newUserObj.user_id) ($($newUserObj.last_name + ', ' + $newUserObj.first_name)) to the security group: $security_group"

			Invoke-DbaQuery @sg_queryObj
		}

		$sg_insert_check_obj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = @"
		SELECT *
		FROM user_group_xref
		WHERE user_id = @user_id
"@
		SqlParameter = @{
			user_id = $newUserObj.user_id
		}
	}

		$sq_check_results = Invoke-DbaQuery @sg_insert_check_obj

		if($null -eq $sq_check_results) {
			Write-Error "Failed to put user $($newUserObj.user_id) ($($newUserObj.last_name + ', ' + $newUserObj.first_name)) in any security groups"
			return
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