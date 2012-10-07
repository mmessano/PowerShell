param( 
	$Subscribers = @('PSQLSMC30', 'PSQLCBS30', 'STGSQL610', 'ISQLDEV610', 'QSQL610'
					'PSQLDLS30', 'PSQLDLS31', 'PSQLDLS32', 'PSQLDLS33', 'PSQLDLS34', 'PSQLDLS35', 'PSQLSVC21')
	)

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServr.Rmo")

# SQL query
$DBQuery = "DECLARE @Subs table (
	publisher			sysname not null,
	publisher_db		sysname not null,
	publication			sysname null,
	replication_type	int not NULL,
	subscription_type	int not NULL,
	last_updated		datetime null,
	subscriber_db		sysname not null,
	update_mode			smallint null,
	last_sync_status	int null,
	last_sync_summary	sysname null,
	last_sync_time		datetime null
	)

INSERT INTO @Subs							
exec sp_MSenumallsubscriptions

SELECT Publisher, Publisher_DB, Publication, Subscriber_DB FROM @Subs
order by 2"

# functions
function Run-Query()
{
	param (
	$SqlQuery,
	$SqlServer,
	$SqlCatalog
	)
	
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$SqlServer;Integrated Security=SSPI;Initial Catalog=$SqlCatalog;");
	
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

function write-log([string]$info)
{
    if($loginitialized -eq $false)
	{
        $FileHeader > $logfile
		$script:loginitialized = $True            
    }            
    $info >> $logfile            
}

foreach ($Subscriber IN $Subscribers) {
	write $Subscriber
	# retrieve the publications from the subscriber(s)
	# this is easier than maintaining a list of servers that replicate
	$databases = Run-Query -SqlQuery $DBQuery -SqlServer $Subscriber | Select-Object -Property Publisher, Publisher_DB, Publication, Subscriber_DB | Sort-Object -Property Publisher_DB, Publication

	if (!$databases) {
		continue;
		}
	
	foreach ($db IN $databases ) {
	
		# set up a per-publication log
		<#---------Logfile Info----------#>            
		#$script:logfile = "C:\Dexma\Logs\$($db.Publisher)-$($db.Publisher_DB)-$($db.Publication)-$(get-date -format MMddyy).sql"
		$script:logfile = "C:\Dexma\Logs\$($db.Publisher)-$($db.Publisher_DB)-$($db.Publication).sql"
		$script:loginitialized = $false            
		$script:FileHeader = 
		"-- Publisher:`t`t$($db.Publisher)`r-- PublishedDB:`t`t$($db.Publisher_DB)`r-- Publication:`t`t$($db.Publication)`r-- SubscriberDB:`t$($db.Subscriber_DB)`r"

		#write-log "$($db.Publisher), $($db.Publisher_DB), $($db.Publication), $($db.Subscriber_DB)"

		$repserver = 	New-Object "Microsoft.SqlServer.Replication.ReplicationServer"
		$srv = 			New-Object "Microsoft.SqlServer.Management.Common.ServerConnection" $($db.Publisher)
		$srv.connect()
		$repserver.ConnectionContext = $srv

		$repdb = 		$repserver.ReplicationDatabases[$($db.Publisher_DB)]

		$publication_object = $repdb.transpublications[$($db.Publication)]

		$script_val = 	[Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bxor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo
		write-log $publication_object.Script($script_val)
		
		Foreach ($article in $publication_object.TransArticles) {
			write-log $article.Script($script_val)
		}
		
		write-log "---------------------------------------------------------------------------"
		write-log "-- subscription creation"
		write-log "---------------------------------------------------------------------------"
		
		Foreach ($subscription in $publication_object.TransSubscriptions)	 {
			write-log $subscription.Script($script_val)
		}
	}
}
# output to console
#$databases
