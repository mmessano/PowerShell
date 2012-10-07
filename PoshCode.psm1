####################################################################################################
## Script Name:     PoshCode Module
## Created On:      
## Author:          Joel 'Jaykul' Bennett
## File:            PoshCode.psm1
## Usage:          
## Version:         3.13
## Purpose:         Provides cmdlets for working with scripts from the PoshCode Repository:
##											Get-PoshCodeUpgrade - get the latest version of this script from the PoshCode server
## 											Get-PoshCode  - Search for and download code snippets
## 											New-PoshCode  - Upload new code snippets
## 											Get-WebFile   - Download
## Requirements:    PowerShell Version 2
## Last Updated:    07/14/2010
## History:
##                  3.13 2010-08-04 - Fixed proxy credentials for download (oops)
##                                  - Fixed WebException handling (e.g.: 404 errors) on Get-WebFile (only report one error, and make it nicer)
##                                  - Fixed test for $filename so it doesn't throw if $filename is empty
##                  3.12 2010-07-14 - Complete help documentation for the last two public functions.
##                  3.11 2010-06-08 - Add code for proxy credentials at Kirk Munro's suggestion.
##                  3.10 2009-11-08 - Fix a typo bug in Get-PoshCode
##                  3.9  2009-10-02 - Put back the fixed NTFS Streams
##                  3.8  2009-08-04 - Fixed PoshCodeUpgrade for CTP3+ and added secondary cert
##                  3.7  2009-07-29 - Remove NTFS Streams 
##                  3.6  2009-05-04 - Documentation Rewrite
##                       
####################################################################################################
#requires -version 2.0
Set-StrictMode -Version Latest

$PoshCode = "http://PoshCode.org/" | 
      Add-Member -type NoteProperty -Name "UserName" -Value "Anonymous" -Passthru |
      Add-Member -type ScriptProperty -Name "ScriptLocation" -Value {
         $module = $null
         Get-Module PoshCode | Select -expand Path -EA "SilentlyContinue" | Tee -var module
         if(!$module) { # Try finding it by path, since it's not loaded as "PoshCode"
            Get-Module | ? {$_.Name -match "^$([RegEx]::Escape($PsScriptRoot))"} | Select -expand Path
         }
      } -Passthru |
      Add-Member -type ScriptProperty -Name "ModuleName" -Value {
         if( Get-Module PoshCode ) { "PoshCode" } else {
            Get-Module | ? {$_.Name -match "^$([RegEx]::Escape($PsScriptRoot))"} | Select -expand Name
         }
      } -Passthru |      
      Add-Member -type NoteProperty -Name "ScriptVersion" -Value 3.13 -Passthru |
      Add-Member -type NoteProperty -Name "ApiVersion" -Value 1 -Passthru

function New-PoshCode {
<#
.SYNOPSIS
	Uploads a script to PoshCode
.DESCRIPTION
	Uploads code to the PowerShell Script Repository and returns the url for you.
.LINK
	http://www.poshcode.org
.EXAMPLE
	C:\PS>Get-Content MyScript.ps1 | New-PoshCode "An example for you" "This is just to show how to do it"
	
	This command gets the content of MyScript.ps1 and passes it to New-Poshcode which then posts it to poshcode.org with the specified title and description.
.PARAMETER Path
	Specifies the path to an item.
.PARAMETER Description
	Sets the free-text summary of the script that will be displayed on the poshcode page for the script. 
.PARAMETER Author
	Specifies the author of the script that is being submitted.
.PARAMETER Language
	Specifies the language of the script that is being submitted.
.PARAMETER Keep
	Specifies how long to keep scripts on the poshcode.org site. Possible values are 'day', 'month', or 'forever'.
.PARAMETER Title
	Specifies the title of the script that is being submitted. 
.PARAMETER URL
	Overrides the default PoshCode url, to allow posting to other Pastebin sites.
.NOTES
 	History:
		v 3.1 - Fixed the $URL parameter so that it's settable again. *This* function should work on any pastebin site
		v 3.0 - Renamed to New-PoshCode.  
    			-	Removed the -Permanent switch, since this is now exclusive to the permanent repository
		v 2.1 - Changed some defaults
    		  - Added "PermanentPosh" switch ( -P ) to switch the upload to the PowerShellCentral repository
		v 2.0 - works with "pastebin" (including posh.jaykul.com/p/ and PowerShellCentral.com/scripts/)
 		v 1.0 - Worked with a special pastebin
#>
[CmdletBinding()]
PARAM(
   [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]$Path
,
   [Parameter(Position=5, Mandatory=$true)]
   [string]$Description
, 
   [Parameter(Mandatory=$true, Position=10)]
   [string]$Author
, 
   [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("BaseName","Name")]
   [string]$Title
, 
   [Parameter(Position=15)]
   [PoshCodeLanguage]$Language="posh"
, 
   [Parameter(Position=20, Mandatory=$false)]
   [ValidateScript({ if($_ -match "^[dmf]") { return $true } else { throw "Please specify 'day', 'month', or 'forever'" } })]
   [string]$Keep="f"
,
   [Parameter()]
   [int]$Parent = 0
,
   [Parameter(Mandatory=$false)]
   [string]$url= $($PoshCode)
)
   
BEGIN {
   $null = [Reflection.Assembly]::LoadWithPartialName("System.Web")
   [string]$data = ""
   [string]$meta = ""
   
   if($language) {
      $meta = "format=" + [System.Web.HttpUtility]::UrlEncode($language)
      # $url = $url + "?" +$lang
   } else {
      $meta = "format=text"
   }
   
   if($Parent) {
      $meta = $meta + "&parent_pid=$Parent"
   }


   # Note how simplified this is by 
   switch -regex ($Keep) {
      "^d" { $meta += "&expiry=d" }
      "^m" { $meta += "&expiry=m" }
      "^f" { $meta += "&expiry=f" }
   }
 
   if($Description) {
      $meta += "&descrip=" + [System.Web.HttpUtility]::UrlEncode($Description)
   } else {
      $meta += "&descrip="
   }   
   $meta += "&poster=" + [System.Web.HttpUtility]::UrlEncode($Author)
   
   function Send-PoshCode ($meta, $title, $data, $url= $($PoshCode)) {
      $meta += "&paste=Send&posttitle=" + [System.Web.HttpUtility]::UrlEncode($Title)
      $data = $meta + "&code2=" + [System.Web.HttpUtility]::UrlEncode($data)
     
      $request = [System.Net.WebRequest]::Create($url)
      $request.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
      if ($request.Proxy -ne $null) {
         $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
      }
      $request.ContentType = "application/x-www-form-urlencoded"
      $request.ContentLength = $data.Length
      $request.Method = "POST"
 
      $post = new-object IO.StreamWriter $request.GetRequestStream()
      $post.Write($data)
      $post.Flush()
      $post.Close()
 
      # $reader = new-object IO.StreamReader $request.GetResponse().GetResponseStream() ##,[Text.Encoding]::UTF8
      # write-output $reader.ReadToEnd()
      # $reader.Close()
      write-output $request.GetResponse().ResponseUri.AbsoluteUri
      $request.Abort()
   }
}
PROCESS {
   $EAP = $ErrorActionPreference
   $ErrorActionPreference = "SilentlyContinue"
   if(Test-Path $Path -PathType Leaf) {
      $ErrorActionPreference = $EAP
      Write-Verbose $Path
      Write-Output $(Send-PoshCode $meta $Title $([string]::join("`n",(Get-Content $Path))) $url)
   } elseif(Test-Path $Path -PathType Container) {
      $ErrorActionPreference = $EAP
      Write-Error "Can't upload folders yet: $Path"
   } else { ## Todo, handle folders?
      $ErrorActionPreference = $EAP
      if(!$data -and !$Title){
         $Title = Read-Host "Give us a title for your post"
      }
      $data += "`n" + $Path
   }
}
END {
   if($data) { 
      Write-Output $(Send-PoshCode $meta $Title $data $url)
   }
}
}

