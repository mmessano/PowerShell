#  Copyright (c) Microsoft Corporation. All rights reserved. 
#   
# THIS SAMPLE CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN 
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER.  
 
<# 
.SYNOPSIS 
    This script will help DNS administrator to ensure that all the DNS servers that are configured on  
    clients as DNS servers are able to resolve all the required zones (corpnet & Internet). Additionally,  
    it’ll also verify health of other DNS resources (Forwarders, RootHints, Zone Delegations, Zone Aging 
    settings etc.) and generate consolidated reports, which can be used for further investigation purpose. 
.DESCRIPTION 
    This script performs a health check of the Enterprise DNS servers configuration. 
.PARAMETER ValidationType 
    Define valdation type: All, Domain, Zone, ZoneAging, ZoneDelegation, Forwarder, RootHints 
.PARAMETER Path 
    Full path of cache files. 
    If the Path parameter is not specified, the current directory is used. 
.PARAMETER CleanUpOldCacheFiles 
    Clean-Up old cache files. 
.PARAMETER CleanUpOldReports 
    Clean-Up old report files. 
.PARAMETER Force 
    Applicable with CleanUpOldCacheFiles & CleanUpOldReports switches and deletes the files without user confirmation.     
.PARAMETER DnsServerList  
    List of name resolvers on which health check need to be performed. 
.PARAMETER,DomainList  
    List of all available root domains across the enterprise. 
.PARAMETER ZoneList  
    List of zones to be verified. 
.PARAMETER ZoneHostingServerList  
    List of zone hosting servers, which hosts one or more zones. 
.PARAMETER DhcpServerList  
    List of DHCP servers across the enterprise. 
.NOTES 
    - Requires Windows Server 2012 or Windows 8 with Remote Server Administration Tools. 
    - Requires read access across all enterprise resources such as AD, DHCP & DNS Servers. 
    - Requires the PowerShell modules: DNSServer, DHCPServer (Only if DNS server list isn't specified through text file)  
      & ActiveDirectory (Only if domain list isn't specified through text file). 
      Basically below RSAT tools should be installed: 
         
    [X] DNS Server Tools                                RSAT-DNS-Server                Installed         
    [X] DHCP Server Tools                               RSAT-DHCP                      Installed 
    [X] Active Directory module for Windows PowerShell  RSAT-AD-PowerShell             Installed 
     
.EXAMPLE 
    Test-EnterpriseDnsHealth All -Verbose 
    Performs a health check of below resources and prints verbose messages on PS console: 
    1. Root Domain Zones or Non-Root Domain zones across all DNS servers. 
    2. Zone aging configuration across all zone hosting servers. 
    3. Configured delegation across all zones. 
    4. All configured Forwarders across all DNS servers. 
    5. All configured RootHints across all DNS servers. 
     
    Test-EnterpriseDnsHealth -ValidationType All –DhcpServerList Dhcp1.contoso.com, Dhcp2.contoso.com –Verbose  
    Will perform a health check of all the resources and prints verbose messages on PS console.  
    It’ll fetch information about DNS servers from Dhcp1.contoso.com & Dhcp2.contoso.com DHCP servers  
    (If DnsServerList.txt is unavailable).  
 
    Test-EnterpriseDnsHealth @("Zone", "Domain") –ZoneHostingServerList Srv1.contoso.com,Srv2.contoso.com 
    Will perform a health check of Zones (all the zones hosted on Srv1.contoso.com,Srv2.contoso.com  
    – If ZoneList.txt is unavailable) & Domains resources. 
 
    Test-EnterpriseDnsHealth ZoneAging,ZoneDelegation -CleanUpOldCacheFiles -ZoneList Zone1.contoso.com,Zone2.contoso.com 
    Will perform a health check of ZoneAging & ZoneDelegation inside zones Zone1.contoso.com & Zone2.contoso.com  
    and deletes the old caches with user confirmation before validation. 
 
    Test-EnterpriseDnsHealth Forwarder,RootHints –CleanUpOldCacheFiles   –CleanUpOldReports –Force –DnsServerList Dns1.contoso.com,Dns2.contoso.com  
    Will perform a health check of Forwarder & RootHints configured at Dns1.contoso.com & Dns2.contoso.com DNS servers  
    and deletes the old caches & reports without user confirmation before validation. 
#> 
 
Param 
(  
    [parameter(Mandatory=$true, Position=0, HelpMessage="Define valdation type: All, Domain, Zone, ZoneAging, ZoneDelegation, Forwarder, RootHints")] 
    [Alias("Type")] 
    [String[]] $ValidationType, 
    [parameter(Mandatory=$false, Position=1, HelpMessage="Full path of cache files.")] 
    [String] $Path = $pwd.path + "\",     
    [parameter(Mandatory=$false, HelpMessage="Clean-Up old cache files.")] 
    [Switch] $CleanUpOldCacheFiles, 
    [parameter(Mandatory=$false, HelpMessage="Clean-Up old report files.")] 
    [Switch] $CleanUpOldReports, 
    [parameter(Mandatory=$false, HelpMessage="Applicable with CleanUpOldCacheFiles & CleanUpOldReports switches and deletes the files without user confirmation.")] 
    [Switch] $Force, 
    [parameter(Mandatory=$false, HelpMessage="List of name resolvers on which health check need to be performed.")] 
    [String[]] $DnsServerList = $null, 
    [parameter(Mandatory=$false, HelpMessage="List of all available root domains across the enterprise.")] 
    [String[]] $DomainList = $null, 
    [parameter(Mandatory=$false, HelpMessage="List of zones to be verified.")] 
    [String[]] $ZoneList = $null, 
    [parameter(Mandatory=$false, HelpMessage="List of zone hosting servers, which hosts one or more zones.")] 
    [String[]] $ZoneHostingServerList = $null, 
    [parameter(Mandatory=$false, HelpMessage="List of DHCP servers across the enterprise.")] 
    [String[]] $DhcpServerList = $null 
) 
 
# 
# Enable strict mode parsing 
# 
Set-StrictMode -Version 2 
 
# 
# Import the required PowerShell modules 
# 
Import-Module DNSServer -ErrorAction Ignore 
Import-Module DHCPServer -ErrorAction Ignore 
Import-Module ActiveDirectory -ErrorAction Ignore 
 
if (-not (Get-Module DNSServer)) { 
    throw 'The Windows Feature "DNS Server Tools" is not installed. ` 
        (On server SKU run "Install-WindowsFeature -Name RSAT-DNS-Server", on client SKU install RSAT client)' 
} 
 
# 
# Initialize global params 
# 
$script:validValidationTypes = @("Domain", "Zone", "ZoneAging", "ZoneDelegation", "Forwarder", "RootHints"); 
$script:allValidationType = "All"; 
$script:switchParamVal = "__SWITCH__"; 
$script:cmdLetReturnedStatus = $null; 
 
$script:dnsServerList = $DnsServerList; 
$script:domainList = $DomainList; 
$script:zoneList = $ZoneList; 
$script:zoneHostingServerList = $ZoneHostingServerList; 
$script:dhcpServerList = $DhcpServerList; 
 
$script:dnsServerListFilePath = $Path + "DnsServerList.txt"; 
$script:domainListFilePath = $Path + "DomainList.txt"; 
$script:zoneListFilePath = $Path + "ZoneList.txt"; 
$script:zoneHostingServerListFilePath = $Path + "ZoneHostingServerList.txt"; 
$script:dhcpServerListFilePath = $Path + "DhcpServerList.txt"; 
 
$script:domainAndHostingServersList = $null; 
$script:zoneAndHostingServersList = $null; 
 
# 
# Check if old cache files already exist and user has asked to delete it. 
# 
if ($CleanUpOldCacheFiles -and (Test-Path -Path ($Path + "*.txt") -PathType Leaf)) 
{ 
    if ($Force) { 
        Remove-Item -Path ($Path + "*.txt") -Force; 
    } else { 
        Remove-Item -Path ($Path + "*.txt") -Confirm; 
    } 
} 
 
# 
# Check if old reports already exist and user has asked to delete it. 
# 
if ($CleanUpOldReports -and (Test-Path -Path ($Path + "*.html") -PathType Leaf)) 
{ 
    if ($Force) { 
        Remove-Item -Path ($Path + "*.html") -Force; 
    } else { 
        Remove-Item -Path ($Path + "*.html") -Confirm; 
    } 
} 
 
# 
# Log levels to log messages 
# 
$script:logLevel = @{ 
    "Verbose" = [int]1 
    ;"Host" = [int]2 
    ;"Warning" = [int]3 
    ;"Error" = [int]4 
} 
 
# 
# Output report view 
# 
$script:resultView =@{ 
    "List" = "List" 
    ;"Table" = "Table" 
} 
 
# 
# Logs comments as per input log level 
# 
Function LogComment 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [string]$message, 
    [int]$level = $script:logLevel.Verbose 
) 
    $message = ([DateTime]::Now).ToString() + ": " + $message; 
    switch ($level) 
    { 
        $script:logLevel.Verbose {Write-Verbose $message}; 
        $script:logLevel.Host {Write-Host -ForegroundColor Cyan $message}; 
        $script:logLevel.Warning {Write-Warning $message};    
        $script:logLevel.Error {Write-Error $message}; 
        default {throw "Not a valid log level: " + $level}; 
    } 
} 
 
