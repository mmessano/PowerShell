# Author: Amit Banerjee
# Description: Powershell code to fetch the IP Addresses that the SQL instance is listening on.
# Notes:
# root\Microsoft\SqlServer\ComputerManagement10 - This namespace is applicable for SQL Server 2008 and above.
# For SQL Server 2005 the namespace is root\Microsoft\SqlServer\ComputerManagement
# There is no equivalent WMI namespace for SQL Server 2000 instance

# Provide the computer name that you want to query
$vComputerName = "PSQLDLS34"
# Provide the SQL instance name that you want the information for
# MSSQLSERVER for default instance
$vInstanceName = "MSSQLSERVER"

Write-Host "IP Address(es) that the SQL instance " $vComputerName "\" $vInstanceName " is listening on are listed below: "

$vListenAll = 0
$vTCPProps = get-WMIObject ServerNetworkProtocolProperty -ComputerName $vComputerName -NameSpace "root\Microsoft\SqlServer\ComputerManagement10" | Where-Object {$_.PropertyName  -eq "ListenOnAllIPs" -and $_.InstanceName -eq $vInstanceName}
foreach ($vTCPProp in $vTCPProps)
{
$vListenAll = $vTCPProp.PropertyNumVal
}

if($vListenAll -eq 1)
{
Write-Host "Is instance configured to listen on All IPs (Listen All property): TRUE"
# Get Networking Adapter Configuration
$vIPconfig = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $vComputerName

# Iterate and get IP address on which the SQL is listening
foreach ($vIP in $vIPconfig)
{
if ($vIP.IPaddress)
{
foreach ($vAddr in $vIP.Ipaddress)
{
$vAddr
}
}
}
}
else
{
# If SQL is configured to listen for specific IP addresses (eg. SQL clusters), then this else block will fetch those IP Addresses
# The Sort-Object ensures that the for-each loop below doesn't break while reporting the active and enabled IPs
$vIPProps = get-WMIObject ServerNetworkProtocolProperty -ComputerName $vComputerName -NameSpace "root\Microsoft\SqlServer\ComputerManagement10" | Where-Object {$_.InstanceName -eq $vInstanceName -and $_.ProtocolName  -eq "Tcp"} | Sort-Object IPAddressName,PropertyName
$vActive = 0
$vEnabled = 0

Write-Host "Is instance configured to listen on All IPs (Listen All property): FALSE"

foreach ($vIPProp in $vIPProps)
{
# Check if the IP is active
if ($vIPProp.Name -ne "IPAll" -and ($vIPProp.PropertyName -eq "Active"))
{
$vActive =  $vIPProp.PropertyNumVal
}
# Check if the IP is enabled
if ($vIPProp.Name -ne "IPAll" -and ($vIPProp.PropertyName -eq "Enabled"))
{
$vEnabled = $vIPProp.PropertyNumVal
}
# Report the IP if active and enabled
if ($vIPProp.Name -ne "IPAll" -and $vIPProp.PropertyName -eq "IPAddress" -and $vEnabled -eq 1 -and $vActive -eq 1)
{
# Get the IP addresses that SQL is configured to listen on
$vTCPProp.PropertyStrVal
}
}
}