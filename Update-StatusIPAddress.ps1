# Update-StatusIPAddress.ps1

function SQL-NONQuery{
	param([string]$Statement,
	[string]$SqlServer = $DEFAULT_SQL_SERVER,
	[string]$DB = $DEFAULT_SQL_DB )

	$conn_options = ("Data Source=$SqlServer; Initial Catalog=$DB;" + "Integrated Security=SSPI")
	$conn = New-Object System.Data.SqlClient.SqlConnection($conn_options)
	$conn.Open()

	$cmd = $conn.CreateCommand()
	$cmd.CommandText = $Statement
	$Server = $cmd.ExecuteNonQuery()
	if(-not $?) {

	$lineno = Get-CurrentLineNumber
	#e:\dexma\support\logerror.ps1  $Output $date $lineno $title  
	./logerror.ps1  $Output $date $lineno $title
	}
	$Server
}

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
										, s.server_id
										, domain
										, ip_address
										, dns_host_name
									FROM t_server s 
										INNER JOIN t_server_properties sp ON s.server_id = sp.server_id
									WHERE Active = '1'
									ORDER BY server_name
									";
				$UpdateQuery	=	"UPDATE t_server_properties
										SET ip_address = $IP.IPAddress
									WHERE server_id = $($s.server_id)"
    		}
	}


$Servers = ( Invoke-SQLCmd -query $ServerQuery -Server $DBServer -Database $DB )

Foreach($s in $servers)
{
	$ServerName = $($s.dns_host_name)
	#$ServerName = $($s.ip_address)
	if(!(Test-Connection -Cn $ServerName -BufferSize 16 -Count 1 -ea 0 -quiet)){
		"Problem connecting to $ServerName"
   	}
	else {
		"Connection to $ServerName succeeded!"
		$IP = Get-IPAddress -ComputerName $ServerName -IPV4only | Select IPAddress
		$IP.IPAddress
		"`tDoing a GetHostEntry on $($s.server_name)..."
		$UpdateQuery	=	"UPDATE t_server_properties SET ip_address = '" + $IP.IPAddress + "' WHERE server_id = $($s.server_id)"
									
		$UpdateQuery
		try {
			#$ServerName = [System.Net.Dns]::gethostentry($server).hostname
			Invoke-SqlCmd -Query $UpdateQuery -Server $DBServer -Database $DB
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
}

