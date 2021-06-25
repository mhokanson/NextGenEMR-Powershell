<#
.SYNOPSIS
Take a docx file and convert it into a blob usable in NextGen tables that use the image data type

.PARAMETER Path
Path to a docx file

.EXAMPLE
ConvertTo-NextGenSQLBlob -Path "C:\Sample.docx"
#>
function ConvertTo-NGSQLBlob()
{
    Param (
		[parameter(Mandatory=$true)] [string] $Path
    )
    
    if(Test-Path $Path)
    {
      $bitBlob = [System.IO.File]::ReadAllBytes($Path)

      $hexBlob = ([System.BitConverter]::ToString($bitBlob)).replace("-","")

      return "0x$hexBlob"
    }
    else {
      return $null
    }
}
