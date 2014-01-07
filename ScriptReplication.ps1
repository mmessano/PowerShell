# ScriptReplication.ps1
cls

function Backup-SMCReplication
{
    param ([string ] $sqlServer
			, [string] $outputDirectory
			)
   
    Import-Module Repl
   
    [string] $path =  "$outputDirectory\$((get-date).toString('yyyy-MMM-dd'))\"
	if ( -not (test-path $path)) {
    	New-Item $path -ItemType Directory | Out-Null
	}
   
    foreach($publication in Get-ReplPublication $sqlServer)
    {
        [string] $fileName = "{0}{1}.sql" -f $path,$publication.DatabaseName.Replace(" ", "")
		
        $fileName = "{0}Create_{1}_{2}.sql" -f $path,$publication.DatabaseName.Replace(" ", ""),$publication.Name.Replace(" ", "")
		
        $publication.Script([Microsoft.SqlServer.Replication.scriptoptions]::Creation `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::EnableReplicationDB `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeCreateLogreaderAgent `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeCreateQueuereaderAgent `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludePublicationAccesses `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeCreateSnapshotAgent `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeArticles `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludePublisherSideSubscriptions `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeSubscriberSideSubscriptions
			) | Out-File $fileName
    }
}


function Delete-SMCReplication()
{
    param ([string ] $sqlServer
			, [string] $outputDirectory
			)
   
    Import-Module Repl
   
    [string] $path =  "$outputDirectory\$((get-date).toString('yyyy-MMM-dd'))\"
	if ( -not (test-path $path)) {
    	New-Item $path -ItemType Directory | Out-Null
	}
	
    foreach($publication in Get-ReplPublication $sqlServer)
    {
        [string] $fileName = "{0}{1}.sql" -f $path,$publication.DatabaseName.Replace(" ", "")
		
        $fileName = "{0}Delete_{1}_{2}.sql" -f $path,$publication.DatabaseName.Replace(" ", ""),$publication.Name.Replace(" ", "")

        $publication.Script([Microsoft.SqlServer.Replication.scriptoptions]::Deletion `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeDisableReplicationDB `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludePublisherSideSubscriptions `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeSubscriberSideSubscriptions `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeArticles `
			-bor  [Microsoft.SqlServer.Replication.scriptoptions]::IncludeReplicationJobs
			) | Out-File $fileName
    }
}



Backup-SMCReplication -sqlServer PSQLDLS30 -outputDirectory e:\Dexma\logs
Delete-SMCReplication -sqlServer PSQLDLS30 -outputDirectory e:\Dexma\logs
