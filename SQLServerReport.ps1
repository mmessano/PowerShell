[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null;
$smoObj = [Microsoft.SqlServer.Management.Smo.SmoApplication];
 
# This gets the sql server
$sql = $smoObj::EnumAvailableSqlServers($false);
 
# Automate Excel
$xl = New-Object -ComObject Excel.Application;
$xl.Visible = $true;
$xl = $xl.Workbooks.Add();
$Sheet = $xl.Worksheets.Item(1);
 
$row = 1;
 
foreach($sqlserver in $sql)
{
	 # headers
     $Sheet.Cells.Item($row, 1) = "Sql Server:";
     $Sheet.Cells.Item($row, 2) = $sqlserver.Name;
     $Sheet.Cells.Item($row, 1).Font.Bold = $true;
     $Sheet.Cells.Item($row, 2).Font.Bold = $true;
	$Sheet.Cells.Item($row, 3) = "";
     	$Sheet.Cells.Item($row, 4) = "Instance:";
     	$Sheet.Cells.Item($row, 5) = $sqlserver.Instance;
     	$Sheet.Cells.Item($row, 4).Font.Bold = $true;
     	$Sheet.Cells.Item($row, 5).Font.Bold = $true;
	 $Sheet.Cells.Item($row, 6) = "";
	 $Sheet.Cells.Item($row, 7) = "Version: ";
	 $Sheet.Cells.Item($row, 8) = $sqlserver.Version;
     	$Sheet.Cells.Item($row, 7).Font.Bold = $true;
     	$Sheet.Cells.Item($row, 8).Font.Bold = $true;
 
	 # Prettify headers
	 for($i = 1; $i -le 8; $i++)
	 {
	 	$Sheet.Cells.Item($row,$i).Interior.ColorIndex = 50;
     		$Sheet.Cells.Item($row,$i).Font.ColorIndex = 20;
	 }
 
	 # Create obj for this sql server
	 $srv = New-Object "Microsoft.SqlServer.Management.Smo.Server" $sqlserver.Name;
	 # Get the databases on this sql server
	 $databases = $srv.Databases;
 
	 # Increase rowcount for formatting
	 $row += 2;
 
	 # Add column headers for databases
	 $Sheet.Cells.Item($row, 1) = "Database";
	 $Sheet.Cells.Item($row, 2) = "Size";
	 $Sheet.Cells.Item($row, 3) = "SpaceAvailable";
	 $Sheet.Cells.Item($row, 4) = "State";
	 $Sheet.Cells.Item($row, 5) = "Table Count";
	 $Sheet.Cells.Item($row, 6) = "Collation";
	 $Sheet.Cells.Item($row, 7) = "Compatibility Level";
	 $Sheet.Cells.Item($row, 8) = "Create Date";
	 $Sheet.Cells.Item($row, 9) = "Index Space Usage";
	 $Sheet.Cells.Item($row, 10) = "Owner";
	 $Sheet.Cells.Item($row, 11) = "Last Backup";
	 $Sheet.Cells.Item($row, 12) = "Trigger Count";
	 $Sheet.Cells.Item($row, 13) = "UDF Count";
	 for($i = 1; $i -le 13; $i++)
	 {
	 	$Sheet.Cells.Item($row,$i).Interior.ColorIndex = 35;
     		$Sheet.Cells.Item($row,$i).Font.ColorIndex = 0;
		$Sheet.Cells.Item($row, $i).Font.Bold = $true;
	 }
	 $row++;
	 # Work through each database in the collection
	 foreach($db in $databases)
	 {
	 	$Sheet.Cells.Item($row, 1) = $db.Name;
		$Sheet.Cells.Item($row, 2) = $db.Size;
		$Sheet.Cells.Item($row, 3) = $db.SpaceAvailable;
		$Sheet.Cells.Item($row, 4) = $db.State;
		$Sheet.Cells.Item($row, 5) = $db.Tables.Count;
		$Sheet.Cells.Item($row, 6) = $db.Collation;
		$Sheet.Cells.Item($row, 7) = $db.CompatibilityLevel;
		$Sheet.Cells.Item($row, 8) = $db.CreateDate;
		$Sheet.Cells.Item($row, 9) = $db.IndexSpaceUsage;
		$Sheet.Cells.Item($row, 10) = $db.Owner;
		$Sheet.Cells.Item($row, 11) = $db.LastBackupDate;
		$Sheet.Cells.Item($row, 12) = $db.Triggers.Count;
		$Sheet.Cells.Item($row, 13) = $db.UserDefinedFunctions.Count;
		for($i = 1; $i -le 13; $i++)
		{
	 		$Sheet.Cells.Item($row,$i).Interior.ColorIndex = 0;
     			$Sheet.Cells.Item($row,$i).Font.ColorIndex = 0;			
		}
		$row++;
	 }
 
	 $row++;
}
 
# Apply autoformat
$Sheet.UsedRange.EntireColumn.AutoFit();