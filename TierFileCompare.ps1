# compare database file paths to disk paths

$Files = Get-Content -Path "e:\Dexma\ClientFilePaths.txt"

IF ($Files)
{
	foreach ($file IN $Files) 
	{
		IF (Test-Path $file = $true)
		{
			# file exists
			Out-File -InputObject $file -FilePath "e:\Dexma\logs\ClientFilesFound.txt" -append -NoClobber
		}
		else
		{
			# file does not exist
			Out-File -InputObject $file -FilePath "e:\Dexma\logs\ClientFilesNotFound.txt" -append -NoClobber
		}
	}
}