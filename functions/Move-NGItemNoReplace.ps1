<#
.SYNOPSIS
Move items to a destination, regardless of whether or not there's a name conflict, without overwriting files in the destination.

.DESCRIPTION
Move-Item doesn't have an option for renaming files if it finds a file conflict when moving a file. This function will append
a ' (#)' to the end of the baseName of the file in the destination folder, as Windows does when it detects a conflict and you
choose to keep both copies of the file

.PARAMETER sourceFile
File object (from get-childitem or similar cmdlet). Not a string so that you can feed a foreach from the resultes of
get-childitem on a folder to the function

.PARAMETER destinationFolder
The folder to move the file to

.EXAMPLE
move-itemNoReplace -sourceFile (Get-ChildItem "C:\test.txt") -destinationFolder "C:\Test"
#>
function move-itemNoReplace
{
	Param (
		[parameter(Mandatory=$true)] [System.Object] $sourceFile,
		[parameter(Mandatory=$true)] [string] $destinationFolder
	)
	# Get the parts of the needed paths
	$sourceFileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
	$sourceFileExtension = [System.IO.Path]::GetExtension($sourceFile)

	$destinationFileBaseName = $sourceFileBaseName

	# Create a new filepath for the file to be copied to
	$destinationFullPath = Join-Path -Path $destinationFolder -ChildPath ($destinationFileBaseName + $sourceFileExtension)

	$i = 2

	if((Test-Path $destinationFolder) -ne $true )
	{
		New-Item -Path $destinationFolder -ItemType directory
	}

	# if the destination already exists, start appending numbers to the filename, in Windows style ' (#)' until an available name is found
	while ((Test-Path $destinationFullPath) -eq $true)
	{

		$destinationFileBaseName = $sourceFileBaseName + " ($i)"
		$destinationFullPath = Join-Path -Path $destinationFolder -ChildPath ($destinationFileBaseName + $sourceFileExtension)

		$i = $i + 1
	}
	Write-Verbose "Moving $sourceFile to $destinationFullPath"
	# Perform the move
	Move-Item -Path $sourceFile -Destination $destinationFullPath
	if ($?) { # if the last command had an error send a notification
		return $true
	} else {
		return $false
	}
}