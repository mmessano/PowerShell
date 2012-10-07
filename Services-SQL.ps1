#Get-Service -DisplayName SQL* -ComputerName

$TableQuery = "EXEC sel_enum_db"
	
	
function Run-Query()
{
	param (
	$SqlQuery,
	$SqlServer,
	$SqlCatalog
	)
	
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=XSQLUTIL18;Integrated Security=SSPI;Initial Catalog=Status;");
	
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $SqlQuery
	$SqlCmd.Connection = $SqlConnection
	
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
	
	$DataSet = New-Object System.Data.DataSet
	$a = $SqlAdapter.Fill($DataSet)
	
	$SqlConnection.Close()
	
	$DataSet.Tables | Select-Object -ExpandProperty Rows
}

$Servers = Run-Query -SqlQuery $TableQuery | Select-Object -Property Server_Name

foreach($Server in $servers)
	{
	Write-Host $($Server.server_name)
	$Service = Get-Service -DisplayName SQL* -ComputerName $($Server.server_name) | Where-Object {$_.Name -eq "ReportServer"}
	if ($Service.Status -eq "Running")
		{
		#Write-Host $($Service.Status)","$($Service.Name)","$($Server.server_name)
		#Set-Service -ComputerName $($Server.server_name) -Name ReportServer -Status Stopped -StartupType Disabled
		Write-Host "Service is running on $($Server.server_name)."
		}
	elseif ($Service.Status -eq "Stopped")
		{
		#Write-Host $($Service.Status)","$($Service.Name)","$($Server.server_name)
		#Write-Host "Stopped service found, forcing Disabled startup type."
		#Set-Service -ComputerName $($Server.server_name) -Name ReportServer -Status Stopped -StartupType Disabled
		Write-Host "Service is not running."
		}
	}