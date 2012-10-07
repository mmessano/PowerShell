# Stops and starts the asoociated services and flushes the Data directory
# which holds all the cached reports
param(
	$Environment
	)

#$BOServers = @{
#				"PROD" = @{	"BOServer" = 'PAPPBO10';
#							"BOServiceName" = 'BOE120SIAPAPPBO10';
#							"BOServiceDisplaName" = 'Server Intelligence Agent (PAPPBO10)';				
#							"BODataFolderPath" = '\\pappbo10\e$\Program Files\Business Objects\BusinessObjects Enterprise 12.0\Data'
#							"BOWebService" = 'World Wide Web Publishing Service';
#							};
#				"IMP" = @{	"BOServer" = 'IAPPBO510';
#							"BOServiceName" = 'BOE120SIAIAPPBO510';
#							"BOServiceDisplaName" = 'Server Intelligence Agent (IAPPBO510)';				
#							"BODataFolderPath" = '\\IAPPBO510\e$\Program Files\Business Objects\BusinessObjects Enterprise 12.0\Data\'
#							"BOWebService" = 'W3SVC';
#							};
#				}				

switch ($Environment)
	{
	PROD1 {	$Server 		= 'PAPPBO20';
			$BOService 		= 'BOE120SIAPAPPBO20';
			$BOWebService 	= 'W3SVC';
			$BODirectory 	= 'E:\Business Objects\BusinessObjects Enterprise 12.0\Data';
			$BODirOld	 	= 'E:\Business Objects\BusinessObjects Enterprise 12.0\DataOld';
		}
	PROD2 {	$Server 		= 'PAPPBO21';
			$BOService 		= 'BOE120SIAPAPPBO21';
			$BOWebService 	= 'W3SVC';
			$BODirectory 	= 'E:\Business Objects\BusinessObjects Enterprise 12.0\Data';
			$BODirOld	 	= 'E:\Business Objects\BusinessObjects Enterprise 12.0\DataOld';
		}
	IMP {	$Server 		= 'IAPPBO510';
			$BOService 		= 'BOE120SIAIAPPBO510';
			$BOWebService 	= 'W3SVC';
			$BODirectory 	= 'E:\Program Files\Business Objects\BusinessObjects Enterprise 12.0\Data';
			$BODirOld	 	= 'E:\Program Files\Business Objects\BusinessObjects Enterprise 12.0\DataOld';
		}
	}
	
# Functions
Function BORemoveDataFolder
	{
	param ($Dir);
	$TargetFolder = $Dir;
	if (Test-Path $TargetFolder)
	{
		try 
		{
			Remove-Item $TargetFolder -Recurse;
		}
		catch 
		{
			Write-Host "`tTried to delete $TargetFolder and failed!";
		}
		finally 
		{
			Write-Host "`tThe '$TargetFolder' folder was deleted successfully.";
		}
	}
	Else
		{
			Write-Host "`tThe Folder $TargetFolder does not Exist!";
		}
}

Function StopBOService
	{
	try 
		{
		Stop-Service $BOService;
	}
	catch 
		{
		Write-Host "The $BOService service failed to stop!";
	}
	finally
		{
		Write-Host "`tThe $BOService service was stopped successfully.";
	}
}
	
Function StopBOWebService
	{
	try 
		{
		Stop-Service $BOWebService;
		}
	catch 
		{
		Write-Host "The $BOWebService service failed to stop!";
		}
	finally
		{
		Write-Host "`tThe $BOWebService service was stopped successfully.";
		}
}

Function SendMail
	{
	$emailFrom = $Server + "@dexma.com";
	$emailTo = "outage@dexma.com";
	$subject = $Server + " Data Folder Maintenance";
	$smtpServer = "Outbound.smtp.dexma.com";
	#$body = "The " + '"' + "$BODirectory" + '"' + " folder has been deleted to clear the old cache files.";
	$smtp = new-object Net.Mail.SmtpClient($smtpServer);
	$smtp.Send($emailFrom, $emailTo, $subject, $body);
}

# get the last day of the month
$LastDayOfMonth = (Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day 1).AddMonths(1).AddDays(-1);
$DateDiff = New-TimeSpan $(Get-Date) $lastDayOfMonth;

# used for testing
#$DateDiff = New-TimeSpan $(Get-Date -month 9 -day 26 -year 2011) $lastDayOfMonth


if ( (Get-Date).DayOfWeek -eq 'Sunday' ) {
	# do it all
	# stop the BO and Web services
		Write-Host "Stopping services...";
		StopBOService;
		StopBOWebService;
	# Move the Data folder
		Write-Host "Moving folder...";
		Move-Item $BODirectory $BODirOld;
	# start the BO and Web services
		Write-Host "Starting Services...";
		Write-Host "`t...$BOService...";
		Start-Service -Name $BOService;
		Write-Host "`t...$BOWebService...";
		Start-Service -Name $BOWebService;
	# Remove the Data folder
		Write-Host "Removing folder..."
		BORemoveDataFolder $BODirOld;
	# Send email
		$body = "The " + '"' + "$BODirectory" + '"' + " folder has been deleted to clear the old cache files.";
		SendMail;
}
elseif ( ((Get-Date).Day -eq '1') -or (($DateDiff).days -eq '0') -or (($DateDiff).days -eq '1') ) {
	# stop the BO service
		Write-Host "The date is within two days of the end of the month or is the first of the month.";
		Write-Host "Stopping BO service...";
		StopBOService;
	# start the BO service	
		Write-Host "Starting BO Service...";
		Write-Host "`t...$BOService...";
		Start-Service -Name $BOService;
	# send email
		$body = "The Server Intelligence Agent " + '"' + "$BOService" + '"' + " service has been restarted for month end reporting availability.";
		SendMail;
}
elseif ( (($DateDiff).days -ge '2') ) {
	Write-Host "The end-of-month date is greater than 2 days away and it is not Sunday.";
	$body = "No changes were made.";
	#SendMail;
}

# check service status
Write-Host "Verifying services are started......";
Get-Service -ComputerName $Server -Name $BOService;
Get-Service -ComputerName $Server -Name $BOWebService;


