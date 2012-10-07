param (
    [string]$tfsServer = "TFSServerName",
    [string]$tfsLocation = "$/TFS/Project",
    [string]$localFolder ="c:\scripts",
    [string]$file,
    [string]$checkInComments = "Checked in from PowerShell"
)
$clientDll = "C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\PrivateAssemblies\Microsoft.TeamFoundation.Client.dll"
$versionControlClientDll = "C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\PrivateAssemblies\Microsoft.TeamFoundation.VersionControl.Client.dll"
$versionControlCommonDll = "C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\PrivateAssemblies\Microsoft.TeamFoundation.VersionControl.Common.dll"

#Load the Assemblies
[Reflection.Assembly]::LoadFrom($clientDll)
[Reflection.Assembly]::LoadFrom($versionControlClientDll)
[Reflection.Assembly]::LoadFrom($versionControlCommonDll)

#Set up connection to TFS Server and get version control
$tfs = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($tfsServer)
$versionControlType = [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
$versionControlServer = $tfs.GetService($versionControlType)

#Create a "workspace" and map a local folder to a TFS location
$workspace = $versionControlServer.CreateWorkspace("PowerShell Workspace",$versionControlServer.AuthenticatedUser)
$workingfolder = New-Object Microsoft.TeamFoundation.VersionControl.Client.WorkingFolder($tfsLocation,$localFolder)
$workspace.CreateMapping($workingFolder)
$filePath = $localFolder + "\" + $file

#Submit file as a Pending Change and submit the change
$workspace.PendAdd($filePath)
$pendingChanges = $workspace.GetPendingChanges()
$workspace.CheckIn($pendingChanges,$checkInComments)

#Delete the temp workspace
$workspace.Delete()