function Get-PoshCode {
<#
.SYNOPSIS
   Search for and/or download scripts from PoshCode.org
.DESCRIPTION	
	Search PoshCode.org by search terms, and returns a list of results, Or download a specific script by ID and output the contents or save to file.
.LINK
	http://www.poshcode.org
.EXAMPLE
	C:\PS>Get-PoshCode Authenticode 
       This command searches the repository for scripts dealing with Authenticode, and list the results
       Normally, you will take one of those IDs and do this:
.EXAMPLE
	C:\PS>Get-PoshCode 456
       This command will download the script with the ID of 456 and save it to file (based on it's name/contents)
.EXAMPLE
	C:\PS>Get-PoshCode 456 -passthru 
       Thi command outputs the contents of that script into the pipeline, so eg:
       (Get-PoshCode 456 -passthru) -replace "AuthenticodeSignature","SillySig"
.EXAMPLE
	C:\PS>Get-PoshCode 456 $ProfileDir\Authenticode.psm1
       This command downloads the script saving it as the name specified.
.EXAMPLE
	C:\PS>Get-PoshCode SCOM | Get-PoshCode
       This command searches the repository for all scripts about SCOM, and then downloads them!
.PARAMETER Path
	Specifies the path to an item.
.PARAMETER Description
	Sets the free-text summary of the script that will be displayed on the poshcode page for the script. 
.PARAMETER Author
	Specifies the author of the script that is being submitted.
.PARAMETER Language
	Specifies the language of the script that is being submitted.
.PARAMETER Keep
	Specifies how long to keep scripts on the poshcode.org site. Possible values are 'day', 'month', or 'forever'.
.PARAMETER Title
	Specifies the title of the script that is being submitted. 
.PARAMETER URL
.NOTES
	All search terms are automatically surrounded with wildcards.
 	History:
	 v 3.10 - Fixed a typo
	 v 3.9  - Fixed and put back the Set-DownloadFlag code
    v 3.7  - Removed the Set-DownloadFlag code because it was throwing on Windows 7:
             "Attempted to read or write protected memory."
	 v 3.4  - Add "-Language" parameter to force PowerShell only, fix upgrade to leave INVALID as .psm1
	 v 3.2  - Add "-Upgrade" switch to cause the script to upgrade itself.
	 v 3.1  - Add "Huddled.PoshCode.ScriptInfo" to TypeInfo, so it can be formatted by a ps1xml
  	        - Add ConvertTo-Module function to try to rename .ps1 scripts to .psm1 
	        - Fixed exceptions thrown by searches which return no results
	        - Removed the auto-wildcards!!!!
	           NOTE: to get the same results as before you must now put * on the front and end of searches
	           This is so that searches on the website work the same as searches here...
	           My intention is to improve the website's search instead of leaving this here.
	           NOTE: the website currently will not search for words less than 4 characters long
	 v 3.0  - Working against the new RSS-based API
	        - And using ParameterSets, which work in CTP2
    v 2.0  - Combined with Find-Poshcode into a single script
    v 1.0  - Working against our special pastebin
         
#>
[CmdletBinding(DefaultParameterSetName="Download")]
   PARAM(
      [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Search")]
      [string]$Query
,
      [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="Download" )]
      [int]$Id
,
      [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Upgrade")]
      [switch]$Upgrade
,
      [Parameter(Position=1, Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
      [Alias("FullName")]
      [string]$SaveAs
,
      [Parameter(Position=2, Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
      [ValidateSet('text','asp','bash','cpp','csharp','posh','vbnet','xml','all')]
      [string]$Language="posh"
,
      [switch]$InBrowser
,
      [switch]$Passthru
,
      [Parameter(Mandatory=$false)][string]$url= $($PoshCode)
   )
PROCESS {
   Write-Debug "ParameterSet Name: $($PSCmdlet.ParameterSetName)"
   if($Language -eq 'all') { $Language = "" }
   switch($PSCmdlet.ParameterSetName) {
      "Search" {
         $results = @(([xml](Get-WebFile "$($url)api$($PoshCode.ApiVersion)/$($query)&lang=$($Language)" -passthru)).rss.channel.GetElementsByTagName("item"))
         if($results.Count -eq 0 ) {
            Write-Host "Zero Results for '$query'" -Fore Red -Back Black
         } 
         else {
            $results | Select @{ n="Id";e={$($_.link -replace $url,'') -as [int]}},
                @{n="Title";e={$_.title}},
                @{n="Author";e={$_.creator}},
                @{n="Date";e={$_.pubDate }},
                @{n="Link";e={$_.guid.get_InnerText() }},
                @{n="Web";e={$_.Link}},
                @{n="Description";e={"$($_.description.get_InnerText())`n" }} |
            ForEach { $_.PSObject.TypeNames.Insert( 0, "Huddled.PoshCode.ScriptInfo" ); $_ }
         }
      }
      "Download" {
         if(!$InBrowser) {
            if($Passthru) {
               Get-WebFile "$($url)?dl=$id" -Passthru
            } 
            elseif($SaveAs) {
               Get-WebFile "$($url)?dl=$id" -fileName $SaveAs | ConvertTo-Module | Set-DownloadFlag -Passthru
            } 
            else {
               Get-WebFile "$($url)?dl=$id" | ConvertTo-Module | Set-DownloadFlag -Passthru
            }
         } 
         else {
            [Diagnostics.Process]::Start( "$($url)$id" )
         }
      }
      "Upgrade" { 
         Get-PoshCodeUpgrade
      }
   }
}
}

function Get-PoshCodeUpgrade {
<#
.SYNOPSIS
	Downloads a new PoshCode module and archives the old version(s).
.LINK
	http://www.poshcode.org
.EXAMPLE
	C:\PS>Get-PoshCodeUpgrade
	This command gets the most recent version of the PoshCode module
.NOTES
	History:
		v3.9 - Fixed and put back the Remove-DownloadFlag
      v3.8 - Switched "Add-Module" to "Import-Module" to make it CTP3+ compatible.
		v3.7 - Removed the Set-DownloadFlag code because it was throwing on Windows 7:
             "Attempted to read or write protected memory."
		v3.3 - Removes old versions, and checks the signature.
		v3.2 - First script version with Upgrade function
#>
[CmdletBinding()]param()

   $VersionFile = [IO.Path]::ChangeExtension( $PoshCode.ScriptLocation,
                  ("{0}{1}" -f  $PoshCode.ScriptVersion, [IO.Path]::GetExtension($PoshCode.ScriptLocation)))
   # Copy it to make sure we don't loose it
   Copy-Item $PoshCode.ScriptLocation $VersionFile
   # Remove old ones ...
   Remove-Item (  [IO.Path]::ChangeExtension( $PoshCode.ScriptLocation, 
                  ".*$([IO.Path]::GetExtension( $($PoshCode.ScriptLocation) ))") 
               ) -exclude ([IO.Path]::GetFileName($VersionFile)) -Confirm
   # Finally, get the new one
   $NewFile = Get-WebFile "$($PoshCode)PoshCode.psm1" -fileName (
                          [IO.Path]::ChangeExtension( $PoshCode.ScriptLocation, ".INVALID.ps1"))
   if( Test-Signature -File $NewFile )
   {
      Move-Item $NewFile $PoshCode.ScriptLocation -Force -passthru | Remove-DownloadFlag -Passthru
      Import-Module $($PoshCode.ModuleName) -Force
   } 
   else { 
      Write-Error "Signature is Not Valid on new version."
      Move-Item $NewFile ([IO.Path]::ChangeExtension( $PoshCode.ScriptLocation, ".INVALID.psm1"))
      Get-Item ([IO.Path]::ChangeExtension( $PoshCode.ScriptLocation, ".INVALID.psm1"))
   }
}

## Test-Signature - Returns true if the signature is valid OR is signed by:
## "4F8842037D878C1FCDC6FD1313B200449716C353" OR "7DEFA3C6C2138C05AAA135FB8096332DEB9603E1"
function Test-Signature {
[CmdletBinding(DefaultParameterSetName="File")]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="Signature")]
   #  We can't actually require the type, or we won't be able to check the fake ones from Joel's Authenticode module
   #  [System.Management.Automation.Signature]
   $Signature
,  [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="File")]
   [System.IO.FileInfo]
   $File
)
PROCESS {
   if($File -and (Test-Path $File -PathType Leaf)) {
      $Signature = Get-AuthenticodeSignature $File
   }
   if(!$Signature) { return $false } else {
      $result = $false;
      try {
         $result = ((($Signature.Status -eq "UnknownError") -and $Signature.SignerCertificate -and
                                          (($Signature.SignerCertificate.Thumbprint -eq "4F8842037D878C1FCDC6FD1313B200449716C353") -or
                     ($Signature.SignerCertificate.Thumbprint -eq "7DEFA3C6C2138C05AAA135FB8096332DEB9603E1"))
                    ) -or $Signature.Status -eq "Valid" )
      } catch { } finally { return $result }
   }
}
}

filter ConvertTo-Module {
   $oldFile  = $_
   if( ([IO.Path]::GetExtension($oldFile) -eq ".ps1") -and 
         [Regex]::Match( [IO.File]::ReadAllText($oldFile), 
              "^[^#]*Export-ModuleMember.*", "MultiLine").Success )
   { 
      $fileName = [IO.Path]::ChangeExtension($oldFile, ".psm1")
      Move-Item $oldFile $fileName -Force
      Get-Item $fileName
   } else { Get-Item $oldFile } 
}

## Get-WebFile (aka wget for PowerShell)
function Get-WebFile {
#.Synopsis
#  Downloads a file or page from the web
#.Description
#  Creates an HttpWebRequest to download a web file
#.Parameter URL
#  The URL of the file/page to download
#.Parameter FileName
#  A Path to save the downloaded content. 
#  Defaults to the current directory and the name of the download.
#  You may specify just a folder name to use the source name as the file name.
#.Parameter Passthru
#  Rather than saving the downloaded content to a file, output it.  
#  This is for text documents like web pages and rss feeds, and allows you to avoid temporarily caching the text in a file.
#.Parameter Quiet
#  Supresses the Write-Progress during download
#.Parameter UserAgent
#  Text to include at the front of the UserAgent string
#  Defaults to PoshCode/3.2 (where 3.2 is the version of the script)
#.Example
#  Get-WebFile http://PoshCode.org/PoshCode.psm1
#
#  Downloads the latest version of this file to the current directory
#.Example
#  Get-WebFile http://PoshCode.org/PoshCode.psm1 ~\Documents\WindowsPowerShell\Modules\PoshCode\
#
#  Downloads the latest version of this file to a PoshCode module directory...
#.Example
#  $RssItems = @(([xml](Get-WebFile http://poshcode.org/api/ -passthru)).rss.channel.GetElementsByTagName("item"))
#
#  Returns the most recent items from the PoshCode.org RSS feed
#.Notes
#  History:
#  v3.12 - Added full help
#  v3.9 - Fixed and replaced the Set-DownloadFlag
#  v3.7 - Removed the Set-DownloadFlag code because it was throwing on Windows 7:
#         "Attempted to read or write protected memory."
#  v3.6.6 Add UserAgent calculation and parameter
#  v3.6.5 Add file-name guessing and cleanup
#  v3.6 - Add -Passthru switch to output TEXT files 
#  v3.5 - Add -Quiet switch to turn off the progress reports ...
#  v3.4 - Add progress report for files which don't report size
#  v3.3 - Add progress report for files which report their size
#  v3.2 - Use the pure Stream object because StreamWriter is based on TextWriter:
#         it was messing up binary files, and making mistakes with extended characters in text
#  v3.1 - Unwrap the filename when it has quotes around it
#  v3   - rewritten completely using HttpWebRequest + HttpWebResponse to figure out the file name, if possible
#  v2   - adds a ton of parsing to make the output pretty
#         added measuring the scripts involved in the command, (uses Tokenizer)
[CmdletBinding()]
   param(
      [Parameter(Mandatory=$true,Position=0)]
      [string]$Url # = (Read-Host "The URL to download")
   ,
      [string]$FileName
   ,
      [switch]$Passthru,
      [switch]$Quiet,
      [string]$UserAgent = "PoshCode/$($PoshCode.ScriptVersion)"      
   )

   Write-Verbose "Downloading '$url'"

   $request = [System.Net.HttpWebRequest]::Create($url);
   $request.UserAgent = $(
         "{0} (PowerShell {1}; .NET CLR {2}; {3}; http://PoshCode.org)" -f $UserAgent, 
         $(if($Host.Version){$Host.Version}else{"1.0"}),
         [Environment]::Version,
         [Environment]::OSVersion.ToString().Replace("Microsoft Windows ", "Win")
      ) 
   if($request.Proxy -ne $null) {
      $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
   }

   try {
      $res = $request.GetResponse();
   } catch [System.Net.WebException] { 
      Write-Error $_.Exception -Category ResourceUnavailable
      return
   }
 
   if((Test-Path variable:res) -and $res.StatusCode -eq 200) {
      if($fileName -and !(Split-Path $fileName)) {
         $fileName = Join-Path (Convert-Path (Get-Location -PSProvider "FileSystem")) $fileName
      }
      elseif((!$Passthru -and !$fileName) -or ($fileName -and (Test-Path -PathType "Container" $fileName)))
      {
         [string]$fileName = ([regex]'(?i)filename=(.*)$').Match( $res.Headers["Content-Disposition"] ).Groups[1].Value
         $fileName = $fileName.trim("\/""'")
         
         $ofs = ""
         $fileName = [Regex]::Replace($fileName, "[$([Regex]::Escape(""$([System.IO.Path]::GetInvalidPathChars())$([IO.Path]::AltDirectorySeparatorChar)$([IO.Path]::DirectorySeparatorChar)""))]", "_")
         $ofs = " "
         
         if(!$fileName) {
            $fileName = $res.ResponseUri.Segments[-1]
            $fileName = $fileName.trim("\/")
            if(!$fileName) { 
               $fileName = Read-Host "Please provide a file name"
            }
            $fileName = $fileName.trim("\/")
            if(!([IO.FileInfo]$fileName).Extension) {
               $fileName = $fileName + "." + $res.ContentType.Split(";")[0].Split("/")[1]
            }
         }
         $fileName = Join-Path (Convert-Path (Get-Location -PSProvider "FileSystem")) $fileName
      }
      if($Passthru) {
         $encoding = [System.Text.Encoding]::GetEncoding( $res.CharacterSet )
         [string]$output = ""
      }
 
      [int]$goal = $res.ContentLength
      $reader = $res.GetResponseStream()
      if($fileName) {
         $writer = new-object System.IO.FileStream $fileName, "Create"
      }
      [byte[]]$buffer = new-object byte[] 4096
      [int]$total = [int]$count = 0
      do
      {
         $count = $reader.Read($buffer, 0, $buffer.Length);
         if($fileName) {
            $writer.Write($buffer, 0, $count);
         } 
         if($Passthru){
            $output += $encoding.GetString($buffer,0,$count)
         } elseif(!$quiet) {
            $total += $count
            if($goal -gt 0) {
               Write-Progress "Downloading $url" "Saving $total of $goal" -id 0 -percentComplete (($total/$goal)*100)
            } else {
               Write-Progress "Downloading $url" "Saving $total bytes..." -id 0
            }
         }
      } while ($count -gt 0)
      
      $reader.Close()
      if($fileName) {
         $writer.Flush()
         $writer.Close()
      }
      if($Passthru){
         $output
      }
   }
   if(Test-Path variable:res) { $res.Close(); }
   if($fileName) {
      Set-DownloadFlag $fileName -PassThru
   }
}

$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

function Set-DownloadFlag {
<#
.Synopsis
	Sets the ZoneTransfer flag which marks a file as being downloaded from the internet.
.Description
	Creates a Zone.Identifier alternate data stream (on NTFS file systems) and writes the ZoneTransfer marker
.Parameter Path
	The file you wish to block
.Parameter Passthru
	If set, outputs the FileInfo object
.Parameter ZoneId
   THe Zone you want to mark the file with. Defaults to 4
#>
[CmdletBinding()]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]
   $Path
,
   [Parameter(Position=1, Mandatory=$false)]
   [ZoneIdentifier]$Zone = "Untrusted"
,
   [Switch]$Passthru
)
PROCESS {

   $FS = new-object PoshCodeNTFS.FileStreams($Path)
   $null = $fs.add('Zone.Identifier')
   $stream = $fs.Item('Zone.Identifier').open()

   $sw = [System.IO.streamwriter]$stream
   $Sw.writeline('[ZoneTransfer]')
   $sw.writeline("ZoneID=$([Int]$zone)")
   $sw.close()
   $stream.close()
   if($Passthru){ Get-ChildItem $Path }
}
}

