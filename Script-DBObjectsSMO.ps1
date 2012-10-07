# Script server objects
#
# Requires Windows Powershell to be installed
# (http://www.microsoft.com/windowsserver2003/technologies/management/powershell/default.mspx)
#
# Returns zero for success, non-zero for failure
#
# RNM 10.10.2007
#------------------


#trap {
#    "AN ERROR OCCURRED! :-("
#    return 255
#    }

[reflection.assembly]::LoadwithPartialName("Microsoft.SQLServer.SMO") | out-Null


# Set variables
[boolean]$defaulted = $false
if ($args[0] -ne $null) {
    $server = $args[0] }
else {
    $server = "default_server"
    $defaulted = $true
     }
 
if ($args[1] -ne $null) {
    $filename = $args[1] }
else {
    $filename = "E:\Dexma\logs\" + $server + "_ScriptedObjects.txt"
    $defaulted = $true
     }
 
if ($args[2] -ne $null) {
    $action = $args[2] }
else {
    $action = "linkedservers"
    $defaulted = $true
     }
 
# Delete output file if it exists already
#if ($filename -ne $null){
#	remove-Item $filename
#	}
 
# Create SQL Server object
$sql = New-Object 'Microsoft.sqlserver.management.smo.server' $server
 
# Create SQL Server ScriptingOptions object
$scropt = New-Object 'Microsoft.sqlserver.management.smo.scriptingoptions'
$scropt.FileName = $filename
$scropt.includeheaders = $true
$scropt.appendtofile = $true
 
# Script required objects
switch ($action) {
       "linkedservers" {
              # Script linked servers
              $sql.LinkedServers | foreach-Object {$_.script($scropt) | out-null}
       }
       "logins" {
                     # Script logins
                     $sql.Logins| foreach-Object {$_.script($scropt) | out-null}
       }
       "jobs" {
                     # Script logins
                     $sql.JobServer.jobs| foreach-Object {$_.script($scropt) | out-null}
       }
       default {
              # Exit with failure code
              "ERROR: Action not recognised"
              return 2
       }
}
 
# Print results
$action + " on " + $server + " scripted to " + $filename
 
# If we defaulted any of the values then issue a warning, otherwise exit cleanly
if ($defaulted -eq $false) {
    return
    }
else
    {
    ""
    "WARNING: One or more of the required command line parameters was not provided. Defaults were used"
    ""
       "Expected parameters: "
       "  <server> <filename to script to> <linkedservers|logins>"
    return 1
    }