# 
# Accepts CmdLet name & param hash and executes the CmdLet. 
# All methods in this script will call this method to execute any CmdLet. 
# 
Function ExecuteCmdLet 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [string]$cmdLetName, 
    [HashTable]$params = @{}    
) 
    $cmdString=$cmdLetName; 
    $displayString=$cmdLetName; 
    $script:cmdLetReturnedStatus = [RetStatus]::Success; 
    if ($null -ne $params) { 
        foreach($key in $params.keys) { 
            if ($script:switchParamVal -eq $params[$key]) { 
                $cmdString +=" -$key ";   
                $displayString +=" -$key "; 
            } else { 
                $cmdString += " -$key `$params[`"$key`"]"; 
                $displayString += " -$key $($params[$key])"; 
            } 
        } 
    }     
    $cmdString += " -ErrorAction Stop 2> `$null"; 
    $displayString += " -ErrorAction Stop 2> `$null"; 
    LogComment $displayString $script:logLevel.Host; 
    $retObj = $null; 
    try { 
        $retObj = Invoke-Expression $cmdString; 
    } catch [Exception] { 
        if (Get-Member -InputObject $_.Exception -Name "Errordata") 
        { 
            # Handling DNS server module specific exceptions. 
            if (5 -eq $_.Exception.Errordata.error_Code) { 
                LogComment $("Caught error: Access is denied, considering it as current login creds don't have server read access.") ` 
                    $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::AccessIsDenied; 
            } elseif (1722 -eq $_.Exception.Errordata.error_Code) { 
                LogComment $("Caught error: The RPC server is unavailable, considering it as server is down.") ` 
                    $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::RpcServerIsUnavailable; 
            } elseif (9601 -eq $_.Exception.Errordata.error_Code) { 
                LogComment $("Caught error: DNS zone does not exist, considering it as given server isn't hosting input zone.") ` 
                    $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::ZoneDoesNotExist; 
            } elseif (9611 -eq $_.Exception.Errordata.error_Code) { 
                LogComment $("Caught error: Invalid DNS zone type, considering it as we can't perform current operation on input zone.") ` 
                    $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::OperationIsNotSupported; 
            } elseif (9714 -eq $_.Exception.Errordata.error_Code) { 
                LogComment $("Caught error: DNS name does not exist, considering it as input record doesn't exist.") ` 
                    $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::RecordDoesNotExist; 
            } else { 
                LogComment $("Caught error while executing '" + $displayString + "' with errorcode: " + $_.Exception.Errordata.error_Code) ` 
                    $script:logLevel.Error; 
                $script:cmdLetReturnedStatus = $([String]$_.Exception.Errordata.error_Code + ":" + $_.Exception.Errordata.error_WindowsErrorMessage); 
                #throw;                            
            } 
        } elseif (Get-Member -InputObject $_ -Name "FullyQualifiedErrorId") { 
            # Handling Resolve-DnsName specific errors. 
            if ($_.FullyQualifiedErrorId.Contains("DNS_ERROR_RCODE_NAME_ERROR")) { 
                LogComment $("Caught error: ResolveDnsNameResolutionFailed in Resolve-DnsName.") $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::ResolveDnsNameResolutionFailed; 
            } elseif ($_.FullyQualifiedErrorId.Contains("System.Net.Sockets.SocketException")) { 
                LogComment $("Caught error: ResolveDnsNameServerNotFound in Resolve-DnsName.") $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::ResolveDnsNameServerNotFound; 
            } elseif ($_.FullyQualifiedErrorId.Contains("ERROR_TIMEOUT")) { 
                LogComment $("Caught error: ResolveDnsNameTimeoutPeriodExpired in Resolve-DnsName.") $script:logLevel.Warning; 
                $script:cmdLetReturnedStatus = [RetStatus]::ResolveDnsNameServerNotFound; 
            } else { 
                LogComment $("Caught error while executing '" + $displayString + "' `n" + $_.Exception) $script:logLevel.Error;   
                $script:cmdLetReturnedStatus = $([String]$_.FullyQualifiedErrorId + ":" + $_.Exception); 
                throw;   
            } 
        } else { 
            LogComment $("Caught error while executing '" + $displayString + "' `n" + $_.Exception) $script:logLevel.Error;   
            $script:cmdLetReturnedStatus = $($_.Exception); 
            throw;                               
        } 
    } 
    if ($null -eq $retObj) { 
        LogComment "CmdLet returned with NULL..." $script:logLevel.Host;         
    } 
    return $retObj 
} 
 
#  
# If $dnsServerListFromCmdLine is Non-NULL then it'll return with existing elements in $dnsServerListFromCmdLine.  
# Else it'll try to load EnterpriseDnsServerList from $script:dnsServerListFilePath file. 
# Even if it's unsuccessful then extracts Dns Server List from DNS options  
# configured on all DHCP scopes and servers in the enterprise 
# 
Function Get-EnterpriseDnsServerList 
{ 
param (   
    $dnsServerListFilePath = $script:dnsServerListFilePath, 
    $dhcpServerListFilePath = $script:dhcpServerListFilePath, 
    $dnsServerListFromCmdLine = $script:dnsServerList 
)     
    $dnsServerList = $null;   
    if ($null -eq $dnsServerListFromCmdLine) {     
        # Load the DNS servers from $dnsServerListFilePath, if exists. 
        $dnsServerList = Get-FileContent $dnsServerListFilePath;     
    } else { 
        $dnsServerList = $dnsServerListFromCmdLine; 
    } 
    if ($null -eq $dnsServerList) { 
        LogComment "Unable to load DNS servers from the cache. So loading from DHCP servers."          
        if (-not(Get-Module DHCPServer)) { 
            LogComment $('The Windows Feature "DHCP Server Tools" is not installed. ` 
                (On server SKU run "Install-WindowsFeature -Name RSAT-DHCP", on client SKU install RSAT client)') ` 
                $script:logLevel.Warning; 
            LogComment $("Skipping this step and returning with NULL DNS List.") $script:logLevel.Warning;  
            return $null; 
        } 
         
        #Get the DHCP server information     
        $dhcpServerList = Get-EnterpriseDhcpServerList $dhcpServerListFilePath; 
         
        if ($null -eq $dhcpServerList) { 
            LogComment $("No DHCP servers were found, returning with NULL DNS server list.") $script:logLevel.Warning; 
            return $null; 
        } 
         
        # Now load the DNS options configured on all DHCP scopes and servers in the enterprise 
        $optionList = @(); 
 
        $v4Options = Get-EnterpriseDhcpv4OptionId $dhcpServerList $false; 
        $optionList += $v4Options; 
 
        $v4Options = Get-EnterpriseDhcpv4OptionId $dhcpServerList $true; 
        $optionList += $v4Options; 
 
        $v6Options = Get-EnterpriseDhcpv6OptionId $dhcpServerList $false; 
        $optionList += $v6Options; 
 
        $v6Options = Get-EnterpriseDhcpv6OptionId $dhcpServerList $true; 
        $optionList += $v6Options; 
         
        $optionList = $optionList  | ?{-not([String]::IsNullOrEmpty($_))}; 
         
        if ($null -eq $optionList) { 
            LogComment $("No DNS server found in configured DHCP options across all input DHCP servers, returning with NULL DNS server list.") $script:logLevel.Warning; 
        } else { 
            # Once done now consolidate the DNS servers in the enumerated options 
            $servers = @(); 
            $optionList | %{ $servers += $_.Value }; 
            $dnsServerList = $servers | sort -Unique;         
            ExecuteCmdLet "Set-Content" @{"Path" = $dnsServerListFilePath; "Value" = $dnsServerList}; 
        } 
    }     
    return $dnsServerList; 
} 
 
#  
# If $domainListFromCmdLine is Non-NULL then it'll return with existing elements in  
# $domainListFromCmdLine. Else it'll try to load all the domains from $domainListFilePath. 
# Even if it's unsuccessful then extracts Domain List from Get-ADForest CmdLet. 
# 
Function Get-EnterpriseDomainList 
{ 
param ( 
    $domainListFilePath = $script:domainListFilePath, 
    $domainListFromCmdLine = $script:domainList 
) 
    $domainList = $null; 
    if ($null -eq $domainListFromCmdLine) { 
        # Load the domain list from $domainListFilePath, if exists. 
        $domainList = Get-FileContent $domainListFilePath;     
    } else { 
        $domainList = $domainListFromCmdLine; 
    } 
    if ($null -eq $domainList) { 
        LogComment "Failed to load domains from the file. So loading from AD."; 
        try { 
            if (Get-Module ActiveDirectory) {                 
                $forestObj = ExecuteCmdLet "Get-ADForest"; 
                if ($null -ne $forestObj) { 
                    $domainList = $forestObj.Domains; 
                } 
                if ($null -ne $domainList) { 
                    ExecuteCmdLet "Set-Content" @{"Path" = $domainListFilePath; "Value" = $domainList}; 
                } else { 
                    LogComment $("Unable to obtain domainList from Get-ADForest. Returning with NULL DomainList.") ` 
                        $script:logLevel.Warning; 
                } 
            } else { 
                LogComment $('The Windows Feature "Active Directory module for Windows PowerShell" is not installed. ` 
                    (On server SKU run "Install-WindowsFeature -Name RSAT-AD-PowerShell", on client SKU install RSAT client)') $script:logLevel.Warning; 
                LogComment $("Skipping this step and returning with NULL DomainList.") $script:logLevel.Warning;                 
            } 
        } catch [Exception] { 
            LogComment $("Get-ADForest failed, Skipping this step and returning with NULL DomainList. `n" ` 
                + $_.Exception) $script:logLevel.Warning; 
        } 
    } 
     
    return $domainList; 
} 
 
#  
# If $zoneListFromCmdLine is Non-NULL then it'll return with existing elements in  
# $zoneListFromCmdLine. Else it'll try to load all the zones from $zoneListFilePath file. 
# 
Function Get-EnterpriseZoneList 
{ 
param ( 
    $zoneListFilePath = $script:zoneListFilePath, 
    $zoneListFromCmdLine = $script:zoneList 
) 
    $zoneList = $null; 
    if ($null -eq $zoneListFromCmdLine) { 
        # Load the zone list from $zoneListFilePath, if exists. 
        $zoneList = Get-FileContent $zoneListFilePath;     
    } else { 
        $zoneList = $zoneListFromCmdLine; 
    }    
    return $zoneList; 
} 
 
# 
# If $zoneHostingServerListFromCmdLine is Non-NULL then it'll return with existing elements in $zoneHostingServerListFromCmdLine.  
# Else it'll try to load zoneHostingServerList from $zoneHostingServerListFilePath file. 
# If unsuccessful then returns with $dnsServerList. 
# 
Function Get-EnterpriseZoneHostingServerList 
{ 
param ( 
    $zoneHostingServerListFilePath = $script:zoneHostingServerListFilePath, 
    $dnsServerList = $script:dnsServerList, 
    $zoneHostingServerListFromCmdLine = $script:zoneHostingServerList 
)     
    $zoneHostingServerList = $null; 
     
    if ($null -eq $zoneHostingServerListFromCmdLine) {        
        # Load the zone hosting servers from $zoneHostingServerListFilePath, if exists. 
        LogComment $("Filling Zone Hosting Servers list from the file."); 
        $zoneHostingServerList = Get-FileContent $zoneHostingServerListFilePath;     
    } else { 
        $zoneHostingServerList = $zoneHostingServerListFromCmdLine; 
    }         
     
    if ($null -eq $zoneHostingServerList) { 
        # Return with DNS Server list. 
        LogComment $("Zone Hosting Servers list isn't available, returning with DNS Server list."); 
        $zoneHostingServerList = $dnsServerList;  
    }     
    return $zoneHostingServerList; 
} 
 
#  
# If $dhcpServerListFromCmdLine is Non-NULL then it'll return with existing elements in $dhcpServerListFromCmdLine.  
# Else it'll try to load all the DHCP servers from $dhcpServerListFilePath file. 
# Even if it's unsuccessful then extracts DHCP Server List from AD with Get-DhcpServerInDC CmdLet. 
# 
Function Get-EnterpriseDhcpServerList 
{ 
param ( 
    $dhcpServerListFilePath = $script:dhcpServerListFilePath, 
    $dhcpServerListFromCmdLine = $script:dhcpServerList 
)  
    $dhcpServerList = $null; 
    if ($null -eq $dhcpServerListFromCmdLine) {        
        # Load the DHCP servers from $dhcpServerListFilePath, if exists. 
        $dhcpServerList = Get-FileContent $dhcpServerListFilePath;  
    } else { 
        $dhcpServerList = $dhcpServerListFromCmdLine; 
    } 
    if ($null -eq $dhcpServerList) {  
        LogComment "Failed to load DHCP server list from the file. So loading from AD."; 
        $dhcpObjList = ExecuteCmdLet "Get-DhcpServerInDC"; 
        foreach($dhcpObj in $dhcpObjList) { 
            if ($null -eq $dhcpServerList) {$dhcpServerList = @()}; 
            $dhcpServerList += $dhcpObj.IPAddress; 
        } 
    } 
     
    return $dhcpServerList; 
} 
 
# 
# Gets the domain list and for each domain it sends a NS lookup query to default DNS  
# server and gathers all the servers hosted these domains.  
# Returns with a HashTable of domians and servers which are hosting these domians. 
# 
Function Get-EnterpriseDomainAndHostingServersHash 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $domainHostingServers, 
    $domainListFilePath = $script:domainListFilePath      
) 
    $domainAndHostingServersHash = $null;   
    # Load the domains from CmdLine or $domainListFilePath, if exists  
    # or collect all the domains from current forest. 
    $domainList = Get-EnterpriseDomainList $domainListFilePath; 
    if ($null -ne $domainList) {     
        #$domainAndHostingServersHash = Get-ServersHostingTheZones $domainList $domainHostingServers;  
        $domainAndHostingServersHash = @{}; 
        foreach($domain in $domainList) { 
            $domainHostingServer = Get-ZoneHostingServerListFromNSRecords $domain; 
            $domainAndHostingServersHash.Add($domain, $domainHostingServer); 
        } 
        Write-HashTableInHtml $domainAndHostingServersHash "DomainAndHostingServersHash"; 
    } else {     
        LogComment $("Failed to get domain list. So returning with NULL HashTable.") $script:logLevel.Warning; 
    }     
    return $domainAndHostingServersHash; 
} 
 
# 
# Gets ZoneList and if it's NULL then enumerate all the zones (except auto-created and TrustAnchors zones) across  
# all zoneHostingServerList. Returns with a HashTable of zones and servers which are hosting these zones. 
# 
Function Get-EnterpriseZoneAndHostingServersHash 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $zoneHostingServerList, 
    $zoneListFilePath = $script:zoneListFilePath      
) 
    $zoneAndHostingServersHash = $null;   
    # Load the zones from CmdLine or $zoneListFilePath, if exists. 
    $zoneList = Get-EnterpriseZoneList $zoneListFilePath;   
    if ($null -ne $zoneList) {     
        $zoneAndHostingServersHash = Get-ServersHostingTheZones $zoneList $zoneHostingServerList; 
    } else {     
        LogComment $("Failed to load zones from the file. So loading it from zoneHostingServerList."); 
        if ($null -ne $zoneHostingServerList) {             
            $zoneAndHostingServersHash = Get-ZonesHostingOnServers $zoneHostingServerList;    
            Write-HashTableInHtml $zoneAndHostingServersHash "ZoneAndHostingServersHash"; 
        } else { 
            LogComment $("Failed to get Zone Hosting Servers list. Returning with NULL.") $script:logLevel.Warning;            
        } 
    }     
    return $zoneAndHostingServersHash; 
} 
 
# 
# Queries all the Zone hosting servers, if they host zones exists in input zone list. 
# Prepares a HashTable of zones and zoneHostingServerList. 
# 
Function Get-ServersHostingTheZones 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $zoneList, 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $zoneHostingServerList  
) 
    $zoneAndHostingServersHash = $null; 
    foreach($zone in $zoneList) { 
        if ($null -eq $zoneAndHostingServersHash) {$zoneAndHostingServersHash = @{}}; 
        if ($zoneAndHostingServersHash.ContainsKey($zone)) { 
            LogComment $($zone + " is already there in ZoneAndHostingServersList."); 
            continue; 
        } 
        LogComment $("Searching for servers which are hosting Zone: " + $zone); 
        $serverList = $null; 
        foreach($server in $zoneHostingServerList) { 
            $tempZoneObj = ExecuteCmdLet "Get-DnsServerZone" @{"ComputerName" = $server; "ZoneName" = $zone}; 
            if ($null -ne $tempZoneObj) { 
                if ($null -eq $serverList) {$serverList = @()};  
                LogComment $($server + " is hosting Zone: " + $zone); 
                $serverList += $server; 
            } else { 
                if ([RetStatus]::ZoneDoesNotExist -eq $script:cmdLetReturnedStatus) { 
                    LogComment $($server + " doesn't host Zone: " + $zone); 
                } else { 
                    LogComment $("Failed to get " + $zone + " info on " + $server + " with error " + $script:cmdLetReturnedStatus) ` 
                       $script:logLevel.Error;  
                } 
            } 
        }  
        if ($null -eq $serverList) { 
            LogComment $("Didn't find any server which is hosting Zone: " + $zone) ` 
                $script:logLevel.Warning; 
        } 
        $zoneAndHostingServersHash.Add($zone, $serverList);            
    }  
     
    return $zoneAndHostingServersHash; 
} 
 
# 
# Gets all the zones across zone hosting servers and prepare a HashTable of zones  
# (except auto-created and TrustAnchors zones) and zoneHostingServerList. 
# 
Function Get-ZonesHostingOnServers 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $zoneHostingServerList  
) 
    $zoneAndHostingServersHash = $null;     
     
    foreach($zoneHostingServer in $zoneHostingServerList) {                 
        $tempZoneObj = ExecuteCmdLet "Get-DnsServerZone" @{"ComputerName" = $zoneHostingServer}; 
        if ($null -ne $tempZoneObj) { 
            foreach ($zone in $tempZoneObj) { 
                if (($false -eq $zone.IsAutoCreated) -and ("TrustAnchors" -ne $zone.ZoneName)) { 
                    if ($null -eq $zoneAndHostingServersHash) {$zoneAndHostingServersHash = @{}};  
                    LogComment $($zoneHostingServer + " is hosting Zone: " + $zone.ZoneName); 
                    if ($zoneAndHostingServersHash.ContainsKey($zone.ZoneName)) { 
                        $zoneAndHostingServersHash[$zone.ZoneName] += $zoneHostingServer; 
                    } else { 
                        $zoneAndHostingServersHash.Add($zone.ZoneName, @($zoneHostingServer)); 
                    } 
                } 
            } 
        }  else { 
            if ([RetStatus]::Success -eq $script:cmdLetReturnedStatus) { 
                LogComment $($zoneHostingServer + " doesn't host any Zone"); 
            } else { 
                LogComment $("Failed to get Zone info on " + $zoneHostingServer + " with error " + $script:cmdLetReturnedStatus) ` 
                    $script:logLevel.Error;  
            } 
        } 
    }     
    return $zoneAndHostingServersHash; 
} 
 
# 
# Returns scope level or server level Dhcpv4 Option List for default Option ID 6 
# 
Function Get-EnterpriseDhcpv4OptionId 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [Array]$dhcpServerList, 
    $scopeOption = $false,  
    $OptionId = 6 
) 
    $optionList = @(); 
 
    foreach ($dhcpServer in $dhcpServerList) { 
        try { 
            if ($true -eq $scopeOption) { 
                $scopeOptions = @(); 
                $scopeList = ExecuteCmdLet "Get-DhcpServerv4Scope" @{"ComputerName" = $dhcpServer}; 
                foreach ($scope in $scopeList) { 
                    try { 
                        $scopeOption = ExecuteCmdLet "Get-DhcpServerv4OptionValue" ` 
                            @{"ComputerName" = $dhcpServer; "OptionId" = $OptionId; "ScopeId" = $scope.ScopeId}; 
                        $scopeOptions += $scopeOption; 
                    } catch { 
                        LogComment "Failed to get options for the scope $($scope.ScopeId). Continuing..."; 
                    } 
                } 
                $optionList += $scopeOptions; 
            } else { 
                try { 
                    $serverOptions = ExecuteCmdLet "Get-DhcpServerv4OptionValue" ` 
                        @{"ComputerName" = $dhcpServer; "OptionId" = $OptionId}; 
                    $optionList += $serverOptions; 
                } catch { 
                    LogComment "Get-DhcpServerv4OptionValue -ComputerName $($dhcpServer) -OptionId $OptionId failed. Continuing..."; 
                } 
            } 
        } catch { 
            LogComment "Get-DhcpServerv4Scope -ComputerName $($dhcpServer) failed" $script:logLevel.Error; 
        } 
    } 
     
    $optionList = $optionList  | ?{-not([String]::IsNullOrEmpty($_))}; 
    if ($null -eq $optionList) { 
        LogComment $("No DHCPv4 option found across the DHCP servers for ScopeOption = " + $scopeOption + ", returning with NULL option list.") $script:logLevel.Warning; 
    } 
    return $optionList; 
} 
 
# 
# Returns scope level or server level Dhcpv6 Option List for default Option ID 23 
# 
Function Get-EnterpriseDhcpv6OptionId 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [Array]$dhcpServerList, 
    $scopeOption = $false,  
    $OptionId = 23 
) 
    $optionList = @(); 
 
    foreach ($dhcpServer in $dhcpServerList) { 
        try { 
            if ($true -eq $scopeOption) { 
                $scopeOptions = @(); 
                $scopeList = ExecuteCmdLet "Get-DhcpServerv6Scope" @{"ComputerName" = $dhcpServer}; 
                foreach ($scope in $scopeList) { 
                    try { 
                        $scopeOption = ExecuteCmdLet "Get-DhcpServerv6OptionValue" ` 
                            @{"ComputerName" = $dhcpServer; "OptionId" = $OptionId; "Prefix" = $scope.Prefix}; 
                        $scopeOptions += $scopeOption; 
                    } catch { 
                        LogComment "Failed to get options for the scope $($scope.Prefix). Continuing..."; 
                    } 
                } 
                $optionList += $scopeOptions; 
            } else { 
                try { 
                    $serverOptions = ExecuteCmdLet "Get-DhcpServerv6OptionValue" ` 
                        @{"ComputerName" = $dhcpServer; "OptionId" = $OptionId}; 
                    $optionList += $serverOptions; 
                } catch { 
                    LogComment "Get-DhcpServerv6OptionValue -ComputerName $($dhcpServer) -OptionId $OptionId failed. Continuing..."; 
                } 
            } 
        } catch { 
            LogComment $("Get-DhcpServerv6Scope -ComputerName $($dhcpServer) failed") $script:logLevel.Error; 
        } 
    } 
 
    $optionList = $optionList  | ?{-not([String]::IsNullOrEmpty($_))}; 
    if ($null -eq $optionList) { 
        LogComment $("No DHCPv6 option found across the DHCP servers for ScopeOption = " + $scopeOption + ", returning with NULL option list.") $script:logLevel.Warning; 
    } 
    return $optionList; 
} 
 
