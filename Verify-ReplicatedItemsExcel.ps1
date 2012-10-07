# Verify-ReplicatedItems.ps1
# mmessano
# 5/27/2011

# servername, dbname and table list as column headers
$ColHeaders = ("SQLServer", "DBName", "addl_loan_data", "appraisal", "borrower", "br_address",
				"br_expense", "br_income", "br_liability", "br_REO", 
				"channels", "codes", "customer_elements", "funding", 
				"inst_channel_assoc", "institution", "institution_association", 
				"loan_appl", "loan_fees", "loan_price_history", "loan_prod", 
				"loan_regulatory", "loan_status", "product", "product_channel_assoc", 
				"property", "servicing", "shipping", "underwriting")
################################################################################

# Queries
$SQLQuery = 
"DECLARE @ReplItems TABLE (
	ServerName varchar(64)
	, DBName varchar(128)
	, TableName varchar(128)
	, ColumnNum int
	)
	
INSERT INTO @ReplItems
EXEC sp_MSForEachDB'
USE ?	
SELECT	DISTINCT
		@@SERVERNAME
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
ORDER BY 2,3'

SELECT * FROM @ReplItems
ORDER BY 1,2"

$ServerQuery = 
"SELECT Server FROM SQLDatabases
WHERE DatabaseName LIKE 'distribution'
AND Filename LIKE '%.MDF'
AND Server NOT LIKE '%PSQLSVC21%' -- not an SMC replication server
ORDER BY 1"
################################################################################

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
################################################################################

# set up the workbook and worksheet
$erroractionpreference = "SilentlyContinue"
$OutBook = New-Object -comobject Excel.Application
$OutBook.visible = $True

$Workbook = $OutBook.Workbooks.Add()
$Worksheet = $Workbook.Worksheets.Item(1)
################################################################################

# write the headers to the spreadsheet with formatting
$idx = 0
foreach ($Title IN $ColHeaders) {
	$idx+=1
	$Worksheet.Cells.Item(1,$idx) = $Title
	}
$UsedRange = $Worksheet.UsedRange
$UsedRange.Interior.ColorIndex = 15
$UsedRange.Font.ColorIndex = 11
$UsedRange.Font.Bold = $True
$UsedRange.Orientation = 90
################################################################################

# starting row for data
$row = 2

# retrieve the servers with a distrbution database
$Publishers = Run-Query -SqlQuery $ServerQuery -SqlServer XSQLUTIL18 -SqlCatalog  Status | Select-Object -Property Server | Sort-Object -Property Server
################################################################################	
	
# main
foreach ($Publisher IN $Publishers) {
	write-host "Server: $($Publisher.Server)"
	
	# get the database list per server
	$databases = Run-Query -SqlQuery $SQLQuery -SqlServer $($Publisher.Server) | Select-Object -Property ServerName, DBName, TableName, ColumnNum | Sort-Object -Property ServerName, DBName, TableName, ColumnNum	
	
	$dbnew = $databases[0].DBName
	Write-Host "DBNew: $dbnew"
	
	foreach ($db IN $databases ) {
		$dbcurrent = $($db.DBName)
		Write-Host "DBCurrent: $dbcurrent"
		
		# skip servers with no databases returned
		if (!$dbcurrent) {
			break;
			}
		elseif ($dbcurrent -ne $dbnew) {
			$row++;
			$dbnew = $($db.DBName);
		}
		
		# server name
		$Worksheet.Cells.Item($row, 1) = $($db.ServerName)
		$Worksheet.Cells.Item($row, 1).Font.Bold = $true;
		
		# database name
		$Worksheet.Cells.Item($row, 2) = $($db.DBName)
		$Worksheet.Cells.Item($row, 2).Font.Bold = $true;
		
		# explicitly test each TableName property
		if  ($($db.TableName) -eq "addl_loan_data") 			{$Worksheet.Cells.Item($row, 3) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "appraisal") 					{$Worksheet.Cells.Item($row, 4) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "borrower") 					{$Worksheet.Cells.Item($row, 5) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "br_address") 				{$Worksheet.Cells.Item($row, 6) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "br_expense") 				{$Worksheet.Cells.Item($row, 7) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "br_income") 					{$Worksheet.Cells.Item($row, 8) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "br_liability") 				{$Worksheet.Cells.Item($row, 9) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "br_REO") 					{$Worksheet.Cells.Item($row, 10) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "channels") 					{$Worksheet.Cells.Item($row, 11) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "codes") 						{$Worksheet.Cells.Item($row, 12) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "customer_elements") 			{$Worksheet.Cells.Item($row, 13) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "funding") 					{$Worksheet.Cells.Item($row, 14) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "inst_channel_assoc") 		{$Worksheet.Cells.Item($row, 15) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "institution") 				{$Worksheet.Cells.Item($row, 16) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "institution_association") 	{$Worksheet.Cells.Item($row, 17) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "loan_appl") 					{$Worksheet.Cells.Item($row, 18) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "loan_fees") 					{$Worksheet.Cells.Item($row, 19) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "loan_price_history") 		{$Worksheet.Cells.Item($row, 20) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "loan_prod") 					{$Worksheet.Cells.Item($row, 21) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "loan_regulatory") 			{$Worksheet.Cells.Item($row, 22) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "loan_status") 				{$Worksheet.Cells.Item($row, 23) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "product") 					{$Worksheet.Cells.Item($row, 24) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "product_channel_assoc") 		{$Worksheet.Cells.Item($row, 25) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "property") 					{$Worksheet.Cells.Item($row, 26) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "servicing") 					{$Worksheet.Cells.Item($row, 27) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "shipping") 					{$Worksheet.Cells.Item($row, 28) = $($db.ColumnNum)}
		if  ($($db.TableName) -eq "underwriting") 				{$Worksheet.Cells.Item($row, 29) = $($db.ColumnNum)}
	}
	# skip servers with no databases returned
	if (!$dbcurrent) {
		}
	else {		
		$row++;
		}
}

#resize the columns to fit the data
$UsedRange.EntireColumn.AutoFit() |out-null