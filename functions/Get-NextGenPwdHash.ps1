function Get-NextGenPwdHash {
	[cmdletbinding()]
	Param(
		[parameter(Mandatory = $true, ValueFromPipeline = $true)] [SecureString]$password
	)

	$insecure_password = [Net.NetworkCredential]::new('', $password).Password
	$salted_string = $username.ToLower() + $moduleVars.passwordSalt + $insecure_password
	
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

	return $ngpwdhash
}