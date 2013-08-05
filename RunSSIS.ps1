    # ---------------------------------------------------------------------------
    ### <Script>
    ### <Author>
    ### Chad Miller
    ### </Author>
    ### <Description>
    ### Executes SSIS package for both server and file system storage types.
    ### </Description>
    ### <Usage>
    ###  -------------------------- EXAMPLE 1 --------------------------
    ### ./RunSSIS.ps1 -path Z002_SQL1\sqlpsx -serverName 'Z002\SQL1'
    ###
    ### This command will execute package sqlpsx on the server Z002\SQL1
    ###
    ###  -------------------------- EXAMPLE 2 --------------------------
    ### ./RunSSIS.ps1 -path Z002_SQL1\sqlpsx -serverName Z002\SQL1 -configFile 'C:\SSISConfig\sqlpsx.xml'
    ###
    ### This command will execute the package as in Example 1 and process and configuration file
    ###
    ###  -------------------------- EXAMPLE 3 --------------------------
    ### ./RunSSIS.ps1 -path 'C:\SSIS\sqlpsx.dtsx'
    ###
    ### This command will execute the package sqlpsx.dtsx located on the file system
    ###
    ###  -------------------------- EXAMPLE 4 --------------------------
    ### ./RunSSIS.ps1 -path 'C:\SSIS\sqlpsx.dtsx -nolog
    ###
    ### This command will execute the package sqlpsx.dtsx located on the file system and skip Windows Event logging
    ###
    ### </Usage>
    ### </Script>
    # ---------------------------------------------------------------------------
     
    param($path=$(throw 'path is required.'), $serverName, $configFile, [switch]$nolog)
     
    # Note: SSIS is NOT backwards compatible. At the beginning of the script you’ll need to comment/uncomment the specific assembly
    # to load 2005 or 2008. Default of the script is set to 2005
    #[reflection.assembly]::Load("Microsoft.SqlServer.ManagedDTS, Version=9.0.242.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91") > $null
    #[Reflection.Assembly]::LoadFile("C:\Program Files\Microsoft SQL Server\90\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll") > $null
    [reflection.assembly]::Load("Microsoft.SqlServer.ManagedDTS, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91") > $null
    #[Reflection.Assembly]::LoadFile("C:\Program Files\Microsoft SQL Server\100\SDK\Assemblies\Microsoft.SQLServer.ManagedDTS.dll") > $null
    #[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.ManagedDTS") > $null
     
    $myName = 'RunSSIS.ps1'
     
    #######################
    function New-ISApplication
    {
       new-object ("Microsoft.SqlServer.Dts.Runtime.Application")
     
    } #New-ISApplication
     
    #######################
    function Test-ISPath
    {
        param([string]$path=$(throw 'path is required.'), [string]$serverName=$(throw 'serverName is required.'), [string]$pathType='Any')
     
        #If serverName contains instance i.e. server\instance, convert to just servername:
        $serverName = $serverName -replace "\\.*"
     
        #Note: Don't specify instance name
     
        $app = New-ISApplication
     
        switch ($pathType)
        {
            'Package' { trap { $false; continue } $app.ExistsOnDtsServer($path,$serverName) }
            'Folder'  { trap { $false; continue } $app.FolderExistsOnDtsServer($path,$serverName) }
            'Any'     { $p=Test-ISPath $path $serverName 'Package'; $f=Test-ISPath $path $serverName 'Folder'; [bool]$($p -bor $f)}
            default { throw 'pathType must be Package, Folder, or Any' }
        }
     
    } #Test-ISPath
     
    #######################
    function Get-ISPackage
    {
        param([string]$path, [string]$serverName)
     
        #If serverName contains instance i.e. server\instance, convert to just servername:
        $serverName = $serverName -replace "\\.*"
     
        $app = New-ISApplication
     
        #SQL Server Store
        if ($path -and $serverName)
        {
            if (Test-ISPath $path $serverName 'Package')
            { $app.LoadFromDtsServer($path, $serverName, $null) }
            else
            { Write-Error "Package $path does not exist on server $serverName" }
        }
        #File Store
        elseif ($path -and !$serverName)
        {
            if (Test-Path -literalPath $path)
            { $app.LoadPackage($path, $null) }
            else
            { Write-Error "Package $path does not exist" }
        }
        else
        { throw 'You must specify a file path or package store path and server name' }
       
    } #Get-ISPackage
     
    #######################
    #MAIN
     
    Write-Verbose "$myName path:$path serverName:$serverName configFile:$configFile nolog:$nolog.IsPresent"
     
    if (!($nolog.IsPresent))
    {
        $log = Get-EventLog -List | Where-Object { $_.Log -eq "Application" }
        $log.Source = $myName
        $log.WriteEntry("Starting:$path",'Information')
    }
     
    $package = Get-ISPackage $path $serverName
     
    if ($package)
    {
     
        if ($configFile)
        {
            if (test-path -literalPath $configFile)
            { $package.ImportConfigurationFile("$configFile") }
            else
            {
                $err = "Invalid file path. Verify configFile:$configFile"
                if (!($nolog.IsPresent)) { $log.WriteEntry("Error:$path:$err",'Error') }
                throw ($err)
                break
            }
        }
     
        $package.Execute()
        $err = $package.Errors | foreach { $_.Source.ToString() + ':' + $_.Description.ToString() }
     
        if ($err)
        {
            if (!($nolog.IsPresent)) { $log.WriteEntry("Error:$path:$err",'Error') }
            throw ($err)
            break
        }
        else
        {
            if (!($nolog.IsPresent)) { $log.WriteEntry("Completed:$path",'Information') }
        }
    }
    else
    {
        $err = "Cannot Load Package. Verify Path:$path and Server:$serverName"
        if (!($nolog.IsPresent)) { $log.WriteEntry("Error:$path:$err",'Error') }
        throw ($err)
        break
    }
    #MAIN
    #######################
