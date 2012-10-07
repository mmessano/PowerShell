# FIXME
# scripting SQL accounts is problematic at best
# the scripter replaces the password with random text which also breaks the 
# continuity of the file.  SSMS does this as well so it is a SQL bug most likely

param (
		$Server
		);

# Load needed assemblies 
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null; 
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMOExtended")| Out-Null; 
 
# Simple function to write html pages 
function writeHtmlPage 
{ 
    param ($title, $heading, $body, $filePath); 
    $html = "<html> 
             <head> 
                 <title>$title</title> 
             </head> 
             <body> 
                 <h1>$heading</h1> 
                $body 
             </body> 
             </html>"; 
    $html | Out-File -FilePath $filePath; 
} 
 
# Return all user databases on a sql server 
function getDatabases 
{ 
    param ($sql_server); 
    $databases = $sql_server.Databases | Where-Object {$_.IsSystemObject -eq $false}; 
    return $databases; 
} 
 
# Get all schemata in a database 
function getDatabaseSchemata 
{ 
    param ($sql_server, $database); 
    $db_name = $database.Name; 
    $schemata = $sql_server.Databases[$db_name].Schemas;
	foreach ($schema in $schemata) 
	{ 
		if ( $schema.Owner -match '\\' )
			{$schema.Owner = $schema.Owner -replace '\\', '-'};
	} 
	return $schemata; 
} 
 
# Get all tables in a database 
function getDatabaseTables 
{ 
    param ($sql_server, $database); 
    $db_name = $database.Name; 
    $tables = $sql_server.Databases[$db_name].Tables | Where-Object {$_.IsSystemObject -eq $false}; 
    return $tables; 
} 
 
# Get all stored procedures in a database 
function getDatabaseStoredProcedures 
{ 
    param ($sql_server, $database); 
    $db_name = $database.Name; 
    $procs = $sql_server.Databases[$db_name].StoredProcedures | Where-Object {$_.IsSystemObject -eq $false}; 
    return $procs; 
} 
 
# Get all user defined functions in a database 
function getDatabaseFunctions 
{ 
    param ($sql_server, $database); 
    $db_name = $database.Name; 
    $functions = $sql_server.Databases[$db_name].UserDefinedFunctions | Where-Object {$_.IsSystemObject -eq $false}; 
    return $functions; 
} 
 
# Get all views in a database 
function getDatabaseViews 
{ 
    param ($sql_server, $database); 
    $db_name = $database.Name; 
    $views = $sql_server.Databases[$db_name].Views | Where-Object {$_.IsSystemObject -eq $false}; 
    return $views; 
} 
 
# Get all table triggers in a database 
function getDatabaseTriggers 
{ 
    param ($sql_server, $database); 
    $db_name = $database.Name; 
    $tables = $sql_server.Databases[$db_name].Tables | Where-Object {$_.IsSystemObject -eq $false}; 
    $triggers = $null; 
    foreach($table in $tables) 
    { 
        $triggers += $table.Triggers; 
    } 
    return $triggers; 
} 

function getDBLogins
{
	param ($sql_server, $database);
	$db_name = $database.Name;
	$logins = $sql_server.Databases[$db_name].Users;# | Where-Object {$_.IsSystemObject -eq $false};
	return $logins;
}

# server level
function getLogins
{
	param ($sql_server);
	$logins = $sql_server.Logins | Where-Object {$_.IsSystemObject -eq $false};
	return $logins;
}
 
# Server level
function getLinkedServers
{
 	param ($sql_server);
	$linkedservers = $sql_server.LinkedServers;
	return $linkedservers;
}
  
function getJobs
{
 	param ($sql_server);
	$jobs = $sql_server.JobServer.Jobs;
	return $jobs;
}
 