function Remove-DownloadFlag {
<#
.Synopsis
	Removes the ZoneTransfer flag which marks a file as being downloaded from the internet.
.Description
	Deletes the Zone.Identifier alternate data stream (on NTFS file systems)
.Parameter Path
	The file you wish to block
.Parameter Passthru
	If set, outputs the FileInfo object
#>
[CmdletBinding()]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]
   $Path
,
   [Switch]$Passthru
)
PROCESS {
   Remove-Stream -Path $Path -Name 'Zone.Identifier'
   if($Passthru){ Get-ChildItem $Path }
}
}

function Get-DownloadFlag {
<#
.Synopsis
	Verify whether the ZoneTransfer flag is set (marking this file as one downloaded from the internet).
.Description
	Reads the Zone.Identifier alternate data stream (on NTFS file systems)
.Parameter Path
	The file you wish to check the ZoneTransfer flag on
#>
[CmdletBinding()]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]
   $Path
)
Process { 
   $FS = new-object PoshCodeNTFS.FileStreams($Path)
   if(!$fs.Item('Zone.Identifier') ) {
      Write-Warning "Zone.Identifier not set on $Path (no Download Flag). This is the equivalent of a 'Trusted' flag."
      return
   }
   
   $reader = [System.IO.streamreader]$fs.Item('Zone.Identifier').open()
   try {
      do { 
         $line = $reader.ReadLine()
      } until (!$line -OR $line -eq '[ZoneTransfer]')
      $out = new-object PSObject
      while($zone = $reader.ReadLine()) {
         $zone = $zone -split "="
         if($zone.Count -lt 2) { break }
         Add-Member -in $out -Type NoteProperty -Name $zone[0] -value ([ZoneIdentifier]$zone[1])
      }
      $out
   } finally {
      $reader.close()
   }
}
}

