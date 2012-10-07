# with remoting enabled
#$sessions = "localhost","PHSCONSOLE" | New-PSSession
$sessions = gc "E:\dexma\logs\computers.txt" | New-PSSession
$block = {
   gwmi -query "select * from Win32_Volume where DriveType='3' AND DriveLetter='C:'" | Select `
      @{Name="Server";Expression={$ENV:COMPUTERNAME}},`
      @{Name="Device";Expression={$_.DriveLetter}},`
      @{Name="MountPoint";Expression={$DID=$_.DeviceID;gwmi Win32_MountPoint | ? { (($_.Volume.Split("=")[1] -replace "[^a-z0-9-]|Volume","") -match ($DID -replace "[^a-z0-9-]|Volume","")) } | % { $_.Directory.Split("=")[1] -replace "`"","" }}},`
      @{Name="Capacity";Expression={[math]::round(($($_.Capacity)/1GB),2)}},`
      @{Name="FreeSpace";Expression={[math]::round(($($_.FreeSpace)/1GB),2)}},`
      @{Name="UsedSpace";Expression={[math]::round((($_.Capacity - $_.FreeSpace)/1GB),2)}},`
      @{Name="PercentFree";Expression={[math]::round(($($_.FreeSpace)/$($_.Capacity)*100),2)}}
}

Invoke-Command -ScriptBlock $block -Session $sessions | Select Server,Device,MountPoint,Capacity,FreeSpace,UsedSpace,PercentFree | Sort Server,Device | Out-GridView -Title "Drive Space"

Get-PSSession | Remove-PSSession



# no remoting
#gc "E:\dexma\logs\computers.txt" | % {
#    $computer = $_
#    gwmi -query "select * from Win32_Volume where DriveType='3'" -computer $computer | Select `
#        @{Name="Server";Expression={$computer}},`
#        @{Name="Device";Expression={$_.DriveLetter}},`
#        @{Name="MountPoint";Expression={$DID=$_.DeviceID;gwmi Win32_MountPoint -computer $computer | ? { (($_.Volume.Split("=")[1] -replace "[^a-z0-9-]|Volume","") -match ($DID -replace "[^a-z0-9-]|Volume","")) } | % { $_.Directory.Split("=")[1] -replace "`"","" }}},`
#        @{Name="Capacity";Expression={[math]::round(($($_.Capacity)/1GB),2)}},`
#        @{Name="FreeSpace";Expression={[math]::round(($($_.FreeSpace)/1GB),2)}},`
#        @{Name="UsedSpace";Expression={[math]::round((($_.Capacity - $_.FreeSpace)/1GB),2)}},`
#        @{Name="PercentFree";Expression={[math]::round(($($_.FreeSpace)/$($_.Capacity)*100),2)}}
#} | Sort Server,Device | Out-GridView -Title "Drive Space"


