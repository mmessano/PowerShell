###########################################################################################
# Scenario: Configure Database mirroring
#
#  How to use this powershell script:
#    - Launch SQL Server PowerShell ( Start -> Run -> sqlps.exe)
#    - Copy the following powershell script and save to file (Ex c:\DBMirrroringSetup.ps1)
#    - in powershell window, type in script file path ( Ex: c:\DBMirrroringSetup.ps1) to run the script
###########################################################################################

# Backup Database
function BackupDatabase
{
        Param([string]$servername, [string]$dbName, [string]$backupfiledir, [Microsoft.SqlServer.Management.Smo.BackupActionType]$actionType)

       $server = GetServer($servername)

        # construct a unique backup file name
        $backupfilepath = $backupfiledir + "\" + $dbName +  "-" + $actionType.ToString() + "-" +[DateTime]::Now.ToString('s').Replace(":","-") + ".bak"
        
        $backup = new-object ('Microsoft.SqlServer.Management.Smo.Backup')
        $backup.Action = $actionType
        $backup.Database = $dbName
        $backup.Devices.AddDevice($backupfilepath, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)

        $backup.SqlBackup($server)

        write-host "Backup completed successfully"
        write-host "Server:",$server.Name
        write-host "Database:$dbName"
        write-host "Backup File:$backupfilepath"
        
        $backupfilepath;
}

# Restore Database
function RestoreDatabase
{
        Param([string]$servername, [string]$dbName, [string]$backupDataFile)

        $server = GetServer($servername)
        $targetDBFilePath = $server.MasterDBPath + "\" + $dbName +  "-Data-" + [DateTime]::Now.ToString('s').Replace(":","-") + ".mdf"
        $targetLogFilePath = $server.MasterDBLogPath + "\" + $dbName +  "-Log-" + [DateTime]::Now.ToString('s').Replace(":","-") + ".ldf"

        $restore = new-object ('Microsoft.SqlServer.Management.Smo.Restore')
        $restore.Database = $dbName
        $restore.Devices.AddDevice($backupDataFile, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)

        $relocateDataFile = new-object ('Microsoft.SqlServer.Management.Smo.RelocateFile')($dbName, $targetDBFilePath)

        $logFileName = $dbName + "_Log"
        $relocateLogFile  = new-object ('Microsoft.SqlServer.Management.Smo.RelocateFile')($logFileName, $targetLogFilePath)

        $restore.RelocateFiles.Add($relocateDataFile)
        $restore.RelocateFiles.Add($relocateLogFile)

        $restore.ReplaceDatabase = $True
        $restore.NoRecovery = $True
        $restore.SqlRestore($server)
        
        write-host "Restore completed successfully"
        write-host "Server:", $server.Name
        write-host "Database:$dbName"
}

# Create Endpoints for Database mirroring and grant permissions
function CreateDBMirroringEndPoint
{
        Param([string]$servername, [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]$mirroringRole)
        $server = GetServer($servername)
        $tcpPort = GetNextAvailableTCPPort $servername

        $endPointName = "Database_Mirroring_" + [DateTime]::Now.ToString('s').Replace(":","-")
        $endpoint  = new-object ('Microsoft.SqlServer.Management.Smo.EndPoint')($server, $endPointName)
        $endpoint.ProtocolType = [Microsoft.SqlServer.Management.Smo.ProtocolType]::Tcp
        $endpoint.EndpointType = [Microsoft.SqlServer.Management.Smo.EndpointType]::DatabaseMirroring
        $endpoint.Protocol.Tcp.ListenerPort = $tcpPort  
        $endpoint.Payload.DatabaseMirroring.ServerMirroringRole = $mirroringRole
        $endpoint.Create()
        $endpoint.Start()
        
        # TCP:Server:port
        $fullyQualifiedName = "TCP://" + $server.NetName + ":" + $tcpPort       
        $fullyQualifiedName;
}

