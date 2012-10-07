#requires -version 2

function Export-Xls{
$data = Get-Process | Select-Object Name, Id, WS
PS> Export-Xls $data C:\Reports\MyWkb.xlsx -WorksheetName “WS” -AppendWorksheet:$false
.EXAMPLE
PS> $data = Get-Process | Select-Object Name, Id, WS
PS> Export-Xls $data C:\Reports\MyWkb.xlsx -SheetPosition “end”
.EXAMPLE
PS> $data = Get-Process | Select-Object Name, Id, WS
PS> Export-Xls $data C:\Reports\MyWkb.xlsx -WorksheetName “WS” -ChartType “xlColumnClustered”
.EXAMPLE
PS> $data = Get-Process | Select-Object Name, Id, WS
PS> Export-Xls $data C:\Reports\MyWkb.xlsx -WorksheetName “WS” -ChartType “xlColumnClustered” -AutoFilter:$true -SplitRow 1 -SplitColumn 1
.EXAMPLE
PS> $header = $headers = @(@(“Name”, “Process Name”),@(“ID”, “id”),@(“WS”, “WS”))
PS> $data = Get-Process | Select-Object Name, Id, WS
PS> Export-Xls $data C:\Reports\MyWkb.xlsx -Headers $header
This will result in a table where column A is titled “Process Name”, column B is titled “id” and column C is titled “WS”
#>
param(
	[parameter(ValueFromPipeline = $true,Position=1)]
	, [ValidateNotNullOrEmpty()]
	, $InputObject
	, [parameter(Position=2)]
	, [ValidateNotNullOrEmpty()]
	, [string]$Path
	, [string]$WorksheetName = (“Sheet ” + (Get-Date).Ticks)
	, [string]$SheetPosition = “begin”
	, [PSObject]$ChartType
	, [switch]$NoTypeInformation = $true
	, [switch]$AppendWorksheet = $true
	, [switch]$AutoFilter = $true
	, [int]$SplitRow = 1
	, [int]$SplitColumn = 0
	, $Headers
)

begin{
[System.Reflection.Assembly]::LoadWithPartialName(“Microsoft.Office.Interop.Excel”)
if($ChartType)
{
	[microsoft.Office.Interop.Excel.XlChartType]$ChartType = $ChartType
}

function Set-ClipBoard{
	param(
		[string]$text
	)
	process{
	Add-Type -AssemblyName System.Windows.Forms
	$tb = New-Object System.Windows.Forms.TextBox
	$tb.Multiline = $true
	$tb.Text = $text
	$tb.SelectAll()
	$tb.Copy()
	}
}

function Add-Array2Clipboard {
	param (
		[PSObject[]]$ConvertObject,
		[switch]$Header
	)
process{
	$array = @()

	if ($Header) {
		$line =”"
		if ($headers) {
		foreach ($column in $headers) {
		$line += ([string]$column[1] + “`t”)
		}
	}
	else {
	$ConvertObject | Get-Member -MemberType Property,NoteProperty,CodeProperty | Select -Property Name | %{$line += ($_.Name.tostring() + “`t”)
	}
	}
	$array += ($line.TrimEnd(“`t”) + “`r”)
	}
	else {
	foreach($row in $ConvertObject){
	$line =”"
	if ($headers) {
	foreach ($column in $headers) {
	if ($row.($column[0])) {
	$val = [string] $row.($column[0])
	}
	else {
	$val = “”
	}
	$line += ($val + “`t”)
	#$line += ($row.([string]$column[0]) + “`t”)
	}
	}
	else {
	$row | Get-Member -MemberType Property,NoteProperty | %{
	$Name = $_.Name
	if(!$Row.$Name){$Row.$Name = “”}
	$line += ([string]$Row.$Name + “`t”)
	}
	}
	$array += ($line.TrimEnd(“`t”) + “`r”)
	}
	}
	Set-ClipBoard $array
	}
}

[System.Threading.Thread]::CurrentThread.CurrentCulture = “en-US”
$excelApp = New-Object -ComObject “Excel.Application”
$originalAlerts = $excelApp.DisplayAlerts
$excelApp.DisplayAlerts = $false
if(Test-Path -Path $Path -PathType “Leaf”){
$workBook = $excelApp.Workbooks.Open($Path)
}
else{
$workBook = $excelApp.Workbooks.Add()
}
$sheet = $excelApp.Worksheets.Add($workBook.Worksheets.Item(1))
if(!$AppendWorksheet){
$workBook.Sheets | where {$_ -ne $sheet} | %{$_.Delete()}
}
$sheet.Name = $WorksheetName
if($SheetPosition -eq “end”){
$nrSheets = $workBook.Sheets.Count
2..($nrSheets) |%{
$workbook.Sheets.Item($_).Move($workbook.Sheets.Item($_ – 1))
}
}

if (($SplitRow -gt 0) -or ($SplitColumn -gt 0)) {
$excelApp.ActiveWindow.SplitRow = $SplitRow
$excelApp.ActiveWindow.SplitColumn = $SplitColumn
$excelApp.ActiveWindow.FreezePanes = $true
}

$sheet.Activate()
$array = @()
}

process{
$array += $InputObject
}

end{
Add-Array2Clipboard $array -Header:$True
$selection = $sheet.Range(“A1″)
$selection.Select() | Out-Null
$sheet.Paste()
$Sheet.UsedRange.HorizontalAlignment = [microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignCenter
Add-Array2Clipboard $array
$selection = $sheet.Range(“A2″)
$selection.Select() | Out-Null
$sheet.Paste() | Out-Null
$selection = $sheet.Range(“A1″)
$selection.Select() | Out-Null

if ($AutoFilter) {
$sheet.UsedRange.EntireColumn.AutoFilter()
}
$sheet.UsedRange.EntireColumn.AutoFit() | Out-Null

$workbook.Sheets.Item(1).Select()
if($ChartType){
$sheet.Shapes.AddChart($ChartType) | Out-Null
}
$workbook.SaveAs($Path)
$excelApp.DisplayAlerts = $originalAlerts
$excelApp.Quit()
Sleep -s 3
Stop-Process -Name “Excel”
}
}