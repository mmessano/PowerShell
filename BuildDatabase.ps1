# Documentation on the SMO can be found here:
# http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.aspx
# PowerShell "$(ProjectDir)\PowerShell\BuildDatabase.ps1" -server 'localhost' -instance 'default' -database 'chattychef' -newDatabase 'gourmet', -file 'C:\bleak\gourmet\database.sql'

# define parameters
param
(
	$server 		= $(read-host "Server ('localhost' okay)"),
	$instance 		= $(read-host "Instance ('default' okay)"),
	$database 		= $(read-host "Database"),
	$newDatabase 	= $(read-host "New Database Name"),
	$file 			= $(read-host "Script path and file name")
)

###
### Replaces a String within a file
###
function Replace-String($find, $replace, $replaceFile)
{
	(Get-Content $replaceFile) | Foreach-Object {$_ -replace $find, $replace} | Set-Content $replaceFile
}

# Get the date for use elsewhere
$timeStamp = (((Get-Date).GetDateTimeFormats())[94]).Replace("-", "").Replace(":", "").Replace(" ", "_")



# Load the SQL Server Management Object
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $server
$dbs=$s.Databases

# This Sql Connection is the .NET SQL Connection, used for Querying data, not writing DDL

# Create SqlConnection object and define connection string
$connection = New-Object System.Data.SqlClient.SqlConnection
if ($database -ne "default")
	{
	$connection.ConnectionString = "Data Source=" + $server + ";Initial Catalog=" + $database + ";Integrated Security=SSPI;"
	}
	else
	{
	$connection.ConnectionString = "Data Source=" + $server + "\" + $instance + ";Initial Catalog=" + $database + ";Integrated Security=SSPI;"
	}




# Scripting Options
$so = new-object Microsoft.SqlServer.Management.Smo.ScriptingOptions
$so.AllowSystemObjects = $false
$so.AnsiPadding = $false
$so.AnsiFile = $false
$so.DdlHeaderOnly = $false
$so.IncludeHeaders = $false

"USE [master]" | Out-File $file
"GO" | Out-File $file -append

#if ($newDatabase -eq "")
#{
"DECLARE @spid int, @killstatement nvarchar(10)" | Out-File $file -append
"declare c1 cursor for select request_session_id from sys.dm_tran_locks where resource_type='DATABASE' AND DB_NAME(resource_database_id) = '" + $newDatabase + "'" | Out-File $file -append
"open c1" | Out-File $file -append
"fetch next from c1 into @spid" | Out-File $file -append
"while @@FETCH_STATUS = 0" | Out-File $file -append
"begin" | Out-File $file -append
" IF @@SPID <> @spid" | Out-File $file -append
" begin" | Out-File $file -append
" set @killstatement = 'KILL ' + cast(@spid as varchar(3))" | Out-File $file -append
" exec sp_executesql @killstatement" | Out-File $file -append
" end" | Out-File $file -append
" fetch next from c1 into @spid" | Out-File $file -append
"end" | Out-File $file -append
"close c1" | Out-File $file -append
"deallocate c1" | Out-File $file -append
"GO" | Out-File $file -append
"IF EXISTS(SELECT name FROM sys.databases WHERE name = '" + $newDatabase + "')" | Out-File $file -append
"BEGIN" | Out-File $file -append
"BACKUP DATABASE " + $database | Out-File $file -append
" TO DISK = '" + $database + "_" + $timeStamp + ".bak'" | Out-File $file -append
" WITH FORMAT," | Out-File $file -append
" MEDIANAME = 'Z_SQLServerBackups'," | Out-File $file -append
" NAME = 'Full Backup of Chatty Chef before Auto Restore Dated " + $timeStamp + "'" | Out-File $file -append
"END" | Out-File $file -append
"GO" | Out-File $file -append
"IF EXISTS(SELECT name FROM sys.databases WHERE name = '" + $newDatabase + "')" | Out-File $file -append
"BEGIN" | Out-File $file -append
"DROP DATABASE " + $newDatabase | Out-File $file -append
"END" | Out-File $file -append
"GO" | Out-File $file -append
# $newDatabase = $database
#}
"CREATE DATABASE [" + $newDatabase + "]" | Out-File $file -append
"GO" | Out-File $file -append
"USE [" + $newDatabase + "]" | Out-File $file -append
"GO" | Out-File $file -append

