param( 

	[String[]] $DatabaseList

	)
	
#	foreach ($i in $DatabaseList)
#	{
#	Write-Host "$i`n"
#	}


#Write-Host $($DatabaseList.Count)
"The number of parameters passed in DatabaseList is $($DatabaseList.Count)"

$i = 0
foreach ($arg in $DatabaseList) { echo "The $i parameter in DatabaseList is $arg"; $i++ }

