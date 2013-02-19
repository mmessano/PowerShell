param($fileFilter=$(throw "Filter must be specified"))

$regex = [regex]"^(?<Program>\S*)\s*pid: (?<PID>\d*)\s*type: (?<Handle>\S*)\s*\w*: (?<File>((\\\\).*|([a-zA-Z]:).*))"

E:\Dexma\bin\ThirdParty\handle $fileFilter | Get-Matches -Pattern $regex
