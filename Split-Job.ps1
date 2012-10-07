#requires -version 1.0
################################################################################
## Run commands in multiple concurrent pipelines
##   by Arnoud Jansveld - www.jansveld.net/powershell
## Version History
## 0.92   Add UseProfile switch: imports the PS profile into each runspace
##        Add Variable parameter: imports variable(s) into each runspace
##        Add Alias parameter: imports alias(es)
##        Restart pipeline if it stops due to an error
##        Set the current path in each runspace to that of the calling process
## 0.91   Revert to v 0.8 input syntax for the script block
##        Add error handling for empty input queue
## 0.9    Add logic to distinguish between scriptblocks and cmdlets or scripts:
##        if a ScriptBlock is specified, a foreach {} wrapper is added
## 0.8    Adds a progress bar
## 0.7    Stop adding runspaces if the queue is already empty
## 0.6    First version. Inspired by Gaurhoth's New-TaskPool script
################################################################################


function Split-Job (
    $Scriptblock = $(throw 'You must specify a command or script block!'),
    [int]$MaxPipelines=10,
    [switch]$UseProfile,
    [string[]]$Variable,
    [string[]]$Alias

) {
    # Create the shared thread-safe queue and fill it with the input objects
    $Queue = [Collections.Queue]::Synchronized([Collections.Queue]@($Input))
    $QueueLength = $Queue.Count
    if ($MaxPipelines -gt $QueueLength) {$MaxPipelines = $QueueLength}
    # Set up the script to be run by each runspace
    $Script  = "Set-Location '$PWD'; "
    $Script += '$Queue = $($Input); '
    $Script += '& {trap {continue}; while ($Queue.Count) {$Queue.Dequeue()}} |'
    $Script += $Scriptblock

    # Create an array to keep track of the set of pipelines
    $Pipelines = New-Object System.Collections.ArrayList

    function Add-Pipeline {
        # This creates a new runspace and starts an asynchronous pipeline with our script.
        # It will automatically start processing objects from the shared queue.
        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($Host)
        $Runspace.Open()
        # Optionally import profile, variables and aliases from the main runspace
        if ($UseProfile) {
            $Pipeline = $Runspace.CreatePipeline(". '$PROFILE'")
            $Pipeline.Invoke()
            $Pipeline.Dispose()
        }
        if ($Variable) {
            Get-Variable $Variable -Scope 2 | foreach {
                trap {continue}
                $Runspace.SessionStateProxy.SetVariable($_.Name, $_.Value)
            }
        }
        if ($Alias) {
            $Pipeline = $Runspace.CreatePipeline({$Input | Set-Alias -value {$_.Definition}})
            $Null = $Pipeline.Input.Write((Get-Alias $Alias -Scope 2), $True)
            $Pipeline.Input.Close()
            $Pipeline.Invoke()
            $Pipeline.Dispose()
        }
        $Pipeline = $Runspace.CreatePipeline($Script)
        $Null = $Pipeline.Input.Write($Queue)
        $Pipeline.Input.Close()
        $Pipeline.InvokeAsync()
        $Null = $Pipelines.Add($Pipeline)
    }

    function Remove-Pipeline ($Pipeline) {
        # Remove a pipeline and runspace when it is done
        $Pipeline.RunSpace.Close()
        $Pipeline.Dispose()
        $Pipelines.Remove($Pipeline)
    }

    # Start the pipelines
    while ($Pipelines.Count -lt $MaxPipelines -and $Queue.Count) {Add-Pipeline} 

    # Loop through the pipelines and pass their output to the pipeline until they are finished
    while ($Pipelines.Count) {
        Write-Progress 'Split-Job' "Queues: $($Pipelines.Count)" `
            -PercentComplete (100 - [Int]($Queue.Count)/$QueueLength*100)
        foreach ($Pipeline in (New-Object System.Collections.ArrayList(,$Pipelines))) {
            if ( -not $Pipeline.Output.EndOfPipeline -or -not $Pipeline.Error.EndOfPipeline ) {
                $Pipeline.Output.NonBlockingRead()
                $Pipeline.Error.NonBlockingRead() | Write-Error
            } else {
                if ($Pipeline.PipelineStateInfo.State -eq 'Failed') {
                    Write-Error $Pipeline.PipelineStateInfo.Reason
                    # Start a new runspace, unless there was a syntax error in the scriptblock
                    if ($Queue.Count -lt $QueueLength) {Add-Pipeline}
                }
                Remove-Pipeline $Pipeline
            }
        }
        Start-Sleep -Milliseconds 100
    }
}