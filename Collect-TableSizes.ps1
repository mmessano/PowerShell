# Collect-TableSizes.ps1

param( 
	$SQLServer = 'XSQLUTIL19',
	$Database = 'Chevron_ES27060'
)

# Keep this next part on one line… This gets your objects to put in the chart

$BigTables= DIR SQLSERVER:\SQL\$SQLServer\DEFAULT\Databases\$Database\Tables | sort-Object -Property RowCount -desc | select-Object -First 20

$excel = new-object -comobject excel.application

$excel.visible = $true
$chartType = "microsoft.office.interop.excel.xlChartType" -as [type]
$workbook = $excel.workbooks.add()
$workbook.WorkSheets.item(1).Name = "BigTables"
$sheet = $workbook.WorkSheets.Item("BigTables")
$x = 2

$sheet.cells.item(1,1) = "Schema Name"
$sheet.cells.item(1,2) = "Table Name"
$sheet.cells.item(1,3) = "RowCount"

Foreach($BigTable in $BigTables)
{
	$sheet.cells.item($x,1) = $BigTable.Schema
	$sheet.cells.item($x,2) = $BigTable.Name
	$sheet.cells.item($x,3) = $BigTable.RowCount
	$x++
}

$range = $sheet.usedRange
$range.EntireColumn.AutoFit()
$workbook.charts.add() | Out-Null
$workbook.ActiveChart.chartType = '-4100'
$workbook.ActiveChart.SetSourceData($range)

