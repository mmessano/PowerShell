param( [string[]] $p, [string[]] $q)
"The number of parameters passed in p is $($p.Count)"
$i = 0
foreach ($arg in $p) { echo "The $i parameter in p is $arg"; $i++ }
"The number of parameters passed in q is $($q.Count)"
$i = 0
foreach ($arg in $q) { echo "The $i parameter in q is $arg"; $i++ }