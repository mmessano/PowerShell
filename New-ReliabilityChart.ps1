$computer = "localhost" 
$chart = New-Object -ComObject msgraph.application 
$chart.visible = $true 
$chart.datasheet.cells.item(1,1) = "Time" 
$chart.datasheet.cells.item(1,2) = "ReliabilityMetric" 
$r = 2 

Get-WmiObject -Class win32_reliabilityStabilityMetrics -computername $computer| 
Select-Object -First 254 | 
ForEach-Object { 
  $chart.datasheet.cells.item($r,1) =  
  [Management.ManagementDatetimeConverter]::ToDateTime($_.TimeGenerated) 
  $chart.datasheet.cells.item($r,2) = $_.SystemStabilityIndex 
$r++ 
}