# 
# Tests health of input zones across all DNS Servers 
# Verifies all the enterprise DNS servers can resolve these zone names. 
# If input zones are root zones then validates _msdcs & _ldap infra records 
# Performs a Test-DnsServer query for all input zones 
# 
Function Test-ZoneHealthAcrossAllDnsServers 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $zoneList, 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $dnsServerList, 
    [bool]$isRootZone = $false, 
    [String]$outputReportName = $MyInvocation.MyCommand 
) 
    $statusArray = @(); 
     
    foreach($zone in $zoneList) { 
     
        $status = New-Object PSObject; 
        $status | Add-Member -memberType NoteProperty -name "ZoneName" -value $zone; 
         
        foreach($dnsServer in $dnsServerList) {  
            try { 
                $result = [RetStatus]::Success; 
                $resultStream = $null; 
                 
                $retVal1 = Test-DnsServerForInputDnsName $zone $dnsServer; 
                $resultStream = $resultStream + "ResolveDnsName:" + $retVal1 + "`n"; 
                $retVal2 = Test-DnsServerForInputZone $zone $dnsServer $dnsServer;  
                $resultStream = $resultStream + "TestDnsServer:" + $retVal2 + "`n"; 
             
                if (!(([RetStatus]::Success -eq $retVal1) -and ([RetStatus]::Success -eq $retVal2))) { 
                    $result = [RetStatus]::Failure; 
                } 
             
                # If it's root zone then validate _msdcs & _ldap infra records 
                if ($isRootZone) { 
                    $retVal3 = Test-DnsServerForInputDnsName ("_msdcs." + $zone) $dnsServer; 
                    $resultStream = $resultStream + "MsdcsResolveDnsName:" + $retVal3 + "`n"; 
                    $retVal4 = Test-DnsServerForInputZone ("_msdcs." + $zone) $dnsServer $dnsServer; 
                    $resultStream = $resultStream + "MsdcsTestDnsServer:" + $retVal4 + "`n"; 
                    $retVal5 = Test-DnsServerForInputDnsName ("_ldap._tcp.dc._msdcs." + $zone) $dnsServer "SRV"; 
                    $resultStream = $resultStream + "LdapTCPMsdcsResolveDnsName:" + $retVal5 + "`n"; 
                    if (!(([RetStatus]::Success -eq $retVal3) -and ([RetStatus]::Success -eq $retVal4) -and ([RetStatus]::Success -eq $retVal5))) { 
                        $result = [RetStatus]::Failure; 
                    } 
                } 
             
                if ([RetStatus]::Success -eq $result) { 
                    LogComment $("Validation of " + $zone + " passed on DNS Server: " + $dnsServer); 
                    LogComment $("Validation of " + $zone + " passed on DNS Server: " + $dnsServer) 
                        $script:logLevel.Host;                 
                } else {                     
                    LogComment $("Validation of " + $zone + " failed on DNS Server: " + $dnsServer) 
                        $script:logLevel.Error;  
                    LogComment $("Validation output:" + $resultStream) $script:logLevel.Error; 
                    $result = $resultStream; 
                } 
            } catch { 
                LogComment $("Test-ZoneHealthAcrossAllDnsServers failed for Zone: " + $zone + " on DNSServer: " + $dnsServer + " `n " + $_.Exception) ` 
                    $script:logLevel.Error; 
                $result = [RetStatus]::Failure; 
            }             
            $status = Insert-ResultInObject $status $dnsServer $result; 
        }   
        $statusArray += $status; 
    }     
    Generate-Report $statusArray $outputReportName $script:resultView.Table; 
    return $statusArray; 
} 
 
# 
# Tests health of root domain zones - $domain & _msdcs.$domain across all DNS Servers 
# Verifies all the enterprise DNS servers can resolve these root domain names. 
# Performs a Test-DnsServer query for input root domain zones 
# 
Function Test-RootDomainHealthAcrossAllDnsServers 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [HashTable]$domainAndHostingServerHash, 
    $dnsServerList 
) 
    Test-ZoneHealthAcrossAllDnsServers $domainAndHostingServerHash.Keys $dnsServerList $true $MyInvocation.MyCommand 
} 
 
# 
# Test health  of input zones scavenging setting across all the zone hosting servers. This method verifies that: 
#   Scavenging should be enabled. 
#   Scavenging shouldn’t be enabled on more than 1 server.  
#   Refresh & non-refresh interval should be set to default value (168 hours). 
#   ScavengeServers should be configured. 
# 
Function Test-ZoneAgingHealth 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [HashTable]$zoneAndHostingServersHash 
) 
 
    $status = New-Object PSObject; 
    foreach($zone in $zoneAndHostingServersHash.keys) { 
             
        $result = [RetStatus]::Success;  
        $agingStatus = $false; 
        $defaultRefreshInterval = [Timespan]::FromHours(168); 
         
        foreach($server in $zoneAndHostingServersHash[$zone]) {          
            try {                
                $retObj = ExecuteCmdLet "Get-DnsServerZoneAging" @{"ComputerName" = $server; "ZoneName" = $zone}; 
                                         
                if ($null -ne $retObj) { 
                    if ($retObj.AgingEnabled) { 
                        LogComment $("Aging is enabled on Server: " + $server + " for Zone: " + $zone);   
                     
                        # In case of non-default values of Refresh & NoRefresh interval and $null ScavengeServers 
                        # we're only giving below 3 warnings, not considering them as a failure case. 
                        if ($defaultRefreshInterval -ne $retObj.RefreshInterval) { 
                            LogComment $("RefreshInterval is set to non-default value: " + $retObj.RefreshInterval) ` 
                                $script:logLevel.Warning; 
                        } 
                        if ($defaultRefreshInterval -ne $retObj.NoRefreshInterval) { 
                            LogComment $("NoRefreshInterval is set to non-default value: " + $retObj.NoRefreshInterval) ` 
                                $script:logLevel.Warning; 
                        }  
                        if ($null -eq $retObj.ScavengeServers) { 
                            LogComment $("There's no ScavengeServers configured.") $script:logLevel.Warning; 
                        }     
                     
                        # If Aging is enabled on more than 1 server, considering it as failure case. 
                        if ($agingStatus) { 
                            $result = [RetStatus]::Failure; 
                            LogComment $("Aging is enabled on more than one server for Zone: " + $zone) ` 
                                $script:logLevel.Warning; 
                        } else {                          
                            $agingStatus = $true; 
                        } 
                    } else { 
                        LogComment $("Aging is disabled on Server: " + $server + " for Zone: " + $zone);                    
                    } 
                } else { 
                    if ([RetStatus]::OperationIsNotSupported -eq $script:cmdLetReturnedStatus) { 
                        LogComment $($zone + " is non-primary zone on " + $server); 
                    } else { 
                        LogComment $("Failed to get " + $zone + " aging info on " + $server + " with error " + $script:cmdLetReturnedStatus) ` 
                            $script:logLevel.Error; 
                        $result = [RetStatus]::Failure; 
                    } 
                }                
            } catch { 
                LogComment $("Test-ZoneAgingHealth failed for Zone: " + $zone + " on Server: " + $server + " `n " + $_.Exception) ` 
                    $script:logLevel.Error; 
                $result = [RetStatus]::Failure; 
            } 
         
            # If Aging is not enabled on any server, considering it as failure case. 
            if (!$agingStatus) { 
                LogComment $("No server found with zone aging enabled for the Zone: " + $zone) ` 
                    $script:logLevel.Warning;  
                $result = [RetStatus]::Failure; 
            } 
             
            if ([RetStatus]::Success -eq $result) { 
                LogComment $("Zone Aging setting validation of " + $zone + " passed."); 
                LogComment $("Zone Aging setting validation of " + $zone + " passed.") ` 
                    $script:logLevel.Host;                 
            } else { 
                LogComment $("Zone Aging setting validation of " + $zone + " failed.") ` 
                    $script:logLevel.Error;                 
            }         
            $status = Insert-ResultInObject $status $zone $result; 
        } 
    }     
    Generate-Report $status $MyInvocation.MyCommand $script:resultView.List; 
    return $status; 
} 
 
# 
# Tests health of delegation chains inside all the input zones hosted across all servers. 
# Verifies name resolution is happening properly through the NameServers pointed by these delegations. 
# 
Function Test-ZoneDelegationHealth 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [HashTable]$zoneAndHostingServersHash 
)     
    $statusArray = @();     
     
    foreach($zone in $zoneAndHostingServersHash.keys) {      
        foreach($server in $zoneAndHostingServersHash[$zone]) {   
            # Get all NS records under the zone. 
            $rrObj = ExecuteCmdLet "Get-DnsServerResourceRecord" @{"ComputerName" = $server; "RRType" = "NS"; "ZoneName" = $zone};              
            # Exclude root level NS record. 
            $rrObj = $rrObj |? hostname -ne "@";             
            $zoneDelObj = $null;             
            if ($null -ne $rrObj) { 
                LogComment $("Performing delegation check for " + $zone + " on " + $server); 
                foreach($rr in $rrObj) {  
                    $result = [RetStatus]::Success; 
                    $resultStream = $null; 
                    $status = New-Object PSObject; 
                    $status | Add-Member -memberType NoteProperty -name "ZoneName :: Server" -value ($zone + " :: " + $server) -Force;                     
                    try { 
                        $zoneDelObj = ExecuteCmdLet "Get-DnsServerZoneDelegation" @{"ComputerName" = $server; "ZoneName" = $zone; "ChildZoneName" = $rr.hostname};  
                        if ($null -eq $zoneDelObj) { 
                            LogComment $("Failed to get info for " + $rr.hostname + " on " + $server + " with error " + $script:cmdLetReturnedStatus) ` 
                                $script:logLevel.Error;  
                            if ([RetStatus]::Success -eq $script:cmdLetReturnedStatus) { 
                                $result = [RetStatus]::Failure; 
                            } else {                             
                                $result = $script:cmdLetReturnedStatus; 
                            } 
                        } else {  
                            foreach($zoneDel in $zoneDelObj) { 
                                $zoneDelName = $zoneDel.ChildZoneName; 
                                LogComment $("Validating ZoneDelegation: " + $zoneDelName + " at server: " + $server); 
                                [Array]$rr_ip = $zoneDel.IPAddress 
                                foreach ($ipRec in $rr_ip) { 
                                    if ($null -ne $ipRec){ 
                                        $ipAddr = @(); 
                                        if ($ipRec.RecordType -eq "A") { 
                                            $ipAddr = $ipRec.RecordData.IPv4Address 
                                        } else { 
                                            $ipAddr = $ipRec.RecordData.IPv6Address 
                                        }   
                                        foreach ($ip in $ipAddr) { 
                                            $retVal = Test-DnsServerForInputDnsName $zoneDelName $ip; 
                                            $resultStream = $resultStream + $ip.IPAddressToString + ":" + $retVal + "`n"; 
                                            if ([RetStatus]::Success -eq $retVal) { 
                                                LogComment $("Validated NameServer IP: " + $ip + " for ZoneDelegation: " + $zoneDelName + " on Server: " + $server); 
                                                LogComment $("Validated NameServer IP: " + $ip + " for ZoneDelegation: " + $zoneDelName + " on Server: " + $server) ` 
                                                    $script:logLevel.Host;                 
                                            } else { 
                                                $result = [RetStatus]::Failure; 
                                                LogComment $("Validation of NameServer IP: " + $ip + " for ZoneDelegation: " + $zoneDelName + " on Server: " + $server + " failed.") ` 
                                                    $script:logLevel.Error; 
                                            } 
                                        } 
                                    } else { 
                                        $result = [RetStatus]::Failure; 
                                        $resultStream = $resultStream + "NullIPAddressRecord;"; 
                                        LogComment $("IPAddress record is null for ZoneDelegation: " + $zoneDelName + " on Server: " + $server) $script:logLevel.Error; 
                                    }   
                                }  
                            } 
                            if ([RetStatus]::Success -ne $result) { 
                                $result = $resultStream; 
                                LogComment $("Validation output:" + $resultStream) $script:logLevel.Error; 
                            } 
                        } 
                    } catch { 
                        LogComment $("Test-ZoneDelegationHealth failed for Zone: " + $zone + " on Server: " + $server + " `n " + $_.Exception) ` 
                            $script:logLevel.Error; 
                        $result = [RetStatus]::Failure; 
                    } 
                    $status = Insert-ResultInObject $status $rr.hostname $result; 
                    $statusArray += $status; 
                }             
            } else { 
                if ([RetStatus]::Success -eq $script:cmdLetReturnedStatus) { 
                    LogComment $("There's no non-root NS record in " + $zone + " on " + $server); 
                } elseif ([RetStatus]::OperationIsNotSupported -eq $script:cmdLetReturnedStatus) { 
                    LogComment $($zone + " isn't a primary or secondary zone on " + $server); 
                } else { 
                    LogComment $("Failed to get NS records under " + $zone + " on " + $server + " with error " + $script:cmdLetReturnedStatus)  ` 
                        $script:logLevel.Error;  
                    $status = New-Object PSObject; 
                    $status | Add-Member -memberType NoteProperty -name "ZoneName :: Server" -value ($zone + " :: " + $server) -Force; 
                    $status = Insert-ResultInObject $status "Get-DnsServerResourceRecord" $script:cmdLetReturnedStatus; 
                    $statusArray += $status; 
                } 
            } 
        }         
    }      
    Generate-Report $statusArray $MyInvocation.MyCommand $script:resultView.List; 
    return $statusArray; 
} 
 
