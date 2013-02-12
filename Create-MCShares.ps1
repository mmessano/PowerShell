# Create-MCShares.ps1
# mmessano 12-20-2012

## Function to return a sql query, return the results in an array.
function SQL-Query{
	param([string]$Query,
		[string]$SqlServer = $DEFAULT_SQL_SERVER,
		[string]$DB = $DEFAULT_SQL_DB,
		[string]$RecordSeparator = "`t"
		)

	$conn_options = ("Data Source=$SqlServer; Initial Catalog=$DB;" + "Integrated Security=SSPI")
	$conn = New-Object System.Data.SqlClient.SqlConnection($conn_options)
	$conn.Open()

	$sqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$sqlCmd.CommandTimeout = "300"
	$sqlCmd.CommandText = $Query
	$sqlCmd.Connection = $conn

	$reader = $sqlCmd.ExecuteReader()
	[array]$serverArray
	$arrayCount = 0
	while($reader.Read()){
		$serverArray += ,($reader.GetValue(0))
		$arrayCount++
	}
	$serverArray
}
   
# // New-Share: Creates new Share on local or remote PC, with custom permissions.
# // Required Parameters: FolderPath, ShareName
# //
# // New-ACE: Creates ACE Objects, for use when running New-Share.
# // Required Parameters: Name, Domain
# //
# // New-SecurityDescriptor: used by New-Share to prepare the permissions.
# // Required Parameters: ACEs

Function New-SecurityDescriptor (
$ACEs = (throw "Missing one or more Trustees"), 
[string] $ComputerName = ".")
{
	#Create SeCDesc object
	$SecDesc = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_SecurityDescriptor").CreateInstance()
	#Check if input is an array or not.
	if ($ACEs -is [System.Array])
	{
		#Add Each ACE from the ACE array
		foreach ($ACE in $ACEs )
		{
			$SecDesc.DACL += $ACE.psobject.baseobject
		}
	}
	else
	{
		#Add the ACE 
		$SecDesc.DACL =  $ACEs
	}
	#Return the security Descriptor
	return $SecDesc
}

Function New-ACE (
	[string] $Name = (throw "Please provide user/group name for trustee"),
	[string] $Domain = (throw "Please provide Domain name for trustee"), 
	[string] $Permission = "Read",
	[string] $ComputerName = ".",
	[switch] $Group = $false)
{
	#Create the Trusteee Object
	$Trustee = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_Trustee").CreateInstance()
	#Search for the user or group, depending on the -Group switch
	if (!$group)
		{ $account = [WMI] "\\$ComputerName\root\cimv2:Win32_Account.Name='$Name',Domain='$Domain'" }
	else
		{ $account = [WMI] "\\$ComputerName\root\cimv2:Win32_Group.Name='$Name',Domain='$Domain'" }
	#Get the SID for the found account.
	$accountSID = [WMI] "\\$ComputerName\root\cimv2:Win32_SID.SID='$($account.sid)'"
	#Setup Trusteee object
	$Trustee.Domain = $Domain
	$Trustee.Name = $Name
	$Trustee.SID = $accountSID.BinaryRepresentation
	#Create ACE (Access Control List) object.
	$ACE = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_ACE").CreateInstance()
	#Select the AccessMask depending on the -Permission parameter
	switch ($Permission)
	{
		"Read"		{ $ACE.AccessMask = 1179817 }
		"Change"	{ $ACE.AccessMask = 1245631 }
		"Full"		{ $ACE.AccessMask = 2032127 }
		default { throw "$Permission is not a supported permission value. Possible values are 'Read','Change','Full'" }
	}
	#Setup the rest of the ACE.
	$ACE.AceFlags = 3
	$ACE.AceType = 0
	$ACE.Trustee = $Trustee
	#Return the ACE
	return $ACE
}

