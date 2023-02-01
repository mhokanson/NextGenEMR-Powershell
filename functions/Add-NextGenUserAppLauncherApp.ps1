function Add-NextGenUserAppLauncherApp {
	<#
		.SYNOPSIS
			Add a NextGen application to a user's Application Launcher settings.
	 
		.PARAMETER username
			The target users user_id
	 
		.PARAMETER application
			The application name as found in the application table
	 
		.PARAMETER operator_id
			The user_id to use for the created_by and modified_by fields in the database for this change
	
		.EXAMPLE
			The below example adds the NextGen Enterprise EHR application to the app laucher of user 42
			> Add-NextGenUserAppLauncherApp -user_id 42 -application 'Enterprise EHR' -operator_id 1

		#>
		[cmdletbinding(SupportsShouldProcess)]
		Param(
			[parameter(Mandatory = $true)] [int]$user_id,
			[parameter(Mandatory = $true)] [string]$application,
			[parameter(Mandatory = $true)] [int]$operator_id
		)
	
		$moduleVars = Get-NextGenVariables

		if ($PSCmdlet.ShouldProcess("$($moduleVars.database)","Adding app launcher shortcut to $application for user $user_id")) {
			$add_app_launcher_entry_obj = @{
				SqlInstance = $moduleVars.databaseServer
				Database = $moduleVars.database
				Query = @"
INSERT INTO application_access
(
	user_id,
	app_id,
	created_by,
	modified_by
)
SELECT
	@user_id,
	a.app_id,
	@operator_id,
	@operator_id
FROM application a
WHERE app_name = @application_name
"@
			SqlParameter = @{
				user_id = $user_id
				application_name = $application
				operator_id = $operator_id
			}
		}
	
			Invoke-DbaQuery @add_app_launcher_entry_obj

			$verification_query_obj = @{
				SqlInstance = $moduleVars.databaseServer
				Database = $moduleVars.database
				Query = @"
SELECT COUNT(1) AS result
FROM application_access aa
INNER JOIN application a
		ON aa.app_id = a.app_id
WHERE aa.user_id = @user_id
  AND a.app_name = @application_name
"@
				SqlParameter = @{
					user_id = $user_id
					application_name = $application
				}
			}
			$verification_result = Invoke-DbaQuery @verification_query_obj
	
			if($verification_result.result -lt 1) {
				Write-Error "Failed to add access to app '$application' for user $user_id"
				return
			} else {
				return
			}

		}
}