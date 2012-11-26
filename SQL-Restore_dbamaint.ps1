# SQL-Restore_dbamaint.ps1

param( 
	$SQLServer,
	$BAKFile = '\\xsqlutil18\e$\MSSQL10.MSSQLSERVER\MSSQL\BAK\dbamaint\dbamaint_backup_2012_11_25_230001_7339465.bak',
	$FilePrefix = 'Log',
	[switch]$Log
)

$ScriptName = [system.io.path]::GetFilenameWithoutExtension($MyInvocation.InvocationName)

IF (!$SQLServer )
{
	$SQLServer = Get-Content "E:\Dexma\data\ServerList.txt"
}

# Functions
function Run-Query()
{
	param (
		$SqlQuery
		, $SqlServer
		, $SqlCatalog
		, $SqlUser
		, $SqlPass
	)
	
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$SqlServer;Integrated Security=SSPI;Initial Catalog=$SqlCatalog;");
	
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $SqlQuery
	$SqlCmd.Connection = $SqlConnection
	
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
	
	$DataSet = New-Object System.Data.DataSet
	$a = $SqlAdapter.Fill($DataSet)
	
	$SqlConnection.Close()
	
	$DataSet.Tables | Select-Object -ExpandProperty Rows
}

$OwnerUpdate = "EXEC sp_changedbowner 'sa';"

foreach ( $Server IN $SQLServer )
	{
	
	Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection
	
	Run-Query -SqlQuery $OwnerUpdate -SqlServer $Server -SqlCatalog dbamaint
	
	}