# 
# Tests health of all configured Forwarders on input DnsServerList. 
# Performs a Test-DnsServer query for these Forwarders in Forwarder context. 
# 
Function Test-ConfiguredForwarderHealth 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]     
    $dnsServerList 
) 
    $statusArray = @(); 
     
    foreach($dnsServer in $dnsServerList) { 
        $status = New-Object PSObject; 
        $status | Add-Member -memberType NoteProperty -name "DNSServer" -value $dnsServer;  
        try { 
            $retObj = ExecuteCmdLet "Get-DnsServerForwarder" @{"ComputerName" = $dnsServer}; 
            if ($null -ne $retObj) { 
                LogComment $("Performing Forwarder health check for DnsServer: " + $dnsServer); 
                foreach($fwdIp in $retObj.IPAddress) {              
                    $result = Test-DnsServerForInputContext $fwdIp.IPAddressToString "Forwarder" $dnsServer; 
                    if ([RetStatus]::Success -eq $result) {                 
                        LogComment $("Validated Forwarder: " + $fwdIp.IPAddressToString + " of DNS Server: " + $dnsServer); 
                        LogComment $("Validated Forwarder: " + $fwdIp.IPAddressToString + " of DNS Server: " + $dnsServer) ` 
                            $script:logLevel.Host;                 
                    } else {             
                        LogComment $("Validation of Forwarder: " + $fwdIp.IPAddressToString + " of DNS Server: " + $dnsServer + " failed.") ` 
                            $script:logLevel.Error; 
                    }      
                    $status = Insert-ResultInObject $status $fwdIp $result; 
                }             
            } else { 
                if ([RetStatus]::Success -ne $script:cmdLetReturnedStatus) { 
                    LogComment $("Unable to get Forwarder list for DnsServer: " + $dnsServer) ` 
                        $script:logLevel.Error;    
                    $status = Insert-ResultInObject $status "Get-DnsServerForwarder" $script:cmdLetReturnedStatus; 
                } else { 
                    LogComment $("There's no forwarder configured on DnsServer: " + $dnsServer); 
                    $status = Insert-ResultInObject $status "NoForwarderConfigured" $script:cmdLetReturnedStatus; 
                }                
            } 
        } catch { 
            LogComment $("Test-ConfiguredForwarderHealth failed on DNSServer: " + $dnsServer + " `n " + $_.Exception) ` 
                $script:logLevel.Error; 
            $status = Insert-ResultInObject $status "ForwarderHealthCheckFailed" [RetStatus]::Failure; 
        } 
        $statusArray += $status; 
    }     
    Generate-Report $statusArray $MyInvocation.MyCommand $script:resultView.List;  
    return $statusArray; 
} 
 
# 
# Tests health of all configured RootHints on input DnsServerList. 
# Performs a Test-DnsServer query for these RootHints in RootHints context. 
# 
Function Test-ConfiguredRootHintsHealth 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]     
    $dnsServerList 
)     
    $statusArray = @(); 
     
    foreach($dnsServer in $dnsServerList) { 
     
        $status = New-Object PSObject; 
        $status | Add-Member -memberType NoteProperty -name "DNSServer" -value $dnsServer;    
        try { 
            $retObj = ExecuteCmdLet "Get-DnsServerRootHint" @{"ComputerName" = $dnsServer}; 
            if ($null -ne $retObj) { 
                LogComment $("Performing RootHints health check for DnsServer: " + $dnsServer); 
                foreach($rH in $retObj) {          
                    $result = [RetStatus]::Success; 
                    $resultStream = $null; 
                    $rHName = $rH.NameServer.RecordData.NameServer; 
                    LogComment $("Validating RootHints: " + $rHName + " for DnsServer: " + $dnsServer); 
                    [Array]$rr_ip = $rH.IPAddress 
                    foreach ($ipRec in $rr_ip) { 
                        $ipAddr = @(); 
                        if ($ipRec.RecordType -eq "A") { 
                            $ipAddr = $ipRec.RecordData.IPv4Address 
                        } else { 
                            $ipAddr = $ipRec.RecordData.IPv6Address 
                        }   
                        foreach ($ip in $ipAddr) { 
                            $retVal = Test-DnsServerForInputContext $ip "RootHints" $dnsServer; 
                            $resultStream = $resultStream + $ip.IPAddressToString + ":" + $retVal + "`n"; 
                            if ([RetStatus]::Success -eq $retVal) { 
                                LogComment $("Validated RootHints: " + $ip + " of DNS Server: " + $dnsServer); 
                                LogComment $("Validated RootHints: " + $ip + " of DNS Server: " + $dnsServer) ` 
                                    $script:logLevel.Host;                 
                            } else { 
                                $result = [RetStatus]::Failure; 
                                LogComment $("Validation of RootHints: " + $ip + " of DNS Server: " + $dnsServer + " failed.") ` 
                                    $script:logLevel.Error; 
                            } 
                        }                         
                    } 
                    if ([RetStatus]::Success -eq $result) { 
                        $status = Insert-ResultInObject $status $rHName $result; 
                    } else { 
                        $status = Insert-ResultInObject $status $rHName $resultStream; 
                        LogComment $("Validation output:" + $resultStream) $script:logLevel.Error; 
                    } 
                } 
            } else { 
                if ([RetStatus]::Success -ne $script:cmdLetReturnedStatus) { 
                    LogComment $("Unable to get RootHints list for DnsServer: " + $dnsServer) ` 
                        $script:logLevel.Error;    
                    $status = Insert-ResultInObject $status "Get-DnsServerRootHint" $script:cmdLetReturnedStatus; 
                } else { 
                    LogComment $("There's no RootHints configured on DnsServer: " + $dnsServer); 
                    $status = Insert-ResultInObject $status "NoRootHintConfigured" $script:cmdLetReturnedStatus; 
                } 
            } 
        } catch { 
            LogComment $("Test-ConfiguredRootHintsHealth failed on DNSServer: " + $dnsServer + " `n " + $_.Exception) ` 
                $script:logLevel.Error; 
            $result = [RetStatus]::Failure; 
            $status = Insert-ResultInObject $status "RootHintsHealthCheckFailed" $result; 
        } 
        $statusArray += $status; 
    } 
     
    Generate-Report $statusArray $MyInvocation.MyCommand $script:resultView.List; 
    return $statusArray; 
} 
 
# 
# Tests whether given DNS Server is able to resolve input DNS Name. 
# 
Function Test-DnsServerForInputDnsName 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $dnsName, 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $dnsServer, 
    $rrType = "All" 
)     
    $result = [RetStatus]::Failure;  
 
    try {     
        $retObj = ExecuteCmdLet "Resolve-DnsName" @{"Name" = $dnsName; "Type" = $rrType; "Server" = $dnsServer}; 
        if ($null -eq $retObj) { 
            LogComment $("Resolve-DnsName for " + $dnsName + " failed on server " + $dnsServer + " with " + $script:cmdLetReturnedStatus) ` 
                $script:logLevel.Error;  
            $result = $script:cmdLetReturnedStatus; 
        } else { 
            LogComment $("Name resolution of " + $dnsName + " passed on server " + $dnsServer);  
            $result = [RetStatus]::Success; 
        } 
         
    } catch { 
        LogComment $("Test-DnsServerForInputDnsName failed " + $_.Exception) $script:logLevel.Error; 
        $result = [RetStatus]::Failure; 
    }    
     
    return $result; 
} 
 
# 
# Performs a Test-DnsServer query on input zone. 
# 
Function Test-DnsServerForInputZone 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $zoneName, 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $dnsServer, 
    $remoteServer = "." 
)     
    $result = [RetStatus]::Failure;  
 
    try { 
     
        $dnsServerIP = $null; 
        if (![Net.IPaddress]::TryParse($dnsServer, [ref]$dnsServerIP)) { 
            try { 
                #Resolve and get first IP 
                $dnsServerIP = [System.Net.Dns]::GetHostAddresses($dnsServer).IPAddressToString.Split(" ")[0];                 
            } catch { 
                LogComment $("Exception while trying to get IP Address of  " + $dnsServer + "`n" + $_.Exception) ` 
                    $script:logLevel.Error; 
                throw; 
            } 
        } 
         
        $retObj = ExecuteCmdLet "Test-DnsServer" @{"ComputerName" = $remoteServer; "ZoneName" = $zoneName; "IPAddress" = $dnsServerIP}; 
        if ($null -eq $retObj) {   
            LogComment $("Test-DnsServer failed for " + $zoneName + " on server " + $dnsServer) $script:logLevel.Warning;  
            $result = $script:cmdLetReturnedStatus; 
        } else { 
            if (($retObj.Result -eq "Success") -or ($retObj.Result -eq "NotAuthoritativeForZone")) { 
                LogComment $("Test-DnsServer passed for " + $zoneName + " on server " + $dnsServer + " with Result: " + $retObj.Result); 
                $result = [RetStatus]::Success; 
            } else { 
                LogComment $("Test-DnsServer failed for " + $zoneName + " on server " + $dnsServer + " with Result: " + $retObj.Result) ` 
                    $script:logLevel.Warning;  
                $result = $retObj.Result; 
            } 
        } 
    } catch { 
        LogComment $("Test-DnsServerForInputDnsName failed " + $_.Exception) $script:logLevel.Error; 
        $result = [RetStatus]::Failure; 
    }    
     
    return $result; 
} 
 
# 
# Performs a Test-DnsServer query on input DNS Server and in given context. 
# 
Function Test-DnsServerForInputContext 
{ 
param (     
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $dnsServer, 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $context, 
    $remoteServer = "." 
)     
    $result = [RetStatus]::Failure;   
 
    try { 
     
        $retObj = ExecuteCmdLet "Test-DnsServer" @{"ComputerName" = $remoteServer; "IPAddress" = $dnsServer; "Context" = $context}; 
        if ($null -eq $retObj) {   
            LogComment $("Test-DnsServer failed for DnsServer: " + $dnsServer + " with context: " + $context) $script:logLevel.Warning;  
            $result = $script:cmdLetReturnedStatus; 
        } else { 
            if ($retObj.Result -eq "Success") { 
                LogComment $("Test-DnsServer Passed for DnsServer: " + $dnsServer + " with context: " + $context + " and Result: " + $retObj.Result); 
                $result = [RetStatus]::Success; 
            } else { 
                LogComment $("Test-DnsServer Failed for DnsServer: " + $dnsServer + " with context: " + $context + " and Result: " + $retObj.Result) ` 
                    $script:logLevel.Warning;  
                $result = $retObj.Result; 
            } 
        } 
    } catch { 
        LogComment $("Test-DnsServerForInputContext failed " + $_.Exception) $script:logLevel.Error; 
        $result = [RetStatus]::Failure; 
    }    
     
    return $result; 
} 
 
