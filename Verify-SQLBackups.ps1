### Code that can be used to Monitor all you Sql Instances Backups from One Location

#Create a new Excel object using COM
$ErrorActionPreference = "silentlycontinue"
$Excel = New-Object -ComObject Excel.Application
$Excel.visible = $False
$Excel.DisplayAlerts = $false
$ExcelWorkbooks = $Excel.Workbooks.Add()
$Sheet = $ExcelWorkbooks.Worksheets.Item(1)

#$MonitorBody = "D:\PowerShell\PScripts\Mail.htm"
#$date = get-date -uformat "%Y%m%d"
$date = ( get-date ).ToString('yyyy/MM/dd')
$save = "E:\Dexma\Logs\DatabaseBackup_Report.xls"

#Counter variable for rows
$intRow = 1

#Read the contents of the Servers.txt file
#foreach ($instance in get-content "serverlist.txt")

##################Loop in all your sqlserver instances#########################
foreach ($instance in get-content "\\xmonitor11\Dexma\Data\ServerLists\SMC_IMP.txt")
{
#Create column headers
    $Sheet.Cells.Item($intRow,1) = "INSTANCE NAME:"
        $Sheet.Cells.Item($intRow,2) = $instance
        $Sheet.Cells.Item($intRow,1).Font.Bold = $True
        $Sheet.Cells.Item($intRow,2).Font.Bold = $True

        $intRow++

        $Sheet.Cells.Item($intRow,1) = "DATABASE NAME"
        $Sheet.Cells.Item($intRow,2) = "LAST FULL BACKUP"
        $Sheet.Cells.Item($intRow,3) = "LAST LOG BACKUP"
        $Sheet.Cells.Item($intRow,4) = "FULL BACKUP AGE(DAYS)"
        $Sheet.Cells.Item($intRow,5) = "LOG BACKUP AGE(HOURS)"

    #Format the column headers
        for ($col = 1; $col -le 5; $col++)
    {
        $Sheet.Cells.Item($intRow,$col).Font.Bold = $True
            $Sheet.Cells.Item($intRow,$col).Interior.ColorIndex = 50
            $Sheet.Cells.Item($intRow,$col).Font.ColorIndex = 36
    }

    $intRow++
    #######################################################
    #This script gets SQL Server database information using PowerShell
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    # Create an SMO connection to the instance
    $s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $instance

    $dbs = $s.Databases
    #Formatting using Excel
    ForEach ($db in $dbs)
    {
        if ($db.Name -ne "tempdb") #We do not need the backup information for the tempdb database
        {
			#We use Date Math to extract the number of days since the last full backup
            $NumDaysSinceLastFullBackup = ((Get-Date) - $db.LastBackupDate).Days
    		#Here we use TotalHours to extract the total number of hours
            $NumDaysSinceLastLogBackup = ((Get-Date) - $db.LastLogBackupDate).TotalHours
            if($db.LastBackupDate -eq "1/1/2005 12:00 AM")
			#This date is a start of Sqlserver infra.
			#This is the default dateTime value for databases that have not had any backups
            {
                $fullBackupDate="Never been backed up"
                $fgColor3="red"
            }
            else
            {
                $fullBackupDate="{0:g}" -f $db.LastBackupDate
            }

            $Sheet.Cells.Item($intRow, 1) = $db.Name
            $Sheet.Cells.Item($intRow, 2) = $fullBackupDate
            $fgColor3="green"

    #Use the .ToString() Method to convert the value of the Recovery model to string and ignore Log #backups for databases with Simple recovery model
                if ($db.RecoveryModel.Tostring() -eq "SIMPLE")
            {
                $logBackupDate="N/A"
                $NumDaysSinceLastLogBackup="N/A"
            }
            else
            {
                if($db.LastLogBackupDate -eq "1/1/2011 12:00 AM")
                {
                    $logBackupDate="Never been backed up"
                }
                else
                {
                    $logBackupDate= "{0:g2}" -f $db.LastLogBackupDate
                }
            }
            $Sheet.Cells.Item($intRow, 3) = $logBackupDate

    #Define your service-level agreement in terms of days here.
                if ($NumDaysSinceLastFullBackup -gt 0)
            {
                $fgColor = 3
            }
            else
            {
                $fgColor = 50
            }

            $Sheet.Cells.Item($intRow, 4) = $NumDaysSinceLastFullBackup
            $Sheet.Cells.item($intRow, 4).Interior.ColorIndex = $fgColor
            $Sheet.Cells.Item($intRow, 5) = $NumDaysSinceLastLogBackup
            $intRow ++
        }
    }
    $intRow ++
}


$Sheet.UsedRange.EntireColumn.AutoFit()
$ExcelWorkbooks.SaveAs($save)
$Excel.quit()
CLS

######Send Email with excel sheet as a attachment#######
$mail = New-Object System.Net.Mail.MailMessage
$att = new-object Net.Mail.Attachment($save)
$mail.From = "mmessano@dexma.com"
$mail.To.Add("mmessano@dexma.com")
$mail.Subject = "Database Backup Report for all SQL servers on $date "
$mail.Body = "This mail gives us detailed information for all the database backups which are scheduled to run every day. Please review the attached Excel report every day and fix the failed backups which are marked in Red and make sure the Full Backup Age(DAYS) is Zero."
$mail.Attachments.Add($att)
$smtp = New-Object System.Net.Mail.SmtpClient("outbound.smtp.dexma.com")
$smtp.Send($mail)
