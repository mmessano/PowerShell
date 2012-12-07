# Test-Switch.ps1

$ENV = $args[0]

if ($ENV -eq $null){
    $ENV = "PROD"
    }
    
switch ($ENV) {
	"PROD"{ $DBServer 	= "status.db.prod.dexma.com"; 
			$DB 		= "status"; 
			$SQLQuery	= "SELECT     s.server_name
	            			FROM         dbo.t_server AS s INNER JOIN
	                        dbo.t_monitoring AS m ON s.server_id = m.server_id
	            			WHERE       (s.active = 1) AND (m.Perfmon = 1) AND (s.environment_id = 0)" }
	
	"DEMO"{ $DBServer 	= "status.db.stage.dexma.com"; 
			$DB 		= "statusstage";
			$SQLQuery 	= "SELECT     s.server_name
	            			FROM         dbo.t_server AS s INNER JOIN
	                        dbo.t_monitoring AS m ON s.server_id = m.server_id
	            			WHERE       (s.active = 1) AND (m.Perfmon = 1) AND (s.environment_id = 1)"}
	
	"IMP" { $DBServer 	= "status.db.imp.dexma.com"; 
			$DB 		= "statusimp";
			$SQLQuery	= "SELECT     s.server_name
	            			FROM         dbo.t_server AS s INNER JOIN
	                        dbo.t_monitoring AS m ON s.server_id = m.server_id
	            			WHERE       (s.active = 1) AND (m.Perfmon = 1) AND (s.environment_id IN ('2', '9'))"}
    }

Write-Host $DBServer, $DB, $SQLQuery

