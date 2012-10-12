#
# This is the second step to build a completelly automatic Data Warehouse with all system informations
# Next steps will show how to create Dim and Fat tables,  schedule daily collection, using AMO ...
#

#-----------------------------------------------------------------------------------------------------------------------------
# Before running this script download computer table from http://www.microsoft.com/technet/scriptcenter/csc/scripts/ad/general/cscad108.mspx
# This script use PsTools that can be downloaded from http://www.microsoft.com/technet/sysinternals/Utilities/PsTools.mspx and installed in C:\Dexma\bin
#-----------------------------------------------------------------------------------------------------------------------------

# --- Prepare the environment -----------------------------

Set-ExecutionPolicy Unrestricted
c:\temp\InitPowerSMO.ps1
$server = SMO_Server 
$db = SMO_Database $server "PowerDW"

#--------------------------------------------------------------------------------------
# Function to collect Disk information
#--------------------------------------------------------------------------------------

function global:PsDisk ($servername,$dn)
{
 $Tablename='disk'
$var=@'
$disk $SizeMB $FreeMB $PercFree
'@
 $out=''
 $out=C:\Dexma\bin\psinfo \\$servername -d Disk
 if ($out -LT '') {$Dischi='';} else {$Dischi=$out[3..$($out.count-1)]; }
 $dischi
 $dischi | 
 %{
   $SizeMB=0 
   $FreeMB=0 
   $PercFree=''
   IF ($dischi -eq '')
            {
                        #======= inserisco la riga senza valori ========================================

                        Invoke-Expression $($("insert-"+$tablename+" "+$servername+" ""$dn"" "+$var) ) | %{$DB.ExecuteNonQuery($_)} 
            }
   else
            {
                        $dischi2=$_.split(":")
                        if ($dischi2[1].trimstart().substring(0,5) -eq 'Fixed' )
                        {
                                   $DISCO=$dischi2[0].trimstart()+':'
                                   $INFO=$($dischi2[1].split(" ") | %{if ($_ -gt '') {$_}})
                                   $INFO[$($INFO.COUNT-1)]
                                   $PercFree=$INFO[$($INFO.COUNT-1)]
$esegui=@'
$FreeBites=
'@
                                   $esegui=$esegui+$($INFO[$($INFO.COUNT-3)]+$INFO[$($INFO.COUNT-2)])
                                   Invoke-Expression $($esegui)
$esegui=@'
$SizeBites=
'@
                                   $esegui=$esegui+$($INFO[$($INFO.COUNT-5)]+$INFO[$($INFO.COUNT-4)])
                                   Invoke-Expression $($esegui)
                                   $disk=$disco
                                   $SizeMB=[int] $($SizeBites/1MB)
                                   $FreeMB=[int] $($FreeBites/1MB)

                                   Invoke-Expression $($("insert-"+$tablename+" "+$servername+" ""$dn"" "+$var) ) | %{$DB.ExecuteNonQuery($_)} 
                        }
            }
 }
}

#--------------------------------------------------------------------------------------
# Function to collect  System informations
#--------------------------------------------------------------------------------------

function global:PsSysinfo ($servername,$dn)
{
$psinfo=C:\Dexma\bin\psinfo \\$servername
$tablename="SysInfo"
$variabili=$($psinfo[1..$($psinfo.count-1)] | %{ $variabile,$valore=$_.split(":"); $variabile.tostring().trimstart().trimend().replace(" ","_")})
$valori=$($psinfo[1..$($psinfo.count-1)] | %{ $variabile,$valore=$_.split(":"); $valore.tostring().trimstart()})
$a=@'
$valori
'@;
$b="insert-"+$tablename+" "+$servername+" ""$dn"" "
$var=''
for ($j=0; $j -lt $valori.count; $j++) {$var=$var+' '+$a.trimend()+'['+$j+']';};
$b=$b+$var
write-host $dn
Invoke-Expression $($b ) | %{$DB.ExecuteNonQuery($_)} 
}

#--------------------------------------------------------------------------------------
# Function to collect installed applications
#--------------------------------------------------------------------------------------

function global:PsApplication ($servername,$dn)
{
$out=''
$out=C:\Dexma\bin\psinfo \\$servername -s Applications
if ($out -LT '') {$Applicazioni='';} else {$Applicazioni=$out[3..$($out.count-1)]; }
$tablename="Application"
$all=insert-table $tablename
Invoke-Expression $($all)
write-host $all

$b="insert-"+$tablename+" "+$servername+" ""$dn"" "
$applicazioni | %{$applic=$_; $c=$b+" ""$applic"""; Invoke-Expression $($c); } | %{$DB.ExecuteNonQuery($_)} 

}

