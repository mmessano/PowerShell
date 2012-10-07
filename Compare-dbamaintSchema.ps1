param( 
	$SqlServerOne = 'XSQLUTIL18',  # default master copy
	$FirstDatabase = 'dbamaint', 
	$SecondDatabase = 'dbamaint',
	[String[]] $ServerList,
	$FilePrefix = 'Log',
	[switch]$Log,
	[switch]$Column
	)

$File = $FilePrefix + '{0}-{1}.csv'
$Date = (Get-Date -Format ddMMyyyy)

$ScriptName = [system.io.path]::GetFilenameWithoutExtension($MyInvocation.InvocationName)

# create arrays for storing the differences found
$TableDifferences = @()
$SprocDifferences = @()
$ColumnDifferences = @()

$TableQuery = "	
	SELECT name AS TableName
		, SCHEMA_NAME(SCHEMA_ID) AS [Schema]
	FROM sys.objects
	WHERE type LIKE 'U'
	AND is_ms_shipped = '0'"

$SprocQuery = "
	SELECT SPECIFIC_NAME AS SprocName
		, (SELECT CONVERT(NVARCHAR(42),HashBytes('SHA1', ROUTINE_DEFINITION),2)) AS SprocHASH
	FROM INFORMATION_SCHEMA.ROUTINES
	WHERE ROUTINE_TYPE = 'PROCEDURE' 
	AND ROUTINE_NAME NOT LIKE 'dt_%' 
	AND ROUTINE_NAME NOT LIKE '%diagram%' 
	AND ROUTINE_NAME NOT LIKE 'upd_SupportPasswords_AcrossSites%'
	AND ROUTINE_NAME NOT LIKE 'upd_SupportSMCPasswords_AcrossSites%'
	AND ROUTINE_NAME != 'sel_AuditTrackingReportStatus'
	"