function Test-DownloadFlag {
<#
.Synopsis
	Verify whether the ZoneTransfer flag is set (marking this file as one downloaded from the internet).
.Description
	Reads the Zone.Identifier alternate data stream (on NTFS file systems)
.Parameter Path
	The file you wish to check the ZoneTransfer flag on
#>
[CmdletBinding()]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]
   $Path
)
Process { 
   Get-ChildItem $Path | Select Name, @{N="Downloaded";E={ [bool]((new-object PoshCodeNTFS.FileStreams($_)).Item('Zone.Identifier')) } }, FullName, Length
}
}

function Normalize-StreamName {
   PARAM($Path,$StreamName)
   if(!$StreamName -and !(Test-Path $Path -EA 0)) { 
      $Path, $Segment, $StreamName = $Path -split ":"
      if($StreamName -or (Test-Path ($Path,$Segment -join ":") -EA 0)) {
         $Path = $Path,$Segment -join ":" 
      } else {
         $StreamName = $Segment
      }
   }
   return $Path,$StreamName
}

function Get-Stream {
<#
.Synopsis
	Get the list of alternate NTFS Streams
.Description
	Reads the named alternate data stream on NTFS file systems.
.Parameter Path
	The file you wish to read from. You may include the stream name in the format:
   C:\Path\File.extension:stream name
.Parameter Stream
   The name of the stream you wish to read from. If you pass this as a separate parameter, you should NOT include it in the Path.
#>
[CmdletBinding()]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
   [Alias("FullName")]
   [string]
   $Path
,
   [Parameter(Position=1,Mandatory=$false)]
   [Alias("Name")][string]$StreamName  
,
   [Parameter()]
   [Switch]$Force
)
Process { 
   $Path,$Stream = Normalize-StreamName $Path $StreamName
   
   Write-Verbose "Path: $Path"
   Write-Verbose "Stream: $Stream"
   ForEach($file in Get-ChildItem $Path) {
      $FS = new-object PoshCodeNTFS.FileStreams($file)
      Write-Verbose "File: $File"
   
      if(!$Stream) {
         $FS
      } else {
         $FS | Where { $_.StreamName -like $Stream } | Tee -Var Output
         if($Force -and -not $Output) {
            $FS.add($Stream) > $null
            $FS.Item($Stream)
         }
      }
   }
}
}

function Get-StreamContent {
<#
.Synopsis
	Get the contents of a named NTFS Stream
.Description
	Reads the named alternate data stream (on NTFS file systems)
.Parameter StreamInfo
   A StreamInfo object for the stream you want to get the content of.
.Parameter Path
	The file to read from. You may include the stream name in the format:
   C:\Path\File.extension:stream name
.Parameter StreamName
   The name of the stream you wish to read from. If you pass this as a separate parameter, you should NOT include it in the Path.
#>
[CmdletBinding(DefaultParameterSetName="ByStream")]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="ByName")]
   [Alias("FullName")][string]$Path
,
   [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="ByStream")]
   [PoshCodeNTFS.StreamInfo]$StreamInfo
,
   [Parameter(Position=1, Mandatory=$false, ParameterSetName="ByName")]
   [Alias("Name")][string]$StreamName
)
Process {
   switch($PSCmdlet.ParameterSetName) {
      "ByName" {
         Get-Stream $Path $StreamName | Get-StreamContent
      }
      "ByStream" {
         $fileStream = $StreamInfo.open()
         $reader = [System.IO.StreamReader]$fileStream
         $reader.ReadToEnd()
         $fileStream.close()
      }
   }
}
}

function Remove-Stream {
<#
.Synopsis
	Remove a stream from a file (or, delete the file).
.Description
	Deletes the named alternate data stream (on NTFS file systems)
.Parameter StreamInfo
   A StreamInfo object for the stream you want to get the content of.
.Parameter Path
	The file to delete from. You may include the stream name in the format:
   "C:\Path\File.extension:stream name"
.Parameter StreamName
   The name of the stream you wish to remove. If you pass this as a separate parameter, you should NOT include it in the Path.
#>
[CmdletBinding(DefaultParameterSetName="ByStream")]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="ByName")]
   [Alias("FullName")][string]$Path
,
   [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="ByStream")]
   [PoshCodeNTFS.StreamInfo]$StreamInfo
,
   [Parameter(Position=1, Mandatory=$false, ParameterSetName="ByName")]
   [Alias("Name")][string]$StreamName
)
Process {
   switch($PSCmdlet.ParameterSetName) {
      "ByName" {
         foreach($StreamInfo in Get-Stream $Path $StreamName) {
            Write-Verbose $($StreamInfo |Out-String)
            $StreamInfo.Delete() > $null
         }
      }
      "ByStream" {
         $StreamInfo.Delete() > $null
      }
   }
}
}

