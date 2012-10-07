# SQL-UnusedIndexes.ps1
# mmessano
# 10/31/2011
################################################################################

# parameters
Param(
	$Clients = ""
	, $TableName = ""
	, $DropIndexStatement = ""
	, $IndexName = ""
)


# Queries
$UnusedIndexesQuery =
   "sel_SQLIndexesUnusedByDatabase"
# IF ($Clients)
#    {$UnusedIndexesQuery = $UnusedIndexesQuery + " @Clients = $Clients"}
# IF ($TableName)
#    {$UnusedIndexesQuery = $UnusedIndexesQuery + " @TableName = $TableName"}
# IF ($DropIndexStatement)
#    {$UnusedIndexesQuery = $UnusedIndexesQuery + " @DropIndexStatement = $DropIndexStatement"}
# IF ($IndexName)
#    {$UnusedIndexesQuery = $UnusedIndexesQuery + " @IndexName = '$IndexName'"}
#    
# Write-Host $UnusedIndexesQuery
################################################################################

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
$indexes = Run-Query -SqlQuery $UnusedIndexesQuery -SqlServer XSQLUTIL18 -SqlCatalog Status

$SpreadSheet = ("E:\Dexma\logs\IndexesUnused-" + (Get-Date -Format ddMMyyyy) + ".xlsx")
$TempCSV = ($env:TEMP + "\" + ([System.GUID]::NewGuid()).ToString() + ".csv")
$indexes | Export-Csv -Path $TempCSV -NoTypeInformation

if (Test-Path -Path $SpreadSheet) { Remove-Item -Path $SpreadSheet }

# set up the workbook
$erroractionpreference = "SilentlyContinue"
$OutBook = New-Object -comobject Excel.Application
$OutBook.visible = $False


$Workbook = $OutBook.Workbooks.Open($TempCSV)
$Workbook.Title = ("Unused Indexes reported by SQL Server DMVs" + (Get-Date -Format D))
$Workbook.Author = "Michael J. Messano"

$Worksheet = $Workbook.Worksheets.Item(1)

$List = $Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null, [Microsoft.Office.Interop.Excel.X1YesNoGuess]::xlYes, $null)
$List.Name = "Item Table"

# add the TotalDrops formula
$LastRow = ($worksheet.UsedRange.Rows.Count + 1)
for ( $i = 2; $i -lt $LastRow; $i++) {
	# write the formula to column 4, subtract leading columns from column total so formual is correct
	# the count is relative from the formula column
	$Worksheet.Cells.item($i,4) = "=SUM(RC[1]" + ':' + "RC[" + ($worksheet.UsedRange.Columns.Count - 4) + "])"
}

# sort the worksheet on the TotalDrops column
$order = [Microsoft.Office.Interop.Excel.XlSortOrder]::xlDescending
$xlDescending = 2
$hasHead = [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes
$range = $worksheet.UsedRange
$sortcolumn = $worksheet.Columns.Item(4)
$range.Sort($sortcolumn, $xlDescending)

# colorize and auto-fit the cells
$LastColumn = ($worksheet.UsedRange.Columns.Count + 1 )
for ( $i = 1; $i -lt $LastColumn; $i++) {
	$Worksheet.Cells.item(1,$i).Interior.ColorIndex = 15
	$Worksheet.Cells.item(1,$i).Font.ColorIndex = 5
	$Worksheet.Cells.item(1,$i).Font.Bold = $True
	if ($i -gt 3) {
		$Worksheet.Cells.item(1,$i).Orientation = 90
		}
}

# this works but is horribly stupidly slow
#for ($r = 2; $r -lt $LastRow; $r++) {
#	for ($c = 4; $c -lt $LastColumn; $c++) {
#		#Write-Host "Found a value of " ($Worksheet.cells.item($r,$c)).Text " here: $r,$c"
#		if ($Worksheet.cells.item($r,$c).Text -eq 1) {
#			$Worksheet.Cells.item($r,$c).Font.ColorIndex = 4
#		}
#	}
#}

# this works as well, might be marginally faster
#foreach ($cell in $range) {
#	Write-Host "Cell values is " ($cell).text
#	if ($cell.text -eq 1) { 
#		$cell.Font.ColorIndex = 4
#	}
#}

$Worksheet.UsedRange.EntireColumn.Autofit() | Out-Null
$Worksheet.Name = "Unused Indexes"

$Workbook.SaveAs($SpreadSheet, 51) 
$Workbook.Saved = $true
$Workbook.Close()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null

$SpreadSheet.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($SpreadSheet) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

if (Test-Path -Path $TempCSV) { Remove-Item -Path $TempCSV }