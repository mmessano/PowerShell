param([string[]]$paths = "paths",[string]$ext = "ext", [switch]$del)

function Search($path, $ext, $del)
{
Start-Job {param($path,$ext,$del)
    $logfile = "E:\GetFiles-$ext.txt"
    $files = gci $path -r -i *.$ext
    $files |out-file $logfile
    $sum = $files |measure-object -property length -sum
    $count = $files.count

    if($sum.sum -ge 1073741824)
        {
        $totalGB = [math]::round($sum.sum/1073741824, 2)
        write-output `n "$count files using a total of $totalGB GB" |out-file $logfile -append
        }
    elseif(($sum.sum -ge 1048576) -and ($sum.sum -lt 1073741824))
        {
        $totalMB = [math]::round($sum.sum/1048576, 2)
        write-output `n "$count files using a total of $totalMB MB" |out-file $logfile -append
        }
    elseif($sum.sum -lt 1048576)
        {
        $totalKB = [math]::round($sum.sum/1024, 2)
        write-output `n "$count files using a total of $totalKB KB" |out-file $logfile -append
        }
    $logsize = gci $logfile |measure-object -property length -sum
    if($del)
        {
        write-output `n "Q: Was the -del switch added? $del" |out-file $logfile -append
        Foreach($file in $files)
            {
            rm $file.fullname -force
            }
        }
        Else
        {
        write-output `n "Q: Was the -del switch added? False" |out-file $logfile -append
        }
    if($logsize.sum -lt 70){rm $logfile -force}
} -arg @($path, $ext, $del) -name $path
}

function usage()
{
Write-host -foregroundcolor green `n`t "Usage is `"commmand.ps1 -paths (`"c:\`",`"path2`") -ext ps1, both are required" `n
Write-host -foregroundcolor green `t "Make sure you DO NOT include the `".`" in the extension, just mp3, jpg, iso, and so on" `n
}

function confirm($strMessage)
{
write-host -foregroundcolor yellow `n $strMessage
$answer = $host.ui.rawui.readkey("NoEcho,IncludeKeyUp")
if ($answer.Character -ine "y")
    {
    write "We're not deleting anything...please re-run without the -del switch to delete"
    break
    }

write "Here's goes nothin..."
}

if(($paths -eq "paths") -or ($ext -eq "ext")){usage;break}

if($del)
{
Confirm("Are you sure you wish to delete ALL PST files? This cannot be undone! Press 'Y' to continue, or any other key to exit...")
}

foreach($path in $paths){Search $path $ext $del}

