#******************************************************************* 
# Global Variables 
#******************************************************************* 
$Script:Version      = '1.0.9.1126' 
$Script:LogSeparator = '*******************************************************************************' 
$Script:LogFile      = "" 
 
#******************************************************************* 
# Functions 
#*******************************************************************
function Get-ScriptName(){ 
# 
#      .SYNOPSIS 
#          Extracts the script name
#      .DESCRIPTION 
#          Extracts the script file name without extention 
#      .NOTES 
#         Author:    Axel Kara, axel.kara@gmx.de 
# 
    $tmp = $MyInvocation.ScriptName.Substring($MyInvocation.ScriptName.LastIndexOf('\') + 1) 
    $tmp.Substring(0,$tmp.Length - 4) 
} 
 
function Write-Log($Msg, [System.Boolean]$LogTime=$true){ 
# 
#      .SYNOPSIS 
#          Creates a log entry 
#      .DESCRIPTION 
#          By default a time stamp will be logged too. This can be 
#        disabled with the -LogTime $false parameter 
#      .NOTES 
#         Author:    Axel Kara, axel.kara@gmx.de 
#      .EXAMPLE 
#          Write-Log -Msg 'Log entry created successfull.' [-LogTime $false] 
# 
    if($LogTime){ 
        $date = Get-Date -format dd.MM.yyyy 
        $time = Get-Date -format HH:mm:ss 
       Add-Content -Path $LogFile -Value ($date + " " + $time + "   " + $Msg) 
    } 
    else{ 
        Add-Content -Path $LogFile -Value $Msg 
    }
} 
 
function Initialize-LogFile($File, [System.Boolean]$reset=$false){ 
# 
#      .SYNOPSIS 
#          Initializes the log file 
#      .DESCRIPTION 
#         Creates the log file header 
#          Creates the folder structure on local drives if necessary 
#        Resets existing log if used with -reset $true 
#      .NOTES 
#         Author:    Axel Kara, axel.kara@gmx.de 
#      .EXAMPLE 
#          Initialize-LogFile -File 'C:\Logging\events.log' [-reset $true] 
# 
try{ 
        #Check if file exists 
        if(Test-Path -Path $File){ 
            #Check if file should be reset 
            if($reset){ 
                Clear-Content $File -ErrorAction SilentlyContinue 
            } 
        } 
        else{ 
            #Check if file is a local file 
            if($File.Substring(1,1) -eq ':'){ 
                #Check if drive exists 
                $driveInfo = [System.IO.DriveInfo]($File) 
                if($driveInfo.IsReady -eq $false){ 
                    Write-Log -Msg ($driveInfo.Name + " not ready.") 
                } 
                 
                #Create folder structure if necessary 
                $Dir = [System.IO.Path]::GetDirectoryName($File) 
                if(([System.IO.Directory]::Exists($Dir)) -eq $false){ 
                    $objDir = [System.IO.Directory]::CreateDirectory($Dir) 
                    Write-Log -Msg ($Dir + " created.") 
                } 
            } 
        } 
        #Write header 
        Write-Log -LogTime $false -Msg $LogSeparator 
        Write-Log -LogTime $false -Msg (((Get-ScriptName).PadRight($LogSeparator.Length - ("   Version " + $Version).Length," ")) + "   Version " + $Version) 
        Write-Log -LogTime $false -Msg $LogSeparator 
    } 
    catch{ 
        Write-Log -Msg $_ 
    } 
} 
 
function Read-Arguments($Values = $args) { 
# 
#      .SYNOPSIS 
#          Reads named script arguments 
#      .DESCRIPTION 
#          Reads named script arguments separated by '=' and tagged with'-' character 
#      .NOTES 
#         Author:    Axel Kara, axel.kara@gmx.de 
# 
    foreach($value in $Values){ 
         
        #Change the character that separates the arguments here 
        $arrTmp = $value.Split("=") 
         
        switch ($arrTmp[0].ToLower()) { 
            -log { 
                $Script:LogFile = $arrTmp[1] 
            } 
        } 
    } 
} 

#******************************************************************* 
# Main Script 
#******************************************************************* 
if($args.Count -ne 0){ 
    #Read script arguments 
    Read-Arguments 
    if($LogFile.StartsWith("\\")){ 
        Write-Host "UNC" 
    } 
    elseif($LogFile.Substring(1,1) -eq ":"){ 
        Write-Host "Local" 
    } 
    else{ 
        $LogFile = [System.IO.Path]::Combine((Get-Location), $LogFile) 
    } 
     
    if($LogFile.EndsWith(".log") -eq $false){ 
        $LogFile += ".log" 
    } 
} 
 
if($LogFile -eq ""){ 
    #Set log file 
    $LogFile = [System.IO.Path]::Combine((Get-Location), (Get-ScriptName) + ".log") 
} 
 
#Write log header 
Initialize-LogFile -File $LogFile -reset $false 
 
 
 
#/////////////////////////////////// 
#/// Enter your script code here /// 
#/////////////////////////////////// 
 
 
#Write log footer 
Write-Log -LogTime $false -Msg $LogSeparator 
Write-Log -LogTime $false -Msg ''