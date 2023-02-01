function Add-NextGenUserToSecurityGroup {
	<#
		.SYNOPSIS
			Add a NextGen application to a user's Application Launcher settings.
	 
		.PARAMETER username
			The target users user_id
	 
		.PARAMETER security_group
			The group_name value for the security group as found in the security_groups table
	 
		.PARAMETER operator_id
			The user_id to use for the created_by and modified_by fields in the database for this change
	
		.EXAMPLE
			The below example adds whatever application '31e35afb-6df0-4c3a-9aef-d12204954473' is to the app laucher of user 42
			> Add-NextGenUserAppLauncherApp -user_id 42 -application_id '31e35afb-6df0-4c3a-9aef-d12204954473' -operator_id 1 "test"

		#>
		[cmdletbinding(SupportsShouldProcess)]
		Param(
			[parameter(Mandatory = $true)] [int]$user_id,
			[parameter(Mandatory = $true)] [string]$security_group,
			[parameter(Mandatory = $true)] [int]$operator_id
		)
	
		$moduleVars = Get-NextGenVariables

		if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Adding user $user_id to security group '$group'")) {

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
	WHERE group_name = @group
"@
				$sg_queryObj = @{
					SqlInstance = $moduleVars.databaseServer
					Database = $moduleVars.database
					Query = $sg_query
					SqlParameter = @{
						user_id = $user_id
						group = $security_group
					}
				}
	
				Write-Verbose "Adding user $($user_id) to the security group: $group"
	
				Invoke-DbaQuery @sg_queryObj
			}
	
			$sg_insert_check_obj = @{
				SqlInstance = $moduleVars.databaseServer
				Database = $moduleVars.database
				Query = @"
			SELECT COUNT(1)
			FROM user_group_xref ugx
			INNER JOIN security_groups sg
					ON ugx.group_id = sg.group_id
			WHERE ugx.user_id = @user_id
			  AND sg.group_name = @group
"@
			SqlParameter = @{
				user_id = $user_id
				group = $security_group
			}
		}
	
			$sq_check_results = Invoke-DbaQuery @sg_insert_check_obj
	
			if($null -eq $sq_check_results) {
				Write-Error "Failed to put user $($user_id) into security group $group"
				return
			}
}