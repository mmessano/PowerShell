#Requires -version 2.0

# -----------------------------------------------------------------------------
# Script: Get-NetworkStatus.ps1
# Version: 1.0
# Author: Jeffery Hicks
#    http://jdhitsolutions.com/blog
#    http://twitter.com/JeffHicks
# Date: 1/18/2011
# Keywords: DNS, WMI, WinRM, Network
# Comments:
# This script assumes you are querying desktop computers with a single network card 
# and IP address. It also assumes you are in a domain, running this administrator
# credentials and that your DNS server is running Microsoft Windows.
#
# "Those who neglect to script are doomed to repeat their work."
#
#  ****************************************************************
#  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
#  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
#  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
#  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
#  ****************************************************************
# -----------------------------------------------------------------------------

<#
   .Synopsis
    Get network health for a given computer. 
    .Description
    This script runs a number of network health tests and checks for a computer
    and writes a custom object to the pipeline.
    .Parameter Computername
    The name of the computer to check. The default is the local computer. This
    parameter has an alias of -Name.
   .Example
    PS C:\> S:\Get-NetworkStatus.ps1 xplab

CShare          : True
Computername    : xplab
LeaseObtained   : 1/19/2011 9:22:58 AM
WMI             : True
AdapterHostname : xplab
Ping            : True
AdminShare      : True
DHCPServer      : 192.168.56.102
WinRM           : True
LeaseExpires    : 1/27/2011 9:22:58 AM
DNSDomain       : jdhlab.local
MACAddress      : 08-00-27-AD-81-3E
IPAddress       : 192.168.56.203
ReverseLookup   : True
DNSHostName     : xplab.jdhlab.local

    .Example
    PS C:\> Import-Module ActiveDirectory
    PS C:\> Get-ADComputer -Filter * -SearchBase "OU=Desktops,DC=jdhlab,DC=local" | Foreach {
    >> S:\Get-Networkstatus $_.Name} | Where {$_.Ping} | 
    >> Export-CSV -Path C:\Work\Desktop-Net-Report.csv -NoTypeInformation

    This command uses the Get-ADComputer cmdlets from the Active Directory module. It queries
    all the computers int he Desktops OU and creates a CSV file only for computers that reply
    to a ping.
  
   .Notes
    NAME: Get-NetworkStatus.ps1
    AUTHOR: Jeffery Hicks
    VERSION: 1.0
    LASTEDIT: 01/19/2011 
    
    Learn more with a copy of Windows PowerShell 2.0: TFM (SAPIEN Press 2010)
    
   .Link
    Http://jdhitsolutions.com/blog
    
    .Link
    Get-WMIObject
    Get-Service
    Test-Connection
    Test-Path
    
    .Inputs
    Strings
    
    .Outputs
    Custom object
 #>

