[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null

$a = Get-Date

$b = "dbName" + $a.Day + "-" + $a.Month + "-" + $a.Year + ".bak.zip"

Remove-Item \\dataserver\folder\dbName.bak

$server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") ("dataserver")

$dbBackup = new-Object ("Microsoft.SqlServer.Management.Smo.Backup")
$dbRestore = new-object ("Microsoft.SqlServer.Management.Smo.Restore")

$dbBackup.Database = "dbName"
$dbBackup.Devices.AddDevice("C:\folder\dbName.bak", "File")
$dbBackup.Action="Database"
$dbBackup.Initialize = $TRUE
$dbBackup.SqlBackup($server)

if(!(Test-Path \\dataserver\folder\dbName.bak)){
 $smtp = new-object Net.Mail.SmtpClient("emailserver")
 $smtp.Send("from", "to", "Backups not working", "Action required immediately for Full Backup")
 Exit
}

$dbRestore.Devices.AddDevice("C:\folder\dbName.bak", "File")

if (!($dbRestore.SqlVerify($server))){
 $smtp = new-object Net.Mail.SmtpClient("emailserver")
 $smtp.Send("from", "to", "Backups not valid", "Action required immediately for Full Backup")
 Exit
}

Copy-Item \\dataserver\folder\dbName.bak C:\Data\dbName.bak

Write-Zip C:\Data\dbName.bak -OutputPath C:\Archives\$b

$webclient = New-Object System.Net.WebClient
$uri = New-Object System.Uri("FTP-server-site")

$webclient.UploadFile($uri, $location)
$c = Get-Date -format t
$smtp = new-object Net.Mail.SmtpClient("emailserver")
$smtp.Send("from", "to", "Database Backup Finish Time", $c)