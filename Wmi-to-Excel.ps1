#
#Wmi-to-Excel.ps1 - 12/02/2009 by Kahuna at http://PoshTips.com
#
$erroractionpreference = "SilentlyContinue"
$a = New-Object -comobject Excel.Application
$a.visible = $True
 
$b = $a.Workbooks.Add()
$c = $b.Worksheets.Item(1)
 
#define column headers for the first row of the spreadsheet
$ColHeaders = ("DBName", "addl_loan_data", "appraisal", "borrower", "br_address",
				"br_expense", "br_income", "br_liability", "br_REO", 
				"channels", "codes", "customer_elements", "funding", 
				"inst_channel_assoc", "institution", "institution_association", 
				"loan_appl", "loan_fees", "loan_price_history", "loan_prod", 
				"loan_regulatory", "loan_status", "product", "product_channel_assoc", 
				"property", "servicing", "shipping", "underwriting")
$idx=0
#write the column headings to the spreadsheet
foreach ($title in $ColHeaders) {
    $idx+=1
    $c.Cells.Item(1,$idx) = $title
	#$c.Cells.Orientation = 90
    }
 
$d = $c.UsedRange
$d.Interior.ColorIndex = 19
$d.Font.ColorIndex = 11
$d.Font.Bold = $True
 
$intRow = 2
 
#get contents of file (passed in $args[0]) containing a host list
 
#foreach ($strComputer in get-content $args[0])
#    {
#    write-host "Processing $strComputer..."
#    $OS       = gwmi -computername $strComputer Win32_OperatingSystem
#    $Computer = gwmi -computername $strComputer Win32_computerSystem
#    $Bios     = gwmi -computername $strComputer win32_bios
# 
#    #populate eash row of the spreadsheet with data collected from WMI
#    $c.Cells.Item($intRow,1)   = $OS.Organization
#    $c.Cells.Item($intRow,2)   = $strComputer.Toupper()
#    $c.Cells.Item($intRow,3)   = $OS.Caption
#    $c.Cells.Item($intRow,4)   = $OS.CSDVersion
#    $c.Cells.Item($intRow,5)   = $Computer.SystemType
#    $c.Cells.Item($intRow,6)   = [System.Management.ManagementDateTimeconverter]::ToDateTime($OS.InstallDate)
#    $c.Cells.Item($intRow,7)   = $Computer.Manufacturer
#    $c.Cells.Item($intRow,8)   = $Computer.Model
#    $c.Cells.Item($intRow,9)   = $Bios.serialnumber
#    $c.Cells.Item($intRow,10)  = $OS.SerialNumber
#    $c.Cells.Item($intRow,11)  = $Computer.NumberOfProcessors
#    $c.Cells.Item($intRow,12)  = "{0:N0}" -f ($computer.TotalPhysicalMemory/1GB)
#    $c.Cells.Item($intRow,13)  = [System.Management.ManagementDateTimeconverter]::ToDateTime($OS.LastBootUpTime)
#    $c.Cells.Item($intRow,14)  = Get-date
# 
#    $intRow += 1
#    }
#resize the columns to fit the data
$d.Orientation = 90
$d.EntireColumn.AutoFit() |out-null