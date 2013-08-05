# DMartSyncTRNByClient.ps1
# copy trn files from one server\folder to another server\folder

param( 
	$Client = 'GTE'
	, $TrnSourcePath = '\\psqlrpt24\e$\MSSQL10.MSSQLSERVER\MSSQL\TRN\'
	, $TrnDestPath = '\\pcon310\Relateprod\FTP sites\'
	)

#clear the console screen
cls

$a = get-date
$b = $a.AddMinutes(-15)

$ClientSrcPath = $TrnSourcePath + '\DMart_' + $Client + 'CDC_Data\'
#Write-Host "ClientPath: " $ClientPath


if (!(Test-Path -Path $ClientSrcPath)){
	Write-Host "$ClientSrcPath not found!"	
	break;
	}
ELSE {
	#Write-Host "Found $ClientSrcPath."
	$CopyFrom = @(Get-ChildItem -path "$ClientSrcPath*.trn" ) | Where-Object{$_.LastWriteTime -lt $b}
	}

#Write-Host "CopyFrom: " $CopyFrom

Write-Host

$ClientDestPath = $TrnDestPath + $Client + 'prodrpt\'
#Write-Host "ClientDestPath: " $ClientDestPath

if (!(Test-Path -Path $ClientDestPath)) {
	Write-Host "$ClientDestPath not found!"
	break;
	}
ELSE {
	#Write-Host "Found $ClientDestPath."
	$CopyTo = @(Get-ChildItem -path "$ClientDestPath*.trn")
	}

#Write-Host "CopyTo: " $CopyTo


$Files2Copy = Compare-Object -ReferenceObject $CopyFrom -DifferenceObject $CopyTo -Property name, length -PassThru | Where-Object {$_.SideIndicator -eq "<="}
#$Files2Copy

if ($Files2Copy -ne $NULL)
	{
	foreach ($File in $Files2Copy)
        {
        write-host "This will copy File $($File.FullName) to $ClientDestPath$($File.Name)" -ForegroundColor "Red"
        Copy-Item -Path $($File.FullName) -Destination $ClientDestPath$($File.Name) -whatif
        }
	}
else
    {
    Write-Host "No files to copy for $Client!" -foregroundcolor "blue"
    }

$Files2Delete = Compare-Object -ReferenceObject $CopyFrom -DifferenceObject $CopyTo -IncludeEqual -Property name, length -PassThru | Where-Object {$_.SideIndicator -eq "=>"}
$Files2Delete

if ($Files2Delete -ne $NULL)
	{
	foreach ($File in $Files2Delete)
    	{
        write-host "This will delete File $($File.FullName)" -ForegroundColor "Red"
        Remove-Item -Path $($File.FullName) -whatif
        }
	}
else
    {
    Write-Host "No files to delete for $Client!" -foregroundcolor "blue"
    }

