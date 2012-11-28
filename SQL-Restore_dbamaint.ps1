# SQL-Restore_dbamaint.ps1

param( 
	$SQLServer,
	$BAKFile = '\\xsqlutil18\e$\MSSQL10.MSSQLSERVER\MSSQL\dbamaint_empty_11_26_2012.bak',
	$FilePrefix = 'Log',
	[switch]$Log
)

$ScriptName = [system.io.path]::GetFilenameWithoutExtension($MyInvocation.InvocationName)

# check input variable.  if empty read server list from a text file
if (!$SQLServer )
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

# SQL Queries
$Truncdbamaint = "
	DECLARE @Table SYSNAME
	DECLARE @CMD NVARCHAR(256)

	DECLARE dTables CURSOR FOR
		SELECT name FROM sys.tables
		WHERE is_ms_shipped = 0
		AND Name != 'SQLDirPaths'; -- contains a foreign key and is truncated by the sproc that uses it
		
	OPEN dTables;
	FETCH NEXT FROM dTables INTO @Table;
		
	WHILE @@FETCH_STATUS = 0
		BEGIN
		
		SELECT @CMD = 'TRUNCATE TABLE [' + @Table + ']'
		PRINT @CMD;
		exec(@CMD);
		FETCH NEXT FROM dTables INTO @Table;
		END;
		
	CLOSE dTables;
	DEALLOCATE dTables;"
	
$OwnerUpdate = "EXEC sp_changedbowner 'sa';"	
$UpdateStats = "exec sp_updatestats;"
$CheckDB = "DBCC CHECKDB WITH DATA_PURITY;"




foreach ( $Server IN $SQLServer )
	{
	# restore dbamaint backup file
	Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection
	
	#fix owner, truncate all tables, update the stats and run DBCC
	Run-Query -SqlQuery $OwnerUpdate 	-SqlServer $Server -SqlCatalog dbamaint
	Run-Query -SqlQuery $Truncdbamaint 	-SqlServer $Server -SqlCatalog dbamaint
	Run-Query -SqlQuery $UpdateStats 	-SqlServer $Server -SqlCatalog dbamaint
	Run-Query -SqlQuery $CheckDB 		-SqlServer $Server -SqlCatalog dbamaint
	
	}

