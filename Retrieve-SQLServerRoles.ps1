# Retrieve-SQLServerRoles

$isodate=Get-Date -format s 
$isodate=$isodate -replace(":","")
#$basepath=(Get-Location -PSProvider FileSystem).ProviderPath
#$instancepath=$basepath + "\instances.txt"
$instancepath="\\xmonitor11\Dexma\Data\ServerLists\All_DB.txt"
$outputfile="E:\Dexma\Logs\\SQLServerHealthSecurityCheck_" + $isodate + ".xls"
#$outputfilefull = $basepath + $outputfile
$outputfilefull = $outputfile

#Part 2 Create a new Excel object using COM
$Excel = New-Object -ComObject Excel.Application
$workbook = $Excel.Workbooks.Add()
$worksheet4 = $workbook.Worksheets.Add() 
$Sheet = $Excel.Worksheets.Item(1)
#$workbook = $excel.Workbooks.Open($basepath + $outputfile)

#Counter variable for rows
$intRow = 2
#Read thru the contents of the SQL_Servers.txt file
#Part 3 
$servers = Import-Csv $instancepath
##Part4#######################################################
foreach ($entry in $servers)
{
	$torp = $entry.TorP
	$mon = $entry.monitor
	$machine = $entry.server
	$errorlog = $entry.errorlog
	$os = $entry.os2000
	$iname = $entry.Instance

	if ($iname -eq "Null")
	{
		$instance = "$machine"
	}
	else
	{
		$instance = "$machine\$iname"
	}
	if ($torp -eq "Prod")
	{
		$ServerType = "Production"
	}
	ElseIf ($torp -eq "Test")
	{
		$ServerType = "Test"
	}
	ElseIf ($torp -eq "Dev")
	{
		$ServerType = "Dev"
	}
	else 
	{
		$ServerType = "Unknown"
	}

	$instance = $instance.toupper()
	#########################################################
	#Create column headers
	$Sheet.Cells.Item($intRow,1) = "INSTANCE NAME:"
	$Sheet.Cells.Item($intRow,2) = $instance
	################################################
	#Part 5 - This script gets SQL Server database information using PowerShell
	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
	# Create an SMO connection to the instance
	$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance
	$logins = $s.Logins

	$intRow++
	$Sheet.Cells.Item($intRow,1) = "LOGIN"
	$Sheet.Cells.Item($intRow,2) = "SYS"
	$Sheet.Cells.Item($intRow,3) = "SECURITY"
	$Sheet.Cells.Item($intRow,4) = "IS SERVER"
	$Sheet.Cells.Item($intRow,5) = "SETUP"
	$Sheet.Cells.Item($intRow,6) = "PROCESS"
	$Sheet.Cells.Item($intRow,7) = "DISK"
	$Sheet.Cells.Item($intRow,8) = "DBCREATOR"
	$Sheet.Cells.Item($intRow,9) = "BULADMIN"
	$Sheet.Cells.Item($intRow,10) = "LOGIN_TYPE"
	#Format the column headers
	for ($col = 1; $col –le 10; $col++)
	{
	$Sheet.Cells.Item($intRow,$col).Font.Bold = $True
	$Sheet.Cells.Item($intRow,$col).Interior.ColorIndex = 48
	$Sheet.Cells.Item($intRow,$col).Font.ColorIndex = 34
	}
	$intRow++
	##part 6 - iterate through the collection 
	foreach ($login in $logins)
	{
		#use name variable for remaining script
		$name = $login.name
		$loginType=$login.logintype
		if ($loginType -eq 0)
		{
		$loginType = "Windows User"
		}elseif ($loginType -eq 1)
		{
		$loginType = "Windows Group"
		}elseif ($loginType -eq 2)
		{
		$loginType = "SQL Login"
		}
		$Sheet.Cells.Item($intRow, 1) = $name 
		$Sheet.Cells.Item($intRow, 2) = $s.Logins["$name"].IsMember("sysadmin")
		$Sheet.Cells.Item($intRow, 3) = $s.Logins["$name"].IsMember("securityadmin")
		$Sheet.Cells.Item($intRow, 4) = $s.Logins["$name"].IsMember("serveradmin")
		$Sheet.Cells.Item($intRow, 5) = $s.Logins["$name"].IsMember("setupadmin")
		$Sheet.Cells.Item($intRow, 6) = $s.Logins["$name"].IsMember("processdmin")
		$Sheet.Cells.Item($intRow, 7) = $s.Logins["$name"].IsMember("diskadmin")
		$Sheet.Cells.Item($intRow, 8) = $s.Logins["$name"].IsMember("dbcreator")
		$Sheet.Cells.Item($intRow, 9) = $s.Logins["$name"].IsMember("bulkadmin")
		$Sheet.Cells.Item($intRow, 10) = $loginType
		$intRow ++
	}
	$intRow ++
}

$Sheet.UsedRange.EntireColumn.AutoFit()
cls
#Part 7 
$EXcel.ActiveWorkbook.SaveAs("$outputfilefull")
$Excel.Quit()
$WorkBook = $Null
$WorkSheet = $Null
$Excel = $Null
[GC]::Collect()