function Set-StreamContent {
<#
.Synopsis
	Set the contents of a named NTFS Stream
.Description
	Sets the content of the named alternate data stream (on NTFS file systems)
.Parameter StreamInfo
   A StreamInfo object for the stream you want to set the content of.
.Parameter Path
	The file to set content on. You may include the stream name in the format:
   "C:\Path\File.extension:stream name"
.Parameter StreamName
   The name of the stream you wish to set. If you pass this as a separate parameter, you should NOT include it in the Path.
#>
[CmdletBinding(DefaultParameterSetName="ByStream")]
PARAM (
   [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="ByName")]
   [Alias("FullName")][string]$Path
,
   [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="ByStream")]
   [PoshCodeNTFS.StreamInfo]$StreamInfo
,
   [Parameter(Position=1, Mandatory=$false, ParameterSetName="ByName")]
   [Alias("Name")][string]$StreamName
, 
   [Parameter(Position=2, Mandatory=$true)]
   [String]$Value
)
Process {
   switch($PSCmdlet.ParameterSetName) {
      "ByName" {
         Write-Verbose "Path: $Path"
         Get-Stream $Path $StreamName -Force | Set-StreamContent -Value $Value
      }
      "ByStream" {
         $writer =[System.IO.streamwriter] $StreamInfo.Open()
         $writer.Write($value)
         $writer.close()
      }
   }
}
}


Add-Type -TypeDefinition @'
public enum PoshCodeLanguage {
   asp,                       
   bash,
   csharp,
   posh,
   vbnet,
   xml,
   text
}
'@

Add-Type -TypeDefinition @'
public enum ZoneIdentifier {
   Trusted = 1,
   Intranet = 2,
   Internet = 3,
   Untrusted = 4
}
'@

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;


///<summary>
///Encapsulates access to alternative data streams of an NTFS file.
///Adapted from a C++ sample by Dino Esposito,
///http://msdn.microsoft.com/library/default.asp?url=/library/en-us/dnfiles/html/ntfs5.asp
///</summary>
namespace PoshCodeNTFS {
   /// <summary>
   /// Wraps the API functions, structures and constants.
   /// </summary>
   internal class Kernel32 
   {
      public const char STREAM_SEP = ':';
      public const int INVALID_HANDLE_VALUE = -1;
      public const int MAX_PATH = 256;
      
      [Flags()] public enum FileFlags : uint
      {
         WriteThrough = 0x80000000,
         Overlapped = 0x40000000,
         NoBuffering = 0x20000000,
         RandomAccess = 0x10000000,
         SequentialScan = 0x8000000,
         DeleteOnClose = 0x4000000,
         BackupSemantics = 0x2000000,
         PosixSemantics = 0x1000000,
         OpenReparsePoint = 0x200000,
         OpenNoRecall = 0x100000
      }

      [Flags()] public enum FileAccessAPI : uint
      {
         GENERIC_READ = 0x80000000,
         GENERIC_WRITE = 0x40000000
      }
      /// <summary>
      /// Provides a mapping between a System.IO.FileAccess value and a FileAccessAPI value.
      /// </summary>
      /// <param name="Access">The <see cref="System.IO.FileAccess"/> value to map.</param>
      /// <returns>The <see cref="FileAccessAPI"/> value.</returns>
      public static FileAccessAPI Access2API(FileAccess Access) 
      {
         FileAccessAPI lRet = 0;
         if ((Access & FileAccess.Read)==FileAccess.Read) lRet |= FileAccessAPI.GENERIC_READ;
         if ((Access & FileAccess.Write)==FileAccess.Write) lRet |= FileAccessAPI.GENERIC_WRITE;
         return lRet;
      }

      [StructLayout(LayoutKind.Sequential)] public struct LARGE_INTEGER 
      {
         public int Low;
         public int High;

         public long ToInt64() 
         {
            return (long)High * 4294967296 + (long)Low;
         }
      }

      [StructLayout(LayoutKind.Sequential)] public struct WIN32_STREAM_ID 
      {
         public int dwStreamID;
         public int dwStreamAttributes;
         public LARGE_INTEGER Length;
         public int dwStreamNameLength;
      }
      
      [DllImport("kernel32")] public static extern SafeFileHandle CreateFile(string Name, FileAccessAPI Access, FileShare Share, int Security, FileMode Creation, FileFlags Flags, int Template);
      [DllImport("kernel32")] public static extern bool DeleteFile(string Name);
      [DllImport("kernel32")] public static extern bool CloseHandle(SafeFileHandle hObject);

      [DllImport("kernel32")] public static extern bool BackupRead(SafeFileHandle hFile, IntPtr pBuffer, int lBytes, ref int lRead, bool bAbort, bool bSecurity, ref int Context);
      [DllImport("kernel32")] public static extern bool BackupRead(SafeFileHandle hFile, ref WIN32_STREAM_ID pBuffer, int lBytes, ref int lRead, bool bAbort, bool bSecurity, ref int Context);
      [DllImport("kernel32")] public static extern bool BackupSeek(SafeFileHandle hFile, int dwLowBytesToSeek, int dwHighBytesToSeek, ref int dwLow, ref int dwHigh, ref int Context);
   }

   /// <summary>
   /// Encapsulates a single alternative data stream for a file.
   /// </summary>
   public class StreamInfo 
   {
      private FileStreams _parent;
      private string _name;
      private long _length;

      internal StreamInfo(FileStreams Parent, string Name, long Length) 
      {
         _parent = Parent;
         _name = Name;
         _length = Length;
      }

      /// <summary>
      /// The name of the file.
      /// </summary>
      public string FileName 
      {
         get { return System.IO.Path.GetFileName(_parent.FileName); }
      }
      
      /// <summary>
      /// The name of the stream.
      /// </summary>
      public string StreamName 
      {
         get { return _name; }
      }
      
      /// <summary>
      /// The length (in bytes) of the stream.
      /// </summary>
      public long Length 
      {
         get { return _length; }
      }
      
      public override string ToString() 
      {
		 if(String.IsNullOrEmpty(_name)) {
			return _parent.FileName;
		 } else {
			return String.Format("{1}{0}{2}", Kernel32.STREAM_SEP, _parent.FileName, _name);
		 }
      }

      public override bool Equals(Object o) 
      {
         if (o is StreamInfo) 
         {
            StreamInfo f = (StreamInfo)o;
            return (f._name.Equals(_name) && f._parent.Equals(_parent));
         }
         else if (o is string) 
         {
            return ((string)o).Equals(ToString());
         }
         else
            return base.Equals(o);
      }
      public override int GetHashCode() 
      {
         return ToString().GetHashCode();
      }

#region Open
      /// <summary>
      /// Opens or creates the stream in read-write mode, with no sharing.
      /// </summary>
      /// <returns>A <see cref="System.IO.FileStream"/> wrapper for the stream.</returns>
      public FileStream Open() 
      {
         return Open(FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
      }
      /// <summary>
      /// Opens or creates the stream in read-write mode with no sharing.
      /// </summary>
      /// <param name="Mode">The <see cref="System.IO.FileMode"/> action for the stream.</param>
      /// <returns>A <see cref="System.IO.FileStream"/> wrapper for the stream.</returns>
      public FileStream Open(FileMode Mode) 
      {
         return Open(Mode, FileAccess.ReadWrite, FileShare.None);
      }
      /// <summary>
      /// Opens or creates the stream with no sharing.
      /// </summary>
      /// <param name="Mode">The <see cref="System.IO.FileMode"/> action for the stream.</param>
      /// <param name="Access">The <see cref="System.IO.FileAccess"/> level for the stream.</param>
      /// <returns>A <see cref="System.IO.FileStream"/> wrapper for the stream.</returns>
      public FileStream Open(FileMode Mode, FileAccess Access) 
      {
         return Open(Mode, Access, FileShare.None);
      }
      /// <summary>
      /// Opens or creates the stream.
      /// </summary>
      /// <param name="Mode">The <see cref="System.IO.FileMode"/> action for the stream.</param>
      /// <param name="Access">The <see cref="System.IO.FileAccess"/> level for the stream.</param>
      /// <param name="Share">The <see cref="System.IO.FileShare"/> level for the stream.</param>
      /// <returns>A <see cref="System.IO.FileStream"/> wrapper for the stream.</returns>
      public FileStream Open(FileMode Mode, FileAccess Access, FileShare Share) 
      {
         try 
         {
			if(String.IsNullOrEmpty(_name)) {
				return new FileStream(ToString(), Mode, Access, Share);
			} else {
				SafeFileHandle hFile = Kernel32.CreateFile(ToString() + Kernel32.STREAM_SEP + "$DATA", Kernel32.Access2API(Access), Share, 0, Mode, 0, 0);
				return new FileStream(hFile, Access);
			}
         }
         catch 
         {
            return null;
         }
      }
#endregion

#region Delete
      /// <summary>
      /// Deletes the stream from the file.
      /// </summary>
      /// <returns>A <see cref="System.Boolean"/> value: true if the stream was deleted, false if there was an error.</returns>
      public bool Delete() 
      {
         return Kernel32.DeleteFile(ToString());
      }
#endregion
   }


