# AHMSIReports.ps1
# http://www.vistax64.com/powershell/190352-executing-sql-queries-powershell.html

$server = "XSQLUTIL18"
$database = "master"
$query = "
SELECT	[sys].[tables].[name]
	  , [sys].[tables].[create_date]
	  , [sys].[tables].[modify_date]
FROM	sys.tables

SELECT	[sys].[columns].[name]
	  , [sys].[columns].[max_length]
	  , [sys].[columns].[precision]
	  , [sys].[columns].[scale]
FROM	sys.columns

SELECT	[sys].[indexes].[name]
	  , [sys].[indexes].[type_desc]
FROM	sys.indexes

SELECT	[sys].[databases].[name]
	  , [sys].[databases].[create_date]
	  , [sys].[databases].[compatibility_level]
	  , [sys].[databases].[collation_name]
FROM	sys.databases

SELECT	[sys].[database_files].[file_id]
	  , [sys].[database_files].[file_guid]
	  , [sys].[database_files].[type]
	  , [sys].[database_files].[type_desc]
	  , [sys].[database_files].[data_space_id]
	  , [sys].[database_files].[name]
	  , [sys].[database_files].[physical_name]
	  , [sys].[database_files].[state]
	  , [sys].[database_files].[state_desc]
	  , [sys].[database_files].[size]
	  , [sys].[database_files].[max_size]
	  , [sys].[database_files].[growth]
FROM	sys.database_files
"

# If you have to use users and passwords, my condolences
$connectionTemplate = "Data Source={0};Integrated Security=SSPI;Initial Catalog={1};"
$connectionString = [string]::Format($connectionTemplate, $server, $database)
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

$command = New-Object System.Data.SqlClient.SqlCommand
$command.CommandText = $query
$command.Connection = $connection

$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $command
$DataSet = New-Object System.Data.DataSet
$SqlAdapter.Fill($DataSet)
$connection.Close()

$excel = new-object -comobject excel.application
$excel.visible = $false
$workbook = $excel.workbooks.add()

for($i=4; $i -ge 0; $i--)
	{
	switch ($i) 
		{
			"0"	{ 	$extractFile 	= 	"E:\Dexma\AHMSIReports\Tables.csv"; 
					$TabName		=	"Tables";
					$Columns		=	"C";}
			"1"	{ 	$extractFile 	= 	"E:\Dexma\AHMSIReports\Columns.csv";  
					$TabName		=	"Columns";
					$Columns		=	"C";}
			"2"	{ 	$extractFile 	= 	"E:\Dexma\AHMSIReports\Indexes.csv"; 
					$TabName		=	"Indexes";
					$Columns		=	"B";}
			"3"	{ 	$extractFile 	= 	"E:\Dexma\AHMSIReports\Databases.csv"; 
					$TabName		=	"Databases";
					$Columns		=	"D";}
			"4"	{ 	$extractFile 	= 	"E:\Dexma\AHMSIReports\DatabaseFiles.csv";  
					$TabName		=	"DatabaseFiles";
					$Columns		=	"L";}
		}

	#$DataSet.Tables[$i] | Export-Csv $extractFile -NoTypeInformation
	
	$csvResults = $DataSet.Tables[$i] | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation
	$csvResults | Out-Clipboard
	
	$Worksheet = $Workbook.Sheets.Add()
    $Worksheet.Name = $TabName
    $Range = $Worksheet.Range("a1","$Columns$($csvResults.count)")
    $Worksheet.Paste($Range, $false)
 
    #Make this look pretty and copy the data to the clipboard.
    #$Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Excel.ActiveCell.CurrentRegion, $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes).Name = "Table2"
    #$Worksheet.ListObjects.Item("Table2").TableStyle = "TableStyleMedium2"
    $Range.EntireColumn.Autofit()
	}

#Clean up by deleting the Sheet1, Sheet2, and Sheet3 sheets.
$Excel.DisplayAlerts = $false
$Workbook.Worksheets.Item("Sheet1").Delete()
$Workbook.Worksheets.Item("Sheet2").Delete()
$Workbook.Worksheets.Item("Sheet3").Delete()
 
$Workbook.SaveAs("E:\Dexma\AHMSIReports\AHMSIReport.xlsx")