# This function builds a list of links for database object types 
function buildLinkList 
{ 
    param ($array, $path); 
    $output = "<ul>"; 
    foreach($item in $array) 
    { 
        if($item.IsSystemObject -eq $false) # Exclude system objects 
        {
            if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Schema") 
            { 
                $output += "`n<li><a href=`"$path" + $item.Owner + ".html`">" + $item.Name + "</a></li>"; 
            } 
            elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Trigger") 
            { 
                $output += "`n<li><a href=`"$path" + $item.Parent.Schema + "." + $item.Name + ".html`">" + $item.Parent.Schema + "." + $item.Name + "</a></li>"; 
            } 
			elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Login") 
            { 
                # Leave the href name unmodified so accounts show up as DOMAIN\ACCOUNT but the link is correct
				$output += "`n<li><a href=`"$path" + ($item.Name -replace "\\", "-") + ".html`">" + $item.Name + "</a></li>"; 
            }
			elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.User") 
            { 
				# Leave the href name unmodified so accounts show up as DOMAIN\ACCOUNT but the link is correct
				$output += "`n<li><a href=`"$path" + ($item.Name -replace "\\", "-") + ".html`">" + $item.Name + "</a></li>"; 
            }
            else 
            { 
				#Write-Host "buildLinkList Default";
				$output += "`n<li><a href=`"$path" + $item.Schema + "." + $item.Name + ".html`">" + $item.Schema + "." + $item.Name + "</a></li>"; 
            } 
        }
		elseif($item.IsSystemObject -eq $true)
		{
#			Write-Host "buildlinkList else statement";
#			Write-Host $item;
			if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Agent.Job")
			{
				$output += "`n<li><a href=`"$path" + $item + ".html`">" + $item + "</a></li>";
			}
			elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.LinkedServer")
			{
				$output += "`n<li><a href=`"$path" + $item.Name + ".html`">" + $item.Name + "</a></li>";
			}
			elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.User") 
            { 
				# Leave the href name unmodified so accounts show up as DOMAIN\ACCOUNT but the link is correct
				$output += "`n<li><a href=`"$path" + ($item.Name -replace "\\", "-") + ".html`">" + $item.Name + "</a></li>"; 
            }
		}
    } 
    $output += "</ul>"; 
    return $output; 
} 
 
# Return the DDL for a given database object 
function getObjectDefinition 
{ 
    param ($item); 
    $definition = ""; 
    # Schemas don't like our scripting options 
	if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Schema")
    { 
		$definition = $item.Script(); 
    } 
    else 
    { 
        $options = New-Object ('Microsoft.SqlServer.Management.Smo.ScriptingOptions'); 
        $options.DriAll = $true; 
        $options.Indexes = $true; 
        $definition = $item.Script($options);
		#Write-Host $item.Script($options);
    } 
    return "<pre>$definition</pre>"; 
} 
 
# This function will get the comments on objects 
# MS calls these MS_Description when you add them through SSMS 
function getDescriptionExtendedProperty 
{ 
    param ($item); 
    $description = "No extended property documentation on object."; 
    foreach($property in $item.ExtendedProperties) 
    { 
        #if($property.Name -eq "MS_Description") 
        #{ 
        $description = $property.Value; 
        #} 
    } 
    return $description; 
} 
 
# Gets the parameters for a Stored Procedure 
function getProcParameterTable 
{ 
    param ($proc); 
    $proc_params = $proc.Parameters; 
    $prms = $proc_params | ConvertTo-Html -Fragment -Property Name, DataType, DefaultValue, IsOutputParameter; 
    return $prms; 
} 
 
# Returns a html table of column details for a db table 
function getTableColumnTable 
{ 
    param ($table); 
    $table_columns = $table.Columns; 
    $objs = @(); 
    foreach($column in $table_columns) 
    { 
        $obj = New-Object -TypeName Object; 
        $description = getDescriptionExtendedProperty $column; 
        Add-Member -Name "Name" -MemberType NoteProperty -Value $column.Name -InputObject $obj; 
        Add-Member -Name "DataType" -MemberType NoteProperty -Value $column.DataType -InputObject $obj; 
        Add-Member -Name "Default" -MemberType NoteProperty -Value $column.Default -InputObject $obj; 
        Add-Member -Name "Identity" -MemberType NoteProperty -Value $column.Identity -InputObject $obj; 
        Add-Member -Name "InPrimaryKey" -MemberType NoteProperty -Value $column.InPrimaryKey -InputObject $obj; 
        Add-Member -Name "IsForeignKey" -MemberType NoteProperty -Value $column.IsForeignKey -InputObject $obj; 
        Add-Member -Name "Description" -MemberType NoteProperty -Value $description -InputObject $obj; 
        $objs = $objs + $obj; 
    } 
    $cols = $objs | ConvertTo-Html -Fragment -Property Name, DataType, Default, Identity, InPrimaryKey, IsForeignKey, Description; 
    return $cols; 
} 
 
