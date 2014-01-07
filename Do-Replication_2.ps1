#Modified Invoke SQL script with much longer time outs
function invoke-sql
{

  param(
    [Parameter(Mandatory = $True)]
    [string]$Query,
    [Parameter(Mandatory = $True)]
    [string]$DBName,
    [Parameter(Mandatory = $True)]
    [string]$DBServerName
  )

  #These could be changed
  $QueryTimeout = 36000 #10 hours
  $ConnectionTimeout = 36000 #10 hours

  #Action of connecting to the DB and executing the query and returning results if there was any.
  $conn = New-Object System.Data.SqlClient.SQLConnection
  $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $DBServerName,$DBName,$ConnectionTimeout
  $conn.ConnectionString = $ConnectionString
  $conn.Open()
  $cmd = New-Object system.Data.SqlClient.SqlCommand ($Query,$conn)
  $cmd.CommandTimeout = $QueryTimeout
  $ds = New-Object system.Data.DataSet
  $da = New-Object system.Data.SqlClient.SqlDataAdapter ($cmd)
  [void]$da.fill($ds)
  $conn.Close()
  $results = $ds.Tables[0]

  $results
}

function SQL-Query {
  param([string]$Query,
    [string]$SqlServer = $DEFAULT_SQL_SERVER,
    [string]$DB = $DEFAULT_SQL_DB,
    [string]$RecordSeparator = "`t")

  $conn_options = ("Data Source=$SqlServer; Initial Catalog=$DB;" + "Integrated Security=SSPI")
  $conn = New-Object System.Data.SqlClient.SqlConnection ($conn_options)
  $conn.Open()

  $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
  $sqlCmd.CommandTimeout = "300"
  $sqlCmd.CommandText = $Query
  $sqlCmd.Connection = $conn

  $reader = $sqlCmd.ExecuteReader()
  if (-not $?) { #error logging
    $lineno = Get-CurrentLineNumber
    ./logerror.ps1 $Output $date $lineno $title
  }
  [array]$serverArray
  $arrayCount = 0
  while ($reader.Read()) {
    $serverArray +=,($reader.GetValue(0))
    $arrayCount++
  }
  $serverArray
}

[string]$SMCIndexesScript = "\\xfs3\DataManagement\Scripts\Move_DB\PowershellScripts\SQL\SMCIndexes.sql";
#[string]$SMCIndexesScript 		= "\\xfs3\Release\Prime Alliance\SMC\LatestVersion\DatabaseScripts\Other\Indexes.sql";
[string]$SMCTriggersScript = "\\xfs3\Release\Prime Alliance\SMC\LatestVersion\DatabaseScripts\Other\Triggers.sql";
[string]$SMCViewsScript = "\\xfs3\Release\Prime Alliance\SMC\LatestVersion\DatabaseScripts\Other\Views.sql";
[string]$SMCImportLoansScript = "\\xfs3\Release\Prime Alliance\SMC\LatestVersion\DatabaseScripts\Other\ImportLoans.sql";

#$CSharpFunctions = '\\xfs3\DataManagement\Scripts\Move_DB\PowershellScripts\PowershellCSharpReplicationFunctions.cs'
#$ReplFunctions = [System.IO.File]::ReadAllText($CSharpFunctions)
#Add-Type -TypeDefinition $ReplFunctions -Language CSharp

function Apply-SMCScripts {
  param(
    [Parameter(Mandatory = $True)]
    [string]$DBServerName,
    [Parameter(Mandatory = $True)]
    [string]$DBName
  )
  Invoke-SQLCMD -ServerInstance $DBServerName -database $DBName -InputFile $SMCIndexesScript -QueryTimeout 120
  #Invoke-SQLCMD -ServerInstance $DBServerName -Database $DBName -InputFile $SMCIndexesScript -QueryTimeout 120
  Invoke-SQLCMD -ServerInstance $DBServerName -database $DBName -InputFile $SMCTriggersScript -QueryTimeout 120
  Invoke-SQLCMD -ServerInstance $DBServerName -database $DBName -InputFile $SMCViewsScript -QueryTimeout 120
  Invoke-SQLCMD -ServerInstance $DBServerName -database $DBName -InputFile $SMCImportLoansScript -QueryTimeout 120
}

