$a = "XSQLUTIL18", "XSQLUTIL19"

$a | % `
{
	$ServerName = $_;
	
	cd sqlserver:\
	cd sql\$ServerName\default\databases
	
	$DBs = dir;
	
	$DBs | % `
	{
	$LastBackupDate = $_.LastBackupDate;
	$LastLogBackupDate = $_.LastLogBackupDate;
	$LastDiffBackupDate = $_.LastDifferentialBackupDate;
	
	invoke-sqlcmd -ServerInstance "XSQLUTIL18" -Database "dbamaint" -query "Insert BackupInfo SELECT '$ServerName', '$lastBackupDate', '$LastLogBackupDate', '$LastDiffBackupDate'" -SuppressProviderContextWarning
	$ServerName;
	$_.Name;
	}
	
	#ft name, LastBackupDate, LastLogBackupDate -autosize

}