Function New-Share (
	[string] $FolderPath = (throw "Please provide the share folder path (FolderPath)")
	, [string] $ShareName = (throw "Please provide the Share Name")
	, $ACEs
	, [string] $Description = ""
	, [string] $ComputerName = ".")
{
	#Start the Text for the message.
	$text = "$ShareName ($FolderPath): "
	#Package the SecurityDescriptor via the New-SecurityDescriptor Function.
	$SecDesc = New-SecurityDescriptor $ACEs -ComputerName $ComputerName
	#Create the share via WMI, get the return code and create the return message.
	if ( ! (GET-WMIOBJECT Win32_Share -ComputerName $ComputerName -Filter "name='$Sharename'") )
		{
		$Share = [WMICLASS] "\\$ComputerName\Root\Cimv2:Win32_Share"
		$result = $Share.Create($FolderPath, $ShareName, 0, $NULL , $Description, $false , $SecDesc)
		}
	ELSE
		{
		$Share = GET-WMIOBJECT Win32_Share -ComputerName $ComputerName -Filter "name='$Sharename'"
		$result = $Share.SetShareInfo( $NULL, $Description, $SecDesc )
		}
	switch ($result.ReturnValue)
	{
		0 {$text += "has been successfully created" }
		2 {$text += "Error 2: Access Denied" }
		8 {$text += "Error 8: Unknown Failure" }
		9 {$text += "Error 9: Invalid Name"}
		10 {$text += "Error 10: Invalid Level" }
		21 {$text += "Error 21: Invalid Parameter" }
		22 {$text += "Error 22 : Duplicate Share"}
		23 {$text += "Error 23: Redirected Path" }
		24 {$text += "Error 24: Unknown Device or Directory" }
		25 {$text += "Error 25: Net Name Not Found" }
	}
	#Create Custom return object and Add results
	$return = New-Object System.Object
	$return | Add-Member -type NoteProperty -name Message -value $text
	$return | Add-Member -type NoteProperty -name ReturnCode -value $result.ReturnValue
	#Return result object
	$return
}


###################
##Start Script Here
###################

$ENV = $args[0]

if ($ENV -eq $null){
    $ENV = "DEN-PROD"
    }
    
switch ($ENV) 
	{
	"PA-PROD"{ 	$DBServer 		= 	"XSQLUTIL18"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									"; 
    		}
	
	"PA-STAGE"{ $DBServer 		= 	"FINREP01V"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									"; 
    		}
	
	"PA-IMP"{ 	$DBServer 		= 	"ISQLDEV610"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"StatusStage"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									"; 
    		}
	
	"PA-QA"{ 	$DBServer 		= 	"ISQLDEV610"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"StatusIMP"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									"; 
    		}
			
	"DEN-PROD"{ $DBServer 		= 	"sqlutil01"; 
				$ArchiveDrive	=	"D"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									--AND dns_host_name LIKE 'sql%'
									ORDER BY server_name
									";
			}
	
	"LOU-PROD"{ $DBServer 		= 	"sqlutil02"; 
				$ArchiveDrive	=	"D"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									--AND server_name LIKE 'HOpusSQL%'
									--OR server_name LIKE 'SQLUTIL%'
									ORDER BY server_name
									"; 
		}
	
	"FINALE"{ 	$DBServer 		= 	"FINREP01V"; 
				$ArchiveDrive	=	"C"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
									WHERE Active = '1'
									--AND server_name LIKE 'FinRep%'
									ORDER BY server_name
									"; 
    		}
	}

$ArchiveIPQuery = "SELECT ip_address FROM t_server_properties where server_id = (select server_id from t_server where server_name = '$DBServer')"

$OperationsSharename = "Operations"
$PerfmonLogsShareName = "PerfmonLogsArchive"
$title = "PerfmonCollector"

$Servers = ( Invoke-SQLCmd -query $ServerQuery -Server $DBServer -Database $DB )
$ArchiveIP = ( Invoke-SQLCmd -query $ArchiveIPQuery -Server $DBServer -Database $DB | Select-Object ip_address)
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().name

# create permissions
if ( $domain -eq "mortgagecadence.internal" ) {
	$DUACE 			= New-ACE -Name "Domain Users" -Domain MC -Permission Read -Group
	$PerfmonACE 	= New-Ace -Name svc_perfmon -Domain MC -Permission Full
	$mmessanoACE 	= New-Ace -Name mm_admin -Domain MC -Permission Full
	$jmckayACE		= New-Ace -Name jmckay -Domain MC -Permission Full
	$rhaagACE		= New-Ace -Name rhaag -Domain MC -Permission Full
	$tdodsonACE		= New-Ace -Name tdodson -Domain MC -Permission Full
	$sbrownACE		= New-Ace -Name sbrown -Domain MC -Permission Full
	$jfalconerACE	= New-Ace -Name jf_admin -Domain MC -Permission Full
	
	$MCACES			= ($DUACE,$PerfmonACE,$mmessanoACE,$jmckayACE,$rhaagACE,$tdodsonACE,$sbrownACE,$jfalconerACE)
	}
ELSEIF ( $domain -eq "mcfinale.net" ) {
	$DUACE 			= New-ACE -Name "Domain Users" -Domain MCFinale -Permission Read -Group
	$PerfmonACE 	= New-Ace -Name svc_perfmon -Domain MCFinale -Permission Full
	$mmessanoACE 	= New-Ace -Name mm_admin -Domain MCFinale -Permission Full
	$jmckayACE		= New-Ace -Name jm_admin -Domain MCFinale -Permission Full
	$rhaagACE		= New-Ace -Name rh_admin -Domain MCFinale -Permission Full
	$tdodsonACE		= New-Ace -Name td_admin -Domain MCFinale -Permission Full
	$sbrownACE		= New-Ace -Name sb_admin -Domain MCFinale -Permission Full
	$jfalconerACE	= New-Ace -Name jf_admin -Domain MCFinale -Permission Full
	
	$MCACES			= ($DUACE,$PerfmonACE,$mmessanoACE,$jmckayACE,$rhaagACE,$tdodsonACE,$sbrownACE,$jfalconerACE)
	}

