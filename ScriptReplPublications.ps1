param ($sqlServer,$path,[switch]$scriptPerPublication)
Import-Module Repl
 
if ($sqlServer -eq "")
{
    $sqlserver = Read-Host -Prompt "Please provide a value for -sqlServer"
}
 
if ($path -eq "")
{
    $path = Read-Host -Prompt "Please provide a value for output directory path"
}
 
    $scriptOptions = New-ReplScriptOptions
    $scriptOptions.IncludeArticles = $true
    $scriptOptions.IncludePublisherSideSubscriptions = $true
    $scriptOptions.IncludeCreateSnapshotAgent = $true
    $scriptOptions.IncludeGo = $true
    $scriptOptions.EnableReplicationDB = $true
    $scriptOptions.IncludePublicationAccesses = $true
    $scriptOptions.IncludeCreateLogreaderAgent = $true
    $scriptOptions.IncludeCreateQueuereaderAgent = $true
    $scriptOptions.IncludeSubscriberSideSubscriptions = $true

    $distributor = Get-ReplServer $sqlserver
 
if($distributor.DistributionServer -eq $distributor.SqlServerName)
{
	$distributor.DistributionPublishers | ForEach-Object {
		$distributionPublisher = $_
		if($distributionPublisher.PublisherType -eq "MSSQLSERVER")
		{
			$outPath =  "{0}\from_{1}\{2}\"  -f $path,$distributionPublisher.Name.Replace("\","_"),$((Get-Date).toString('yyyy-MMM-dd_HHmmss'))
			New-Item $outPath -ItemType Directory | Out-Null
			Get-ReplPublication $distributionPublisher.Name | ForEach-Object {
				$publication = $_
				$fileName = "{0}{1}.sql" -f $outPath,$publication.DatabaseName.Replace(" ", "")
				if($scriptPerPublication)
				{
					$fileName = "{0}{1}_{2}.sql" -f $outPath,$publication.DatabaseName.Replace(" ", ""),$publication.Name.Replace(" ", "")
				}
				Write-Debug $("Scripting {0} to {1}" -f $publication.Name.Replace(" ", ""),$fileName)
				Get-ReplScript -rmo $publication -scriptOpts $($scriptOptions.ScriptOptions) | Out-File $fileName -Append
			}
		}
	}
}
else
{
    $outPath =  "{0}\from_{1}\{2}\"  -f $path,$distributor.SqlServerName.Replace("\","_"),$((Get-Date).toString('yyyy-MMM-dd_HHmmss'))
    New-Item $outpath -ItemType Directory | Out-Null
    Get-ReplPublication $distributor.SqlServerName | ForEach-Object {
		$publication = $_
		$fileName = "{0}{1}.sql" -f $outPath,$publication.DatabaseName.Replace(" ", "")
		if($scriptPerPublication)
		{
			$fileName = "{0}{1}_{2}.sql" -f $outPath,$publication.DatabaseName.Replace(" ", ""),$publication.Name.Replace(" ", "")
		}
		Write-Debug $("Scripting {0} to {1}" -f $publication.Name.Replace(" ", ""),$fileName)
		Get-ReplScript -rmo $publication -scriptOpts $($scriptOptions.ScriptOptions) | Out-File $fileName -Append
	}
}