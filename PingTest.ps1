# PingTest.ps1

cls
$Errors.Clear;

$ENV = $args[0]

if ($ENV -eq $null){
    $ENV = "PA-PROD"
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
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									"; 
    		}
	
	"PA-STAGE"{ $DBServer 		= 	"STGSQLCBS620"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"StatusStage"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									"; 
    		}
	
	"PA-IMP"{ 	$DBServer 		= 	"ISQLDEV610"; 
				$ArchiveDrive	=	"E"
				$DB 			= 	"StatusImp"; 
				$ServerQuery	= 	"SELECT server_name
										, domain
										, ip_address
										, dns_host_name
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
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
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
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
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
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
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
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
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
									WHERE Active = '1'
									--AND server_name LIKE 'FinRep%'
									ORDER BY server_name
									"; 
    		}
	}

$Servers = ( Invoke-SQLCmd -query $ServerQuery -Server $DBServer -Database $DB )

$Count = $Servers.Count

# create NULL array
$ServerProperties = @()

Foreach($s in $servers)
{
	$ServerName = $($s.dns_host_name)
	$ServerIP = $($s.ip_address)
	if(!(Test-Connection -Cn $ServerName -BufferSize 16 -Count 1 -ea 0 -quiet)){
		"Problem connecting to $ServerName"
		"Flushing DNS"
		ipconfig /flushdns | out-null
		"Registering DNS"
		ipconfig /registerdns | out-null
		"doing a NSLookup for $ServerName"
		nslookup $ServerName
		"Re-pinging $ServerName"
		if(!(Test-Connection -Cn $ServerName -BufferSize 16 -Count 1 -ea 0 -quiet)){
			"Problem still exists in connecting to $ServerName"
			}
		ELSE {
			"Resolved problem connecting to $ServerName"
			}
   	}
	else {
		#"Connection to $ServerName succeeded!"
		#"`tDoing a GetHostEntry on $($s.server_name)..."
		try {
			$ServerHostName = [System.Net.Dns]::gethostentry($ServerName).hostname
			}	
		catch [System.SystemException] {
			Write-Host "Exception connecting to $Server(System.SystemException)" 
			$_.Exception
			# $_.Exception | Get-Member # show the exception's members to see what is available
			Write-Host
			if ($_.Exception.InnerException) {
				Write-Host "Inner Exception: "
				$_.Exception.InnerException # display the exception's InnerException if it has one
				}
			}
		catch [System.Exception] {
			Write-Host "Exception connecting to $Server(System.Exception)" 
			$_.Exception
			# $_.Exception | Get-Member # show the exception's members to see what is available
			Write-Host
			if ($_.Exception.InnerException) {
				Write-Host "Inner Exception: "
				$_.Exception.InnerException # display the exception's InnerException if it has one
				}
			}
	}
	#Write-Host "`tGetHostEntry Succeeded for: " $ServerHostName " = " $ServerIP
	$ServerProp = New-Object -TypeName PSObject
				Add-Member -InputObject $ServerProp -type NoteProperty -Name "ServerName" 	-value $($s.server_name)
				Add-Member -InputObject $ServerProp -type NoteProperty -Name "ServerIP" 	-value $ServerIP
				Add-Member -InputObject $ServerProp -type NoteProperty -Name "ServerFQDN" 	-value $ServerHostName
	$ServerProperties += $ServerProp
}
Write-Host "Processed $Count servers!"
$ServerProperties

$Errors