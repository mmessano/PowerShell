#region LoadAssemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
#endregion

#Get SQL account information
$credential = Get-Credential
$loginName = $credential.UserName #-replace("\\","")   
$password = $credential.Password


$Excel = New-Object -ComObject Excel.Application
$Excel.visible = $False
$Workbook = $Excel.Workbooks.Add()

#Get list of servers
$srvlist = @(get-content "C:\Users\mmessano\SQLServers.txt")

#Counter variable for rows
$c = $srvlist.Count 
$intRow = 1

#Verify there's a sheet in the workbook for each server 
for ($i = 4; $i -le $c; $i++) 
{
$Workbook.Sheets.Add() 
}

$a = 1
#Read thru the contents of the SQL_Servers.txt file
foreach ($instance in $srvlist) 
{
$Sheet = $Workbook.Worksheets.Item($a) 
$srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
$srv.ConnectionContext.LoginSecure = $false
$srv.ConnectionContext.set_Login($loginName)
$srv.ConnectionContext.set_SecurePassword($password)    
#set headers
$Sheet.Cells.Item($intRow,1) = "INSTANCE NAME:"
$Sheet.Cells.Item($intRow,1).Font.Bold = $True
$Sheet.Cells.Item($intRow,2) = $instance
$Sheet.Cells.Item($intRow,2).Font.Bold = $True
$intRow += 1
$Sheet.Cells.Item($intRow,1) = "VERSION:"
$Sheet.Cells.Item($intRow,2) = "EDITION:"
$Sheet.Cells.Item($intRow,3) = "COLLATION:"
$Sheet.Cells.Item($intRow,4) = "OS VERSION:"
$Sheet.Cells.Item($intRow,5) = "PLATFORM:"
$Sheet.Cells.Item($intRow,6) = "PHYS MEM:"
$Sheet.Cells.Item($intRow,7) = "NUM CPU:"
for ($col = 1; $col –le 7; $col++)
{
$Sheet.Cells.Item($intRow,$col).Font.Bold = $True
$Sheet.Cells.Item($intRow,$col).Interior.ColorIndex = 48
$Sheet.Cells.Item($intRow,$col).Font.ColorIndex = 34
}

#get values
$intRow += 1

$Sheet.Cells.Item($intRow,1) = $srv.Information.Version 
$Sheet.Cells.Item($intRow,2) = $srv.Information.Edition
$Sheet.Cells.Item($intRow,3) = $srv.Information.Collation
$Sheet.Cells.Item($intRow,4) = $srv.Information.OSVersion
$Sheet.Cells.Item($intRow,5) = $srv.Information.Platform
$Sheet.Cells.Item($intRow,6) = $srv.Information.PhysicalMemory
$Sheet.Cells.Item($intRow,7) = $srv.Information.Processors

$intRow += 2

$Sheet.Cells.Item($intRow,1) = "DATABASES"
$Sheet.Cells.Item($intRow,1).Font.Bold = $True

$intRow += 1

$Sheet.Cells.Item($intRow,1) = "DATABASE NAME"
$Sheet.Cells.Item($intRow,2) = "COLLATION"
$Sheet.Cells.Item($intRow,3) = "COMPATIBILITY LEVEL"
$Sheet.Cells.Item($intRow,4) = "AUTOSHRINK"
$Sheet.Cells.Item($intRow,5) = "RECOVERY MODEL"
$Sheet.Cells.Item($intRow,6) = "SIZE (MB)"
$Sheet.Cells.Item($intRow,7) = "SPACE AVAILABLE (MB)"
for ($col = 1; $col –le 7; $col++)
{
$Sheet.Cells.Item($intRow,$col).Font.Bold = $True
$Sheet.Cells.Item($intRow,$col).Interior.ColorIndex = 48
$Sheet.Cells.Item($intRow,$col).Font.ColorIndex = 34
}
$intRow += 1

$dbs = $srv.Databases
ForEach ($db in $dbs) 
{
#Divide the value of SpaceAvailable by 1KB 
$dbSpaceAvailable = $db.SpaceAvailable/1KB
#Format the results to a number with three decimal places 
$dbSpaceAvailable = "{0:N3}" -f $dbSpaceAvailable
$Sheet.Cells.Item($intRow, 1) = $db.Name
$Sheet.Cells.Item($intRow, 2) = $db.Collation
$Sheet.Cells.Item($intRow, 3) = $db.CompatibilityLevel
#Change the background color of the Cell depending on the AutoShrink property value 
if ($db.AutoShrink -eq "True")
{
$fgColor = 3
}
else
{
$fgColor = 0
}
$Sheet.Cells.Item($intRow, 4) = $db.AutoShrink 
$Sheet.Cells.item($intRow, 4).Interior.ColorIndex = $fgColor
$Sheet.Cells.Item($intRow, 5) = $db.RecoveryModel
$Sheet.Cells.Item($intRow, 6) = "{0:N3}" -f $db.Size
#Change the background color of the Cell depending on the SpaceAvailable property value 
if ($dbSpaceAvailable -lt 1.00)
{
$fgColor = 3
}
else
{
$fgColor = 0
}
$Sheet.Cells.Item($intRow, 7) = $dbSpaceAvailable 
$Sheet.Cells.item($intRow, 7).Interior.ColorIndex = $fgColor

$intRow += 1

}
$Sheet.UsedRange.EntireColumn.AutoFit()
$name = $instance -replace("\\", "-")
$Sheet.Name = $name
$intRow = 1
$a += 1
}
#Save file and close Excel.
$xlExcel8 = 56
$timeStamp = Get-Date -Format "yyyyMMdd_HH_mm"
$fileName = "C:\Dexma\logs\ServerInfo_" + $timeStamp + ".xls"
$Workbook.SaveAs($fileName, $xlExcel8)
$Excel.Quit
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel)