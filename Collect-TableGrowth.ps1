[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null 

# functions
function Run-Query()
{
	param (
	$SqlQuery,
	$SqlServer,
	$SqlCatalog
	)
	
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$SqlServer;Integrated Security=SSPI;Initial Catalog=$SqlCatalog;");
	
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$sqlCmd.CommandTimeout = "300"
	$SqlCmd.CommandText = $SqlQuery
	$SqlCmd.Connection = $SqlConnection
	
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
	
	$DataSet = New-Object System.Data.DataSet
	$a = $SqlAdapter.Fill($DataSet)
	
	$SqlConnection.Close()
	
	$DataSet.Tables | Select-Object -ExpandProperty Rows
}
################################################################################

# Queries
$ServerQuery = 
"SELECT Server FROM SQLMonitoredObjects
WHERE DatabaseName LIKE 'distribution'
AND Filename LIKE '%.MDF'
AND Server NOT LIKE '%PSQLSVC21%' -- not an SMC replication server
ORDER BY 1"
################################################################################


# retrieve the servers with a distribution database
$Publishers = Run-Query -SqlQuery $ServerQuery -SqlServer XSQLUTIL18 -SqlCatalog  Status | Select-Object -Property Server | Sort-Object -Property Server

# Database and server repository
$ServerCentral = "XSQLUTIL18" 
$DatabaseCentral = "Status" 
#Today date
$TodaysDate = get-date -format "yyyy-MM-dd hh:mm:ss" 

foreach ($svr in get-content "C:\servers\servers.txt" )
{     
	$Server=New-Object "Microsoft.SqlServer.Management.Smo.Server" "$svr"
	$data = $Server.Databases| where-object 
	{
		$_.IsSystemObject -eq $FALSE -and $_.IsAccessible -eq $TRUE -and $_.name -ne "DBA"
	} | foreach 
		{
			$DatabaseName = $_.name
			$ServerName = $Server.Name
			foreach ($tables in $Server.Databases[$_.name].tables ) 
			{
            if (!$tables.IsSystemObject)
            	{
					$tablename = $tables.name
					$SpaceIndexUsed = $tables.IndexSpaceUsed
					$SpaceDataUsed = $tables.DataSpaceUsed

					$sql = "insert into TableGrowth (DDate,
					ServerName,DatabaseName,TableName,
					SpaceIndexUsed,SpaceDataUsed) values 
					('$TodaysDate','$ServerName','$DatabaseName'
					,'$TableName',$SpaceIndexUsed,$SpaceDataUsed)"
					#Invoke-Sqlcmd -ServerInstance $ServerCentral -Database $DatabaseCentral -Query $sql
				}
			}
		}
}