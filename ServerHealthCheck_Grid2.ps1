Clear-Host
[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")

[int]$numOfPerfmonCollections = 2
[int]$intervalOfCollections = 2

## Counters to collect ##
$physicalcounters =  ("\Memory\Available MBytes") `
	,("\PhysicalDisk(_Total)\Avg. Disk sec/Read")`
	,("\PhysicalDisk(_Total)\Avg. Disk sec/Write")  `
	,("\Processor(_Total)\% Processor Time") 
	
## SQL Counter template ([instancekey] is replaced with instance name in Get-SQLCounters Function)
$sqlCounterTemplate =  ("\[instancekey]:SQL Statistics\Batch Requests/sec") `
				,("\[instancekey]:Access Methods\Workfiles Created/sec")`
				,("\[instancekey]:Buffer Manager\Page life expectancy")

# Creates an new array with a SQLInstance specific list of counters 
# "\[instancekey]:Buffer Manager\Page life expectancy"
function Get-SQLCounters{
	param([string] $SQLServerToMonitor, $counters)
	$counterArray = @() # holds the instance specific counters array to pass into get-counter
	# Generate a counter path friendly name (SQLServer (default instance) or MSSQL$InstanceName)
	[int]$instPos = $SQLServerToMonitor.IndexOf("\");
	if($instPos -gt 0){ 
		$instPos += 1;
		$instancekey = "MSSQL$" + $SQLServerToMonitor.Substring($instPos,($SQLServerToMonitor.Length - $instPos))
	} else { # Default Instance
		$instancekey = "SQLServer"
	}
	## Rebuilds Counter array with SQL Specific counters
	foreach($cnter in $counters) {
		$counterArray += $cnter.Replace("[instancekey]",$instancekey)
	}
 	return $counterArray;
}

## Based on a Chad Miller script
function Invoke-Sqlcmd3
{
    param(
    [string]$ServerInstance,
    [string]$Query
    )
	$QueryTimeout=30
    $conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Integrated Security=True"
	$conn.ConnectionString=$constring
    	$conn.Open()
		if($conn){
    	$cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
    	$cmd.CommandTimeout=$QueryTimeout
    	$ds=New-Object system.Data.DataSet
    	$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    	[void]$da.fill($ds)
    	$conn.Close()
    	$ds.Tables[0]
	}
}

### ********** ###
### Begin Code ###
$server = Read-Host -Prompt "Specify a server" 

# Get a DateTime to use for filtering
[int]$hourThreshold = Read-Host -Prompt "Number of Hours to Check in Logs"

[datetime] $DatetoCheck = (Get-Date).AddHours(-1 * $hourThreshold)
[string]$sysprocessQuery = @"
	SELECT spid,blocked,open_tran,waittime,lastwaittype,waitresource,dbid
	,cpu,physical_io,memusage,hostname 
	FROM master..sysprocesses 
	WHERE blocked != 0  
	order by spid
"@

if(Test-Connection -ComputerName $server)
{
	Write-Host "$server pinged successfully"
} else {
	Write-Host "$server could not be pinged!"
	break;
}

#Grab SQL Services
$SQLServices = Get-WmiObject -ComputerName $server win32_service | 
		Where-Object {$_.name -like "*SQL*" } |
		Select-Object Name,StartMode,State,Status 
 
 if($SQLServices.Count -gt 0) {
	$SQLServices | Out-GridView -Title "$server SQL Services Information"
	}



# Grab OS counters and add to SQL Counter array for single grid output.
	Write-Host "Reading OS Perf Counters...."
	try{
		$sqlCounters = Get-Counter -ComputerName $server -Counter $physicalcounters `
								-MaxSamples $numOfPerfmonCollections -SampleInterval $intervalOfCollections
	} catch {
		Write-Host "Problem Reading Perf Counters" + $Error
	}
	

# Check each SQL Service (not Agent, etc) gather information
Foreach($sqlService in $SQLServices | 
			Where-Object{$_.name -like "MSSQL$*" -or $_.name -eq "MSSQLSERVER"} |
			Where-Object{$_.State -eq "Running"  } )
{
	[string]$sqlServerName = $sqlService.Name
	$sqlServerName = $sqlServerName.Replace("MSSQL$","$server\")
	$sqlServerName = $sqlServerName.Replace("MSSQLSERVER","$server")
	
	Write-host "Checking $sqlServerName"
	$sqlServer = New-Object("Microsoft.SqlServer.Management.Smo.Server") $sqlServerName	 
	
	# Grab any blocking processes
	try{
		$tbl = Invoke-Sqlcmd3 -Query $sysprocessQuery -ServerInstance $sqlServerName |
			Where-Object {$_.blocked -ne "0"} | 
			Out-GridView -Title "$sqlServerName Blocked Processes"
	}
	catch{
		Write-Host "Problem Reading SysProcesses" + $Error
	}
	
	# 
	Write-Host "Reading SQL Log for $sqlServerName"
	try{
		$sqlServer.ReadErrorLog() |	Where{$_.LogDate -is [datetime] } | 
				Where-Object{$_.LogDate -gt $DatetoCheck } | 
				Where-Object{$_.Text -like "*Error*" -or $_.Text -like "*Fail*"} |
				Select-Object LogDate,Text |
				Out-GridView -Title "$sqlServerName Log Errors"
	} catch {
		Write-Host "Error Reading $sqlServer.Name"
	}
	
	# Get SQL Instance specific counter array and build up array $sqlCounters to store for all instances
	try{
		$sqlInstanceCounters = Get-SQLCounters -SQLServerToMonitor $sqlServerName -counters $sqlCounterTemplate
	} catch {
		Write-Host "Error Building SQL Counter Template $_"
	}
	
	try{
		$sqlCounters += Get-Counter -ComputerName $server -Counter $sqlInstanceCounters `
						-MaxSamples $numOfPerfmonCollections -SampleInterval $intervalOfCollections 
	} catch {
		Write-Host "Error getting SQL Counters $_"
	}						
	
} # end of SQL instances loop

	# Push counters to grid		
	$sqlCounters | ForEach-Object{ $_.CounterSamples | Select-Object  Path, CookedValue } |
		Out-GridView -Title "$sqlServer Perfmon Counters"

	try{
	Write-Host "Reading Event Logs..."
	# Check Server System and Application Event Logs
	$systemLog = Get-EventLog -ComputerName $server `
		-EntryType "Error" -LogName "System" -After $DatetoCheck |
		Select-Object TimeGenerated,Source,Message 
		
	$appLog = Get-EventLog -ComputerName $server `
		-EntryType "Error" -LogName "Application" -After $DatetoCheck |
		Select-Object TimeGenerated,Source,Message 
		
	if($systemLog.Count -gt 0) {$serverLogs += $systemLog}	
	if($appLog.Count -gt 0) {$serverLogs += $appLog}	
	
	if($serverLogs.Count -gt 0) { $serverLogs | Out-GridView -Title "$server Event Logs" }

} catch {
	Write-Host "Problem Reading Server Event Logs:" + $Error
}







