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
#Write-Host "ClientPath : " $ClientPath


if (!(Test-Path -Path $ClientSrcPath)){
	Write-Host "$ClientSrcPath not found!"	
	break;
	}
ELSE {
	#Write-Host "Found $ClientPath to TRN folder."
	$CopyFrom = @(Get-ChildItem -path "$ClientSrcPath*.trn" ) | Where-Object{$_.LastWriteTime -lt $b}
	}

#Write-Host "CopyFrom: " $CopyFrom

Write-Host

$ClientDestPath = $TrnDestPath + $Client + 'prodrpt\'
if (!(Test-Path -Path $ClientDestPath)) {
	Write-Host "$ClientDestPath not found!"
	break;
	}
ELSE {
	#Write-Host "Found $TranDestPath."
	$CopyTo = @(Get-ChildItem -recurse -path "$ClientDestPath*.trn")
	}

#Write-Host "CopyTo: " $CopyTo


$Files2Copy = Compare-Object -ReferenceObject $CopyFrom -DifferenceObject $CopyTo  -Property fullname, name, length  | Where-Object {$_.SideIndicator -eq "<="}
#$Files2Copy

foreach ($File in $Files2Copy)
    {
    if ($File -ne $NULL)
        {
        write-host "This will copy File $($File.FullName) to $ClientDestPath$($File.Name)" -ForegroundColor "Red"
        Copy-Item -Path $($File.FullName) -Destination $ClientDestPath$($File.Name) -whatif
        }
    else
        {
        Write-Host "No files to delete!" -foregroundcolor "blue"
        }
    }