# Get DB Mirroring Endpoint ( if configured already)
# Note: we can have only one DB mirroring end point per sql instance
function GetFullyQualifiedMirroringEndpoint
{
        Param([string]$serverInstance, [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]$mirroringRole)
        $fullyQualifiedMirroringEndPointName = ""
        
        $EndPointList = GetEndPointList $serverInstance

        $server = GetServer $serverInstance
        
        if($EndPointList -eq $null)
        {
                $fullyQualifiedMirroringEndPointName = CreateDBMirroringEndPoint $serverInstance $mirroringRole
        }
        else
        {
                foreach($endPoint in $EndPointList)
                {
                        $fullyQualifiedMirroringEndPointName = "TCP://" + $server.NetName + ":" + $endPoint.Properties["ListenerPort"].Value
                        break
                }
        }
        
        write-host "Server Name:$serverInstance"
        write-host "Mirroring Role:$mirroringRole"
        write-host "EndPointName:$fullyQualifiedMirroringEndPointName"
        $fullyQualifiedMirroringEndPointName;
}

# Get EndPoint List
function GetEndPointList
{
        Param([string]$servername)
        $server = GetServer($servername)

        $PSPath = $server.PsPath + "\EndPoints"

        $EndPointList = @()

        
        $AllEndPoints = dir $PSPath
        foreach($endpoint in $AllEndPoints)
        {
                $EndPointList += $endpoint.Protocol.Tcp
        }

        $EndPointList;
}

# Get Next available port
function GetNextAvailableTCPPort
{
        Param([string]$serverInstance)
        
        $measure = GetEndPointList $serverInstance | measure-object ListenerPort -max

        if($measure.Maximum -eq $null)
        {
                $maxPort = 5000
        }
        else
        {
                $maxPort = $measure.Maximum
        }

        #choose a random port that is greater than the current max port
        $maxPort + (new-object random).Next(1,500)
}


