param($fileFilter=$(throw "Filter must be specified"))

$regex = [regex]"^(?<program>\S*)\s*pid: (?<pid>\d*)\s*(?<handle>[\da-z]*):\s*(?<file>(\\\\)|([a-z]:).*)"

#$regex = [regex]"(?<pid>\d*)\s*"

$Lines = E:\Dexma\bin\ThirdParty\handle $fileFilter | 
	foreach {
    	if ( $_  -match $regex) {
			$matches | select @{n="Path";e={$_.file}},@{n="Handle";e={$_.handle}},@{n="Pid";e={$_.pid}},@{n="Program";e={$_.program}}

    }
}


$Lines