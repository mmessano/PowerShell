# Server-Audit.ps1
# Pings a list of servers contained in the text file servers.txt and if the server responds, returns information from each server
#
# mmessano
# 12-5-2012

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

function getwmiinfo ($svr) {
	# Get ComputerSystem info and write it to a CSV file
	gwmi -query "select * from
		Win32_ComputerSystem" -computername $svr | 
		 	select Name, Model, Manufacturer, DNSHostName, CurrentTimeZone, 
		 			Domain, NumberOfProcessors, NumberOfLogicalProcessors,
					SystemType, TotalPhysicalMemory, PrimaryOwnerName | export-csv -path .\$svr\BOX_ComputerSystem.csv -noType

	# Get OperatingSystem info and write it to a CSV file
	gwmi -query "select * from
		Win32_OperatingSystem" -computername $svr | 
		 	select Name, Version, FreePhysicalMemory, OSLanguage, OSProductSuite,
		 			OSType, ServicePackMajorVersion, ServicePackMinorVersion | export-csv -path .\$svr\BOX_OperatingSystem.csv -noType

	# Get NetworkAdapter info and write it to a CSV file
#	gwmi -Query "select * from Win32_NetworkAdapterConfiguration" -ComputerName $srv |
#			select Description, IPAddress, DefaultIPGateway 
	
	# Get PhysicalMemory info and write it to a CSV file
	gwmi -query "select * from
		Win32_PhysicalMemory" -computername $svr | select Name, Capacity, DeviceLocator,
		Tag | export-csv -path .\$svr\BOX_PhysicalMemory.csv -noType

	# Get LogicalDisk info and write it to a CSV file
	gwmi -query "select * from Win32_LogicalDisk
		 where DriveType=3" -computername $svr | select Name, FreeSpace,
		 Size | export-csv -path .\$svr\BOX_LogicalDisk.csv -noType
		 
	
			"

}

$Adapters = Get-WmiObject -ComputerName $Target Win32_NetworkAdapterConfiguration
			$IPInfo = @()
			Foreach ($Adapter in ($Adapters | Where {$_.IPEnabled -eq $True})) 
			{
				$Details = "" | Select Description, "Physical address", "IP Address / Subnet Mask", "Default Gateway", "DHCP Enabled", DNS, WINS
				$Details.Description = "$($Adapter.Description)"
				$Details."Physical address" = "$($Adapter.MACaddress)"
				If ($Adapter.IPAddress -ne $Null) {
				$Details."IP Address / Subnet Mask" = "$($Adapter.IPAddress)/$($Adapter.IPSubnet)"
					$Details."Default Gateway" = "$($Adapter.DefaultIPGateway)"
				}
				If ($Adapter.DHCPEnabled -eq "True")	{
					$Details."DHCP Enabled" = "Yes"
				}
				Else {
					$Details."DHCP Enabled" = "No"
				}
				If ($Adapter.DNSServerSearchOrder -ne $Null)	{
					$Details.DNS =  "$($Adapter.DNSServerSearchOrder)"
				}
				$Details.WINS = "$($Adapter.WINSPrimaryServer) $($Adapter.WINSSecondaryServer)"
				$IPInfo += $Details
			}