#Generate script for all Roles
#foreach ($Roles in $dbs[$database].Roles)
#{
# $Roles.Script($so) " | out-File $file -append
#}

foreach ($User in $dbs[$database].Users)
{
if ($User.Name -like "db_*" -or
$User.Name -like "dbo" -or
$User.Name -like "sys" -or
$User.Name -like "guest" -or
$User.Name -like "INFORMATION_SCHEMA"
)
{}
else
{
"IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE name = '" + $User.Name + "')" | out-File $file -append
"BEGIN" | out-File $file -append
" CREATE LOGIN ["+ $User.Name +"] WITH PASSWORD = '" + $User.Name + "', CHECK_POLICY = OFF" | out-File $file -append
"END" | out-File $file -append
"GO" | out-file $file -append
$User.Script($so) | out-File $file -append

"GO" | out-file $file -append
}
}


#Generate script for all schemas

"-----------------------------" | out-File $file -append
"-- Schemas" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($schemas in $dbs[$database].Schemas)
{
if ($schemas.Name -like "db_*" -or
$schemas.Name -like "dbo" -or
$schemas.Name -like "sys" -or
$schemas.Name -like "guest" -or
$schemas.Name -like "INFORMATION_SCHEMA"
)
{}
else
{
$schemas.Script($so) | out-File $file -append
"GO" | out-file $file -append
}
}



#Generate script for all tables

