# define parameters
param
(
  $server = $(read-host "Server ('localhost' okay)"),
  $instance = $(read-host "Instance ('default' okay)"),
  $database = $(read-host "Database"),
  $tables = $(read-host "Tables (wildcards okay)"),
  $file = $(read-host "Script path and file name")
)

# trap errors
$errors = "c:\dexma\logs\psscripterrors.txt"
trap
{
  "______________________" | out-file $errors -append;
  "ERROR SCRIPTING TABLES" | out-file $errors -append;
  get-date | out-file $errors -append;
  "ERROR: " + $_ | out-file $errors -append;
  "`$server = $server" | out-file $errors -append;
  "`$instance = $instance" | out-file $errors -append;
  "`$database = $database" | out-file $errors -append;
  "`$tables = $tables" | out-file $errors -append;
  "`$file = $file" | out-file $errors -append;
  "`$path = $path" | out-file $errors -append;
  "`$scripts = $scripts" | out-file $errors -append;
  throw "ERROR: See $errors"
}

# retrieve set of table objects
$path = "sqlserver:\sql\$server\$instance\databases\$database\tables"
$tableset =get-childitem $path -ErrorAction stop |
  where-object {$_.displayname -like $tables}

# script each table
foreach ($table in $tableset)
{
  $table.script() | out-file $file -append -ErrorAction stop
}