# retrieve list of SQL servers from the network
[void][reflection.assembly]::LoadWithPartialName( "Microsoft.SqlServer.Smo" );
$smoApp = [Microsoft.SqlServer.Management.Smo.SmoApplication];
$smoApp::EnumAvailableSqlServers($false);

# find all SQL servers on the network
$SQL = [System.Data.Sql.SqlDataSourceEnumerator]::Instance.GetDataSources() | `
foreach {
"INSERT INTO dbo.FoundSQLServers VALUES ('$($_.ServerName)', '$($_.InstanceName)', '$($_.IsClustered)', '$($_.Version)')" `
>> C:\Dexma\Logs\INSERTFoundSQLServers.sql
        };