# SQL-Restore_dbamaint.ps1

param( 
	$SQLServer = 'STGSQLDOC710',
	$BAKFile = 'e:\Dexma\MSSQL\Bak\',
	$FilePrefix = 'Log',
	[switch]$Log
)