Param(
    [Parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [ValidateNotNullorEmpty()]
    [Alias("name")]
    [string[]]$Computername=$env:computername
)

Begin
{ 
    Set-StrictMode -Version 2.0
    
    #not necessarily good practice, but I'm turning off the error pipeline
    #to suppress all error messages. I've set default values that should cover
    #everything.
    $ErrorActionPreference="SilentlyContinue"
    
   #define some helper functions
   Function Get-DefaultDNSServer {
        #this is fast and easy, but perhaps not the best PowerShell
        $lookup=nslookup $env:computername | select-string "Server"
        #get the matching line, split it at the colon, get the last
        #item from the array and trim any spaces.
        $lookup.line.split(":")[1].Trim()
    }

    Function New-ReverseIP {
        Param([string]$IPAddress)
        $arr=$IPAddress.Split(".")
        $Reverse="{0}.{1}.{2}.{3}" -f $arr[3],$arr[2],$arr[1],$arr[0]
        Write-Output $Reverse
    }
} #close Begin

Process {
    Foreach ($name in $computername) 
    {
        #set some default values
        $dns				= $False
        $dnsHostName		= $Null
        $IP					= $Null
        $ReverseVerify		= $False    
        $CShare				= $False
        $AdminShare			= $False
        $WMIVerify			= $False
        $WinRMVerify		= $False
        $AdapterHostname	= $Null
        $DNSDomain			= $Null
        $DHCPServer			= $Null
        $LeaseObtained		= $Null
        $LeaseExpires		= $Null

        #test connection
        $Ping = Test-Connection $name -Quiet

        #resolve DNS Name
        $dns=[system.net.dns]::GetHostEntry("$name")

        if ($dns)
        {
            Write-Verbose ($dns | out-String)
            $dnshostname = $dns.hostname
            #filter out IPv6 addresses
            $IPv4 = $dns.addresslist | where {$_.AddressFamily -eq "Internetwork"}
            if (($IPv4 | Measure-Object).Count -gt 1)
            {
                #only take the first address
                $IP=$IPv4[0].IPAddressToString
            }
            else
            {
                $IP=$IPv4.IPAddressToString
            }
        } #close if $DNS
        else
        {
            Write-Verbose "No DNS record found for $name"
        }

        if ($IP)
        {
            #verify reverse lookup
            Write-Verbose "Reverse lookup check"
            $RevIP = "{0}.in-addr.arpa" -f (New-ReverseIP $IP)
            Write-Verbose $revIP
            $DNSServer = Get-DefaultDNSServer
            $filter = "OwnerName = ""$RevIP"" AND RecordData=""$DNSHostName."""
            Write-Verbose "Querying $DNSServer for $filter"
            $record = Get-WmiObject -Class "MicrosoftDNS_PTRType" -Namespace "Root\MicrosoftDNS" -ComputerName $DNSServer -filter $filter
            if ($record)
            {
                Write-Verbose ($record | Out-String)
          
                if ($record.RecordData -match $dnsHostName) 
                {
                    $ReverseVerify=$True
                }
            }
            #Get Network adapter configuration for primary IP
            Write-Verbose "Getting WMI NetworkAdapterConfiguration for address $IP"
            $configs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -filter "IPEnabled=True" -computername $name
           
            #get the adapter with the matching primary IP
            $adapter = $configs | where {$_.IPAddress -contains $IP}
            Write-Verbose ($adapter | Out-String)

            if ($adapter) 
            {
                $AdapterHostname	= $adapter.DNSHostname
                $DNSDomain			= $adapter.DNSDomain
                $DHCPServer			= $adapter.DHCPServer
                $LeaseObtained		= $adapter.ConvertToDateTime($adapter.dhcpleaseobtained)
                $LeaseExpires		= $adapter.ConvertToDateTime($adapter.dhcpleaseExpires)
            }
          
        } #close if $IP
        
        #Verify admin shares
        if (Test-Path -Path \\$name\c$) {$CShare=$True}
        if (Test-Path -Path \\$name\admin$) {$AdminShare=$True}

        #Verify WMI service
        Write-Verbose "Validating WinMgmt Service on $name"
        $wmisvc = Get-Service -Name Winmgmt -ComputerName $name 
        if ($wmisvc.status -eq "Running") {$WMIVerify=$True}

        #validate WinRM
        Write-Verbose "Validating WinRM Service on $name"
        $WinRMSvc = Get-Service -Name WinRM -computername $name
        if ($WinRMSvc.status -eq "Running") {$WinRMVerify=$True}
                
        #Get MAC Address for the computer. There are several ways to get this.
        #I'm taking the easy way.
        Write-Verbose "Retrieving MAC address from $name"
        #MAC Address regular expression pattern
        [regex]$MACPattern = "([0-9a-fA-F][0-9a-fA-F]-){5}([0-9a-fA-F][0-9a-fA-F])"
        #run NBTSTAT.EXE and save results
        $nbt = nbtstat -a $name
        #parse out the MAC Address
        $MACAddress = ($MACPattern.match($nbt)).Value   

        Write-Verbose "Creating object"
        #Write a custom object to the pipeline
        New-Object -TypeName PSObject -Property @{
            Computername	= $name
            AdapterHostname	= $adapterHostName
            DNSHostName		= $dnsHostname
            DNSDomain		= $DNSDomain
            IPAddress		= $IP
            ReverseLookup	= $ReverseVerify
            DHCPServer		= $DHCPServer
            LeaseObtained	= $LeaseObtained
            LeaseExpires	= $LeaseExpires
            MACAddress		= $MACAddress
            AdminShare		= $AdminShare
            CShare			= $CShare
            WMI				= $WMIVerify
            Ping			= $Ping
            WinRM			= $WinRMVerify
        } #close Property hash table
    } #close Foreach
} #close Process

End 
{
    $ErrorActionPreference = "Continue"
    Write-Verbose "Finished."
} #close End

#end of script