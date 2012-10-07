#=============================================================================# 
#                                                                             # 
# ImportExportExcel.psm1                                                      # 
# Imports data from excel and exports data to excel                           # 
# Author: Jeremy Engel                                                        # 
# CreationDate: 05.17.2011                                                    # 
# ModifiedDate: 07.11.2011                                                    # 
# Version: 1.0.8                                                              # 
#                                                                             # 
#=============================================================================# 
 
function Import-Excel { 
  <# 
    .Synopsis 
     Converts an Excel document into an array of objects with the columns as separate properties. 
    .Example 
     Import-Excel -Path .\Example.xlsx 
     This example would import the data stored in the Example.xlsx spreadsheet. 
    .Description 
     The Import-Excel cmdlet converts an Excel document into an array of objects whose property names are determined by the column headers and whose values are determined by the column data. 
     Additionally, you can specify whether this particular Excel file has any headers at all, in which case the objects will be given the property names based on their column. Likewise, if the document has headers, but one column does not, its data will be assigned a Column# property name. 
    .Parameter Path 
     Specifies the path to the Excel file to import. You can also pipe a path to Import-Excel. 
    .Parameter NoHeaders 
     Specifies that the document being imported has no headers. Default value is False. 
    .Outputs 
     PSObject[] 
    .Notes 
     Name:   Import-Excel 
     Module: ImportExportExcel.psm1 
     Author: Jeremy Engel 
     Date:   05.17.2011 
    .Link 
     Export-Excel 
  #> 
  [CmdletBinding()] 
  Param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$Path, 
        [Parameter(Mandatory=$false)][switch]$NoHeaders 
        ) 
  $Path = if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path -Path (Get-Location) -ChildPath $Path} 
  if(!(Test-Path $Path) -or $Path -notmatch ".xls$|.xlsx$") { Write-Host "ERROR: Invalid excel file [$Path]." -ForeGroundColor Red; return } 
  $excel = New-Object -ComObject Excel.Application 
  if(!$excel) { Write-Host "ERROR: Please install Excel first. I haven't figured out how to read an Excel file as xml yet." -ForeGroundColor Red; return } 
  $content = @() 
  $workbooks = $excel.Workbooks 
  $workbook = $workbooks.Open($Path) 
  $worksheets = $workbook.Worksheets 
  $sheet = $worksheets.Item(1) 
  $range = $sheet.UsedRange 
  $rows = $range.Rows 
  $columns = $range.Columns 
  $headers = @() 
  $top = if($NoHeaders){1}else{2}  # This tells the import code what line to start on when retrieving data 
  if($NoHeaders) { for($c=1;$c-le$columns.Count;$c++) { $headers += "Column$c" } }  # If the Excel file has no headers, use Column1, Column2, etc... 
  else { 
    $headers = $rows | Where-Object { $_.Row -eq 1 } | %{ $_.Value2 } 
    for($i=0;$i-lt$headers.Count;$i++) { if(!$headers[$i]) { $headers[$i] = "Column$($i+1)" } }  # If a column is missing a header, then create one 
    } 
  for($r=$top;$r-le$rows.Count;$r++) {  # This for clause reads the content of Excel file and populates an array of objects, with the headers as property names 
    $data = $rows | Where-Object { $_.Row -eq $r } | %{ $_.Value2 } 
    $line = New-Object PSOBject 
    for($c=0;$c-lt$columns.Count;$c++) { $line | Add-Member NoteProperty $headers[$c]($data[$c]) } 
    $content += $line 
    } 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($columns) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($rows) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($range) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheets) } while($o -gt -1) 
  $workbook.Close($false) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbooks) } while($o -gt -1) 
  $excel.Quit() 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) } while($o -gt -1) 
  return $content 
  } 
 
function Export-Excel { 
  <# 
    .Synopsis 
     Converts an array of objects into an Excel document. 
    .Example 
     Export-Excel -Path .\Example.xlsx -InputObject $data 
     This example would import the data stored in $data into an Excel document and save it as Example.xlsx. 
    .Description 
     The Export-Excel cmdlet converts an array of objects into an Excel document. 
     Additionally, you can specify whether you would like the header of each column bolded, and also if you would like it to have a bottom border. 
    .Parameter InputObject 
     Specifies the objects to export to Excel. Enter a variable that contains the objects or type a command or expression that gets the objects. You can also pipe objects to Export-Excel. 
    .Parameter Path 
     Specifies the path to the Excel output file. The parameter is required. 
    .Parameter HeaderBorder 
     Specifies whether to give each header a border, and if so, what type of border to be used. The available options are Line, ThickLine, or DoubleLine. 
    .Parameter BoldHeader 
     Specifies that the header row should be bolded. 
    .Parameter Force 
     Overwrites the file specified in path without prompting. 
    .Outputs 
     String Path 
    .Notes 
     Name:   Export-Excel 
     Module: ImportExportExcel.psm1 
     Author: Jeremy Engel 
     Date:   05.17.2011 
    .Link 
     Import-Excel 
  #> 
  [CmdletBinding()] 
  Param([Parameter(Mandatory=$true)][string]$Path, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][PSObject]$InputObject, 
        [Parameter(Mandatory=$false)][ValidateSet("Line","ThickLine","DoubleLine")][string]$HeaderBorder, 
        [Parameter(Mandatory=$false)][switch]$BoldHeader, 
        [Parameter(Mandatory=$false)][switch]$Force 
        ) 
  $Path = if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path -Path (Get-Location) -ChildPath $Path} 
  if($Path -notmatch ".xls$|.xlsx$") { Write-Host "ERROR: Invalid file extension in Path [$Path]." -ForeGroundColor Red; return } 
  $excel = New-Object -ComObject Excel.Application 
  if(!$excel) { Write-Host "ERROR: Please install Excel first." -ForeGroundColor Red; return } 
  $workbook = $excel.Workbooks.Add() 
  $sheet = $workbook.Worksheets.Item(1) 
  $xml = ConvertTo-XML $InputObject # I couldn't figure out how else to read the NoteProperty names 
  $lines = $xml.Objects.Object.Property 
  for($r=2;$r-le$lines.Count;$r++) { 
    $fields = $lines[$r-1].Property 
    for($c=1;$c-le$fields.Count;$c++) { 
      if($r -eq 2) { $sheet.Cells.Item(1,$c) = $fields[$c-1].Name } 
      $sheet.Cells.Item($r,$c) = $fields[$c-1].InnerText 
      } 
    } 
  [void]($sheet.UsedRange).EntireColumn.AutoFit() 
  $headerRow = $sheet.Range("1:1") 
  if($BoldHeader) { $headerRow.Font.Bold = $true } 
  switch($HeaderBorder) { 
    "Line"       { $style = 1 } 
    "ThickLine"  { $style = 4 } 
    "DoubleLine" { $style = -4119 } 
    default      { $style = -4142 } 
    } 
  $headerRow.Borders.Item(9).LineStyle = $style 
  if($Force) { $excel.DisplayAlerts = $false } 
  $workbook.SaveAs($Path) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($headerRow) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) } while($o -gt -1) 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) } while($o -gt -1) 
  $excel.ActiveWorkbook.Close($false) 
  $excel.Quit() 
  do { $o = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) } while($o -gt -1) 
  return $Path 
  } 
 
Export-ModuleMember Export-Excel,Import-Excel