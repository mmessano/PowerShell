#serverstatus.ps1
# Pings a list of servers contained in the text file servers.txt and if the server responds, returns information from each server
#
# Change log:
# January 29, 2009: Allen White
#   Initial Version

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
#[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement') | out-null


function getwmiinfo ($svr) {
	# Get ComputerSystem info and write it to a CSV file
	gwmi -query "select * from
		 Win32_ComputerSystem" -computername $svr | select Name,
		 Model, Manufacturer, Description, DNSHostName,
		 Domain, DomainRole, PartOfDomain, NumberOfProcessors,
		 SystemType, TotalPhysicalMemory, UserName, Workgroup | export-csv -path .\$svr\BOX_ComputerSystem.csv -noType

	# Get OperatingSystem info and write it to a CSV file
	gwmi -query "select * from
		 Win32_OperatingSystem" -computername $svr | select Name,
		 Version, FreePhysicalMemory, OSLanguage, OSProductSuite,
		 OSType, ServicePackMajorVersion, ServicePackMinorVersion | export-csv -path .\$svr\BOX_OperatingSystem.csv -noType

	# Get PhysicalMemory info and write it to a CSV file
	gwmi -query "select * from
		 Win32_PhysicalMemory" -computername $svr | select Name, Capacity, DeviceLocator,
		 Tag | export-csv -path .\$svr\BOX_PhysicalMemory.csv -noType

	# Get LogicalDisk info and write it to a CSV file
	gwmi -query "select * from Win32_LogicalDisk
		 where DriveType=3" -computername $svr | select Name, FreeSpace,
		 Size | export-csv -path .\$svr\BOX_LogicalDisk.csv -noType

}

function getsqlinfo {
	param (
		[string]$svr,
		[string]$inst
		)
	
	# Create an ADO.Net connection to the instance
	$cn = new-object system.data.SqlClient.SqlConnection("Data Source=$inst;Integrated Security=SSPI;Initial Catalog=master");

	# Create an SMO connection to the instance
	$s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $inst

	# Extract the specific instance name, and set it to MSSQLSERVER if it's the default instance
	$nm = $inst.Split("\")
	if ($nm.Length -eq 1) {
		$instnm = "MSSQLSERVER"
	} else {
		$instnm = $nm[1]
	}

	# Set the CSV output file name and pipe the instances Information collection to it
	$outnm = ".\" + $svr + "\" + $instnm + "_GEN_Information.csv"
	$s.Information | export-csv -path $outnm -noType
	
	# Create a DataSet for our configuration information
	$ds = new-object "System.Data.DataSet" "dsConfigData"

	# Set ShowAdvancedOptions ON for the query
	$s.Configuration.ShowAdvancedOptions.ConfigValue = 1
	$s.Configuration.Alter()

	# Build our query to get configuration, session and lock info, and execute it
	$q = "exec sp_configure;
"
	$q = $q + "exec sp_who;
"
	$q = $q + "exec sp_lock;
"
	$da = new-object "System.Data.SqlClient.SqlDataAdapter" ($q, $cn)
	$da.Fill($ds)

	# Build datatables for the config data, load them from the query results, and write them to CSV files
	$dtConfig = new-object "System.Data.DataTable" "dtConfigData"
	$dtWho = new-object "System.Data.DataTable" "dtWhoData"
	$dtLock = new-object "System.Data.DataTable" "dtLockData"
	$dtConfig = $ds.Tables[0]
	$dtWho = $ds.Tables[1]
	$dtLock = $ds.Tables[2]
	$outnm = ".\" + $svr + "\" + $instnm + "_GEN_Configure.csv"
	$dtConfig | select name, minimum, maximum, config_value, run_value | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_GEN_Who.csv"
	$dtWho | select spid, ecid, status, loginame, hostname, blk, dbname, cmd, request_id | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_GEN_Lock.csv"
	$dtLock | select spid, dbid, ObjId, IndId, Type,Resource, Mode, Status | export-csv -path $outnm -noType

	# Set ShowAdvancedOptions OFF now that we're done with Config
	$s.Configuration.ShowAdvancedOptions.ConfigValue = 0
	$s.Configuration.Alter()

	# Write the login name and default database for SQL Logins only to a CSV file
	$outnm = ".\" + $svr + "\" + $instnm + "_GEN_Logins.csv"
	$s.Logins | select Name, DefaultDatabase | export-csv -path $outnm -noType

	# Write information about the databases to a CSV file
	$outnm = ".\" + $svr + "\" + $instnm + "_GEN_Databases.csv"
	$dbs = $s.Databases
	$dbs | select Name, Collation, CompatibilityLevel, AutoShrink, RecoveryModel, Size, SpaceAvailable | export-csv -path $outnm -noType
	foreach ($db in $dbs) {
		# Write the information about the physical files used by the database to CSV files for each database
		$dbname = $db.Name
		if ($db.IsSystemObject) {
			$dbtype = "_SDB"
		} else {
			$dbtype = "_UDB"
		}
		$users = $db.Users
		$outnm = ".\" + $svr + "\" + $instnm + $dbtype + "_" + $dbname + "_Users.csv"
		$users | select $dbname, Name, Login, LoginType, UserType, CreateDate | export-csv -path $outnm -noType
		$fgs = $db.FileGroups
		foreach ($fg in $fgs) {
			$files = $fg.Files
			$outnm = ".\" + $svr + "\" + $instnm + $dbtype + "_" + $dbname + "_DataFiles.csv"
			$files | select $db.Name, Name, FileName, Size, UsedSpace | export-csv -path $outnm -noType
			}
		$logs = $db.LogFiles
		$outnm = ".\" + $svr + "\" + $instnm + $dbtype + "_" + $dbname + "_LogFiles.csv"
		$logs | select $db.Name, Name, FileName, Size, UsedSpace | export-csv -path $outnm -noType
		}
	
	# Create CSV files for each ErrorLog file
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog.csv"
	$s.ReadErrorLog() | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog_1.csv"
	$s.ReadErrorLog(1) | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog_2.csv"
	$s.ReadErrorLog(2) | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog_3.csv"
	$s.ReadErrorLog(3) | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog_4.csv"
	$s.ReadErrorLog(4) | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog_5.csv"
	$s.ReadErrorLog(5) | export-csv -path $outnm -noType
	$outnm = ".\" + $svr + "\" + $instnm + "_ERL_ErrorLog_6.csv"
	$s.ReadErrorLog(6) | export-csv -path $outnm -noType
}

# Get our list of target servers from the local servers.txt file
$servers = get-content 'servers.txt'

foreach ($prcs in $servers) {
	# The first entry in the file is the machine name, the second is the instance name so separate them
	$srvc = $prcs.Split(",")
	$server = $srvc[0]
	$instance = $srvc[1]
	
	# Ping the machine to see if it's on the network
	$results = gwmi -query "select StatusCode from Win32_PingStatus where Address = '$server'" 
	$responds = $false	
	foreach ($result in $results) {
		# If the machine responds break out of the result loop and indicate success
		if ($result.statuscode -eq 0) {
			$responds = $true
			break
		}
	}

	if ($responds) {
		# Check to see if a directory exists for this machine, if not create one
		if (!(Test-Path -path .\$server)) {
			New-Item .\$server\ -type directory
		}
		
		# Get the server info in the first function and the instance info in the second
		getwmiinfo $server
		getsqlinfo $server $instance
	} else {
		# Let the user know we couldn't connect to the server
		Write-Output "$server does not respond"
	}
}