# Returns a html table containing trigger details 
function getTriggerDetailsTable 
{ 
    param ($trigger); 
    $trigger_details = $trigger | ConvertTo-Html -Fragment -Property IsEnabled, CreateDate, DateLastModified, Delete, DeleteOrder, Insert, InsertOrder, Update, UpdateOrder; 
    return $trigger_details; 
} 
 
# This function creates all the html pages for our database objects 
function createObjectTypePages 
{ 
    param ($objectName, $objectArray, $filePath, $db); 
    New-Item -Path $($filePath + $db.Name + "\$objectName") -ItemType directory -Force | Out-Null; 
    # Create index page for object type 
    $page = $filePath + $($db.Name) + "\$objectName\index.html"; 
    $list = buildLinkList $objectArray ""; 
    if($objectArray -eq $null) 
    { 
        $list = "No $objectName in $db"; 
    }
    writeHtmlPage $objectName $objectName $list $page; 
    # Individual object pages 
    if($objectArray.Count -gt 0) 
    { 
        foreach ($item in $objectArray) 
        { 
			if($item.IsSystemObject -eq $false) # Exclude system objects 
            { 
                $description = getDescriptionExtendedProperty($item); 
                $body = "<h2>Description</h2>$description"; 
                $definition = getObjectDefinition $item; 
                if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Schema") 
                { 
					$page = $filePath + $($db.Name + "\$objectName\" + $item.Owner + ".html");
                } 
                elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Trigger") 
                { 
                    $page = $filePath + $($db.Name + "\$objectName\" + $item.Parent.Schema + "." + $item.Name + ".html"); 
            	}
				elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Login")
				{
					$page = $filePath + $($db.Name + "\$objectname\" + ($item.Name -replace "\\", "-") + ".html");
				}
				elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.User")
				{
					$page = $filePath + $($db.Name + "\$objectname\" + ($item.Name -replace "\\", "-") + ".html");
				}
            	else 
            	{ 
					$page = $filePath + $($db.Name + "\$objectName\" + $item.Schema + "." + $item.Name + ".html"); 
                } 
                $title = ""; 
            	if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Schema") 
            		{ 
            		    $title = $item.Name; 
            		    $body += "<h2>Object Definition</h2>$definition"; 
            		}
					elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Login")
					{
						$title = $item.Name;
						$body += "<h2>Object Definition</h2>$definition";
					}
	                else 
	                { 
	                $title = $item.Schema + "." + $item.Name; 
	                if(([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.StoredProcedure") -or ([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.UserDefinedFunction")) 
	                  	{ 
	                   	    $proc_params = getProcParameterTable $item; 
	                   	    $body += "<h2>Parameters</h2>$proc_params<h2>Object Definition</h2>$definition"; 
	                   	} 
		                elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Table") 
		                { 
		                    $cols = getTableColumnTable $item; 
		                    $body += "<h2>Columns</h2>$cols<h2>Object Definition</h2>$definition"; 
		                } 
		                elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.View") 
		                { 
		                    $cols = getTableColumnTable $item; 
		                    $body += "<h2>Columns</h2>$cols<h2>Object Definition</h2>$definition"; 
		                } 
		                elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Trigger") 
		                { 
		                    $title = $item.Parent.Schema + "." + $item.Name; 
		                    $trigger_details = getTriggerDetailsTable $item; 
		                    $body += "<h2>Details</h2>$trigger_details<h2>Object Definition</h2>$definition"; 
	                  	}
#						elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Login") 
#		                {  
#							$body += "<h2>Object Definition</h2>$definition"; 
#		                } 
                } 
                
            }
			elseif($item.IsSystemObject -eq $true) # system object
			#else # system object; using ($item.IsSystemObject -eq $true) does not work as Jobs and LinkedServers do not have that property
			{
				$description = getDescriptionExtendedProperty($item); 
                $body = "<h2>Description</h2>$description"; 
                $definition = getObjectDefinition $item;
                if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.Agent.Job") 
                { 
					$title = $item;
					$page = $filePath + $($db.Name + "\$objectName\" + $item + ".html");
					$body += "<h2>Object Definition</h2>$definition";
                }
				elseif([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.LinkedServer") 
                { 
					$title = $item.Name;
					$page = $filePath + $($db.Name + "\$objectName\" + $item.Name + ".html");
					$body += "<h2>Object Definition</h2>$definition";
                }
				if([string]$item.GetType() -eq "Microsoft.SqlServer.Management.Smo.User") 
                { 
					$title = $item.Name;
					$page = $filePath + $($db.Name + "\$objectName\" + $item.Name + ".html");
					$body += "<h2>Object Definition</h2>$definition";
                }
			}
			writeHtmlPage $title $title $body $page; 
        } 
    } 
}	# end createObjectTypePages
 
# Root directory where the html documentation will be generated 
$filePath = "$env:USERPROFILE\database_documentation\$Server\"; 
New-Item -Path $filePath -ItemType directory -Force | Out-Null; 
# sql server that hosts the databases we wish to document 
$sql_server = New-Object Microsoft.SqlServer.Management.Smo.Server $Server; 
# IsSystemObject not returned by default so ask SMO for it
# not needed for LinkedServers or Jobs
$sql_server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "IsSystemObject"); 
$sql_server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject"); 
$sql_server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], "IsSystemObject"); 
$sql_server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Trigger], "IsSystemObject"); 
$sql_server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.User], "IsSystemObject");

# Get databases on our server 
$databases = getDatabases $sql_server; 

# Get LinkedServers for the current server
$linkedservers = getLinkedServers $sql_server;
createObjectTypePages "LinkedServers" $linkedservers $filePath;
Write-Host "Documented Linked Servers on " $sql_server.Name;

# Get jobs for the current server
$jobs = getJobs $sql_server;
createObjectTypePages "Jobs" $jobs $filePath;
Write-Host "Documented Jobs on " $sql_server.Name;

# get logins for the current server
$logins = getLogins $sql_server;
createObjectTypePages "Logins" $logins $filePath;
Write-Host "Documented Logins on " $sql_server.Name;
	
	
foreach ($db in $databases) 
{ 
    Write-Host "Started documenting " $db.Name; 
    # Directory for each database to keep everything tidy 
    New-Item -Path $($filePath + $db.Name) -ItemType directory -Force | Out-Null; 
 
    # Make a page for the database 
    $db_page = $filePath + $($db.Name) + "\index.html"; 
    $body = "<ul> 
                <li><a href='Schemata/index.html'>Schemata</a></li> 
                <li><a href='Tables/index.html'>Tables</a></li> 
                <li><a href='Views/index.html'>Views</a></li> 
                <li><a href='Stored Procedures/index.html'>Stored Procedures</a></li> 
                <li><a href='Functions/index.html'>Functions</a></li> 
                <li><a href='Triggers/index.html'>Triggers</a></li> 
				<li><a href='Users/index.html'>Users</a></li>
            </ul>"; 
    writeHtmlPage $db $db $body $db_page; 
         
    # Get schemata for the current database 
    $schemata = getDatabaseSchemata $sql_server $db;
    createObjectTypePages "Schemata" $schemata $filePath $db; 
    Write-Host "`tDocumented schemata in " $db.Name; 
    
	# Get tables for the current database 
    $tables = getDatabaseTables $sql_server $db; 
    createObjectTypePages "Tables" $tables $filePath $db; 
    Write-Host "Documented tables in " $db.Name; 
    
	# Get views for the current database 
    $views = getDatabaseViews $sql_server $db; 
    createObjectTypePages "Views" $views $filePath $db; 
    Write-Host "`tDocumented views in " $db.Name; 
    
	# Get procs for the current database 
    $procs = getDatabaseStoredProcedures $sql_server $db; 
    createObjectTypePages "Stored Procedures" $procs $filePath $db; 
    Write-Host "`tDocumented stored procedures in " $db.Name; 
   
	# Get functions for the current database 
    $functions = getDatabaseFunctions $sql_server $db; 
    createObjectTypePages "Functions" $functions $filePath $db; 
    Write-Host "`tDocumented functions in " $db.Name; 
    
	# Get triggers for the current database 
    $triggers = getDatabaseTriggers $sql_server $db; 
    createObjectTypePages "Triggers" $triggers $filePath $db; 
    Write-Host "`tDocumented triggers in " $db.Name; 
    
	# get logins for the current server
	$logins = getDBLogins $sql_server $db;
	createObjectTypePages "Users" $logins $filePath $db;
	Write-Host "`tDocumented Users in " $db.Name;
	
	Write-Host "Finished documenting " $db.Name; 
}