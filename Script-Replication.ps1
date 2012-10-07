[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServr.Rmo")

$servername = "STGSQL610"
$repserver = New-Object "Microsoft.SqlServer.Replication.ReplicationServer"
$srv = New-Object "Microsoft.SqlServer.Management.Common.ServerConnection" $servername
$srv.connect()
$repserver.ConnectionContext = $srv

$databasename = "Boeing4"
$repdb = $repserver.ReplicationDatabases[$databasename]

$repdb.transpublications

$publication_name = "BoeingSMC"
$publication_object = $repdb.transpublications[$publication_name]

$publication_object.TransArticles

$publication_object.TransSubscriptions

$script_val = [Microsoft.SqlServer.Replication.ScriptOptions]::Creation -bxor [Microsoft.SqlServer.Replication.ScriptOptions]::IncludeGo

$publication_object.Script($script_val)

Foreach ($article in $publication_object.TransArticles) {
	$article.Script($script_val)
	}
	
Foreach ($subscription in $publication_object.TransSubscriptions)	 {
	$subscription.Script($script_val)
	}