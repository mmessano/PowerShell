# DMart-UpdateDB.ps1

param( 
	$SQLServer = 'STGSQLDOC710',
	$ScriptDir = 'C:\Users\MMessano\Desktop\DMartMigration',
	$Beta = 1,
	[String[]] $DatabaseList,
	$FilePrefix = 'Log',
	[switch]$Log
)

$DQuery = "SELECT CDCReportDB FROM ClientConnectionCDC WHERE Beta = " + $Beta + " ORDER BY 1"

$Databases = Invoke-Sqlcmd -ServerInstance $SQLServer -Database PA_DMart -Query $DQuery 

$DataScripts = Get-ChildItem -Path $ScriptDir -Filter *Data*.sql | sort-object -desc

cls

if ($Databases) {
	foreach ($DB IN $Databases) {
		Write-Host "Begin" $DB[0]
			if ($DataScripts) {
				foreach ( $DataScript IN $DataScripts ) {
					Invoke-SQLCMD -ServerInstance $SQLServer -Database $DB[0] -InputFile $DataScript.FullName
					Write-Host "`tApplied " $DataScript.FullName "to the" $DB[0]"database"on" $SQLServer."
				}
			}
		}
#		else {
#			Write-Host "WTF " $DB[0] " is not a Data database."
#		}
	Write-Host "End" $DB[0]
}

