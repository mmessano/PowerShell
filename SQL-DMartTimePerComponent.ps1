# SQL-DMartTimePerComponent.ps1
# mmessano
# 9/26/2012
################################################################################
# parameters
param( 
	$SQLServer = 'PSQLRPT24'
	, $Database = 'PA_DMart'
	, $StartDate = (Get-Date)
	, $EndDAte = (Get-Date)
)

Import-Module SqlServer
Import-Module Pscx

# Queries
$Queries = "sel_DMartComponentLogByClient ", "sel_DMartComponentLogByTaskName", "sel_DMartCDC_DataComponentLogByClient", "sel_DMartCDC_DataComponentLogByTaskName"
Write-host $Queries

$SpreadSheet = ("E:\Dexma\logs\DMartTaskExecutionTimesMatrix-" + (Get-Date -Format ddMMyyyy) + ".xlsx")
if (Test-Path -Path $SpreadSheet) { Remove-Item -Path $SpreadSheet }	 #delete existing files

# set up the Excel object
$erroractionpreference = "SilentlyContinue"
$ExcelObj = New-Object -comobject Excel.Application
$ExcelObj.visible = $True

#Sleep!  This is because I don't know better and need to wait to add the workbook.
Start-Sleep -s 1

# set up the workbook object
$Workbook = $ExcelObj.Workbooks.Add()
$Workbook.Title = ("Execution Times Per Component for DMart SSIS Package Execution" + (Get-Date -Format D))
$Workbook.Author = "Michael J. Messano"


foreach ($Query IN $Queries ) {

	#$csvResults = Get-SQLData $sql $db $query | Select-Object SchemaName, TableName, ObjectId, MaxColumnId | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation
	$csvResults = Get-SQLData $SQLServer $Database $Query | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation

	#$csvResults | Out-Host
	
	#This requires Pscx.
	$csvResults | Out-Clipboard

	#Create the workbook and paste in the board data.  We throw in a sleep here because I don't know how to wait until the workbook is ready to be added...
	Start-Sleep -s 1
	$Worksheet = $Workbook.Sheets.Add()
	$Worksheet.Name = $csvResults.ReportDate
	$Range = $Worksheet.Range("a1","d$($csvResults.count + 1)")
	$Worksheet.Paste($Range, $false)
#-confirm:$false
	#Make this look pretty and copy the data to the clipboard.
	#$Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes).Name = "Table2"
	$Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null, [Microsoft.Office.Interop.Excel.X1YesNoGuess]::xlYes, $null)
	$Worksheet.ListObjects.Item("Table2").TableStyle = "TableStyleMedium2"
	#$Range.EntireColumn.Autofit()
	$Worksheet.UsedRange.EntireColumn.Autofit() | Out-Null
}

$List = $Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null, [Microsoft.Office.Interop.Excel.X1YesNoGuess]::xlYes, $null)
$List.Name = "Item Table"

 colorize and auto-fit the cells
$LastColumn = ($worksheet.UsedRange.Columns.Count + 1 )
for ( $i = 1; $i -lt $LastColumn; $i++) {
	$Worksheet.Cells.item(1,$i).Interior.ColorIndex = 15
	$Worksheet.Cells.item(1,$i).Font.ColorIndex = 5
	$Worksheet.Cells.item(1,$i).Font.Bold = $True
	if ($i -gt 3) {
		$Worksheet.Cells.item(1,$i).Orientation = 90
		}
}

#Clean up by deleting the Sheet1, Sheet2, and Sheet3 sheets.
$Excel.DisplayAlerts = $false
$Workbook.Worksheets.Item("Sheet1").Delete()
$Workbook.Worksheets.Item("Sheet2").Delete()
$Workbook.Worksheets.Item("Sheet3").Delete()

$Workbook.SaveAs($SpreadSheet, 51) 
$Workbook.Saved = $true
$Workbook.Close()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null

$SpreadSheet.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($SpreadSheet) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
$ExcelObj.Quit()
