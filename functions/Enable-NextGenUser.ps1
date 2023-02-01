function Enable-NextGenUser {
	<#
		.SYNOPSIS
			Enables a user account in NextGen EMR.
			Similar to Enable-ADUser from the Active Directory module

		.PARAMETER username
			The users username

		.EXAMPLE
			Enable-NextGenUser -identity "test" resets the last_logon_date, and changes the delete_ind to 'N' for the user with the login_id "test"
		#>
	[cmdletbinding(SupportsShouldProcess)]
	Param(
		[parameter(Mandatory = $true, ValueFromPipelineByPropertyName)] [string]$username
	)

	$moduleVars = Get-NextGenVariables

	# Support -WhatIf output
	if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Enable user: '$username'")) {
		$enableUserQueryObj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = @"
	UPDATE user_mstr
	SET last_logon_date = CONVERT(varchar(8),GETDATE(),112),
		delete_ind = 'N',
		modified_by = @operator_id,
		modify_timestamp = GETDATE()
	WHERE login_id = @username
"@
			SqlParameter = @{
				username = $username
				operator_id = $moduleVars.operator_id
			}
		}

		Invoke-DbaQuery @enableUserQueryObj



		$confirmationQueryObj = @{
			SqlInstance = $moduleVars.databaseServer
			Database = $moduleVars.database
			Query = @"
	SELECT last_logon_date, delete_ind
	FROM user_mstr
	WHERE login_id = @username
"@
			SqlParameter = @{
				username = $username
				operator_id = $moduleVars.operator_id
			}
		}

		$confirmationResults = Invoke-DbaQuery @confirmationQueryObj

		if( $confirmationResults.delete_ind -ne "N" -or
			$confirmationResults.last_logon_date -ne (Get-Date -Format "yyyyMMdd")) {
			Write-Error "Account enabling failed"
			return
		}
		Write-Output "Account successfully enabled"
	}
}