   /// <summary>
   /// Encapsulates the collection of alternative data streams for a file.
   /// A collection of <see cref="StreamInfo"/> objects.
   /// </summary>
   public class FileStreams : CollectionBase 
   {
      private FileInfo _file;

#region Constructors
      public FileStreams(string File) 
      {
         _file = new FileInfo(File);
         initStreams();
      }
      public FileStreams(FileInfo file) 
      {
         _file = file;
         initStreams();
      }

      /// <summary>
      /// Reads the streams from the file.
      /// </summary>
      private void initStreams() 
      {
		 base.List.Add(new StreamInfo(this,String.Empty,_file.Length));
		 
         //Open the file with backup semantics
         SafeFileHandle hFile = Kernel32.CreateFile(_file.FullName, Kernel32.FileAccessAPI.GENERIC_READ, FileShare.Read, 0, FileMode.Open, Kernel32.FileFlags.BackupSemantics, 0);
         if (hFile.IsInvalid) return;

         try 
         {
            Kernel32.WIN32_STREAM_ID sid = new Kernel32.WIN32_STREAM_ID();
            int dwStreamHeaderLength = Marshal.SizeOf(sid);
            int Context = 0;
            bool Continue = true;
            while (Continue) 
            {
               //Read the next stream header
               int lRead = 0;
               Continue = Kernel32.BackupRead(hFile, ref sid, dwStreamHeaderLength, ref lRead, false, false, ref Context);
               if (Continue && lRead == dwStreamHeaderLength) 
               {
                  if (sid.dwStreamNameLength>0) 
                  {
                     //Read the stream name
                     lRead = 0;
                     IntPtr pName = Marshal.AllocHGlobal(sid.dwStreamNameLength);
                     try 
                     {
                        Continue = Kernel32.BackupRead(hFile, pName, sid.dwStreamNameLength, ref lRead, false, false, ref Context);
                        char[] bName = new char[sid.dwStreamNameLength];
                        Marshal.Copy(pName,bName,0,sid.dwStreamNameLength);

                        //Name is of the format ":NAME:$DATA\0"
                        string sName = new string(bName);
                        int i = sName.IndexOf(Kernel32.STREAM_SEP, 1);
                        if (i>-1) sName = sName.Substring(1, i-1);
                        else 
                        {
                           //This should never happen. 
                           //Truncate the name at the first null char.
                           i = sName.IndexOf('\0');
                           if (i>-1) sName = sName.Substring(1, i-1);
                        }

                        //Add the stream to the collection
                        base.List.Add(new StreamInfo(this,sName,sid.Length.ToInt64()));
                     }
                     finally 
                     {
                        Marshal.FreeHGlobal(pName);
                     }
                  }

                  //Skip the stream contents
                  int l = 0; int h = 0;
                  Continue = Kernel32.BackupSeek(hFile, sid.Length.Low, sid.Length.High, ref l, ref h, ref Context);
               }
               else break;
            }
         }
         finally 
         {
            Kernel32.CloseHandle(hFile);
         }
      }
#endregion

#region File
      /// <summary>
      /// Returns the <see cref="System.IO.FileInfo"/> object for the wrapped file. 
      /// </summary>
      public FileInfo FileInfo 
      {
         get { return _file; }
      }
      /// <summary>
      /// Returns the full path to the wrapped file.
      /// </summary>
      public string FileName 
      {
         get { return _file.FullName; }
      }

      /// <summary>
      /// Returns the length of the main data stream, in bytes.
      /// </summary>
      public long Length {
         get {return _file.Length;}
      }

      /// <summary>
      /// Returns the length of all streams for the file, in bytes.
      /// </summary>
      public long FullLength
      {
         get 
         {	// don't initialize with "this.Length" anymore, because we include the default stream now
            long length = 0; 
            foreach (StreamInfo s in this) length += s.Length;
            return length;
         }
      }
#endregion

#region Open
      /// <summary>
      /// Opens or creates the default file stream.
      /// </summary>
      /// <returns><see cref="System.IO.FileStream"/></returns>
      public FileStream Open() 
      {
         return new FileStream(_file.FullName, FileMode.OpenOrCreate);
      }

      /// <summary>
      /// Opens or creates the default file stream.
      /// </summary>
      /// <param name="Mode">The <see cref="System.IO.FileMode"/> for the stream.</param>
      /// <returns><see cref="System.IO.FileStream"/></returns>
      public FileStream Open(FileMode Mode) 
      {
         return new FileStream(_file.FullName, Mode);
      }

      /// <summary>
      /// Opens or creates the default file stream.
      /// </summary>
      /// <param name="Mode">The <see cref="System.IO.FileMode"/> for the stream.</param>
      /// <param name="Access">The <see cref="System.IO.FileAccess"/> for the stream.</param>
      /// <returns><see cref="System.IO.FileStream"/></returns>
      public FileStream Open(FileMode Mode, FileAccess Access) 
      {
         return new FileStream(_file.FullName, Mode, Access);
      }

      /// <summary>
      /// Opens or creates the default file stream.
      /// </summary>
      /// <param name="Mode">The <see cref="System.IO.FileMode"/> for the stream.</param>
      /// <param name="Access">The <see cref="System.IO.FileAccess"/> for the stream.</param>
      /// <param name="Share">The <see cref="System.IO.FileShare"/> for the stream.</param>
      /// <returns><see cref="System.IO.FileStream"/></returns>
      public FileStream Open(FileMode Mode, FileAccess Access, FileShare Share) 
      {
         return new FileStream(_file.FullName, Mode, Access, Share);
      }
#endregion

#region Delete
      /// <summary>
      /// Deletes the file, and all alternative streams.
      /// </summary>
      public void Delete() 
      {
         for (int i=base.List.Count;i>0;i--) 
         {
            base.List.RemoveAt(i);
         }
         _file.Delete();
      }
#endregion

#region Collection operations
      /// <summary>
      /// Add an alternative data stream to this file.
      /// </summary>
      /// <param name="Name">The name for the stream.</param>
      /// <returns>The index of the new item.</returns>
      public int Add(string Name) 
      {
         StreamInfo FSI = new StreamInfo(this, Name, 0);
         int i = base.List.IndexOf(FSI);
         if (i==-1) i = base.List.Add(FSI);
         return i;
      }
      /// <summary>
      /// Removes the alternative data stream with the specified name.
      /// </summary>
      /// <param name="Name">The name of the string to remove.</param>
      public void Remove(string Name) 
      {
         StreamInfo FSI = new StreamInfo(this, Name, 0);
         int i = base.List.IndexOf(FSI);
         if (i>-1) base.List.RemoveAt(i);
      }

