$dir = dir e:\dexma
$dir |ConvertTo-Csv -Delimiter "`t" -NoTypeInformation|out-clipboard
$excel = New-Object -ComObject Excel.Application
$excel.visible = $true
$workbook = $excel.Workbooks.Add()
$range = $workbook.ActiveSheet.Range("b5","b$($dir.count + 5)")
$workbook.ActiveSheet.Paste($range, $false)
$workbook.SaveAs("e:\dexma\logs\output.xlsx")