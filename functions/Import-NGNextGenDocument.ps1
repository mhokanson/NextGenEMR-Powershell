# Deprecate/refactor this in favor of Import-NGDocument.ps1

<#
2 possible workflows
	if a document already exists
	* archive the existing document (blobulize into the database)
	* delete existing file from the file server
	* copy new document onto the file server
	* update patient_documents record to point to the new document
	if a document DOESN'T already exist
	* copy new document onto the file server
	* INSERT record into patient_documents
#>
function Import-NextGenDocument
{

	Param (
		[parameter(Mandatory=$true)] [string] $connectionString,
		[parameter(Mandatory=$true)] [string] $Path,
		[parameter(Mandatory=$true)] [string] $enc_id,
		[parameter(Mandatory=$true)] [string] $document_desc,
		[parameter(Mandatory=$false)] [string] $document_category,
		[parameter(Mandatory=$true)] [int] $NGUserID,
		[parameter(Mandatory=$true)] [string] $app_created_by
	)
	
	# A query that will grab details for any existing document
	$Sql = "SELECT  enterprise_id,
					practice_id,
					ISNULL(document_id,'') AS document_id,
					file_format,
					source_name,
					location,
					sub_location,
					ISNULL(document_file,'') AS document_file,
					NEWID() AS new_guid
			FROM patient_documents
			WHERE enc_id = '$enc_id'
			  AND document_desc = '$document_desc'";
			  
	# create and open the connection to the SQL database
	$connection = New-Object System.Data.SqlClient.SqlConnection
	$connection.ConnectionString = $connectionString
	$connection.Open()
	
	# turn the SQL query into a command that can be run through the open DB connection
	$command = New-Object System.Data.SQLClient.SQLCommand
	$command.Connection = $connection
	$command.CommandText = $Sql
	
	# Execute the query
	$reader = $command.ExecuteReader() 

	<###################################################################
	####################################################################
	####################################################################
	####################################################################
	#################### If a document exists ##########################
	####################################################################
	####################################################################
	####################################################################
	####################################################################
	###################################################################>
	if($reader.HasRows)
	{
		while ($reader.Read())
		{
				# assign SQL record values to parameters
				$enterprise_id  = $reader.GetValue(0);
				$practice_id    = $reader.GetValue(1);
				$document_id    = $reader.GetValue(2);
				$file_format    = $reader.GetValue(3);
				$source_name    = $reader.GetValue(4);
				$location       = $reader.GetValue(5);
				$sub_location   = $reader.GetValue(6);
				$document_file  = $reader.GetValue(7);
				$archive_doc_id = $reader.GetValue(8);
		}
	
		$reader.Close()

		# Get document in Blob format
		$currentDocument = "$location$sub_location$document_file"
		$documentBlob = convertTo-NextGenSQLBlob -Path $currentDocument


		if($null -ne $document)
		{
			$archiveSQL = " INSERT INTO
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
								'$archive_doc_id',
								'$enterprise_id',
								'$practice_id',
								'$document_id',
								'$file_format',
								'$document_desc',
								$NGUserID,
								GETDATE(),
								$NGUserID,
								GETDATE(),
								$documentBlob,
								'$source_name'
							)";

							# turn the SQL query into a command that can be run through the open DB connection
							$command = New-Object System.Data.SQLClient.SQLCommand
							$command.Connection = $connection
							$command.CommandText = $archiveSQL
							Write-Host $archiveSQL -ForegroundColor Cyan
							# Execute the query
							$rowsAffected = $command.ExecuteNonQuery() 
							if($rowsAffected -eq 0)
							{
								Write-Warning -Message "Archiving existing document failed!"
								Return 0;
							}
							else {
								Write-Warning -Message "Archiving success!"
								Remove-Item $currentDocument
							}
						}
						else {
							Write-Warning -Message "Nothing to archive!"
						}

		# Get values needed for dealing with the new document
		$storage_location = get-NextGenDocumentStorageLocation -connectionString $connectionString
		$year = Get-Date -uformat %Y
		$date = Get-Date -uformat %Y%m%d
		$doc_sub_location = "$year\$date\"
		$docGuid = New-Guid
		$doc_file_name = "$docGuid.doc"
		if($document_id -eq "")
		{
			$document_id = New-Guid
		}

		$newFilePath = "$location$doc_sub_location$doc_file_name"

		# Make sure that the file won't overwrite an existing file
		while((Test-Path -Path $newFilePath -PathType leaf) -eq $true)
		{
			$docGuid = New-Guid
			$doc_file_name = "$docGuid.doc"
			$newFilePath = "$location$doc_sub_location$doc_file_name"
		}


		$NextGen_update_statement = @"
		UPDATE patient_documents
		SET location = '$storage_location',
			sub_location = '$doc_sub_location',
			document_file = '$doc_file_name',
			created_by = $NGUserID,
			create_timestamp = GETDATE(),
			modified_by = $NGUserID,
			modify_timestamp = GETDATE()
		WHERE document_id = '$document_id'
"@

		# turn the SQL query into a command that can be run through the open DB connection
		$command = New-Object System.Data.SQLClient.SQLCommand
		$command.Connection = $connection
		$command.CommandText = $NextGen_update_statement

		$rowsAffected = $command.ExecuteNonQuery() 
		if($rowsAffected -eq 0)
		{
			Write-Warning -Message "Adding new document failed!"
			Return 0;
		}
		else {
			Write-Warning -Message "Adding new document success!"
			Copy-Item -Path $Path -Destination $newFilePath -Verbose
		}
#Write-Output "Line 185"
	}
	<###################################################################
	####################################################################
	####################################################################
	####################################################################
	################# If a document  doesn't exist #####################
	####################################################################
	####################################################################
	####################################################################
	####################################################################
	###################################################################>
	else {
#Write-Output "Line 198"
		$reader.Close()
#Write-Output "Line 200"
		# Get values needed for dealing with the new document
		$get_NextGen_Info_query = @"
				SELECT  pe.enterprise_id,
						pe.practice_id,
						pe.person_id
				FROM patient_encounter pe 
				WHERE pe.enc_id = '$enc_id'
"@
#Write-Output $get_NextGen_Info_query
		# turn the SQL query into a command that can be run through the open DB connection
		$command = New-Object System.Data.SQLClient.SQLCommand
		$command.Connection = $connection
		$command.CommandText = $get_NextGen_Info_query

		# Execute the query
		$reader = $command.ExecuteReader() 

		if($reader.HasRows)
		{
			while ($reader.Read())
			{
					# assign SQL record values to parameters
					$enterprise_id  = $reader.GetValue(0);
					$practice_id    = $reader.GetValue(1);
					$person_id      = $reader.GetValue(2);
			}
		} else {
			Write-Warning -Message "Unable to find encounter details"
			return 0;
		}
		
		$reader.Close()


		$storage_location = get-NextGenDocumentStorageLocation -connectionString $connectionString
		$year = Get-Date -uformat %Y
		$date = Get-Date -uformat %Y%m%d
		$doc_sub_location = "$year\$date\"
		$docGuid = New-Guid
		$doc_file_name = "$docGuid.doc"
		$document_id = New-Guid
	
		$newFilePath = "$storage_location$doc_sub_location$doc_file_name"
	
		# Make sure that the file won't overwrite an existing file
		while((Test-Path -Path $newFilePath -PathType leaf) -eq $true)
		{
			$docGuid = New-Guid
			$doc_file_name = "$docGuid.doc"
			$newFilePath = "$storage_location$doc_sub_location$doc_file_name"
		}
#Write-Output "New File Path: $newFilePath"    
		$NextGen_insert_statement = @"
		INSERT INTO patient_documents
		(
			enterprise_id,
			practice_id,
			enc_id,
			person_id,
			document_id,
			document_file,
			document_desc,
			app_created_by,
			file_format,
			created_by,
			modified_by,
			location,
			sub_location
		)
		VALUES
		(
			'$enterprise_id',
			'$practice_id',
			'$enc_id',
			'$person_id',
			'$document_id',
			'$doc_file_name',
			'$document_desc',
			'$app_created_by',
			'DCX',
			$NGUserID,
			$NGUserID,
			'$storage_location',
			'$doc_sub_location'
		)
"@
#Write-Output $NextGen_insert_statement        
		# turn the SQL query into a command that can be run through the open DB connection
		$command = New-Object System.Data.SQLClient.SQLCommand
		$command.Connection = $connection
		$command.CommandText = $NextGen_insert_statement
	
		$rowsAffected = $command.ExecuteNonQuery() 
		if($rowsAffected -eq 0)
		{
			Write-Warning -Message "Adding new document failed!"
			Return 0;
		}
		else {
			Copy-Item -Path $Path -Destination $newFilePath -Verbose
			Write-Warning -Message "Adding new document success!"
		}






		# Add the document to Category view in NextGen EHR, if the document qualifies
		if( $document_category -ne "" -and
			$document_category -ne $null)
		{
			$NextGen_Category_Insert = @"
			INSERT INTO view_history
			(   enterprise_id,
				practice_id,
				view_history_id,
				enc_id,
				person_id,
				cat_id,
				object_type,
				object_id,
				enc_timestamp
			)
			SELECT
				'$enterprise_id',
				'$practice_id',
				NEWID(),
				'$enc_id',
				'$person_id',
				(SELECT cat_id FROM view_categories_mstr WHERE cat_desc = '$document_category'),
				'D',
				'$document_desc',
				enc_timestamp
			FROM patient_encounter
			WHERE enc_id = '$enc_id'
"@
			$command.CommandText = $NextGen_Category_Insert
			
			# execute the query
#            $reader = $command.ExecuteReader() 
			
			# close SQL query
#            $reader.Close()


			$command.CommandText = $NextGen_Category_Insert
			$rowsAffected = $command.ExecuteNonQuery() 
			if($rowsAffected -eq 0)
			{
				Write-Warning -Message "Adding new category failed!"
				Send-MailMessage -SmtpServer "intranet1.nwsurgical.com" -To "mhokanson@reboundmd.com" -From "DocumentImportTroubleshooting@Reboundmd.com" -Subject "Import Category Query" -Body $NextGen_Category_Insert
				Return 0;
			}
			else {
				Copy-Item -Path $Path -Destination $newFilePath -Verbose
				Write-Warning -Message "Adding new category record success!"
			}
		}
	}

	# close SQL query
	$connection.Close()
}
