# DMart-UpdateDB.ps1

param( 
	$SQLServer = 'PSQLRPT24',
	$ScriptDir = '\\xfs3\DataManagement\Footprints\79866',
	$Beta = 6,
	[String[]] $DatabaseList,
	$FilePrefix = 'Log',
	[switch]$Log
)

$SQuery = "SELECT StageDB FROM ClientConnection WHERE Beta = " + $Beta
$DQuery = "SELECT ReportDB FROM ClientConnection WHERE Beta = " + $Beta

$Query = $SQuery + " UNION " + $DQuery

$Databases = Invoke-Sqlcmd -ServerInstance $SQLServer -Database PA_DMart -Query $Query

$DataScripts = Get-ChildItem -Path $ScriptDir -Filter *Data*.sql | sort-object -desc
$StageScripts = Get-ChildItem -Path $ScriptDir -Filter *Stage*.sql | sort-object -desc

if ($Databases) {
	foreach ($i IN $Databases) {
		if ($i[0].EndsWith("Stage")) {
			#Write-Host $i[0] " is a Stage database.";
			if ($StageScripts) {
				foreach ( $StageScript IN $StageScripts ) {
					Invoke-SQLCMD -ServerInstance $SQLServer -Database $i[0] -InputFile $StageScript.FullName
					Write-Host "`tApplied " $StageScript.fullname "to "$i[0]"."
				}
			}
		}
		elseif ($i[0].EndsWith("Data")) {
			#Write-Host $i[0] "is a Data database.";
			if ($DataScripts) {
				foreach ( $DataScript IN $DataScripts ) {
					Invoke-SQLCMD -ServerInstance $SQLServer -Database $i[0] -InputFile $DataScript.FullName
					Write-Host "`tApplied " $DataScript.FullName "to "$i[0]"."
				}
			}
		}
		else {
			Write-Host "WTF " $i[0] " is not a Data or Stage database."
		}
	}
}