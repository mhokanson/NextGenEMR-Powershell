function get-NGSystemSettings {
	Param (
		[parameter(Mandatory = $true)] [string] $DBServer,
		[parameter(Mandatory = $true)] [string] $Database,
		[parameter(Mandatory = $false)] [switch] $UseWindowsAuthentication,
		[parameter(Mandatory = $false)] [string] $DBUsername,
		[parameter(Mandatory = $false)] [securestring] $DBPassword
	)
	
	$get_storage_location_query = @"
SELECT
	ISNULL(doc_store.connection_info,(SELECT pl.preference_value FROM preference_list pl WHERE preference_id = 501)) AS doc_store_root,
	ISNULL(img_store.connection_info,(SELECT pl.preference_value FROM preference_list pl WHERE preference_id = 201)) AS img_store_root,
	ISNULL(note_store.connection_info,(SELECT pl.preference_value FROM preference_list pl WHERE preference_id = 412)) AS note_store_root,
	ISNULL(report_store.connection_info,(SELECT pl.preference_value FROM preference_list pl WHERE preference_id = 305)) AS report_store_root
FROM practice_emr settings
LEFT JOIN storage doc_store
	ON settings.document_storage_id = doc_store.storage_id
LEFT JOIN storage img_store
	ON settings.image_storage_id = img_store.storage_id
   AND 1 = img_store.product_id
   AND 'Y' <> img_store.delete_ind
LEFT JOIN storage note_store
	ON settings.note_storage_id = note_store.storage_id
   AND 1 = note_store.product_id
   AND 'Y' <> note_store.delete_ind
LEFT JOIN storage report_store
	ON settings.patient_report_storage_id = report_store.storage_id
   AND 1 = report_store.product_id
   AND 'Y' <> report_store.delete_ind
"@

	if ($UseWindowsAuthentication) {
		$settings = Invoke-NGSQLCommand -Server $DBServer -Database $Database -UseWindowsAuthentication:$true -Query $get_storage_location_query
	}
	else {
		$settings = Invoke-NGSQLCommand -Server $DBServer -Database $Database -Username $DBUsername -Password [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DBPassword)) -Query $get_storage_location_query
	}

	return $settings
}