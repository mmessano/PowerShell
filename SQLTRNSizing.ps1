#Connection Strings
$Database = "dbamaint"
$Server = "PSQLPA24"
#SMTP Relay Server
$SMTPServer = "smtp.domain.com"
#Export File
$AttachmentPath = "C:\Dexma\Logs\output.csv"
# Connect to SQL and query data, extract data to SQL Adapter
$SqlQuery = "exec sel_TRNSizing"
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Data Source=$Server;Initial Catalog=$Database;Integrated Security = True"
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $SqlConnection
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet
$nRecs = $SqlAdapter.Fill($DataSet)
$nRecs | Out-Null
#Populate Hash Table
$objTable = $DataSet.Tables[0]
#Export Hash Table to CSV File
$d = Get-Date
$ThisWeek = $d.toshortdatestring()
$dLastWeek = $d.AddDays(-7)
$LastWeek = $dLastWeek.toshortdatestring()
write-host $ThisWeek
write-host $LastWeek
$objTable | Export-CSV $AttachmentPath -NoType

#TO_STRING(TO_TIMESTAMP(date, time), 'yyyy-MM-dd')

$GraphCompareAll = ".\logparser.exe `"select to_string(to_timestamp('BackupDate', 'mm/dd/yy hh:mm:ss'), 'yyyy-MM-dd') AS BackupDate, TotalSize   into TRNLogSizing.gif
                    from c:\dexma\logs\*.csv
                    order by to_string(to_timestamp('BackupDate', 'mm/dd/yy hh:mm:ss'), 'yyyy-MM-dd') desc`" -groupSize:1280x960 -categories:ON -maxCategoryLabels:-1 -chartTitle:WeeklyResponseTimeComparison"
Invoke-Expression $GraphCompareAll