function global:RegVal($keyname,$keyvalue)
{
#RegVal \\servername\hklm\System\CurrentControlSet\Services\tcpip\parameters Domain
$val=reg query $keyname /v $keyvalue
$val[2].replace($keyvalue,"").replace("REG_SZ","").trimstart()

}

#--------------------------------------------------------------------------------------
# Function to collect  Network informations
#--------------------------------------------------------------------------------------

function global:PsNetInfo($servername,$dn2)
{
$tcpipparamloc = "\\$servername\hklm\System\CurrentControlSet\Services\tcpip\parameters"
$Hostname = RegVal $tcpipparamloc hostname
if ($hostname -lt '') { 
$inserisco="insert-NetInfo "+$servername +" "+"""$dn2""" 
Invoke-Expression $($inserisco) |  %{$DB.ExecuteNonQuery($_)}
}
else
{
$Domainname = RegVal $tcpipparamloc domain
$Routing =  RegVal $tcpipparamloc IPEnableRouter
$DomainNameD = RegVal $tcpipparamloc  UseDomainNameDevolution

$netbtparamloc = "\\$servername\hklm\System\CurrentControlSet\Services\netbt\parameters"
$Nodetype = RegVal $netbtparamloc DHCPNodeType
$LMhostsEnab = RegVal $netbtparamloc EnableLMHosts

$nodetypestr="Unknown"
Switch ($Nodetype) {
4 {$NodeTypeStr = "Mixed"}
8 {$NodeTypestr = "Hybrid"}
else {$NodeTypestr = "Not known"}
}

$IPRouting="unknown"
if ($routing -eq 0) {$IPRouting="No"}
if ($routing -eq 1) {$IPRouting="Yes"}

$niccol = gwmi Win32_NetworkAdapterConfiguration -computerName $servername | WHERE {$_.IPEnabled}

#check if DNS enabled for WINS Resolution anywhere
ForEach ($nic in $NicCol) {$DnsWins = $nic.DNSEnabledForWINSResolution}
If ($DnsWins)
{$winsproxy = "Yes"}
Else {$WinsProxy = "No"}

# Display global settings.
# Get os version number = 5.1 is XP.2k3

$OSVersion=[float]$(gwmi Win32_OperatingSystem -computerName $servername).version.substring(0,3)

# Finally Display per-adapter settings

$adapterconfigcol = gwmi Win32_NetworkAdapterConfiguration -computerName $servername
$adaptercol= gwmi Win32_NetworkAdapter -computerName $servername

For ($i=0; $i -lt $adaptercol.length; $i++)
{

$nic=$adaptercol[$i]
$config=$adapterconfigcol[$i]

# Display Information for IP enabled connections
If ($config.IPEnabled)
{ 

$Index = $nic.Index
$AdapterType = $Nic.AdapterType
If
($OsVersion -gt 5.0) {$Conn = $Nic.NetConnectionID}
Else
{$Conn = $nic.Index}

"$($Nic.AdapterType) - Adapter: $Conn"
"Connection-specific DNS Suffix . : $($config.DNSDomain)"
"Description . . . . . . . . . . . : $($Nic.Description)"
"Physical Address. . . . . . . . . : $($Nic.MACAddress)"
"DHCP Enabled. . . . . . . . . . . : $($Config.DHCPEnabled)"
"Autoconfiguration Enabled . . . . : $($Nic.AutoSense)"
"IP Address. . . . . . . . . . . . : $($config.IPAddress)"
"Subnet Mask . . . . . . . . . . . : $($Config.IPSubnet)"
"Default Gateway . . . . . . . . . : $($Config.DefaultIPGateway)"
"DHCP Server . . . . . . . . . . . : $($Config.DHCPServer)"
"DNS Servers . . . . . . . . . . . : $($Config.DNSServerSearchOrder)"
"Primary WINS Server . . . . . . . : $($Config.WINSPrimaryServer)"
"Secondary WINS Server . . . . . . : $($Config.WINSSecondaryServer)"
"Lease Obtained. . . . . . . . . . : $($Config.DHCPLeaseObtained)"
"Lease Expires . . . . . . . . . . : $($Config.DHCPLeaseExpires)"
""
Invoke-Expression $($(insert-table NetInfo))
$allvaria=@'
$Hostname  $DomainName $NodeTypeStr $IPRouting $WinsProxy $([boolean]$DomainNameD) $([boolean] $LMHostsEnab) $DomainName $Conn $($config.DNSDomain) $($Nic.Description) $($Nic.MACAddress) $($Config.DHCPEnabled) $($Nic.AutoSense) "$($config.IPAddress)" "$($Config.IPSubnet)" $($Config.DefaultIPGateway) $($Config.DHCPServer) "$($Config.DNSServerSearchOrder)" $($Config.WINSPrimaryServer) $($Config.WINSSecondaryServer) $($Config.DHCPLeaseObtained) $($Config.DHCPLeaseExpires)
'@

$inserisco="insert-NetInfo "+$servername +" "+"""$dn2""" +" "+$allvaria
Invoke-Expression $($inserisco) |  %{$DB.ExecuteNonQuery($_)}

}
}
}
}

