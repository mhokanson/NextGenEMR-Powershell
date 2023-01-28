function Get-NextGenVariables {
	return $(Get-Content $(Join-Path $env:APPDATA -ChildPath "Powershell\NextGenEMR\settings.json") | ConvertFrom-Json)
}