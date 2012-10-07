param (
    [string]$filename = $(throw "need a filename, e.g. c:\temp\test.xls"),
    [string]$worksheet
)

if (-not (Test-Path $filename)) {
    throw "Path '$filename' does not exist."
    exit
}

if (-not $worksheet) {
    Write-Warning "Defaulting to Sheet1 in workbook."
    $worksheet = "Sheet1"
}

# resolve relative paths
$filename = Resolve-Path $filename

# assume header row (HDR=YES)
#$connectionString = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=${filename};Extended Properties=`"Excel 8.0;HDR=YES`"";
$connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=${filename};Extended Properties=`"Excel 12.0 Xml;HDR=YES`"";
#"Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$filepath`";Extended Properties=`"Excel 12.0 Xml;HDR=YES`";"
#$connectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=E:\Dexma\logs\IndexesUnused-11062012.xlsx;Extended Properties='Excel 12.0 Macro;HDR=YES';"


$connection = New-Object system.data.OleDb.OleDbConnection $connectionString;
$connection.Open();
$command = New-Object system.data.OleDb.OleDbCommand "select * from [$worksheet`$]"

$command.connection = $connection
$reader = $command.ExecuteReader("CloseConnection")

if ($reader.HasRows) {
    # cache field names
    $fields = @()
    $count = $reader.FieldCount

    for ($i = 0; $i -lt $count; $i++) {
        $fields += $reader.GetName($i)
    }

    while ($reader.read()) {

        trap [exception] {
            Write-Warning "Error building row."
            break;
        }

        # needs to match field count
        $values = New-Object object[] $count

        # cache row values
        $reader.GetValues($values)

        $row = New-Object psobject
        $fields | foreach-object -begin {$i = 0} -process {
            $row | Add-Member -MemberType noteproperty -Name $fields[$i] -Value $values[$i]; $i++
        }
        $row # emit row
    }
}