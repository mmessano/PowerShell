#Load command-line parameters - if they exist
param ([string]$sqlserver, [string]$filename)

#Reference RMO Assembly
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication") | out-null
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Rmo") | out-null

$TableQuery = "SELECT DISTINCT Server
	FROM SQLDatabases
	WHERE DatabaseName LIKE '%distribution%'
	ORDER BY 1"

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

function errorhandler([string]$errormsg)
{
    writetofile ("Replication Script Generator run at: " + (date)) $filename 1
    writetofile ("[Replication Script ERROR] " + $errormsg) $filename 0
    write-host("[Replication Script ERROR] " + $errormsg) -Foregroundcolor Red
}

function writetofile([string]$text, [string]$myfilename, [int]$cr_prefix)
{
    if ($cr_prefix -eq 1) { "" >> $myfilename }
    $text >> $myfilename
}

function initializefile([string]$myfilename)
{
    "" > $myfilename
}

trap {errorhandler($_); Break}

$Servers = Run-Query -SqlQuery $TableQuery | Select-Object -Property Server

Clear-host

foreach($server in $Servers)
{


	$filename = "E:\Dexma\Logs\ReplicationBackupScript_" + $($server.server) + ".txt"
	initializefile $filename
	
	$repsvr = New-Object "Microsoft.SqlServer.Replication.ReplicationServer" $($server.server)

	# if we don't have any replicated databases then there's no point in carrying on
	if ($repsvr.ReplicationDatabases.Count -eq 0)
	{
	    writetofile ("Replication Script Generator run at: " + (date)) $filename 0
	    writetofile "ZERO replicated databases on $($server.server)!!!" $filename 1
	}

	# similarly, if we don't have any publications then there's no point in carrying on
	[int] $Count_Tran_Pub = 0
	[int] $Count_Merge_Pub = 0

	foreach($replicateddatabase in $repsvr.ReplicationDatabases)
	{
	        $Count_Tran_Pub = $Count_Tran_Pub + $replicateddatabase.TransPublications.Count
	        $Count_Merge_Pub = $Count_Merge_Pub + $replicateddatabase.MergePublications.Count
	}

	if (($Count_Tran_Pub + $Count_Merge_Pub) -eq 0)
	{
	    writetofile ("Replication Script Generator run at: " + (date)) $filename 0
	    writetofile "ZERO Publications on $($server.server)!!!" $filename 1
	}

	# if we got this far we know that there are some publications so we'll script them out
	# the $scriptargs controls exactly what the script contains
	# for a full list of the $scriptargs see the end of this script
	$scriptargs = [Microsoft.SqlServer.Replication.scriptoptions]::Creation `
	-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeArticles `
	-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludePublisherSideSubscriptions `
	-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeSubscriberSideSubscriptions

	writetofile ("Replication Script Generator run at: " + (date)) $filename 0
	writetofile " PUBLICATIONS ON $($server.server)" $filename 1
	writetofile " TRANSACTIONAL PUBLICATIONS ($Count_Tran_Pub)" $filename 1

	foreach($replicateddatabase in $repsvr.ReplicationDatabases)
	{
	    if ($replicateddatabase.TransPublications.Count -gt 0)
	    {
	        foreach($tranpub in $replicateddatabase.TransPublications)
	        {
	            write-host "********************************************************************************" -Foregroundcolor Blue
	            "***** Writing to file script for publication: " + $tranpub.Name
	            write-host "********************************************************************************" -Foregroundcolor Blue
	            writetofile "********************************************************************************" $filename 0
	            writetofile ("***** Writing to file script for publication: " + $tranpub.Name) $filename 0
	            writetofile "********************************************************************************" $filename 0
	            [string] $myscript=$tranpub.script($scriptargs) 
	            writetofile $myscript $filename 0
	        }
	    }
	}

	writetofile " MERGE PUBLICATIONS ($Count_Merge_Pub)" $filename 1
	writetofile "" $filename 0

	foreach($replicateddatabase in $repsvr.ReplicationDatabases)
	{
	    if ($replicateddatabase.MergePublications.Count -gt 0)
	    {
	        foreach($mergepub in $replicateddatabase.MergePublications)
	        {
	            write-host "********************************************************************************" -Foregroundcolor Blue
	            "***** Writing to file script for publication: " + $mergepub.Name
	            write-host "********************************************************************************" -Foregroundcolor Blue
	            writetofile "********************************************************************************" $filename 0
	            writetofile ("***** Writing to file script for publication: " + $mergepub.Name) $filename 0
	            writetofile "********************************************************************************" $filename 0
	            [string] $myscript=$mergepub.script($scriptargs) 
	            writetofile $myscript $filename 0
	        }
	    }
	}
}
#Creation Specifies that the generated script is for creating replication objects.
#Deletion Specifies that the script is for deleting a replication object.
#DisableReplicationDB Specifies that the script is a deletion script that disables publishing on a database and removes any agent jobs needed for publishing.
#EnableReplicationDB Specifies that the script is a creation script that enables publishing on a database and creates any agent jobs needed for publishing.
#IncludeAgentProfiles Specifies that the script includes all user-defined replication agent profiles defined on the Distributor.
#IncludeAll Specifies that the script includes all possible replication objects that can exist, which is equivalent to setting all values of ScriptOptions.
#IncludeArticles Specifies that the script includes articles.
#IncludeChangeDestinationDataTypes Specifies that the script includes any user-defined data type mappings. This option is only supported for non-SQL Server Publishers when the IncludeArticles option is enabled. This option is only supported on SQL Server 2005 and later versions.
#IncludeCreateDistributionAgent Specifies that the script includes Distribution Agent jobs.
#IncludeCreateLogreaderAgent Specifies that the script includes Log Reader Agent jobs.
#IncludeCreateMergeAgent Specifies that the script includes Merge Agent jobs.
#IncludeCreateQueuereaderAgent Specifies that the script includes Queue Reader Agent jobs.
#IncludeCreateSnapshotAgent Specifies that the script includes Snapshot Agent jobs.
#IncludeDisableReplicationDB Specifies that the script disables publishing on a database and removes any agent jobs needed for publishing.
#IncludeDistributionPublishers Specifies that the script includes Publishers.
#IncludeEnableReplicationDB Specifies that the script enables publishing on a database and creates any agent jobs needed for publishing.
#IncludeGo Specifies that the script includes the GO command at the end of a batch.
#IncludeInstallDistributor Specifies that the script installs publishing objects at the Distributor.
#IncludeMergeDynamicSnapshotJobs Specifies that the script includes the definition of any existing partitioned snapshot jobs for merge publications with parameterized row filters. This option is only supported for Microsoft SQL Server 2000 and later versions.
#IncludeMergeJoinFilters Specifies that the script includes the definition of all join filters defined for a merge publication.
#IncludeMergePartitions Specifies that the script includes the definition of any existing partitions for merge publications with parameterized row filters. This option is supported for Microsoft SQL Server 2005 and later versions.
#IncludeMergePublicationActivation Specifies that the script includes setting the status of a merge publication to active. This option is supported for SQL Server 2005 and later versions.
#IncludePartialSubscriptions Specifies that the script includes subscriptions to transactional publications that do not subscribe to all articles in the publication.
#IncludePublicationAccesses Specifies that the script includes all logins added to the publication access list (PAL). This option is only supported for publication creation scripts. Deleting a publication automatically removes the PAL.
#IncludePublications Specifies that the script includes publications.
#IncludePublisherSideSubscriptions Specifies that the script includes the registration of all subscriptions at the Publisher.
#IncludePullSubscriptions Specifies that the script includes all pull subscriptions.
#IncludeRegisteredSubscribers Specifies that the script includes the registration of all Subscribers at the Publisher.
#IncludeReplicationJobs Specifies that the script includes the definition of all SQL Server Agent jobs created by replication. This option is supported for SQL Server 2005 and later versions.
#IncludeSubscriberSideSubscriptions
#IncludeUninstallDistributor Specifies that the script uninstalls publishing objects at the Distributor.
#InstallDistributor Specifies a creation script that installs publishing objects at the Distributor.
#None Clears all scripting options.
#UninstallDistributor Specifies a deletion script that uninstalls publishing objects at the Distributor. 