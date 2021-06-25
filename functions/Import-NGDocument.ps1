function Import-NGDocument {
	<#
		.SYNOPSIS
			Take a docx file from the local filesystem and insert it into the NextGen EMR database. As there
			may or may not be a document already in the encounter this module supports inserting a brand-new
			document or replacing an existing document.
	 
		.PARAMETER Path
			Path to the local file to import
	 
		.PARAMETER Description
			What the imported document should display as in NextGen EMR
	 
		.PARAMETER DBServer
			The NextGen EMR database server
	 
		.PARAMETER Database
			The NextGen EMR database name
	 
		.PARAMETER UseWindowsAuthentication
			Connect to the database as the current user
	 
		.PARAMETER DBUsername
			If not using UseWindowsAuthentication, the username to use when logging into the database
	 
		.PARAMETER DBPassword
			If not using UseWindowsAuthentication, the password to use when logging into the database
	 
		.PARAMETER enc_id
			The GUID for the encounter in NextGen EMR to insert the document into
	 
		.PARAMETER Category
			If the document is to be sorted into a NextGen EMR category indicate it here. Can be multiple categories
	 
		.PARAMETER UserID
			The internal user_id from the user_mstr table in NextGen EMR to log the function action as
	 
		.EXAMPLE
		
			Add-CellComment -Worksheet $excelPkg.Sheet1 -CellAddress A1 -Comment "This is a comment" -Author "Automated Process"
		#>
	Param (
		[parameter(Mandatory = $true)] [string] $Path,
		[parameter(Mandatory = $true)] [string] $Description,
		[parameter(Mandatory = $true)] [string] $DBServer,
		[parameter(Mandatory = $true)] [string] $Database,
		[parameter(Mandatory = $false)] [switch] $UseWindowsAuthentication,
		[parameter(Mandatory = $false)] [string] $DBUsername,
		[parameter(Mandatory = $false)] [securestring] $DBPassword,
		[parameter(Mandatory = $true)] [string] $enc_id,
		[parameter(Mandatory = $false)] [string[]] $Category,
		[parameter(Mandatory = $true)] [int] $UserID,
		[parameter(Mandatory = $false)] [string] $Application
	)

	if($null -eq $Application) {
		$Application = "Powershell"
	}




	# Determine if a conflicting document already exists
	$existingDocumentCheckQuery = @"
SELECT  enterprise_id,
		practice_id,
		ISNULL(document_id,'') AS document_id,
		file_format,
		source_name,
		location,
		sub_location,
		ISNULL(document_file,'') AS document_file,
		NEWID() AS archive_doc_id
FROM patient_documents
WHERE enc_id = '$enc_id'
  AND document_desc = '$Description'
"@


	if ($UseWindowsAuthentication) {
		$existingDocumentCheckResults = Invoke-NGSQLCommand -Server $DBServer -Database $Database -UseWindowsAuthentication:$true -Query $existingDocumentCheckQuery
	}
	else {
		$existingDocumentCheckResults = Invoke-NGSQLCommand -Server $DBServer -Database $Database -Username $DBUsername -Password [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DBPassword)) -Query $existingDocumentCheckQuery
	}

	$archiveExistingDocument = $true
	if ($null -eq $existingDocumentCheckResults) {
		Write-Verbose "No conflicting document"
		$archiveExistingDocument = $false
	}
	else {
		Write-Verbose "Conflicting document will be archived"
		$archiveExistingDocument = $true
	}

	if ($archiveExistingDocument) {
		$documentToArchive = Join-Path "$($existingDocumentCheckResults.location)$($existingDocumentCheckResults.sub_location)" -ChildPath $existingDocumentCheckResults.document_file
		
		$documentBlob = convertTo-NextGenSQLBlob -Path $documentToArchive
		
		$archiveDocumentQuery = @"
INSERT INTO
patient_documents_archive
(
	archive_doc_id,
	enterprise_id,
	practice_id,
	document_id,
	document_type,
	document_desc,
	created_by,
	create_timestamp,
	modified_by,
	modify_timestamp,
	binarydata,
	source_name
)
VALUES
(
	'$(existingDocumentCheckResults.archive_doc_id)',
	'$(existingDocumentCheckResults.enterprise_id)',
	'$(existingDocumentCheckResults.practice_id)',
	'$(existingDocumentCheckResults.document_id)',
	'$(existingDocumentCheckResults.file_format)',
	'$Description',
	$UserID,
	GETDATE(),
	$UserID,
	GETDATE(),
	$documentBlob,
	'$Application'
)
"@

		if ($UseWindowsAuthentication) {
			Write-Verbose "Archiving the existing document"
			$archiveDocumentResults = Invoke-NGSQLCommand -Server $DBServer -Database $Database -UseWindowsAuthentication:$true -Query $archiveDocumentQuery
		}
		else {
			Write-Verbose "Archiving the existing document"
			$archiveDocumentResults = Invoke-NGSQLCommand -Server $DBServer -Database $Database -Username $DBUsername -Password [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DBPassword)) -Query $archiveDocumentQuery
		}
	}

	# TODO: Figure out what Invoke-NGSQLCommand returns on failure
	if($archiveDocumentResults) {
		Write-Verbose "Document archived"
		Remove-Item $documentToArchive -WhatIf
	}
	else {
		Write-Error "The archiving of the existing document failed!"
		return
	}

$doc_id = New-Guid
$fileDestination = "$($(Get-NGSystemSettings).doc_store_root)\$(Get-Date -uformat %Y)\$(Get-DAte -UFormat %Y%m%d)\$($doc_id).doc"

Copy-Item -Path $Path -Destination $fileDestination

# if we archived a document we do an UPDATE
if($archiveExistingDocument) {
	$document_update_query = @"
	UPDATE patient_documents
	SET location = '$($(Get-NGSystemSettings).doc_store_root)',
		sub_location = '$("$(Get-Date -uformat %Y)\$(Get-DAte -UFormat %Y%m%d)")',
		document_file = '$("$($doc_id).doc")',
		created_by = $UserID,
		create_timestamp = GETDATE(),
		modified_by = $UserID,
		modify_timestamp = GETDATE()
	WHERE document_id = '$($existingDocumentCheckResults.document_id)'
"@

if ($UseWindowsAuthentication) {
	Write-Verbose "Archiving the existing document"
	$updateDocumentResults = Invoke-NGSQLCommand -Server $DBServer -Database $Database -UseWindowsAuthentication:$true -Query $document_update_query
}
else {
	Write-Verbose "Archiving the existing document"
	$updateDocumentResults = Invoke-NGSQLCommand -Server $DBServer -Database $Database -Username $DBUsername -Password [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DBPassword)) -Query $document_update_query
}

# TODO: Figure out what Invoke-NGSQLCommand returns on failure
if($updateDocumentResults) {
	Write-Verbose "Document archived"
	Remove-Item $documentToArchive -WhatIf
}
else {
	Write-Error "The archiving of the existing document failed!"
	return
}


}
# if we didn't archive, we INSERT
else {

}
}