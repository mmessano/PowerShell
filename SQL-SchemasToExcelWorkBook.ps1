#This script was inspired by Phil Factor's article at http://www.simple-talk.com/dotnet/.net-tools/com-automation-of-office-applications-via-powershell/.
Import-Module SqlServer
Import-Module Pscx

#This script will, for each relevant service, create an Excel workbook and populate it with the values from that service.
$sql = "PSQLRPT24"
$db = "PA_DMart"

#Create a directory if it does not already exist.
$DirectoryToSaveTo='e:\Dexma\Logs\'

if (!(Test-Path -path "$DirectoryToSaveTo"))
{
	New-Item "$DirectoryToSaveTo" -type directory | out-null
}
$filename = $DirectoryToSaveTo + "Test File.xlsx"
if (test-path $filename) { rm $filename }	#delete existing files

$Excel = New-Object -Com Excel.Application
$Excel.Visible = $true

#Sleep!  This is because I don't know better and need to wait to add the workbook.
Start-Sleep -s 1
$Workbook = $Excel.Workbooks.Add()

$schemas_query = "select distinct SCHEMA_NAME(schema_id) as Name, schema_id from sys.tables order by Name DESC;"
foreach ($record in Get-SQLData $sql $db $schemas_query)
{
	$query = "select SCHEMA_NAME(schema_id) as SchemaName, name as TableName, object_id as ObjectId, max_column_id_used as MaxColumnId from sys.tables where schema_id =" + $record.schema_id
	$csvResults = Get-SQLData $sql $db $query | Select-Object SchemaName, TableName, ObjectId, MaxColumnId | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation

	#This requires Pscx.
	$csvResults | Out-Clipboard

	#Create the workbook and paste in the board data.  We throw in a sleep here because I don't know how to wait until the workbook is ready to be added...
	Start-Sleep -s 1
	$Worksheet = $Workbook.Sheets.Add()
	$Worksheet.Name = $record.Name
	$Range = $Worksheet.Range("a1","d$($csvResults.count + 1)")
	$Worksheet.Paste($Range, $false)

	#Make this look pretty and copy the data to the clipboard.
	$Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Excel.ActiveCell.CurrentRegion, $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes).Name = "Table2"
	$Worksheet.ListObjects.Item("Table2").TableStyle = "TableStyleMedium2"
	$Range.EntireColumn.Autofit()
}

#Clean up by deleting the Sheet1, Sheet2, and Sheet3 sheets.
$Excel.DisplayAlerts = $false
$Workbook.Worksheets.Item("Sheet1").Delete()
$Workbook.Worksheets.Item("Sheet2").Delete()
$Workbook.Worksheets.Item("Sheet3").Delete()

$Workbook.SaveAs($filename)
#$Excel.quit()
