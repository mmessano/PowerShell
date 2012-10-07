# SQL-VLFToExcel.ps1
# Number of VLFs to Excel Chart

param( 
	$SQLServer = 'PSQLDLS30'
)

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$DataSet = New-Object System.Data.DataSet
$SqlConnection.ConnectionString = "Server=$SQLServer;Database=master;Integrated Security=True"

$SqlCmd.CommandText = "
DECLARE @VLF_TEMP TABLE (
	FileID varchar(3)
	, FileSize numeric(20,0)
	, StartOffset bigint
	, FSeqNo bigint
	, Status char(1)
	, Parity varchar(4)
	, CreateLSN numeric(25,0)
)

DECLARE @VLF_DB_TOTAL_TEMP TABLE (
	name sysname
	, vlf_count int
)

DECLARE db_cursor CURSOR READ_ONLY FOR 
	SELECT name 
	FROM master.dbo.sysdatabases

DECLARE @name sysname, @stmt varchar(40)

OPEN db_cursor

FETCH NEXT FROM db_cursor INTO @name

WHILE (@@fetch_status <> -1)

BEGIN

	IF (@@fetch_status <> -2)
	BEGIN
		INSERT INTO @VLF_TEMP
		EXEC ('DBCC LOGINFO ([' + @name + ']) WITH NO_INFOMSGS')

		INSERT INTO @VLF_DB_TOTAL_TEMP
			SELECT @name, COUNT(*) FROM @VLF_TEMP
			DELETE FROM @VLF_TEMP
	END

	FETCH NEXT FROM db_cursor INTO @name
END

CLOSE db_cursor
DEALLOCATE db_cursor


SELECT TOP 10 @@servername as [ServerName]
			, name as [DBName]
			, vlf_count as [VLFCount]
FROM @VLF_DB_TOTAL_TEMP
WHERE vlf_count > 50
ORDER BY vlf_count DESC
"

$SqlCmd.Connection = $SqlConnection
$SqlAdapter.SelectCommand = $SqlCmd
$SqlAdapter.Fill($DataSet)
$VLFCount =$DataSet.Tables[0]

$excel = new-object -comobject excel.application
$excel.visible = $true
$chartType = "microsoft.office.interop.excel.xlChartType" -as [type]
$workbook = $excel.workbooks.add()
$workbook.WorkSheets.item(1).Name = "VLF"
$sheet = $workbook.WorkSheets.Item("VLF")
$sheet.cells.item(1,1) = "ServerName"
$sheet.cells.item(1,2) = "DBName"
$sheet.cells.item(1,3) = "VLFCount"

$x = 2

Foreach($VLFCount in $VLFCount)
{
	$sheet.cells.item($x,1) = $VLFCount.ServerName
	$sheet.cells.item($x,2) = $VLFCount.DBName
	$sheet.cells.item($x,3) = $VLFCount.VLFCount
	$x++
}

$range = $sheet.usedRange
$range.EntireColumn.AutoFit()
$workbook.charts.add() | Out-Null
$workbook.ActiveChart.chartType = '-4100'
$workbook.ActiveChart.SetSourceData($range)

# If you want to have more fun, then change ::xlPie to 
# ::xl3DPieExploded and uncomment the following lines

#For($i = 15 ; $i -le 360 ; $i +=15)
#{
#	$workbook.ActiveChart.rotation = $i
#}