# Get Server object
function GetServer
{
        Param([string]$serverInstance)

       $array = $serverInstance.Split("\")

       if([String]::IsNullOrEmpty($serverInstance))
       {
                write-error "Server instance  name is not valid"
                return
       }

       if($array.Length -eq 1)
       {
                $machineName = $array[0]
                $instanceName = "DEFAULT"
       }
       else
       {
                $machineName = $array[0]
                $instanceName = $array[1]
       }

       $PSPath = "\SQL\" + $machineName + "\" + $instanceName


       $server = get-item $PSPath

       CheckForErrors
       $server;
}

# Set Recovery Model for given database
function SetRecoveryModel
{
        Param($serverInstance, $dbName, [Microsoft.SqlServer.Management.Smo.RecoveryModel]$recoveryModel)
        
        write-host "Setting", $recoveryModel, "Recovery model for database:", $dbName
        $server = GetServer($serverInstance)

        $PSPath = $server.PsPath + "\Databases\"  + $dbName

        $db = get-item $PSPath
        $db.RecoveryModel = $recoveryModel
        $db.Alter()
        
        write-host "[SetRecoveryModel:] OK"
        CheckForErrors
}


# Set Partner, Witness
function SetMirroringPartner
{
        Param($serverInstance, $dbName, $fqName, [bool]$isPartner)
        $server = GetServer($serverInstance)

        $PSPath = $server.PsPath + "\Databases\"  + $dbName
        
        $db = get-item $PSPath
        
        if($isPartner -eq $True)
        {
                $db.MirroringPartner = $fqName
        }
        else
        {
                $db.MirroringWitness = $fqName
        }
        
        $db.Alter()
}

# Reports Errors
function CheckForErrors
{
        $errorsReported = $False
        if($Error.Count -ne 0)
        {
                write-host "******************************"
                write-host "Errors:", $Error.Count
                write-host "******************************"
                foreach($err in $Error)
                {
                        $errorsReported  = $True
                        if( $err.Exception.InnerException -ne $null)
                        {
                                write-host $err.Exception.InnerException.ToString()
                        }
                        else
                        {
                                write-host $err.Exception.ToString()
                        }
                                
                        write-host "----------------------------------------------"
                }
                
                throw
        }
        
}

# Perform initial validation checks to make sure that all input parameters are valid
function PerformValidation
{
        Param($primary , $mirror, $witness, $shareName, $dbName)
        #Clear any errors
        $Error.Clear()
        
        write-host "Performing Validation checks..."
        
        $primaryServer = GetServer $primary

        $PSPath = $primaryServer.PsPath + "\Databases\"  + $dbName
       
        $primaryDatabase = get-item $PSPath

        write-host "Checking if Database:$dbName on Primary:$primary is not mirrored..."
        if($primaryDatabase.MirroringStatus -ne [Microsoft.SqlServer.Management.Smo.MirroringStatus]::None)
        {
                $errorMessage = "Cannot setup mirroring on database due to its current MirroringState:" + $primaryDatabase.MirroringStatus
                throw $errorMessage
        }
       
        write-host "[$dbName on Primary:$primary is not mirrored Check:] OK"
        
        if($primaryDatabase.Status -ne [Microsoft.SqlServer.Management.Smo.DatabaseStatus]::Normal)
        {
                $errorMessage = "Cannot setup mirroring on database due to its current Status:" + $primaryDatabase.Status
                throw $errorMessage
        }
        
        write-host "Checking if Database:$dbName does not exist on  Mirror:$mirror..."
        $mirrorServer = GetServer $mirror
        $PSPath = $mirrorServer.PsPath + "\Databases\"
        
        $mirrorDatabase= get-childitem $PSPath | where {$_.Name -eq $dbName}  
        
        if($mirrorDatabase -ne $null)
        {
                $dbMeasures = $mirrorDatabase | measure-object
                if($dbMeasures.Count -ne 0)
                {
                        $errorMessage = "Database:" + $dbName + " already exists on mirror server:" + $mirror
                        throw $errorMessage
                }
        }
       
        write-host "[$dbName does not exist on Mirror:$mirror Check:] OK"
        
        write-host "Checking if Witness Server exists..."
        $witnessServer = GetServer $witness
        write-host "[Witness Server Existence Check:] OK"
       
        write-host "Checking if File Share:$ShareName exists..."
        if([System.IO.Directory]::Exists($shareName) -ne $True)
        {
                $errorMessage = "Share:" + $shareName + " does not exists"
                throw $errorMessage
        }
        
        write-host "[File Share Existence Check:] OK"
       
       
        CheckForErrors
}

# Configure Database mirroring; if input params are not passed into this function,
# those values are read from user entered text from console
function ConfigureDatabaseMirroring
{
        Param([string]$primary = $(Read-Host "Primary SQL Instance(like server\instance)") ,
                [string]$mirror = $(Read-Host "Mirror SQL Instance(like server\instance)") ,
                [string]$witness = $(Read-Host "Witness SQL Instance(like server\instance)") ,
                [string]$shareName = $(Read-Host "Share Path(unc path like \\server\share)") ,
                [string]$dbName = $(Read-Host "Database Name")
                )
        
        write-host
        write-host "============================================================="
        write-host " 1: Performing Initial checks; validating input parameters"
        write-host "============================================================="
        PerformValidation $primary $mirror $witness  $shareName $dbName
        
        write-host
        write-host "============================================================="
        write-host " 2: Set Recovery Model as FULL on primary database"
        write-host "============================================================="
        $fullRecoveryModelType = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Full
        SetRecoveryModel $primary $dbName $fullRecoveryModelType

        write-host
        write-host "============================================================="
        write-host " 3: Perform Full Database backup from Primary instance"
        write-host "============================================================="
        $backupActionType = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database
        $primaryBackupDataFile = BackupDatabase $primary $dbName $shareName $backupActionType

        write-host
        write-host "============================================================="
        write-host " 4: Restore Database backup on Mirror"
        write-host "============================================================="
        RestoreDatabase $mirror $dbName $primaryBackupDataFile

        write-host
        write-host "============================================================="
        write-host " 5: Create endpoints for database mirroring"
        write-host "============================================================="

        $mirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::Partner
        $primaryFQName = GetFullyQualifiedMirroringEndpoint $primary $mirroringRole

        $mirrorFQName = GetFullyQualifiedMirroringEndpoint $mirror $mirroringRole

        $mirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::Witness
        $witnessFQName = GetFullyQualifiedMirroringEndpoint $witness $mirroringRole

        write-host
        write-host "============================================================="
        write-host "  6: Set Primary, Mirror, Witness states in database"
        write-host "============================================================="
        write-host "Connecting to Mirror and set Primary as partner ..."
        SetMirroringPartner $mirror $dbName $primaryFQName $True

        write-host "Connecting to Primary, set partner as mirror ..."
        SetMirroringPartner $primary $dbName $mirrorFQName   $True
       
        write-host "Connecting to Primary, set partner as witness ..."
        SetMirroringPartner $primary $dbName $witnessFQName   $False
        
        write-host
        write-host "============================================================="
        write-host "  Database:$dbName mirrored successfully."
        write-host "============================================================="
}

################################################
# Configure Database mirroring
################################################
ConfigureDatabaseMirroring