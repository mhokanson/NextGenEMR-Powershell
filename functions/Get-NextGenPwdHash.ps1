function Get-NextGenPwdHash {
	[cmdletbinding()]
	Param(
		[parameter(Mandatory = $true, ValueFromPipeline = $true)] [string]$username,
		[parameter(Mandatory = $true, ValueFromPipeline = $true)] [SecureString]$password
	)
	$moduleVars = Get-NextGenVariables

	$insecure_password = [Net.NetworkCredential]::new('', $password).Password
	$salted_string = $username.ToLower() + $moduleVars.passwordSalt + $insecure_password
	
	# Create a hash for the password value
	$mystream = [IO.MemoryStream]::new([byte[]][char[]]$salted_string)
	$hashString = $(Get-FileHash -InputStream $mystream -Algorithm SHA1).Hash
	
	$ngpwdhash = ""
	# Break the hex string into 2-character hex values
	$hashArray = $hashString -split '(.{2})' -ne ''

	# Process each hex value
	foreach ($element in $hashArray) {
		if ($element -eq "7E") {
			$ngpwdhash += "0A"
			# NextGen drops leading zeros from hex values (except the line above)
		}
		elseif ($element.Substring(0, 1) -eq "0") {
			$ngpwdhash += $element.Substring(1, 1)
		}
		else {
			$ngpwdhash += $element
		}
	}

	return $ngpwdhash
}