function DO-Replication
{

  <#
.SYNOPSIS
Initiate Merge Replication Sync
.DESCRIPTION
This Function kicks of a Transactional Replication Synchronization
.EXAMPLE
Give an example of how to use it

.PARAMETER subscriber
The SQL Instance Name name of the Publication, EG localhost

.PARAMETER spublisher
The SQL Instance Name name of the Publisher, eg MyPublisher

.PARAMETER publication
The name of the publication

.PARAMETER subscriptionDatabase
The name of the Subscriber Database

.PARAMETER publicationDatabase
The name of the publisher database

.PARAMETER forceReInit
$true to force a ReInitialization of the subscription, $false otherwise

.PARAMETER verboseLevel
Logging verbosity level

.PARAMETER retries
Number of times to retry the sync in case of a failure

#>

  param
  (
    [string][Parameter(Mandatory = $true,Position = 0)] $subscriber,
    [string][Parameter(Mandatory = $true,Position = 1)] $publisher,
    [string][Parameter(Mandatory = $true,Position = 2)] $publication,
    [string][Parameter(Mandatory = $true,Position = 3)] $subscriptionDatabase,
    [string][Parameter(Mandatory = $true,Position = 4)] $publicationDatabase,
    [boolean][Parameter(Mandatory = $true,Position = 5)] $forceReInit,
    [int32][Parameter(Mandatory = $true,Position = 6)] $verboseLevel,
    [int32][Parameter(Mandatory = $true,Position = 7)] $retries
  )

  "Subscriber: $subscriber";
  "Publisher: $publisher";
  "Publication: $publication";
  "Publication Database: $publicationDatabase";
  "Subscription Database: $subscriptionDatabase";
  "ForceReInit: $forceReinit";
  "VerboseLevel: $verboseLevel";
  "Retries: $retries";

  for ($counter = 1; $counter -le $retries; $counter++)
  {

    #"Subscriber $subscriber";

    $serverConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection $publisher;

    try
    {

      $transSubscription = New-Object Microsoft.SqlServer.Replication.TransSubscription
      $transSubscription.ConnectionContext = $serverConnection;
      $transSubscription.DatabaseName = $publicationDatabase;
      $transSubscription.PublicationName = $publication;
      $transSubscription.SubscriptionDBName = $subscriptionDatabase;
      $transSubscription.SubscriberName = $subscriber;

      if ($true -ne $transSubscription.LoadProperties())
      {
        throw New-Object System.ApplicationException "A subscription to [$publication] does not exist on [$subscriber]"
      }
      else
      {
        $ReplJob = SQL-Query -Query "select name from sysjobs where category_id = 15 and name like '%$($publicationDatabase)%' " -sqlserver $Publisher -DB "msdb"
        SQL-Query -Query "exec sp_start_job '$($ReplJob)'" -sqlserver $publisher -DB "msdb"
      }


      if ($null -eq $transSubscription.SubscriberSecurity)
      {
        throw New-Object System.ApplicationException "There is insufficent metadata to synchronize the subscription. Recreate the subscription with the agent job or supply the required agent properties at run time.";
      }


      if ($forceReInit -eq $true)
      {
        $transSubscription.Reinitialize();
      }

      $transSubscription.SynchronizationAgent.CommitPropertyChanges;
      $transSubscription.SynchronizationAgent.Synchronize;

      "Sync Complete";
      return;



    } catch [exception]
    {
      if ($counter -lt $retries)
      {
        $_.Exception.Message + ": " + $_.Exception.InnerException
        "Retry $counter";
        continue;
      }
      else
      {
        $Error[0] | Out-String
        return $_.Exception.Message + ": " + $_.Exception.InnerException
      }

    }
  }
}

cls

#DO-Replication -Subscriber "STGSQLLFC6" -publisher "STGSQLLFC6" -publication "RLCSMC" -subscriptionDatabase "RLCSMC" -publicationDatabase "RLC" -forceReInit $True -verboselevel 1 -retries 1
Apply-SMCScripts -DBServerName "STGSQLLFC6" -dbname "RLCSMC"


# wave2
##DO-Replication -Subscriber "PSQLSMC1" -publisher "PSQLLFC2" -publication "ArizonaStateCUSMC" -subscriptionDatabase "ArizonaStateCUSMC" -publicationDatabase "ArizonaStateCU" -forceReInit $True -verboselevel 1 -retries 1
##DO-Replication -Subscriber "PSQLSMC1" -publisher "PSQLLFC2" -publication "TowerSMC" -subscriptionDatabase "Tower32SMC" -publicationDatabase "Tower32" -forceReInit $True -verboselevel 1 -retries 1
##DO-Replication -Subscriber "PSQLSMC1" -publisher "PSQLLFC2" -publication "WrightPattSMC" -subscriptionDatabase "WrightPattSMC" -publicationDatabase "WrightPatt32" -forceReInit $True -verboselevel 1 -retries 1
##DO-Replication -Subscriber "PSQLSMC1" -publisher "PSQLLFC6" -publication "SummitCUSMC" -subscriptionDatabase "SummitCUSMC" -publicationDatabase "SummitCU" -forceReInit $True -verboselevel 1 -retries 1

##Apply-SMCScripts -DBServerName "PSQLSMC1" -DBName "ArizonaStateCUSMC"
##Apply-SMCScripts -DBServerName "PSQLSMC1" -DBName "Tower32SMC"
##Apply-SMCScripts -DBServerName "PSQLSMC1" -DBName "WrightPattSMC"
##Apply-SMCScripts -DBServerName "PSQLSMC1" -DBName "SummitCUSMC"
