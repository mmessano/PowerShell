# Verify-ReplicatedItems.ps1
# mmessano
# 5/27/2011
################################################################################

# Queries
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
	$sqlCmd.CommandTimeout = "300"
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

# zero the array
$ReplicatedItems = @()

# retrieve the servers with a distribution database
$Publishers = Run-Query -SqlQuery $ServerQuery -SqlServer XSQLUTIL18 -SqlCatalog  Status | Select-Object -Property Server | Sort-Object -Property Server
################################################################################	
	
# main
foreach ($Publisher IN $Publishers) {
	#write-host "Server: $($Publisher.Server)"
	
	# get the database list per server
	$databases = Run-Query -SqlQuery $ReplItemsQuery -SqlServer $($Publisher.Server) | Sort-Object -Property ServerName, Databasename#, TableName, ColumnNum	
	
	
	if (!$databases) {
		Write-Host "Found an empty database record for server $($Publisher.Server)."
		}
	else {
		$dbnew = $databases[0].Databasename
		}
	#Write-Host "DBNew: $dbnew"
	
	foreach ($db IN $databases ) {
		$dbcurrent = $($db.Databasename)
		#Write-Host "DBCurrent: $dbcurrent"

		# skip servers with no databases returned
		if (!$dbcurrent) {
			break;
			}
		
		$ReplicatedItem = New-Object -TypeName PSObject
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "ServerName" 				-Value $($db.ServerName)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "DatabaseName" 			-Value $($db.Databasename)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "addl_loan_data" 			-Value $($db.addl_loan_data)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "appraisal" 				-Value $($db.appraisal) 
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "borrower" 				-Value $($db.borrower)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "br_address" 				-Value $($db.br_address)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "br_expense" 				-Value $($db.br_expense)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "br_income" 				-Value $($db.br_income) 
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "br_liability" 			-Value $($db.br_liability)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "br_REO" 					-Value $($db.br_REO)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "channels" 				-Value $($db.channels)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "codes" 					-Value $($db.codes)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "customer_elements" 		-Value $($db.customer_elements)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "funding" 					-Value $($db.funding)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "inst_channel_assoc" 		-Value $($db.inst_channel_assoc)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "institution" 				-Value $($db.institution)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "institution_association" 	-Value $($db.institution_association)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "loan_appl" 				-Value $($db.loan_appl)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "loan_fees" 				-Value $($db.loan_fees)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "loan_price_history" 		-Value $($db.loan_price_history)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "loan_prod" 				-Value $($db.loan_prod)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "loan_regulatory" 			-Value $($db.loan_regulatory)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "loan_status" 				-Value $($db.loan_status)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "product" 					-Value $($db.product)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "product_channel_assoc" 	-Value $($db.product_channel_assoc)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "property" 				-Value $($db.property)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "servicing" 				-Value $($db.servicing)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "shipping" 				-Value $($db.shipping)
			Add-Member -InputObject $ReplicatedItem -type NoteProperty -Name "underwriting" 			-Value $($db.underwriting)
		$ReplicatedItems += $ReplicatedItem
	}
}
$ReplicatedItems = $ReplicatedItems | Sort-Object "ServerName", "DatabaseName"

$SpreadSheet = ("E:\Dexma\logs\ReplicatedItems-" + (Get-Date -Format ddMMyyyy) + ".xlsx")
$TempCSV = ($env:TEMP + "\" + ([System.GUID]::NewGuid()).ToString() + ".csv")
$ReplicatedItems | Export-Csv -Path $TempCSV -NoTypeInformation

if (Test-Path -Path $SpreadSheet) { Remove-Item -Path $SpreadSheet }

# set up the workbook and worksheet
$erroractionpreference = "SilentlyContinue"
$OutBook = New-Object -comobject Excel.Application
$OutBook.visible = $False

$Workbook = $OutBook.Workbooks.Open($TempCSV)
$Workbook.Title = ("Replicated Items for SMC replication" + (Get-Date -Format D))
$Workbook.Author = "Michael J. Messano"

$Worksheet = $Workbook.Worksheets.Item(1)

$LastColumn = ($worksheet.UsedRange.Columns.Count + 1 )
for ( $i = 1; $i -lt $LastColumn; $i++) {
	$Worksheet.Cells.item(1,$i).Interior.ColorIndex = 15
	$Worksheet.Cells.item(1,$i).Font.ColorIndex = 5
	$Worksheet.Cells.item(1,$i).Font.Bold = $True
	if ($i -gt 2) {
		$Worksheet.Cells.item(1,$i).Orientation = 90
		}
}

$Worksheet.UsedRange.EntireColumn.Autofit() | Out-Null
$Worksheet.Name = "SMC Replicated Items"

$List = $Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null, [Microsoft.Office.Interop.Excel.X1YesNoGuess]::xlYes, $null)
$List.Name = "Item Table"

$Workbook.SaveAs($SpreadSheet, 51)
$Workbook.Saved = $true
$Workbook.Close()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($Workbook) | Out-Null

$SpreadSheet.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($SpreadSheet) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

if (Test-Path -Path $TempCSV) { Remove-Item -Path $TempCSV }