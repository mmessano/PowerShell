param( 
	$SqlServerOne = 'YourDatabaseServer',
	$FirstDatabase = 'FirstDatabaseToCompare', 
	$SqlUsernameOne = 'SQL Login',
	$SqlPasswordOne = 'SQL Password',
	$SqlServerTwo = 'YourDatabaseServer',
	$SecondDatabase = 'SecondDatabaseToCompare', 
	$SqlUsernameTwo = 'SQL Login',
	$SqlPasswordTwo = 'SQL Password',
	$FilePrefix = 'Log',
	[switch]$Log,
	[switch]$Column
	)

$File = $FilePrefix + '{0}-{1}.csv'

$TableQuery = "	select sysobjects.name as TableName
	from sysobjects
	where sysobjects.xtype like 'U' and --specify only user tables
	sysobjects.name not like 'dtproperties' --specify only user tables"

function write-log([string]$info)
{
#    if($loginitialized -eq $false)
#	{
#        $FileHeader > $logfile            
#        $script:loginitialized = $True            
#    }            
    $info >> $logfile            
}

function Run-Query()
{
	param (
	$SqlQuery,
	$SqlServer,
	$SqlCatalog, 
	$SqlUser,
	$SqlPass
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


<#---------Logfile Info----------#>            
$script:logfile = "C:\Dexma\powershell_bits\DMartAudit-$(get-date -format MMddyy).log"
$script:Seperator = @"

$("-" * 25)

"@            
$script:loginitialized = $false            
$script:FileHeader = @"

CompareDMart:  C:\Dexma\powershell_bits\Compare-DMartSchema.ps1
Last Modified:  $(Get-Date -Date (get-item "C:\Dexma\powershell_bits\Compare-DMartSchema.ps1").LastWriteTime -f MM/dd/yyyy)
"@

$TablesDBOne = Run-Query -SqlQuery $TableQuery -SqlServer $SqlServerOne -SqlCatalog $FirstDatabase -SqlUser $SqlUsernameOne -SqlPass $SqlPasswordOne | Select-Object -Property TableName

$TablesDBTwo = Run-Query -SqlQuery $TableQuery -SqlServer $SqlServerTwo -SqlCatalog $SecondDatabase -SqlUser $SqlUsernameTwo -SqlPass $SqlPasswordTwo | Select-Object -Property TableName

# log to console
Write-Host 'Differences in Tables: '
write-log ""
$Database = @{Name='Database';Expression={if ($_.SideIndicator -eq '<='){'{0}, {1}' -f $SqlServerOne, $FirstDatabase} else {'{0}, {1}' -f $SqlServerTwo, $SecondDatabase}}}
#$Database = @{Name='Database';Expression={if ($_.SideIndicator -eq '<='){'{0} / {1}' -f $FirstDatabase, $SqlServerOne} else {'{0} / {1}' -f $SecondDatabase, $SqlServerTwo}}}
$TableDifference  = Compare-Object $TablesDBOne $TablesDBTwo -SyncWindow (($TablesDBOne.count + $TablesDBTwo.count)/2) -Property TableName | select TableName, $Database

if ($log)
{
	if ($TableDifference)
	{
		foreach ( $Row in $TableDifference )
			{
				write-log " $($Row.TableName) exists in: $($Row.Database)"
			}
	}
}

$TableDifference | Sort-Object -Property TableName, Database


if ($Column)
{
	#Compare columns in matching tables in DB
	$SameTables = Compare-Object $TablesDBOne $TablesDBTwo -SyncWindow (($TablesDBOne.count + $TablesDBTwo.count)/2) -Property TableName -IncludeEqual -ExcludeDifferent 
	
	$ColumnQuery = @"
select sysobjects.name as TableName
	, syscolumns.name as ColumnName 
	, systypes.name as Type
	, systypes.Length
	, systypes.XUserType
from sysobjects, syscolumns, systypes
where sysobjects.xtype like 'U' and --specify only user tables
	sysobjects.name not like 'dtproperties' and --specify only user tables
	syscolumns.xusertype= systypes.xusertype --get data type info
	and sysobjects.id=syscolumns.id 
	and sysobjects.name = '{0}'
order by sysobjects.name, syscolumns.name, syscolumns.type
"@
	
	#Write-Host "`n"
	#Read-Host 'Press Enter to Check for Column Differences'
	
	foreach ($Table in $SameTables)
	{
		$ColumnsDBOne = Run-Query -SqlQuery ($ColumnQuery -f $table.tablename)  -SqlServer $SqlServerOne -SqlCatalog $FirstDatabase -SqlUser $SqlUsernameOne -SqlPass $SqlPasswordOne | Select-Object -Property TableName, ColumnName, Type, Length, XUserType

		$ColumnsDBTwo = Run-Query -SqlQuery ($ColumnQuery -f $table.tablename) -SqlServer $SqlServerTwo -SqlCatalog $SecondDatabase -SqlUser $SqlUsernameTwo -SqlPass $SqlPasswordTwo | Select-Object -Property TableName, ColumnName, Type, Length, XUserType
		
		$ColumnDifference = Compare-Object $ColumnsDBOne $ColumnsDBTwo -SyncWindow (($ColumnsDBOne.count + $ColumnsDBTwo.count)/2) -Property TableName, ColumnName, Type, Length, XUserType, Name | Select-Object TableName, ColumnName, Type, Length, XUserType, $Database
		
		if ($log -and $ColumnDifference )
		{
			#$ColumnDifference | Export-Csv -Path ($file -f $Table.TableName,'Columns' ) -NoTypeInformation -NoClobber
			#$ColumnDifference | Out-File -FilePath ($file -f $Table.TableName,'Columns' ) -NoClobber -Append
			#write-log "Table: $($Table.TableName)"
			foreach ( $Row in $ColumnDifference )
			{
				write-log "$($Row.Database), $($Row.TableName), $($Row.ColumnName), $($Row.Type), $($Row.Length), $($Row.XUserType),$($Row.Name)"
			}
		}
		# output to console
		$ColumnDifference | sort ColumnName, Database
		
	}
}