# SET-SNMPCommunityName.ps1

$Error.Clear()
$erroractionpreference = "SilentlyContinue"

$a = New-Object -comobject Excel.Application
$a.visible = $True
$b = $a.Workbooks.Add()
$c = $b.Worksheets.Item(1)
$c.Cells.Item(1,1) = "Machine Name"
$c.Cells.Item(1,2) = "SNMP Updated"
$d = $c.UsedRange
$d.Interior.ColorIndex = 19
$d.Font.ColorIndex = 11
$d.Font.Bold = $True
$intRow = 2

foreach ($strComputer in get-content C:\MachineList.Txt) {
		$c.Cells.Item($intRow,1) = $strComputer.ToUpper()
		# Using .NET method to ping test the servers
		$ping = new-object System.Net.NetworkInformation.Ping
		$Reply = $ping.send($strComputer)
		if($Reply.status -eq "success") {
			# Open the registry on the remote machine
			$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $strComputer)
			# Navigate to the reg key where the SNMP Community String is stored
			$regKey= $reg.OpenSubKey("SYSTEM\\CurrentControlSet\\Services\\SNMP\\Parameters\\ValidCommunities",$true)
			# Create a new entry for new SNMP String
			$regKey.SetValue('ipm0nitoR','4','DWORD')
			# This is where I delete the old SNMP String
			$regKey.DeleteValue('public')
			If($Error.Count -eq 0) {
				$c.Cells.Item($intRow,2).Interior.ColorIndex = 4
				$c.Cells.Item($intRow,2) = "Yes"
				# If there is no error it will output Yes with green cell
				}
			Else {
				$c.Cells.Item($intRow,2).Interior.ColorIndex = 3
				$c.Cells.Item($intRow,2) = "No"
				# If there is an error it will output No with red cell so if you do not have old string remove that part or it will error everytime but still update
				$Error.Clear()
			}
		}
		Else {
			$c.Cells.Item($intRow,2).Interior.ColorIndex = 3
			$c.Cells.Item($intRow,2) = "Not Pingable"
			# If the server is not pingable we output that with Red cell
		}
	$Error.Clear()
	$Reply = ""
	$pwage = ""
	$intRow = $intRow + 1
	}
$d.EntireColumn.AutoFit()
cls