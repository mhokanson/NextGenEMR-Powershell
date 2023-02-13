function Set-NextGenUserPassword {
	<#
		.SYNOPSIS
			Set the password of a user account in NextGen EMR.
			Similar to Set-ADUserPassword from the Active Directory module

		.PARAMETER username
			The users username

		.PARAMETER password
			The users password as a SecureString
		#>
	[cmdletbinding(SupportsShouldProcess)]
	Param(
		[parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)] [string]$username,
		[parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)] [SecureString]$password,
		[parameter(Mandatory = $false)] [switch]$noPasswordChangeRequired = $false

	)

	$moduleVars = Get-NextGenVariables

	# Support -WhatIf output
	if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Set password for $username")) {
		$passwordHash = Get-NextGenPwdHash -Password $password

		if($noPasswordChangeRequired -eq $true){
			$force_new_pwd_ind = "N"
		} else {
			$force_new_pwd_ind = "Y"
		}


		$setPasswordQueryObj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = @"
	UPDATE user_mstr
	SET 
		password = @passwordHash,
		force_new_pwd_ind = '$force_new_pwd_ind',
		modified_by = @operator_id,
		modify_timestamp = GETDATE()
	WHERE login_id = @username
"@
			SqlParameter = @{
				username = $username
				passwordHash = $passwordHash
				operator_id = $moduleVars.operator_id
			}
		}

		Invoke-DbaQuery @setPasswordQueryObj

		$verificationQueryObj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = @"
	SELECT
		password
	FROM user_mstr
	WHERE login_id = @username
"@
			SqlParameter = @{
				username = $username
				passwordHash = $passwordHash
				operator_id = $moduleVars.operator_id
			}
		}

		$verificationResults = Invoke-DbaQuery @verificationQueryObj

		if($verificationResults.password -ne $passwordHash) {
			Write-Error "Password set failed"
			return
		}
		Write-Output "Password successfully updated"
	}
}