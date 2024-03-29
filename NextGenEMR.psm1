$script:ModuleRoot = $PSScriptRoot

function Import-ModuleFile
{
	[CmdletBinding()]
	Param (
		[string]
		$Path
	)
	
	if ($doDotSource) { . $Path }
	else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null) }
}

# Detect whether at some level dotsourcing was enforced
$script:doDotSource = $false
if ($NextGen_Docs_dotsourcemodule) { $script:doDotSource = $true }
if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsPowerShell\NextGenEMR\System" -Name "DoDotSource" -ErrorAction Ignore).DoDotSource) { $script:doDotSource = $true }
if ((Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\WindowsPowerShell\NextGenEMR\System" -Name "DoDotSource" -ErrorAction Ignore).DoDotSource) { $script:doDotSource = $true }

#Requires -Modules dbatools

# Import non-powershell components
[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
[System.Reflection.Assembly]::LoadFrom($ModuleRoot + "\components\itextsharp.dll") | Out-Null
$moduleSettings = Join-Path $env:AppData -childPath "PowerShell\NextGenEMR\settings.json"
if($(Test-Path $moduleSettings) -eq $false){
	New-Item -ItemType File -Path $moduleSettings
	$blankSettings = @"
{
	"databaseServer":"",
	"database":"",
	"databaseUseTrusted":true,
	"databaseUsername":"",
	"databasePassword":"",
	"operator_id":,
	"passwordSalt":""
}
"@
	Set-Content -Path $moduleSettings -Value $blankSettings
}

# Import all public functions
foreach ($function in (Get-ChildItem "$ModuleRoot\functions\*.ps1"))
{
	. Import-ModuleFile -Path $function.FullName
}