function write-log([string]$info)
{
    if($loginitialized -eq $false)
	{
        $FileHeader > $logfile            
        $script:loginitialized = $True            
    }            
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
$script:logfile = "E:\Dexma\Logs\DbamaintAudit-$(get-date -format MMddyy).log"
$script:Seperator = @"

$("-" * 25)

"@            
$script:loginitialized = $false            
$script:FileHeader = 
@"
SourceServer, ComparedServer, DifferentServer, Database, Schema.Table, Column, Type, Length
"@

# write empty line to log to zero it out if there are no results
Write-Log

# outer loop over the list of databases passed in
foreach ($SqlServerTwo in $ServerList)
{
#"Current server:" + $SqlServerTwo
# get the table lists from each db
$TablesDBOne = Run-Query -SqlQuery $TableQuery -SqlServer $SqlServerOne -SqlCatalog $FirstDatabase -SqlUser $SqlUsernameOne -SqlPass $SqlPasswordOne | Select-Object -Property TableName, Schema
$TablesDBTwo = Run-Query -SqlQuery $TableQuery -SqlServer $SqlServerTwo -SqlCatalog $SecondDatabase -SqlUser $SqlUsernameTwo -SqlPass $SqlPasswordTwo | Select-Object -Property TableName, Schema

# get the stored procedure names and definition hashes
$SprocsDBOne = Run-Query -SqlQuery $SprocQuery -SqlServer $SqlServerOne -SqlCatalog $FirstDatabase -SqlUser $SqlUsernameOne -SqlPass $SqlPasswordOne | Select-Object -Property SprocName, SprocHASH
$SprocsDBTwo = Run-Query -SqlQuery $SprocQuery -SqlServer $SqlServerTwo -SqlCatalog $SecondDatabase -SqlUser $SqlUsernameOne -SqlPass $SqlPasswordOne | Select-Object -Property SprocName, SprocHASH

$Server = 		@{Name='Server';	Expression={if ($_.SideIndicator -eq '<='){'{0}' -f $SqlServerOne} 	else {'{0}' -f $SqlServerTwo}}}
$Database = 	@{Name='Database';	Expression={if ($_.SideIndicator -eq '<='){'{0}' -f $FirstDatabase} else {'{0}' -f $SecondDatabase}}}

$TableDifference = Compare-Object $TablesDBOne $TablesDBTwo -SyncWindow (($TablesDBOne.count + $TablesDBTwo.count)/2) -Property TableName, Schema | select TableName, Schema, $Server, $Database
$SprocDifference = Compare-Object $SprocsDBOne $SprocsDBTwo -SyncWindow (($SprocsDBOne.count + $SprocsDBTwo.count)/2) -Property SprocName, SprocHASH | select SprocName, SprocHASH, $Server, $Database

if ($log)
{
	if ($TableDifference)
	{
		foreach ( $Row in $TableDifference )
			{
				write-log "$SqlServerOne, $SqlServerTwo, $($Row.Server), $FirstDatabase, $($Row.Schema).$($Row.TableName)"
				#write-log "Server:`t$($Row.Server)`nDbase:`t$($Row.Database)`nTable:`t$($Row.TableName)`n"
				$TableDiff = New-Object -TypeName PSObject
					Add-Member -InputObject $TableDiff -type NoteProperty -Name "SQLServerExists" 	-value $SqlServerOne
					Add-Member -InputObject $TableDiff -type NoteProperty -Name "SQLServerMissing" 	-value $SqlServerTwo
					Add-Member -InputObject $TableDiff -type NoteProperty -Name "Database" 			-value $($Row.Database)
					Add-Member -InputObject $TableDiff -type NoteProperty -Name "Schema"			-Value $($Row.Schema)
					Add-Member -InputObject $TableDiff -type NoteProperty -Name "TableName" 		-value $($Row.TableName)
				$TableDifferences += $TableDiff
			}
	}
	if ($SprocDifference)
	{
		foreach ( $Diff in $SprocDifference )
			{
				#Write-Host "Found a sproc difference."
				write-log "$SqlServerOne, $SqlServerTwo, $($Diff.Server), $FirstDatabase, $($Diff.SprocName), $($Diff.SprocHASH)"
				$SprocDiff = New-Object -TypeName PSObject
					Add-Member -InputObject $SprocDiff -type NoteProperty -Name "SQLServerExists" 	-Value $SqlServerOne
					Add-Member -InputObject $SprocDiff -type NoteProperty -Name "SQLServerMissing" 	-Value $SqlServerTwo
					Add-Member -InputObject $SprocDiff -type NoteProperty -Name "Server" 			-Value $($Diff.Server)
					Add-Member -InputObject $SprocDiff -type NoteProperty -Name "Database" 			-Value $($Diff.Database)
					Add-Member -InputObject $SprocDiff -type NoteProperty -Name "SprocName" 		-Value $($Diff.SprocName)
					Add-Member -InputObject $SprocDiff -type NoteProperty -Name "SprocHASH" 		-Value $($Diff.SprocHASH)
				$SprocDifferences += $SprocDiff
			}
	}
}

# output to console
# use Out-Host so both objects are written with the correct headers
#$TableDifference | Sort-Object -Property TableName, Database | Out-Host
#$SprocDifference | Sort-Object -Property SprocName, SprocHASH | Out-Host

if ($Column)
{
	#Compare columns in matching tables in DB
	$SameTables = Compare-Object $TablesDBOne $TablesDBTwo -SyncWindow (($TablesDBOne.count + $TablesDBTwo.count)/2) -Property TableName -IncludeEqual -ExcludeDifferent 
	
	$ColumnQuery = @"
select so.name as TableName
	, sc.name as ColumnName
	, SCHEMA_NAME(so.SCHEMA_ID) as [Schema]
	, st.name as [Type]
	, isc.CHARACTER_MAXIMUM_LENGTH AS [Length]
	, st.User_Type_ID as UserTypeID
from sys.objects so, sys.columns sc, sys.types st, information_schema.columns isc
where so.type like 'U' and
	so.name not like 'dtproperties' 
	and sc.user_type_id= st.user_type_id
	and so.object_id=sc.object_id
	and sc.name = isc.COLUMN_NAME
	and so.name = isc.TABLE_NAME
	and so.name = '{0}'
order by so.name, sc.name--, sc.type
"@
	
	foreach ($Table in $SameTables)
	{
		$ColumnsDBOne = Run-Query -SqlQuery ($ColumnQuery -f $table.tablename) -SqlServer $SqlServerOne -SqlCatalog dbamaint -SqlUser $SqlUsernameOne -SqlPass $SqlPasswordOne | Select-Object -Property TableName, ColumnName, Schema, Type, Length, UserTypeID, Name
		$ColumnsDBTwo = Run-Query -SqlQuery ($ColumnQuery -f $table.tablename) -SqlServer $SqlServerTwo -SqlCatalog dbamaint -SqlUser $SqlUsernameTwo -SqlPass $SqlPasswordTwo | Select-Object -Property TableName, ColumnName, Schema, Type, Length, UserTypeID, Name
		
		#$Server = 		@{Name='Server';	Expression={if ($_.SideIndicator -eq '<='){'{0}' -f $SqlServerOne} 	else {'{0}' -f $SqlServerTwo}}}

		$ColumnDifference = Compare-Object $ColumnsDBOne $ColumnsDBTwo -SyncWindow (($ColumnsDBOne.count + $ColumnsDBTwo.count)/2) -Property TableName, Schema, ColumnName, Type, Length, UserTypeID, Name | Select-Object TableName, Schema, ColumnName, Type, Length, UserTypeID, Name, $Server, $Database

		if ($log -and $ColumnDifference )
		{
			foreach ( $Row in $ColumnDifference )
			{
				write-log "$SqlServerOne, $SqlServerTwo, $($Row.Server), $($Row.Database), $($Row.TableName), $($Row.Schema).$($Row.ColumnName), $($Row.Type), $($Row.length)"
				$ColumnDiff = New-Object -TypeName PSObject
					#Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "SQLServerOne" -Value $SqlServerOne
					#Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "SQLServerTwo" -Value $SqlServerTwo
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "Server" 		-Value $($Row.Server)
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "Database" 	-Value $($Row.Database)
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "TableName" 	-Value $($Row.TableName)
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "Schema"		-Value $($Row.Schema)
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "ColumnName" 	-Value $($Row.ColumnName)
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "Type" 		-Value $($Row.Type)
					Add-Member -InputObject $ColumnDiff -type NoteProperty -Name "Length" 		-Value $($Row.length)
				$ColumnDifferences += $ColumnDiff
			}
		}
		# output to console
		#$ColumnDifference | Sort-Object -Property ColumnName, Database, Schema
		
	}
}
}

# output to console
# use Out-Host so both objects are written with the correct headers
#$TableDifferences | Sort-Object -Property Server, TableName, Database | Format-Wide {$_} -AutoSize -Force | Out-Host
#$SprocDifferences | Sort-Object -Property Server, SprocName, SprocHASH | Format-Wide {$_} -AutoSize -Force | Out-Host
#$ColumnDifferences | Sort-Object -Property Server, ColumnName, TableName | Format-Wide {$_} -AutoSize | Out-Host


$TableDifferences | Sort-Object -Property SQLServerTwo, TableName, Database | Export-Csv -Path e:\dexma\logs\TableDiff.$ScriptName.$Date.csv -notypeinformation
$SprocDifferences | Sort-Object -Property SQLServerMissing, SprocHASH, SprocName  | Export-Csv -Path e:\dexma\logs\SprocDiff.$ScriptName.$Date.csv -notypeinformation
$ColumnDifferences | Sort-Object -Property Server, ColumnName, TableName | Where-Object {$_.Server -ne "XSQLUTIL18"} | Export-Csv -Path e:\dexma\logs\ColDiff.$ScriptName.$Date.csv -notypeinformation