      /// <summary>
      /// Returns the index of the specified <see cref="StreamInfo"/> object in the collection.
      /// </summary>
      /// <param name="FSI">The object to find.</param>
      /// <returns>The index of the object, or -1.</returns>
      public int IndexOf(StreamInfo FSI) 
      {
         return base.List.IndexOf(FSI);
      }
      /// <summary>
      /// Returns the index of the <see cref="StreamInfo"/> object with the specified name in the collection.
      /// </summary>
      /// <param name="Name">The name of the stream to find.</param>
      /// <returns>The index of the stream, or -1.</returns>
      public int IndexOf(string Name) 
      {
         return base.List.IndexOf(new StreamInfo(this, Name, 0));
      }

      public StreamInfo this[int Index] 
      {
         get { return (StreamInfo)base.List[Index]; }
      }
      public StreamInfo this[string Name] 
      {
         get 
         { 
            int i = IndexOf(Name);
            if (i==-1) return null;
            else return (StreamInfo)base.List[i];
         }
      }
#endregion

#region Overrides
      /// <summary>
      /// Throws an exception if you try to add anything other than a StreamInfo object to the collection.
      /// </summary>
      protected override void OnInsert(int index, object value) 
      {
         if (!(value is StreamInfo)) throw new InvalidCastException();
      }
      /// <summary>
      /// Throws an exception if you try to add anything other than a StreamInfo object to the collection.
      /// </summary>
      protected override void OnSet(int index, object oldValue, object newValue) 
      {
         if (!(newValue is StreamInfo)) throw new InvalidCastException();
      }

      /// <summary>
      /// Deletes the stream from the file when you remove it from the list.
      /// </summary>
      protected override void OnRemoveComplete(int index, object value) 
      {
         try 
         {
            StreamInfo FSI = (StreamInfo)value;
            if (FSI != null) FSI.Delete();
         }
         catch {}
      }

      public new StreamEnumerator GetEnumerator() 
      {
         return new StreamEnumerator(this);
      }
#endregion

#region StreamEnumerator
      public class StreamEnumerator : object, IEnumerator 
      {
         private IEnumerator baseEnumerator;
            
         public StreamEnumerator(FileStreams mappings) 
         {
            this.baseEnumerator = ((IEnumerable)(mappings)).GetEnumerator();
         }
            
         public StreamInfo Current 
         {
            get 
            {
               return ((StreamInfo)(baseEnumerator.Current));
            }
         }
            
         object IEnumerator.Current 
         {
            get 
            {
               return baseEnumerator.Current;
            }
         }
            
         public bool MoveNext() 
         {
            return baseEnumerator.MoveNext();
         }
            
         bool IEnumerator.MoveNext() 
         {
            return baseEnumerator.MoveNext();
         }
            
         public void Reset() 
         {
            baseEnumerator.Reset();
         }
            