#---------------------------------------------------------------------------------------------------
# Function to collect all informations for each server in previously downloaded AD Computer table
#---------------------------------------------------------------------------------------------------

function global:collect($tablename)
{
# -- Create table if not exist --------------------------------------------------------
if ($($DB.ExecuteWithResults($("sp_columns "+$tablename)).TABLES[0].ROWS).count -lt 1) 
{ 

    if ($tablename.toupper() -eq "NETINFO") {$DB.ExecuteNonQuery($("CREATE TABLE [dbo].[NetInfo]([ServerName] `
[varchar](50),[DistinguishedName] [varchar](500),[HostName] [varchar](100),[PrimaryDNSSuffix] [varchar](100),`
      [NodeType] [varchar](100),   [IPRoutingEnabled] [varchar](100),          `
[WINSProxyEnabled] [varchar](100),            [UseDNSDomainNameDevloution] [varchar](100),[LMHostsEnabled] `
[varchar](100),[DNSSuffixSearchList] [varchar](100),[Ethernet8023Adapter] [varchar](100),[ConnectionspecificDNSSuffix] `
[varchar](100),[Description] [varchar](100),[PhysicalAddress] [varchar](100),[DHCPEnabled] `
[varchar](100),[AutoconfigurationEnabled] [varchar](100),[IPAddress] [varchar](1000),[SubnetMask] `
[varchar](1000),[DefaultGateway] [varchar](100),[DHCPServer] [varchar](100),[DNSServers] [varchar](100),[PrimaryWINSServer] `
[varchar](100),[SecondaryWINSServer] [varchar](100),[LeaseObtained] [varchar](100),[LeaseExpires] [varchar](100))"));} 

    if ($tablename.toupper() -eq "SYSINFO") {$DB.ExecuteNonQuery($("CREATE TABLE [dbo].[SysInfo]([ServerName] `
[varchar](50),[DistinguishedName] [varchar](500),            [Uptime] [varchar](50),   [Kernel_version] [varchar](50),  `
  [Product_type] [varchar](50),[Product_version] [varchar](50),[Service_pack] [varchar](50),[Kernel_build_number] `
[varchar](50),[Registered_organization] [varchar](50),[Registered_owner] [varchar](50),[Install_date] `
[varchar](50),[Activation_status] [varchar](50),[IE_version] [varchar](50),[System_root] [varchar](50),[Processors] `
[varchar](50),[Processor_speed] [varchar](50),[Processor_type] [varchar](50),[Physical_memory] [varchar](50),[Video_driver] [varchar](100))"));} 

    if ($tablename.toupper() -eq "APPLICATION") {$DB.ExecuteNonQuery($("CREATE TABLE [dbo].[Application]([ServerName] `
[varchar](50),[DistinguishedName] [varchar](500),[Application] [varchar](500))"));}

    if ($tablename.toupper() -eq "DISK") {$DB.ExecuteNonQuery($("CREATE TABLE [dbo].[Disk]([ServerName] `
[varchar](50),[DistinguishedName] [varchar](500),[Disk] [varchar](50),[SizeMB] [bigint] NULL,[FreeMB] [bigint] `
NULL,[PercFree] [varchar](50))"));}

}


$all=insert-table $tablename
Invoke-Expression $($all)
write-host $all
$DB.ExecuteNonQuery("delete from [$tablename]")
#----------------- query to collect info only win2003Server from computer table ------------------------
$servers=$($DB.ExecuteWithResults `
("select name,distinguishedname from computer where OperatingSystem='Windows Server 2003' ").TABLES[0].ROWS)

$servers | %{$dn2=$_.distinguishedname; $inserisco="Ps"+$tablename+" "+$_.name+" "+"""$dn2"""; `
write-host $inserisco; Invoke-Expression $($inserisco)}

$path="d:\ad\"+$tablename+"_delta.ps1"
&($path)

}

# --------- Script execution ----------------------------------------
# -- Create and import data - table Application
collect Application
# -- Create and import data - table SysInfo
collect SysInfo
# -- Create and import data - table Disk
collect Disk
# -- Create and import data - table NetInfo
collect NetInfo
