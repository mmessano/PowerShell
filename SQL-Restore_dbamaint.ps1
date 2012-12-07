# SQL-Restore_dbamaint.ps1
# mmessano
# 11-29-2012

param( 
	$SQLServer,
	$BAKFile = '\\xsqlutil18\e$\MSSQL10.MSSQLSERVER\MSSQL\dbamaint_empty_11_26_2012.bak',
	$FilePrefix = 'Log',
	[switch]$Log
)

#$ScriptName = [system.io.path]::GetFilenameWithoutExtension($MyInvocation.InvocationName)

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

$DrivesQuery = "
DECLARE @drives TABLE
	( 
	drive CHAR(1),
	free  VARCHAR(16)
	);
INSERT INTO @drives
			( drive
			, free
			)
            
EXEC MASTER..Xp_fixeddrives

SELECT drive
FROM   @drives
WHERE drive NOT LIKE '%C%'
ORDER BY 1"

$OwnerUpdate = "EXEC sp_changedbowner 'sa';"	
$UpdateStats = "exec sp_updatestats;"
$CheckDB = "DBCC CHECKDB WITH DATA_PURITY;"




foreach ( $Server IN $SQLServer )
	{
	# determine drive letters
	$Drives = Run-Query -SqlQuery $DrivesQuery -SqlServer $Server -SqlCatalog master | Select drive
	#Write-Host $Server $Drives 
	
	if ( $Drives.Count -gt 1 ) 
	{
		Write-Host "Multiple drive letters found."
		foreach ( $Drive IN $Drives ) 
			{
			switch ($Drive) 
				{ 
			    "D" { Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive) }
			    "E" { Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive) }
			    "F" { Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive) }
				"G" { Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive) }
				"H" { Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive) }
    			}
			}
		
#		foreach ( $Drive IN $Drives ) 
#			{
#			#Write-Host $($Drive.Drive)
#			if ( $($Drive.Drive) -eq 'D' ) 
#				{
#					Write-Host "D drive found."
#					Write-Host "Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)"
#					Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)
#				}
#			ELSEIF ( $($Drive.Drive) -eq 'E' )
#				{
#					Write-Host "E drive found."
#					Write-Host "Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)"
#					Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)
#				}
#			ELSEIF ( $($Drive.Drive) -eq 'F' )
#				{
#					Write-Host "F drive found."
#					Write-Host "Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)"
#					Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)
#				}
#			ELSEIF ( $($Drive.Drive) -eq 'G' )
#				{
#					Write-Host "G drive found."
#					Write-Host "Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)"
#					Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drive.Drive) -LDrive $($Drive.Drive)
#				}
#			}
	}
	ELSE
	{
		Write-Host "Single drive letter found."
		#Write-Host $($Drives.Drive)
		Write-Host "Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drives.Drive) -LDrive $($Drives.Drive)"
		Restore-SQLdatabase -SQLServer $Server -SQLDatabase dbamaint -Path $BAKFile -TrustedConnection -DDrive $($Drives.Drive) -LDrive $($Drives.Drive)
	}
	
	#fix owner, truncate all tables, update the stats and run DBCC
	Run-Query -SqlQuery $OwnerUpdate 	-SqlServer $Server -SqlCatalog dbamaint
	Run-Query -SqlQuery $Truncdbamaint 	-SqlServer $Server -SqlCatalog dbamaint
	Run-Query -SqlQuery $UpdateStats 	-SqlServer $Server -SqlCatalog dbamaint
	Run-Query -SqlQuery $CheckDB 		-SqlServer $Server -SqlCatalog dbamaint
	
	}