# 
# Gets the ZoneHostingServerList from the NS records for input DNS Zone. 
# 
Function Get-ZoneHostingServerListFromNSRecords 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    $dnsZone,     
    $dnsServer = $null 
)    
    try { 
        $retObj = $null; 
        $zoneHostingServerList = $null; 
        if ($null -eq $dnsServer) { 
            $retObj = ExecuteCmdLet "Resolve-DnsName" @{"Name" = $dnsZone; "Type" = "NS"}; 
        } else {     
            $retObj = ExecuteCmdLet "Resolve-DnsName" @{"Name" = $dnsZone; "Type" = "NS"; "Server" = $dnsServer}; 
        } 
         
        if ($null -eq $retObj) { 
            if ([RetStatus]::Success -eq $script:cmdLetReturnedStatus) { 
                LogComment $("No NS records found for zone: " + $dnsZone + " on server: " + $dnsServer) ` 
                    $script:logLevel.Warning;  
            } else { 
                LogComment $("Resolve-DnsName for " + $dnsZone + " failed on server " + $dnsServer + " with " + $script:cmdLetReturnedStatus) ` 
                    $script:logLevel.Error;  
            }             
        } else { 
            LogComment $("NS records found for zone: " + $dnsZone + " on server: " + $dnsServer); 
            $retObj = $retObj | ? Type -eq "NS"; 
            $zoneHostingServerList = @(); 
            $retObj | % {$zoneHostingServerList += $_.NameHost}; 
        } 
         
    } catch { 
        LogComment $("Get-ZoneHostingServerListFromNSRecords failed " + $_.Exception) $script:logLevel.Error; 
    }   
    return $zoneHostingServerList; 
} 
 
