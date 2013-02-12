  #######################################################################################
##
## GET-PerfmonDataCollectorStatus.ps1
##
## Schedules Perfmon collection on servers with the Perfmon flag in t_monitoring set to 1 
## 
  #######################################################################################
 

## Function to return a sql query, return the results in an array.
function SQL-Query{
	param([string]$Query,
	[string]$SqlServer = $DEFAULT_SQL_SERVER,
	[string]$DB = $DEFAULT_SQL_DB,
	[string]$RecordSeparator = "`t")

	$conn_options = ("Data Source=$SqlServer; Initial Catalog=$DB;" + "Integrated Security=SSPI")
	$conn = New-Object System.Data.SqlClient.SqlConnection($conn_options)
	$conn.Open()

	$sqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$sqlCmd.CommandTimeout = "300"
	$sqlCmd.CommandText = $Query
	$sqlCmd.Connection = $conn

	$reader = $sqlCmd.ExecuteReader()
	if(-not $?) {#error logging
	$lineno = Get-CurrentLineNumber
	./logerror.ps1  $Output $date $lineno $title 
	}
	[array]$serverArray
	$arrayCount = 0
	while($reader.Read()){
		$serverArray += ,($reader.GetValue(0))
		$arrayCount++
	}
	$serverArray
}

###################
##Start Script Here
###################

$ENV = $args[0]

if ($ENV -eq $null){
    $ENV = "PROD"
    }
    
switch ($ENV) 
	{
	"PA-PROD"{ 	$DBServer 		= 	"XSQLUTIL18"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
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
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'
										AND st.type_name NOT IN ('Payload', 'Utility', 'Queueing', 'PGP', 'Internal FTP', 'FTP', 'Connection', 'IISConnection', 'FileServer')
										--AND server_name = 'iwebcbs10'
									ORDER BY server_name
									"; 
    		}
	
	"PA-STAGE"{ $DBServer 		= 	"STGSQLCBS620"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
										, domain
										, ip_address
										--, dns_host_name
										, perfmon_path
										, perfmon_drive
										, perfmon_start_time
										, perfmon_end_time
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
										INNER JOIN t_perfmon_properties pp ON s.server_id = pp.server_id
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'
										AND st.type_name NOT IN ('Payload', 'Utility', 'Queueing', 'PGP', 'Internal FTP', 'FTP', 'Connection', 'IISConnection', 'FileServer')
									ORDER BY server_name
									"; 
    		}
	
	"PA-IMP"{ 	$DBServer 		= 	"ISQLDEV610"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"StatusStage"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
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
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'
										AND st.type_name NOT IN ('Payload', 'Utility', 'Queueing', 'PGP', 'Internal FTP', 'FTP', 'Connection', 'IISConnection', 'FileServer')
									ORDER BY server_name
									"; 
    		}
	
	"PA-QA"{ 	$DBServer 		= 	"ISQLDEV610"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"StatusIMP"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
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
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'
										AND st.type_name NOT IN ('Payload', 'Utility', 'Queueing', 'PGP', 'Internal FTP', 'FTP', 'Connection', 'IISConnection', 'FileServer')
									ORDER BY server_name
									"; 
    		}
			
	"DEN-PROD"{ $DBServer 		= 	"SQLUTIL01"; 
				$ArchiveDrive	=	"D"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
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
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'
									--AND dns_host_name LIKE 'sql01.generation%'
									--AND server_name LIKE 'SQLUTIL%'
									--OR server_name LIKE 'HOpusSQL%'
									ORDER BY server_name
									";
			}
	
	"LOU-PROD"{ $DBServer 		= 	"SQLUTIL02"; 
				$ArchiveDrive	=	"D"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
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
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'
									--AND server_name LIKE 'SQLUTIL%'
									--OR server_name LIKE 'HOpusCap%'
									ORDER BY server_name
									";  
			}
	
	"FINALE"{ $DBServer 		= 	"FINREP01V"; 
				$ArchiveDrive	=	"C"
				$DB 			= 	"Status"; 
				$ServerQuery	= 	"SELECT server_name
										, [Type] = 
											CASE st.type_name
												WHEN 'BOS-IIS' THEN 'IIS'
												WHEN 'Web-IIS' THEN 'IIS'
												WHEN 'Web' THEN 'IIS'
												WHEN 'Citrix PVS' THEN 'PVS'
												WHEN 'Citrix XenApp' THEN 'XenApp'
												WHEN 'Opus App' THEN 'App'
												WHEN 'SQL' THEN 'SQL'
												ELSE st.type_name
											END
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
										INNER JOIN t_server_type_assoc sta ON s.server_id = sta.server_id
										INNER JOIN t_server_type st ON sta.type_id = st.type_id
									WHERE Active = '1'"; 
    		}
	}

$Servers = ( Invoke-SQLCmd -query $ServerQuery -Server $DBServer -Database $DB )
$OutText = ''

foreach ($Server in $Servers) 
{
	if ($Server -ne $null) 
	{
        # servers are named the same in each domain therefore unroutable
		$ServerName 			= 	$($Server.dns_host_name)	
		$ServerIPAddress		= 	$($Server.ip_address)
		$ServerType 			= 	$($Server.Type)
		$PerfmonDrive			= 	$($Server.perfmon_drive)
		
		Write-Host "----- Begin $ServerName. -----"
		
		#https://mjolinor.wordpress.com/2012/03/22/named-captures-in-regular-expressions/
		#$regex = [regex]'(TCP|UDP)\s+([\d.]+):(\d+)\s+([\d.]+):(\d+)\s+(\w+)'
		#Matches             1          2       3        4       5      6
		
		$regex = [regex]'(?<DCS>[SystemHealth]+)\s+(?<Type>[Counter]+)\s+(?<Status>[Running | Stopped]+)'
		
		$StrCMDStatus = "C:\Windows\System32\Logman.exe -s $ServerName"
		$MyOutput = Invoke-Expression $StrCMDStatus | where { $_ -match $regex }
		
		if ( $MyOutput -eq $NULL ) {
			$OutText += $ServerName, "`t", $NULL, "`t", $NULL  , "`t", $NULL, "`n"
			}
		else {
			$OutText += $ServerName, "`t", $Matches.DCS, "`t", $Matches.Type  , "`t", $Matches.Status, "`n"
			}
		
		Write-Host "----- End $ServerName. -----"
		Write-Host ""
	}
}

$OutText | Sort-Object -Property Type, Status, DCS | Format-Table
