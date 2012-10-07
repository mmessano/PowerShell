
$names = Get-Content e:\dexma\temp\tempserver.txt
foreach($name in $names) {
    $svc = Get-WmiObject Win32_Service -ComputerName $name -Filter "name='DexFileImpExp2'"
    #Write-Host $name;
	#Write-Host $svc;
#	if ($svc.started -eq $true) {
#        $svc.StopService()
#    }
#    $svc.StartService()
	if ($svc.Started -eq $true) {
		Stop-Service -InputObject (get-Service -ComputerName PAPP10 -Name DexFileImpExp2)
		Write-Host "Stopped service on $name."
	}
	Start-Service -InputObject (get-Service -ComputerName PAPP10 -Name DexFileImpExp2)
	Write-Host "Started service on $name."
}
