Import-Module NextGenEMR -Force

$newUser = @{
	username = "testtest"
	firstname = "testfname"
	lastname = "testlname"
	email = "test@reboundmd.com"
	password = "Password.1" | ConvertTo-SecureString -AsPlainText -Force
	securityGroups = @(
		"TestGroup"
	)
	userPrefs = @(
		$(ConvertFrom-Json @"
		[
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "DEFAULT_TEMPLATE", "item_value": ""},
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "DEFAULT_TEMPLATE_DEMOGRAPHICS", "item_value": ""},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "Display KBM Help Menu", "item_value": "TRUE"},
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "EHR Patient Info Bar State", "item_value": "1 0"},
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "INITIAL_MODULE", "item_value": ""},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "LABS_INITIAL_MODULE_VIEW", "item_value": "Results Flowsheet"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "LABS_VIEW_LONG_DESC", "item_value": "Short Description"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "LABS_VIEW_RESULTS_ONLY", "item_value": "0"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "Main Toolbar", "item_value": "168|16384|0|0"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "PatSel - Full day appts", "item_value": "true"},
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "Prompt Enc auto create sync", "item_value": "Y"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "Quick View Bar", "item_value": "0|0|622|588|4096"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "Summary View Bar", "item_value": "0|0|309|588|4096"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "Suspend EPM Patient Sync.", "item_value": "N"},
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "Use Provider Location XRef", "item_value": "0"},
				{"enterprise_id": "00001", "practice_id": "0001", "item_name": "WorkFlow Appts: Open Template", "item_value": "0"},
				{"enterprise_id": "     ", "practice_id": "    ", "item_name": "WorkFlow Delegate Notify", "item_value": "1"}
		]
"@)
	)
}

Add-NextGenUser @newUser -Verbose