# 
# Tests $filePath and returns with its content. 
# Also removes any null or empty string across the content. 
# 
Function Get-FileContent 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [String]$filePath 
) 
    $fileContent = $null; 
    if (Test-Path $filePath) { 
        $fileContent = ExecuteCmdLet "Get-Content" @{"Path" = $filePath};         
    } else { 
        LogComment $($filePath + " not found."); 
    } 
    if ($null -ne $fileContent) { 
        $fileContent = $fileContent | ?{-not([String]::IsNullOrEmpty($_))}; 
    } else { 
        LogComment $("Returning with Null content for " + $filePath); 
    } 
    return $fileContent; 
} 
 
# 
# Converts input object to HTML format to generate the report. 
# 
Function Generate-Report 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [Object]$inputObj,  
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [String]$contextName, 
    [String]$viewAs = $script:resultView.Table 
)     
 
    $head = @' 
    <!--mce:0--> 
'@ 
 
    $header = "<H1>DNS Health Report for " + $contextName + "</H1>"; 
    $ouputFile = $contextName + ".html"; 
    $inputObj = $inputObj | ? {$null -ne ($_ | gm -m properties)}; 
    $inputObj | 
        ConvertTo-Html -Head $head -Body $header -As $viewAs |  
        Out-File $ouputFile | Out-Null; 
         
    # Do the colour coding of Success & Failure, basically a hack in HTML. 
    $success2Search = "<td>" + [RetStatus]::Success + "</td>"; 
    $success2Replace = "<td style=`"color:green;font-weight:bold;`">" + [RetStatus]::Success + "</td>"; 
    $failure2Search = "<td>" + [RetStatus]::Failure + "</td>"; 
    $failure2Replace = "<td style=`"color:red;font-weight:bold;`">" + [RetStatus]::Failure + "</td>"; 
     
    $content = Get-Content -path $ouputFile; 
    $content = $content -creplace $success2Search, $success2Replace; 
    $content = $content -creplace $failure2Search, $failure2Replace; 
    $content | Set-Content $ouputFile  -Encoding UTF8 | Out-Null; 
} 
 
