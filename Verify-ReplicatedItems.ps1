# Verify-ReplicatedItems.ps1
# mmessano
# 5/27/2011

# static variables
$StatusServer = 'XSQLUTIL18'
$StatusDB = 'Status'
$ENV = $args[0]
################################################################################

# servers 
switch ($ENV) {        ##Serverlists broken out according to server type and environment as defined in t_server tables
    "PROD"      { $serverlist = "\\xmonitor11\dexma\data\serverlists\SMC_PROD.txt" }
     
    "STAGE"     { $serverlist = "\\xmonitor11\dexma\data\serverlists\SMC_DEMO.txt" }
						
	"IMP"       { $serverlist = "\\xmonitor11\dexma\data\serverlists\SMC_IMP.txt" }
                
    "QA"        { $serverlist = "\\xmonitor11\dexma\data\serverlists\SMC_QA.txt" }
}
$serverlist
################################################################################

# Queries
$ServerQuery = 
"SELECT Server FROM SQLDatabases
WHERE DatabaseName LIKE 'distribution'
AND Filename LIKE '%.MDF'
AND Server NOT LIKE '%PSQLSVC21%' -- not an SMC replication server
ORDER BY 1"

$ReplItemsQuery = 
"DECLARE @ReplItems TABLE (
	[ServerName] [varchar](64) NOT NULL,
	[Databasename] [varchar](128) NOT NULL,
	[addl_loan_data] [int] NULL,
	[appraisal] [int] NULL,
	[borrower] [int] NULL,
	[br_address] [int] NULL,
	[br_expense] [int] NULL,
	[br_income] [int] NULL,
	[br_liability] [int] NULL,
	[br_REO] [int] NULL,
	[channels] [int] NULL,
	[codes] [int] NULL,
	[customer_elements] [int] NULL,
	[funding] [int] NULL,
	[inst_channel_assoc] [int] NULL,
	[institution] [int] NULL,
	[institution_association] [int] NULL,
	[loan_appl] [int] NULL,
	[loan_fees] [int] NULL,
	[loan_price_history] [int] NULL,
	[loan_prod] [int] NULL,
	[loan_regulatory] [int] NULL,
	[loan_status] [int] NULL,
	[product] [int] NULL,
	[product_channel_assoc] [int] NULL,
	[property] [int] NULL,
	[servicing] [int] NULL,
	[shipping] [int] NULL,
	[underwriting] [int] NULL
)
	
INSERT INTO @ReplItems
EXEC sp_MSForEachDB'
USE ?	
SELECT ServerName AS ServerName
		, DB_NAME() AS DBName
		, addl_loan_data, appraisal, borrower
		, br_address, br_expense, br_income
		, br_liability, br_REO, channels
		, codes, customer_elements, funding
		, inst_channel_assoc, institution, institution_association
		, loan_appl, loan_fees, loan_price_history
		, loan_prod, loan_regulatory, loan_status
		, product, product_channel_assoc, property
		, servicing, shipping, underwriting
FROM
(SELECT	DISTINCT
		@@SERVERNAME AS ServerName
		, DB_NAME() AS DBName
		, t.name AS TableName
		, COUNT(c.name) AS ColumnNum
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.types ty ON c.system_type_id = ty.system_type_id
where t.is_published = 1 
	or t.is_merge_published = 1
	or t.is_schema_published = 1
GROUP BY t.name
--ORDER BY 2,3
) AS SourceTable
PIVOT
(SUM(ColumnNum)
FOR TableName IN (addl_loan_data
		, appraisal, borrower, br_address
		, br_expense, br_income, br_liability
		, br_REO, channels, codes
		, customer_elements, funding, inst_channel_assoc
		, institution, institution_association, loan_appl
		, loan_fees, loan_price_history, loan_prod
		, loan_regulatory, loan_status, product
		, product_channel_assoc, property, servicing
		, shipping, underwriting)
) AS PivotTable;'

SELECT * FROM @ReplItems
ORDER BY 1,2"
################################################################################

# function(s)
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

function Txt-extract{
  param([string]$txtName)
  $returnArray = Get-Content $txtname
  return $returnArray
}
################################################################################

# set up the database connection
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server={0};Database={1};trusted_connection=true;" -f $StatusServer, $StatusDB

$SQLConnection.Open();

$SQLCommand = New-Object System.Data.SqlClient.SqlCommand
$SQLCommand.Connection = $SQLConnection

# clean up the destination table
# assume once a day, use hour greater than 6 to be safe
$SQLCommand.CommandText = "DELETE FROM SMCReplicatedItems WHERE DATEDIFF(hh, LastUpdate, GetDate()) > 6 "
$SQLCommand.ExecuteNonQuery();

# retrieve the servers
$Publishers = Txt-extract $serverlist
################################################################################	
	
# main
foreach ($Publisher IN $Publishers) {
	# get the database list per server
	$databases = Run-Query -SqlQuery $ReplItemsQuery -SqlServer $Publisher
	
	if (!$databases) {
		Write-Host "Found an empty database record for server $Publisher."
		}
	else {
		$dbnew = $databases[0].Databasename
		}
	
	foreach ($db IN $databases ) {
		$dbcurrent = $($db.DatabaseName)
		
		# skip servers with no databases returned
		if (!$dbcurrent) {
			break;
			}
		
		# database loop		
		$SQLCommand.CommandText = 
			"INSERT INTO SMCReplicatedItems (ServerName, DatabaseName, addl_loan_data, appraisal, borrower, br_address,
				br_expense, br_income, br_liability, br_REO,
				channels, codes, customer_elements, funding,
				inst_channel_assoc, institution, institution_association, 
				loan_appl, loan_fees, loan_price_history, loan_prod, 
				loan_regulatory, loan_status, product, product_channel_assoc, 
				property, servicing, shipping, underwriting, LastUpdate)
			VALUES
			('$($db.Servername)', '$($db.DatabaseName)', '$($db.addl_loan_data)', '$($db.appraisal)', '$($db.borrower)', '$($db.br_address)',
				'$($db.br_expense)', '$($db.br_income)', '$($db.br_liability)', '$($db.br_REO)',
				'$($db.channels)', '$($db.codes)', '$($db.customer_elements)', '$($db.funding)',
				'$($db.inst_channel_assoc)', '$($db.institution)', '$($db.institution_association)',
				'$($db.loan_appl)', '$($db.loan_fees)', '$($db.loan_price_history)', '$($db.loan_prod)',
				'$($db.loan_regulatory)', '$($db.loan_status)', $($db.product), '$($db.product_channel_assoc)',
				'$($db.property)', '$($db.servicing)', '$($db.shipping)', '$($db.underwriting)', GetDate())
			"
		# insert the data row per database
		$SQLCommand.ExecuteNonQuery();
	}
}
$SQLConnection.Close();