# begin updating servers
foreach ($Server in $Servers) 
{
	if ($Server -ne $null) 
	{
        # servers are named the same in each domain therefore unroutable; use the full dns name
		$ServerName 			= 	$($Server.dns_host_name)
		$ServerIPAddress		= 	$($Server.ip_address)
		$PerfmonDrive			= 	$($Server.perfmon_drive)
		
		$OldPerfLogsDir			= 	"\\" + $ServerIPAddress + "\" + $PerfmonDrive + "$\" + "PerfmonLogs"
		$OperationsLocalPath	= 	$PerfmonDrive + ":\" + $OperationsSharename
		$PerfmonLogsArchiveLP 	= 	$ArchiveDrive + ":\" + $PerfmonLogsShareName
		$ArchiveDir 			= 	"\\" + $ArchiveIP.ip_address + "\" + $PerfmonLogsShareName + "\" + $ServerName + "\"
		$PerfmonLogsArchive		= 	"\\" + $DBServer + "\" + $ArchiveDrive + "$\" + $PerfmonLogsShareName
		$OperationsRoot 		= 	"\\" + $ServerIPAddress + "\" + $PerfmonDrive + "$\" + $OperationsSharename		
		
		
		
		Write-Host "----- Begin $ServerName. -----"
		
		# remove old PerfmonLogs directory
		if ( Test-Path -Path $OldPerfLogsDir ) {
			Write-Host "Removing old PerfmonLogs directory."
			Remove-Item -path $OldPerfLogsDir
			}
			
        # create operations directory if it does not exist
		if (!(Test-Path -path $OperationsRoot)) {
            Write-Host "Creating directories."
			New-Item -Path $OperationsRoot -type directory
			# create sub-directories
			if (!( Test-Path -path ($OperationsRoot + "\Logs") )) {
			New-Item -Path ($OperationsRoot + "\Logs") -type directory
				}
			if (!( Test-Path -path ($OperationsRoot + "\Support") )) {
			New-Item -Path ($OperationsRoot + "\Support") -type directory
				}
			if (!( Test-Path -path ($OperationsRoot + "\Support\Perfmon") )) {
			New-Item -Path ($OperationsRoot + "\Support\Perfmon") -type directory
				}
			}
		ELSE {
			Write-Host "Operations directory exists, checking for sub-directories."
			if (!( Test-Path -path ($OperationsRoot + "\Logs") )) {
			New-Item -Path ($OperationsRoot + "\Logs") -type directory
				}
			if (!( Test-Path -path ($OperationsRoot + "\Bin") )) {
			New-Item -Path ($OperationsRoot + "\Bin") -type directory
				}
			if (!( Test-Path -path ($OperationsRoot + "\SSIS") )) {
			New-Item -Path ($OperationsRoot + "\SSIS") -type directory
				}
			if (!( Test-Path -path ($OperationsRoot + "\Support") )) {
			New-Item -Path ($OperationsRoot + "\Support") -type directory
				}
			if (!( Test-Path -path ($OperationsRoot + "\Support\Perfmon") )) {
			New-Item -Path ($OperationsRoot + "\Support\Perfmon") -type directory
				}
			}
		
		# always create share and apply/modify permissions
		New-Share -FolderPath $OperationsLocalPath -ShareName $OperationsShareName -Computer $ServerName -ACEs $MCACES
		
		# check for archive server
		if ( $($Server.server_name) -eq $DBServer ) {
			if (!(Test-Path -path $PerfmonLogsArchive)) {
            	New-Item -Path $PerfmonLogsArchive -type directory
				}
			# always create share and apply/modify permissions
			New-Share -FolderPath $PerfmonLogsArchiveLP -ShareName $PerfmonLogsShareName -Computer $ServerName -ACEs $MCACES
			}
		
		# create archive share if it does not exist
		if (!(Test-Path -path $ArchiveDir)) {
			New-Item $ArchiveDir -type directory
			}
		

		Write-Host "----- End $ServerName. -----"
		Write-Host ""
	}
}

#C:\users\mm_admin\Documents\WindowsPowerShell\Scripts\Create-MCShares.ps1 DEN-PROD
# rebuild MOF file in an admin ps window
# C:\Windows\System32\wbem\MOFComp CIMWIN32.MOF
