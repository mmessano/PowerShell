# Get-DiskSpaceUsage.ps1

gwmi -query "SELECT SystemName `
					,Caption `
					,VolumeName `
					,Size `
					,Freespace `
				FROM win32_logicaldisk `
				WHERE DriveType=3" -computer (gc E:\Dexma\Servers.txt) `
				| Select-Object SystemName `
								,Caption `
								,VolumeName `
								,@{Name="Size(GB)"; Expression={"{0:N2}" -f ($_.Size/1GB)}} `
								,@{Name="Freespace(GB)"; Expression={"{0:N2}" -f ($_.Freespace/1GB)}} `
								,@{n="% Free";e={"{0:P2}" -f ([long]$_.FreeSpace/[long]$_.Size)}} `
				| export-csv E:\Dexma\Disk-GB.csv

