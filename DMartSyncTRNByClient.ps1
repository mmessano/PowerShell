# DMartSyncTRNByClient.ps1
# copy trn files from one server\folder to another server\folder


param( $Client = 'GTE', $TrnSourcePath = '\\psqlrpt24\e$\MSSQL10.MSSQLSERVER\MSSQL\BAK', $TrnDestPath = '\\pcon310\Relateprod\FTP sites\')

#clear the console screen
cls

function create-7zip([String] $aDirectory, [String] $aZipfile){
    [string]$pathToZipExe = "C:\Program Files\7-zip\7z.exe"
    [Array]$arguments = "a", "-t7z", "$aZipfile", "$aDirectory", "-r"
    & $pathToZipExe $arguments
}

function Trim-Bak{
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[System.String]
		$Text	
	)
$regexpattern = "(DMart_\w*_Data_backup_\d{4}_\d{2}_\d{2})"

#$text = "DMart_GTECDC_Data_backup_2013_09_10_233001_7091656.bak"
$regex = New-Object System.Text.RegularExpressions.Regex $regexpattern

$match = $regex.Match($text)
    
    if ($match.Success -and $match.Length -gt 0){
		#$string = ($match.value.ToString()).split(" ")
		$string = $match.value.ToString()
		$string = $string + ".bak"
		return $string
	} else {
		return $Text
	}
	
}	

$a = get-date
$b = $a.AddMinutes(-15)
$b = $a.AddMinutes(-1)

$ClientSrcPath = $TrnSourcePath + '\DMart_' + $Client + 'CDC_Data\'
#Write-Host "ClientPath: " $ClientPath


if (!(Test-Path -Path $ClientSrcPath)){
	Write-Host "$ClientSrcPath not found!"	
	break;
	}
ELSE {
	#Write-Host "Found $ClientSrcPath."
	$CopyFrom = @(Get-ChildItem -path "$ClientSrcPath*bak" ) | Where-Object{$_.LastWriteTime -lt $b}
	#$CopyFrom = @(Get-ChildItem -path "$ClientSrcPath*.trn" ) | Where-Object{$_.LastWriteTime -lt $b}
	}

#Write-Host "CopyFrom: " $CopyFrom

Write-Host
$d = (get-date).toshortdatestring()
$d = $d -replace "`/","-"
$Output = "E:\dexma\logs\Prodops_Scripts_Logs_$d.txt"

$ClientDestPath = $TrnDestPath + $Client + 'prodrpt\'
#$ClientDestPath = $TrnDestPath
#Write-Host "ClientDestPath: " $ClientDestPath

if (!(Test-Path -Path $ClientDestPath)) {
	Write-Host "$ClientDestPath not found!"
	break;
	}
ELSE {
	#Write-Host "Found $ClientDestPath."
	$CopyTo = @(Get-ChildItem -path "$ClientDestPath*.bak")
	}

#Write-Host "CopyTo: " $CopyTo


#$Files2Copy = Compare-Object -ReferenceObject $CopyFrom -DifferenceObject $CopyTo -Property name, length -PassThru | Where-Object {$_.SideIndicator -eq "<="}
#$Files2Copy
$Files2Copy = Get-ChildItem -path "$ClientSrcPath*.bak"  | Where-Object{$_.LastWriteTime -lt $b}

if ($Files2Copy -ne $NULL)
	{
	foreach ($File in $Files2Copy)
        {
        
		[string] $fileZip = $File.FullName
		[string] $newFileZip = Trim-Bak -Text $fileZip
		Rename-Item $fileZip $ClientSrcPath$newFileZip
		$fileZip = $newFileZip.replace(".bak",".7z")
		Write-Host -ForegroundColor Magenta "file: $newFileZip"
		create-7zip  $($ClientSrcPath + $newFileZip) $($ClientSrcPath + $fileZip)
		#we make sure the zipfile is created and delete the .TRN file, the zip file will get cleaned up from the trnfiledel task on xmonitor11
		if (Test-Path $($ClientSrcPath + $newFileZip)) {
			Add-Content $Output "Removing file $($ClientSrcPath + $newFileZip)"
			Remove-Item $($ClientSrcPath + $newFileZip) #-WhatIf
		}
		write-host "This will copy File $($ClientSrcPath + $fileZip) to $ClientDestPath$fileZip" -ForegroundColor "magenta"
        Copy-Item -Path $($ClientSrcPath + $fileZip) -Destination $ClientDestPath #-whatif
		Add-Content $Output "File $fileZip Copied to $ClientDestPath"
		# Check the Zipfile exist
        }
	}
else
    {
    Write-Host "No files to copy for $Client!" -foregroundcolor "blue"
	Add-Content $Output "No files to copy for $Client!"
    }

#$Files2Delete = Compare-Object -ReferenceObject $CopyFrom -DifferenceObject $CopyTo -IncludeEqual -Property name, length -PassThru | Where-Object {$_.SideIndicator -eq "=>"}
#$Files2Delete

#if ($Files2Delete -ne $NULL)
#	{
#	foreach ($File in $Files2Delete)
#    	{
#        write-host "This will delete File $($File.FullName)" -ForegroundColor "Red"
#        Remove-Item -Path $($File.FullName) -whatif
#        }
#	}
#else
#    {
#    Write-Host "No files to delete for $Client!" -foregroundcolor "blue"
#    }