"-----------------------------" | out-File $file -append
"-- Tables Part 1 - Table Structure" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($tables in $dbs[$database].Tables)
{
if ($tables.Name -ne "sysdiagrams" -and
$tables.Name -ne "sys"
)
{
$tables.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}



"-----------------------------" | out-File $file -append
"-- Tables Part 2 - Indices and Triggers" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($tables in $dbs[$database].Tables)
{
if ($tables.Name -ne "sysdiagrams" -and
$tables.Name -ne "sys"
)
{
#Generate script for all indexes in the specified table
foreach($index in $tables.Indexes)
{
$index.Script($so) | out-File $file -append
"GO" | out-File $file -append
}

foreach($tableTriggers in $tables.Triggers)
{
$tableTriggers.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}
}


"-----------------------------" | out-File $file -append
"-- Tables Part 3 - Generate Reference Table Data" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($table in $dbs[$database].Tables)
{
if ($table.Name -ne "sysdiagrams" -and
$table.Name -ne "sys"
)
{
#Generate script for all indexes in the specified table
foreach($extendedProperty in $table.ExtendedProperties)
{
if
(
$extendedProperty.Name -eq "IsReferenceTable" -and
$extendedProperty.Value -eq "True"
)
{
"EXEC sys.sp_addextendedproperty " | out-File $file -append
"@name = N'IsReferenceTable', " | out-File $file -append
"@value = N'true', " | out-File $file -append
"@level0type = N'SCHEMA', @level0name = " + $table.Schema + ", " | out-File $file -append
"@level1type = N'TABLE', @level1name = " + $table.Name + " " | out-File $file -append
"GO" | out-File $file -append
"INSERT INTO [" + $table.Schema + "].[" + $table.Name + "]" | out-File $file -append
"(" | out-File $file -append
$columnCounter = 0
foreach ($column in $table.Columns)
{
if ($columnCounter -gt 0)
{
", [" + $column.Name + "]" | out-File $file -append
}
else
{
" [" + $column.Name + "]" | out-File $file -append
}
$columnCounter++
}
")" | out-File $file -append
"VALUES" | out-File $file -append
"(" | out-File $file -append
# Build a Query to Load in the Data from the reference table
$query = "SELECT "
$columnCounter = 0
foreach ($column in $table.Columns)
{
if ($columnCounter -gt 0)
{
$query = $query + ",[" + $column.Name + "]"
}
else
{
$query = $query + "[" + $column.Name + "]"
}
$columnCounter++
}
$query = $query + " FROM [" + $table.Schema + "].[" + $table.Name + "]"
# "-- " + $query | out-File $file -append
$connection.open()

# Create SqlCommand object, define command text, and set the connection
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.CommandText = $query
$cmd.Connection = $connection

# Create SqlDataReader
$dr = $cmd.ExecuteReader()

if ($dr.HasRows)
{
While ($dr.Read())
{
# Write-Host $dr["FirstName"] $dr["LastName"]
$columnCounter = 0
foreach ($column in $table.Columns)
{
# Write-Host $column.Name $column.DataType
Write-Host $columnCounter
if ($columnCounter -eq 0)
{
if
(
$column.DataType.ToString() -eq "int" -OR
$column.DataType.ToString() -eq "bit"
)
{
" " + $dr[$column.Name] | out-File $file -append
}
else
{
" '" + $dr[$column.Name] + "'" | out-File $file -append
}
}
else
{
if
(
($column.DataType.ToString() -eq "int") -OR
($column.DataType.ToString() -eq "bit")
)
{
", " + $dr[$column.Name] | out-File $file -append
}
else
{
", '" + $dr[$column.Name] + "'" | out-File $file -append
}
}
$columnCounter++
}
}
}
Else
{
Write-Host The DataReader contains no rows.
}

# Close the data reader and the connection
$dr.Close()
$connection.Close()
")" | out-File $file -append
}
}
}
}

#Generate script for all extended Stored Procedures
"-----------------------------" | out-File $file -append
"-- Extended Stored Procedures" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($Extendedprocedures in $dbs[$database].ExtendedStoredProcedures)
{
if ($Extendedprocedures.Schema -ne "sys" -and
$Extendedprocedures.Schema -ne "sys"
)
{
"GO" | out-File $file -append
$Extendedprocedures.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}


$so = new-object Microsoft.SqlServer.Management.Smo.ScriptingOptions
$so.AllowSystemObjects = $false
$so.AnsiPadding = $false
$so.AnsiFile = $false
$so.IncludeHeaders = $false

#Generate script for all Stored Procedures
"-----------------------------" | out-File $file -append
"-- Stored Procedures" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($procedures in $dbs[$database].StoredProcedures)
{
if ($procedures.Schema -ne "sys")
{
"GO" | out-File $file -append
$procedures.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}

#Generate script for all Views
"-----------------------------" | out-File $file -append
"-- Views" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($Views in $dbs[$database].Views)
{
if ($Views.Schema -ne "sys" -and
$Views.Schema -ne "INFORMATION_SCHEMA")
{
"GO" | out-File $file -append
$Views.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}

#Generate scription for all UserDefinedFunctions
"-----------------------------" | out-File $file -append
"-- User Defined Functions" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($UserDefinedFunction in $dbs[$database].UserDefinedFunctions)
{
if ($UserDefinedFunction.schema -ne "sys")
{
$UserDefinedFunction.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}


#Generate script for database Triggers
"-----------------------------" | out-File $file -append
"-- Triggers" | out-File $file -append
"-----------------------------" | out-File $file -append
foreach ($Triggers in $dbs[$database].Triggers)
{
if ($Triggers.Schema -ne "sys")
{
$Triggers.Script($so) | out-File $file -append
"GO" | out-File $file -append
}
}

Replace-String "SET ANSI_NULLS ON" "" $file
Replace-String "SET QUOTED_IDENTIFIER ON" "" $file