# 
# Inserts result value in input object.  
# 
Function Insert-ResultInObject 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [Object]$inputObj,  
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [String]$resultName, 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [String]$resultVal 
)         
    if (Get-Member -InputObject $inputObj -Name $resultName) { 
        $inputObj.$resultName = $resultVal;         
    } else { 
        $inputObj | Add-Member -memberType NoteProperty -name $resultName -value $resultVal;         
    }     
    return $inputObj; 
} 
 
# 
# Writes input HashTable content into HTML file after joining the all Arrays. 
# 
Function Write-HashTableInHtml 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [HashTable]$inputHash,  
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [String]$fileLabel 
) 
    $tempHash = @{}; 
    foreach($key in $inputHash.Keys){ 
         $tempHash[$key] = $inputHash[$key] -join '; '; 
    }     
    $tempObj = New-Object PSObject -Property $tempHash; 
    Generate-Report $tempObj $fileLabel $script:resultView.List; 
} 
 
# 
# Creates Enum with input name and values in PS. 
# More info @ http://blogs.msdn.com/b/powershell/archive/2007/01/23/how-to-create-enum-in-powershell.aspx 
# 
Function New-Enum 
{ 
param ( 
    [parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [string] $enumName, 
    [Array] $enumVals = @() 
) 
    $appdomain = [System.Threading.Thread]::GetDomain(); 
    $assembly = new-object System.Reflection.AssemblyName; 
    $assembly.Name = "EmittedEnum"; 
    $assemblyBuilder = $appdomain.DefineDynamicAssembly($assembly, ` 
        [System.Reflection.Emit.AssemblyBuilderAccess]::Save -bor [System.Reflection.Emit.AssemblyBuilderAccess]::Run); 
    $moduleBuilder = $assemblyBuilder.DefineDynamicModule("DynamicModule", "DynamicModule.mod"); 
    $enumBuilder = $moduleBuilder.DefineEnum($enumName, [System.Reflection.TypeAttributes]::Public, [System.Int32]); 
    for($i = 0; $i -lt $enumVals.Count; $i++) { 
        $null = $enumBuilder.DefineLiteral($enumVals[$i], $i); 
    } 
    $enumBuilder.CreateType() > $null | Out-Null; 
}  
 
# 
# Creating a Enum RetStatus for returned status. 
# 
New-Enum -EnumName RetStatus -EnumVals @("Success", "Failure", "RpcServerIsUnavailable", "AccessIsDenied",  
                                         "ZoneDoesNotExist", "OperationIsNotSupported", "RecordDoesNotExist",  
                                         "NotApplicable","ResolveDnsNameServerNotFound", "ResolveDnsNameResolutionFailed",  
                                         "ResolveDnsNameTimeoutPeriodExpired"); 
                                          
# 
# Creating a Enum ValidationType for input validation types. 
# 
New-Enum -EnumName ValidationType -EnumVals $script:validValidationTypes; 
 
############################################################ 
############### Main Script Body Begins Here ############### 
############################################################ 
 
try { 
    # Start logging in Test-EnterpriseDnsHealth.txt 
    Start-Transcript Test-EnterpriseDnsHealth.txt | Out-Null;  
     
    if ($null -eq $script:dnsServerList) {$script:dnsServerList = Get-EnterpriseDnsServerList;}     
    if ($null -eq $script:dnsServerList) { 
        throw "Unable to get DNS server information. Exiting..."; 
    } 
     
    if ($null -eq $script:zoneHostingServerList) {$script:zoneHostingServerList = Get-EnterpriseZoneHostingServerList}; 
    if ($null -eq $script:zoneHostingServerList) { 
        throw "Unable to get Zone Hosting server information. Exiting..."; 
    } 
         
    if($ValidationType -icontains $script:allValidationType) { 
        LogComment $("Validation type contains 'All'. Performing all available health checks.") $script:logLevel.Host; 
        $applicableValidationTypes = $script:validValidationTypes; 
    } else { 
        $applicableValidationTypes =  $ValidationType; 
    } 
     
    foreach ($validationSubType in $applicableValidationTypes) {  
        LogComment $("Performing health check for Validation Type: " + $validationSubType) $script:logLevel.Host; 
        Switch ($validationSubType) 
        { 
            ([ValidationType]::Domain) {          
                if($null -eq $script:domainAndHostingServersList) { 
                    $script:domainAndHostingServersList = Get-EnterpriseDomainAndHostingServersHash $script:zoneHostingServerList; 
                } 
                if ($null -ne $script:domainAndHostingServersList) {         
                    Test-RootDomainHealthAcrossAllDnsServers $script:domainAndHostingServersList $script:dnsServerList; 
                } else { 
                LogComment $("No domain found, Skipping RootDomainHealthCheckUp") $script:logLevel.Warning; 
                } 
            } 
             
            ([ValidationType]::Zone) { 
                if($null -eq $script:zoneAndHostingServersList) { 
                    $script:zoneAndHostingServersList = Get-EnterpriseZoneAndHostingServersHash $script:zoneHostingServerList; 
                } 
                if ($null -ne $script:zoneAndHostingServersList) {             
                    Test-ZoneHealthAcrossAllDnsServers $script:zoneAndHostingServersList.Keys $script:dnsServerList; 
                } else { 
                    LogComment $("No zone found, Skipping ZoneHealthCheckUp") $script:logLevel.Warning; 
                } 
            } 
             
            ([ValidationType]::ZoneAging) { 
                if($null -eq $script:zoneAndHostingServersList) { 
                    $script:zoneAndHostingServersList = Get-EnterpriseZoneAndHostingServersHash $script:zoneHostingServerList; 
                } 
                if ($null -ne $script:zoneAndHostingServersList) {                                 
                    Test-ZoneAgingHealth $script:zoneAndHostingServersList;                                
                } else { 
                    LogComment $("No zone found, Skipping ZoneAgingHealthCheckUp") $script:logLevel.Warning; 
                } 
            }            
             
            ([ValidationType]::ZoneDelegation) { 
                if($null -eq $script:zoneAndHostingServersList) { 
                    $script:zoneAndHostingServersList = Get-EnterpriseZoneAndHostingServersHash $script:zoneHostingServerList; 
                } 
                if ($null -ne $script:zoneAndHostingServersList) {                                 
                    Test-ZoneDelegationHealth $script:zoneAndHostingServersList;             
                } else { 
                    LogComment $("No zone found, Skipping ZoneDelegationHealthCheckUp") $script:logLevel.Warning; 
                } 
            } 
             
            ([ValidationType]::Forwarder) { 
                Test-ConfiguredForwarderHealth $script:dnsServerList; 
            } 
             
            ([ValidationType]::RootHints) { 
                Test-ConfiguredRootHintsHealth $script:dnsServerList; 
            } 
             
            default { 
                LogComment $($validationSubType + " isn't a valid input ValidationType, skipping the validation.") $script:logLevel.Warning; 
                LogComment $("Choose '" + $script:allValidationType + "' or one or more validation types among below:`n" + $($script:validValidationTypes | Out-String)) ` 
                    $script:logLevel.Warning; 
            } 
        } 
    } 
} catch { 
    LogComment $("Caught exception during Test-EnterpriseDnsHealth: `n" + $_.Exception) $script:logLevel.Error; 
} Finally { 
    # Stop logging in Test-EnterpriseDnsHealth.txt 
    Stop-Transcript | Out-Null; 
    # Line number correction in output log file Test-EnterpriseDnsHealth.txt 
    $logContent = Get-Content Test-EnterpriseDnsHealth.txt; 
    $logContent > Test-EnterpriseDnsHealth.txt | Out-Null; 
}