         void IEnumerator.Reset() 
         {
            baseEnumerator.Reset();
         }
      }
#endregion
   }
}
'@


Set-Alias block Set-DownloadFlag
Set-Alias unblock Remove-DownloadFlag
Set-Alias Search-PoshCode Get-PoshCode

# Might want to also export:   Get-Stream, Get-StreamContent, Remove-Stream, Set-StreamContent -alias block, unblock

Export-ModuleMember Get-PoshCode, New-PoshCode, Remove-DownloadFlag, Set-DownloadFlag, Get-DownloadFlag, Test-DownloadFlag, Get-WebFile, Get-PoshCodeUpgrade -alias block, unblock, Search-PoshCode

# SIG # Begin signature block
# MIIRDAYJKoZIhvcNAQcCoIIQ/TCCEPkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNWz/vdYO89Kjl2S94gB2QVPf
# itGggg5CMIIHBjCCBO6gAwIBAgIBFTANBgkqhkiG9w0BAQUFADB9MQswCQYDVQQG
# EwJJTDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERp
# Z2l0YWwgQ2VydGlmaWNhdGUgU2lnbmluZzEpMCcGA1UEAxMgU3RhcnRDb20gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMDcxMDI0MjIwMTQ1WhcNMTIxMDI0MjIw
# MTQ1WjCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0YXJ0Q29tIEx0ZC4xKzAp
# BgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRlIFNpZ25pbmcxODA2BgNV
# BAMTL1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJbnRlcm1lZGlhdGUgT2JqZWN0
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyiOLIjUemqAbPJ1J
# 0D8MlzgWKbr4fYlbRVjvhHDtfhFN6RQxq0PjTQxRgWzwFQNKJCdU5ftKoM5N4YSj
# Id6ZNavcSa6/McVnhDAQm+8H3HWoD030NVOxbjgD/Ih3HaV3/z9159nnvyxQEckR
# ZfpJB2Kfk6aHqW3JnSvRe+XVZSufDVCe/vtxGSEwKCaNrsLc9pboUoYIC3oyzWoU
# TZ65+c0H4paR8c8eK/mC914mBo6N0dQ512/bkSdaeY9YaQpGtW/h/W/FkbQRT3sC
# pttLVlIjnkuY4r9+zvqhToPjxcfDYEf+XD8VGkAqle8Aa8hQ+M1qGdQjAye8OzbV
# uUOw7wIDAQABo4ICfzCCAnswDAYDVR0TBAUwAwEB/zALBgNVHQ8EBAMCAQYwHQYD
# VR0OBBYEFNBOD0CZbLhLGW87KLjg44gHNKq3MIGoBgNVHSMEgaAwgZ2AFE4L7xqk
# QFulF2mHMMo0aEPQQa7yoYGBpH8wfTELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0
# YXJ0Q29tIEx0ZC4xKzApBgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRl
# IFNpZ25pbmcxKTAnBgNVBAMTIFN0YXJ0Q29tIENlcnRpZmljYXRpb24gQXV0aG9y
# aXR5ggEBMAkGA1UdEgQCMAAwPQYIKwYBBQUHAQEEMTAvMC0GCCsGAQUFBzAChiFo
# dHRwOi8vd3d3LnN0YXJ0c3NsLmNvbS9zZnNjYS5jcnQwYAYDVR0fBFkwVzAsoCqg
# KIYmaHR0cDovL2NlcnQuc3RhcnRjb20ub3JnL3Nmc2NhLWNybC5jcmwwJ6AloCOG
# IWh0dHA6Ly9jcmwuc3RhcnRzc2wuY29tL3Nmc2NhLmNybDCBggYDVR0gBHsweTB3
# BgsrBgEEAYG1NwEBBTBoMC8GCCsGAQUFBwIBFiNodHRwOi8vY2VydC5zdGFydGNv
# bS5vcmcvcG9saWN5LnBkZjA1BggrBgEFBQcCARYpaHR0cDovL2NlcnQuc3RhcnRj
# b20ub3JnL2ludGVybWVkaWF0ZS5wZGYwEQYJYIZIAYb4QgEBBAQDAgABMFAGCWCG
# SAGG+EIBDQRDFkFTdGFydENvbSBDbGFzcyAyIFByaW1hcnkgSW50ZXJtZWRpYXRl
# IE9iamVjdCBTaWduaW5nIENlcnRpZmljYXRlczANBgkqhkiG9w0BAQUFAAOCAgEA
# UKLQmPRwQHAAtm7slo01fXugNxp/gTJY3+aIhhs8Gog+IwIsT75Q1kLsnnfUQfbF
# pl/UrlB02FQSOZ+4Dn2S9l7ewXQhIXwtuwKiQg3NdD9tuA8Ohu3eY1cPl7eOaY4Q
# qvqSj8+Ol7f0Zp6qTGiRZxCv/aNPIbp0v3rD9GdhGtPvKLRS0CqKgsH2nweovk4h
# fXjRQjp5N5PnfBW1X2DCSTqmjweWhlleQ2KDg93W61Tw6M6yGJAGG3GnzbwadF9B
# UW88WcRsnOWHIu1473bNKBnf1OKxxAQ1/3WwJGZWJ5UxhCpA+wr+l+NbHP5x5XZ5
# 8xhhxu7WQ7rwIDj8d/lGU9A6EaeXv3NwwcbIo/aou5v9y94+leAYqr8bbBNAFTX1
# pTxQJylfsKrkB8EOIx+Zrlwa0WE32AgxaKhWAGho/Ph7d6UXUSn5bw2+usvhdkW4
# npUoxAk3RhT3+nupi1fic4NG7iQG84PZ2bbS5YxOmaIIsIAxclf25FwssWjieMwV
# 0k91nlzUFB1HQMuE6TurAakS7tnIKTJ+ZWJBDduUbcD1094X38OvMO/++H5S45Ki
# 3r/13YTm0AWGOvMFkEAF8LbuEyecKTaJMTiNRfBGMgnqGBfqiOnzxxRVNOw2hSQp
# 0B+C9Ij/q375z3iAIYCbKUd/5SSELcmlLl+BuNknXE0wggc0MIIGHKADAgECAgFR
# MA0GCSqGSIb3DQEBBQUAMIGMMQswCQYDVQQGEwJJTDEWMBQGA1UEChMNU3RhcnRD
# b20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERpZ2l0YWwgQ2VydGlmaWNhdGUgU2ln
# bmluZzE4MDYGA1UEAxMvU3RhcnRDb20gQ2xhc3MgMiBQcmltYXJ5IEludGVybWVk
# aWF0ZSBPYmplY3QgQ0EwHhcNMDkxMTExMDAwMDAxWhcNMTExMTExMDYyODQzWjCB
# qDELMAkGA1UEBhMCVVMxETAPBgNVBAgTCE5ldyBZb3JrMRcwFQYDVQQHEw5XZXN0
# IEhlbnJpZXR0YTEtMCsGA1UECxMkU3RhcnRDb20gVmVyaWZpZWQgQ2VydGlmaWNh
# dGUgTWVtYmVyMRUwEwYDVQQDEwxKb2VsIEJlbm5ldHQxJzAlBgkqhkiG9w0BCQEW
# GEpheWt1bEBIdWRkbGVkTWFzc2VzLm9yZzCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMfjItJjMWVaQTECvnV/swHQP0FTYUvRizKzUubGNDNaj7v2dAWC
# rAA+XE0lt9JBNFtCCcweDzphbWU/AAY0sEPuKobV5UGOLJvW/DcHAWdNB/wRrrUD
# dpcsapQ0IxxKqpRTrbu5UGt442+6hJReGTnHzQbX8FoGMjt7sLrHc3a4wTH3nMc0
# U/TznE13azfdtPOfrGzhyBFJw2H1g5Ag2cmWkwsQrOBU+kFbD4UjxIyus/Z9UQT2
# R7bI2R4L/vWM3UiNj4M8LIuN6UaIrh5SA8q/UvDumvMzjkxGHNpPZsAPaOS+RNmU
# Go6X83jijjbL39PJtMX+doCjS/lnclws5lUCAwEAAaOCA4EwggN9MAkGA1UdEwQC
# MAAwDgYDVR0PAQH/BAQDAgeAMDoGA1UdJQEB/wQwMC4GCCsGAQUFBwMDBgorBgEE
# AYI3AgEVBgorBgEEAYI3AgEWBgorBgEEAYI3CgMNMB0GA1UdDgQWBBR5tWPGCLNQ
# yCXI5fY5ViayKj6xATCBqAYDVR0jBIGgMIGdgBTQTg9AmWy4SxlvOyi44OOIBzSq
# t6GBgaR/MH0xCzAJBgNVBAYTAklMMRYwFAYDVQQKEw1TdGFydENvbSBMdGQuMSsw
# KQYDVQQLEyJTZWN1cmUgRGlnaXRhbCBDZXJ0aWZpY2F0ZSBTaWduaW5nMSkwJwYD
# VQQDEyBTdGFydENvbSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eYIBFTCCAUIGA1Ud
# IASCATkwggE1MIIBMQYLKwYBBAGBtTcBAgEwggEgMC4GCCsGAQUFBwIBFiJodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS9wb2xpY3kucGRmMDQGCCsGAQUFBwIBFihodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS9pbnRlcm1lZGlhdGUucGRmMIG3BggrBgEFBQcC
# AjCBqjAUFg1TdGFydENvbSBMdGQuMAMCAQEagZFMaW1pdGVkIExpYWJpbGl0eSwg
# c2VlIHNlY3Rpb24gKkxlZ2FsIExpbWl0YXRpb25zKiBvZiB0aGUgU3RhcnRDb20g
# Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkgUG9saWN5IGF2YWlsYWJsZSBhdCBodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS9wb2xpY3kucGRmMGMGA1UdHwRcMFowK6ApoCeG
# JWh0dHA6Ly93d3cuc3RhcnRzc2wuY29tL2NydGMyLWNybC5jcmwwK6ApoCeGJWh0
# dHA6Ly9jcmwuc3RhcnRzc2wuY29tL2NydGMyLWNybC5jcmwwgYkGCCsGAQUFBwEB
# BH0wezA3BggrBgEFBQcwAYYraHR0cDovL29jc3Auc3RhcnRzc2wuY29tL3N1Yi9j
# bGFzczIvY29kZS9jYTBABggrBgEFBQcwAoY0aHR0cDovL3d3dy5zdGFydHNzbC5j
# b20vY2VydHMvc3ViLmNsYXNzMi5jb2RlLmNhLmNydDAjBgNVHRIEHDAahhhodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS8wDQYJKoZIhvcNAQEFBQADggEBACY+J88ZYr5A
# 6lYz/L4OGILS7b6VQQYn2w9Wl0OEQEwlTq3bMYinNoExqCxXhFCHOi58X6r8wdHb
# E6mU8h40vNYBI9KpvLjAn6Dy1nQEwfvAfYAL8WMwyZykPYIS/y2Dq3SB2XvzFy27
# zpIdla8qIShuNlX22FQL6/FKBriy96jcdGEYF9rbsuWku04NqSLjNM47wCAzLs/n
# FXpdcBL1R6QEK4MRhcEL9Ho4hGbVvmJES64IY+P3xlV2vlEJkk3etB/FpNDOQf8j
# RTXrrBUYFvOCv20uHsRpc3kFduXt3HRV2QnAlRpG26YpZN4xvgqSGXUeqRceef7D
# dm4iTdHK5tIxggI0MIICMAIBATCBkjCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoT
# DVN0YXJ0Q29tIEx0ZC4xKzApBgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmlj
# YXRlIFNpZ25pbmcxODA2BgNVBAMTL1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJ
# bnRlcm1lZGlhdGUgT2JqZWN0IENBAgFRMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEWMCMGCSqGSIb3DQEJBDEWBBQlmhi/IwaS
# DoD7e6VQ2D8hA2ZmJTANBgkqhkiG9w0BAQEFAASCAQAG6GGvK30WnUHcIWGC9eFQ
# 1feEWgLb25aQXOwLFdZqELqwEb4zPcc6simiwM5EyhIlT0IwNnpjbleeuDGbuDKt
# CKGJXCKGjRe11lgTaw7VMO9pY6q7hGroYJGFBnUNqukMGJxQLl22072BXy+mRZst
# sUe/c43joWmvxu7UkFG+cDLJxl3CMQJOMn5csItN6hvL+BrqHtfvpVx9zzx9MglN
# vS56SicBF7wNhYQOfF3DfrmIYD2SULA52u7sgaBRCPrD4c7Q1FhhW3oTjtcjWTqE
# gv62MQ60yiJqkGrN5jUU2lrHZNheDbWpUTIYtDhJZnihsQCBYaeV2CfDXtuJL3In
# SIG # End signature block
