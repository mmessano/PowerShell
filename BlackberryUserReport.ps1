# http://activelydirect.blogspot.com/2011/02/blackberry-user-report.html
# http://activelydirect.blogspot.com/2011/03/write-excel-spreadsheets-fast-in.html

Function Get-LocalDomainController($objectDomain) {
 return ([System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite()).Servers | Where-Object { $_.Domain.Name -eq $objectDomain } | ForEach-Object { $_.Name } | Select-Object -first 1
}
  
Function Get-ObjectADDomain($distinguishedName) {
 return ((($distinguishedName -replace "(.*?)DC=(.*)",'$2') -replace "DC=","") -replace ",",".")
}
  
Function Get-ActiveDirectoryObject($distinguishedName) {
 return [ADSI]("LDAP://" + (Get-LocalDomainController (Get-ObjectADDomain $distinguishedName)) + "/" + ($distinguishedName -replace "/","\/"))
}
Function Get-CarrierNetwork($carrier) {
 if($carrier -eq "100") { $network = "T-Mobile US"
 } elseif($carrier -eq "101") { $network = "Cingular Wireless"
 } elseif($carrier -eq "102") { $network = "AT&T Wireless"
 } elseif($carrier -eq "103") { $network = "Nextel"
 } elseif($carrier -eq "104") { $network = "Sprint PCS"
 } elseif($carrier -eq "105") { $network = "Verizon Wireless"
 } elseif($carrier -eq "106") { $network = "Alltel"
 } elseif($carrier -eq "107") { $network = "Rogers AT&T"
 } elseif($carrier -eq "108") { $network = "Microcell"
 } elseif($carrier -eq "109") { $network = "Bell Mobility"
 } elseif($carrier -eq "110") { $network = "BT Cellnet"
 } elseif($carrier -eq "111") { $network = "O2 Germany"
 } elseif($carrier -eq "112") { $network = "Digifone"
 } elseif($carrier -eq "113") { $network = "Telfort"
 } elseif($carrier -eq "114") { $network = "T-Mobile Germany Austria"
 } elseif($carrier -eq "115") { $network = "Tim Italy"
 } elseif($carrier -eq "116") { $network = "Hutchison"
 } elseif($carrier -eq "117") { $network = "Bouygues Telecom"
 } elseif($carrier -eq "118") { $network = "Vodafone SFR France"
 } elseif($carrier -eq "119") { $network = "Orange France"
 } elseif($carrier -eq "120") { $network = "Vodafone UK Netherlands"
 } elseif($carrier -eq "121") { $network = "Telcel Mexico"
 } elseif($carrier -eq "122") { $network = "Telstra"
 } elseif($carrier -eq "123") { $network = "T-Mobile UK"
 } elseif($carrier -eq "124") { $network = "Vodafone Germany"
 } elseif($carrier -eq "125") { $network = "O2 UK Ireland Isle Of Man Netherlands"
 } elseif($carrier -eq "126") { $network = "Telus"
 } elseif($carrier -eq "127") { $network = "Smart"
 } elseif($carrier -eq "128") { $network = "Starhub"
 } elseif($carrier -eq "129") { $network = "Telefonica Spain"
 } elseif($carrier -eq "130") { $network = "Vodafone Switzerland Swisscom"
 } elseif($carrier -eq "131") { $network = "Cable Wireless West Indies"
 } elseif($carrier -eq "132") { $network = "Vodafone Italy"
 } elseif($carrier -eq "133") { $network = "Vodafone Spain"
 } elseif($carrier -eq "134") { $network = "T-Mobile Netherlands"
 } elseif($carrier -eq "135") { $network = "Cincinnati Bell"
 } elseif($carrier -eq "136") { $network = "Telefonica Mexico"
 } elseif($carrier -eq "137") { $network = "Vodafone Austria"
 } elseif($carrier -eq "138") { $network = "Vodafone Australia Fiji"
 } elseif($carrier -eq "139") { $network = "Vodafone Ireland"
 } elseif($carrier -eq "140") { $network = "Telenor Sweden"
 } elseif($carrier -eq "141") { $network = "CSL"
 } elseif($carrier -eq "142") { $network = "Orange UK"
 } elseif($carrier -eq "143") { $network = "Vodafone New Zealand"
 } elseif($carrier -eq "144") { $network = "Singtel"
 } elseif($carrier -eq "145") { $network = "Globe"
 } elseif($carrier -eq "146") { $network = "Optus"
 } elseif($carrier -eq "147") { $network = "Orange Be Mobistar"
 } elseif($carrier -eq "148") { $network = "Vodafone Hungary"
 } elseif($carrier -eq "149") { $network = "Bharti"
 } elseif($carrier -eq "150") { $network = "KPN NL"
 } elseif($carrier -eq "151") { $network = "Wind Hellas Tim Greece"
 } elseif($carrier -eq "152") { $network = "Vodafone Belgium"
 } elseif($carrier -eq "153") { $network = "Vodafone Portugal"
 } elseif($carrier -eq "154") { $network = "Tim Brazil"
 } elseif($carrier -eq "155") { $network = "BT-Mobile"
 } elseif($carrier -eq "156") { $network = "Earthlink"
 } elseif($carrier -eq "157") { $network = "Aether"
 } elseif($carrier -eq "158") { $network = "E Plus"
 } elseif($carrier -eq "159") { $network = "Base"
 } elseif($carrier -eq "160") { $network = "Dobson Communications"
 } elseif($carrier -eq "161") { $network = "Vodafone Egypt"
 } elseif($carrier -eq "162") { $network = "Orange Switzerland"
 } elseif($carrier -eq "163") { $network = "Rim Wlan"
 } elseif($carrier -eq "164") { $network = "T-Mobile Suncom"
 } elseif($carrier -eq "165") { $network = "Maxis"
 } elseif($carrier -eq "166") { $network = "Vodafone Denmark TDC"
 } elseif($carrier -eq "167") { $network = "Vodafone Singapore M1"
 } elseif($carrier -eq "168") { $network = "Vodacom South Africa"
 } elseif($carrier -eq "169") { $network = "T-Mobile Poland"
 } elseif($carrier -eq "170") { $network = "T-Mobile Czech"
 } elseif($carrier -eq "171") { $network = "T-Mobile Hungary"
 } elseif($carrier -eq "172") { $network = "AT&T Sprint"
 } elseif($carrier -eq "173") { $network = "Mtn South Africa"
 } elseif($carrier -eq "174") { $network = "Tim Chile Entel PCS"
 } elseif($carrier -eq "175") { $network = "Orange Spain"
 } elseif($carrier -eq "176") { $network = "Vodafone Smartone Hong Kong"
 } elseif($carrier -eq "177") { $network = "TCS Telecommunication Systems"
 } elseif($carrier -eq "178") { $network = "Avea"
 } elseif($carrier -eq "179") { $network = "Fast 100"
 } elseif($carrier -eq "180") { $network = "Turkcell"
 } elseif($carrier -eq "181") { $network = "Partner Communications"
 } elseif($carrier -eq "183") { $network = "Orange Romania"
 } elseif($carrier -eq "186") { $network = "Telkomsel"
 } elseif($carrier -eq "188") { $network = "Vodafone Greece"
 } elseif($carrier -eq "189") { $network = "United States Cellular Corp"
 } elseif($carrier -eq "190") { $network = "Mobilink"
 } elseif($carrier -eq "191") { $network = "Velocita Wireless"
 } elseif($carrier -eq "192") { $network = "Vodafone Croatia"
 } elseif($carrier -eq "193") { $network = "Vodafone Slovenia"
 } elseif($carrier -eq "194") { $network = "Vodafone Luxembourg"
 } elseif($carrier -eq "195") { $network = "Vodafone Iceland"
 } elseif($carrier -eq "196") { $network = "Vodafone Fiji"
 } elseif($carrier -eq "197") { $network = "Vodafone Romania"
 } elseif($carrier -eq "198") { $network = "Vodafone Czech"
 } elseif($carrier -eq "199") { $network = "Vodafone Bahrain"
 } elseif($carrier -eq "200") { $network = "Vodafone Kuwait"
 } elseif($carrier -eq "201") { $network = "T-Mobile Croatia"
 } elseif($carrier -eq "202") { $network = "T-Mobile Slovakia"
 } elseif($carrier -eq "203") { $network = "Nortel"
 } elseif($carrier -eq "204") { $network = "China Mobile"
 } elseif($carrier -eq "205") { $network = "Movilnet"
 } elseif($carrier -eq "209") { $network = "Sympac"
 } elseif($carrier -eq "210") { $network = "Personal Argentina"
 } elseif($carrier -eq "212") { $network = "Etisalat UAE"
 } elseif($carrier -eq "213") { $network = "Cbeyond"
 } elseif($carrier -eq "214") { $network = "AMX"
 } elseif($carrier -eq "215") { $network = "Telefonica Venezuela"
 } elseif($carrier -eq "216") { $network = "Telefonica Brazil"
 } elseif($carrier -eq "217") { $network = "Orange Romania"
 } elseif($carrier -eq "218") { $network = "Ktpowertel Korea"
 } elseif($carrier -eq "219") { $network = "Rolling Stones"
 } elseif($carrier -eq "220") { $network = "Docomo"
 } elseif($carrier -eq "222") { $network = "Vodafone Bulgaria"
 } elseif($carrier -eq "223") { $network = "Nextel International"
 } elseif($carrier -eq "224") { $network = "PCCW Sunday"
 } elseif($carrier -eq "225") { $network = "Hawaiian Telcom Credo Mobile"
 } elseif($carrier -eq "226") { $network = "Verizon Mvno"
 } elseif($carrier -eq "227") { $network = "Mobily"
 } elseif($carrier -eq "228") { $network = "BWA"
 } elseif($carrier -eq "229") { $network = "O2 Czech Republic"
 } elseif($carrier -eq "230") { $network = "Hutchison India"
 } elseif($carrier -eq "231") { $network = "Celcom"
 } elseif($carrier -eq "234") { $network = "Dialog"
 } elseif($carrier -eq "235") { $network = "XL"
 } elseif($carrier -eq "236") { $network = "Reliance"
 } elseif($carrier -eq "237") { $network = "Verizon Wireless Wholesale"
 } elseif($carrier -eq "238") { $network = "Vodafone Turkey"
 } elseif($carrier -eq "239") { $network = "Telefonica Morocco Meditel"
 } elseif($carrier -eq "240") { $network = "Indosat"
 } elseif($carrier -eq "241") { $network = "Alcatel Shanghai Bell"
 } elseif($carrier -eq "245") { $network = "3 UK Italy Sweden Denmark Austria Ireland"
 } elseif($carrier -eq "247") { $network = "Vodafone Essar"
 } elseif($carrier -eq "248") { $network = "Centennial Wireless"
 } elseif($carrier -eq "250") { $network = "T-Mobile Austria"
 } elseif($carrier -eq "254") { $network = "OI Brazil"
 } elseif($carrier -eq "255") { $network = "Telecom New Zealand"
 } elseif($carrier -eq "258") { $network = "Hutchinson 3G Australia"
 } elseif($carrier -eq "259") { $network = "Cable & Wireless Trinidad Tobago"
 } elseif($carrier -eq "268") { $network = "Bmobile"
 } elseif($carrier -eq "269") { $network = "Tata Teleservices India"
 } elseif($carrier -eq "271") { $network = "T-Mobile Croatia"
 } elseif($carrier -eq "273") { $network = "BT Italy"
 } elseif($carrier -eq "274") { $network = "1&1"
 } elseif($carrier -eq "277") { $network = "MTS Mobility"
 } elseif($carrier -eq "278") { $network = "Virgin Mobile"
 } elseif($carrier -eq "280") { $network = "Orange Slovakia"
 } elseif($carrier -eq "282") { $network = "Taiwan Mobile"
 } elseif($carrier -eq "285") { $network = "Orange Austria"
 } elseif($carrier -eq "286") { $network = "Vodafone Malta"
 } elseif($carrier -eq "288") { $network = "Base Jim Mobile"
 } elseif($carrier -eq "295") { $network = "CMCC Peoples"
 } elseif($carrier -eq "298") { $network = "Digitel Wireless"
 } elseif($carrier -eq "299") { $network = "SK Telecom"
 } elseif($carrier -eq "300") { $network = "Solo Mobile"
 } elseif($carrier -eq "301") { $network = "Carphone Warehouse"
 } elseif($carrier -eq "302") { $network = "20:20 Mobile Group"
 } elseif($carrier -eq "308") { $network = "XL Indonesia"
 } elseif($carrier -eq "309") { $network = "Fido Solutions"
 } elseif($carrier -eq "310") { $network = "Wind Italy"
 }
 return $network
}
#--------------------------------------------------------------------------------------------------#
Set-Variable forestRootDn -option Constant -value ([ADSI]("LDAP://" + (([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()).name) + "/rootDSE")).defaultNamingContext
# Modify the array below to include your SQL servers or local SQL instance on a BES
Set-Variable sqlServers -option Constant -value @("east-coast-sql.usa.ad.mydomain.local","west-coast-sql.usa.ad.mydomain.local","remote-bes-server.japan.ad.mydomain.local")
#--------------------------------------------------------------------------------------------------#
$blackberryUsers = @()
 
$objectConnection = New-Object -comObject "ADODB.Connection"
$objectCommand = New-Object -comObject "ADODB.Command"
$objectConnection.Open("Provider=ADsDSOObject;")
$objectCommand.ActiveConnection = $objectConnection
 
$ldapBase = "GC://$forestRootDn"
$ldapAttr = "distinguishedName,sAMAccountName,givenName,sn,homeMDB,telephoneNumber,streetAddress,l,st,postalCode,c"
$ldapScope = "subtree"
 
foreach($sqlServer in $sqlServers) {
 
 $sqlConnection = New-Object System.Data.SQLClient.SQLConnection
 $sqlConnection.ConnectionString = "server=$sqlServer;database=BESMgmt;trusted_connection=true;"
 $sqlConnection.Open()
  
 $sqlCommand = New-Object System.Data.SQLClient.SQLCommand
 $sqlCommand.Connection = $sqlConnection
 $sqlCommand.CommandText = "SELECT u.DisplayName as DisplayName, u.MailboxSMTPAddr as MailboxSMTPAddr, u.PIN as PIN, d.phonenumber as phonenumber, d.ModelName as ModelName, d.VendorID as VendorID, d.IMEI as IMEI, d.HomeNetwork as HomeNetwork, d.PasswordEnabled as PasswordEnabled, s.MachineName as MachineName FROM UserConfig u, SyncDeviceMgmtSummary d, ServerConfig s WHERE u.id = d.userconfigid and u.ServerConfigId = s.id"
  
 $sqlDataReader = $sqlCommand.ExecuteReader()
  
 if($sqlDataReader.HasRows -eq  $true) {
  while($sqlDataReader.Read()) {
   $displayName = $sqlDataReader.Item("DisplayName")
   $proxyAddress = $sqlDataReader.Item("MailboxSMTPAddr")
   $pin = $sqlDataReader.Item("PIN")
   $phoneNumber = $sqlDataReader.Item("phonenumber")
   $modelName = $sqlDataReader.Item("ModelName")
   $vendorId = $sqlDataReader.Item("VendorID")
   $imei = $sqlDataReader.Item("IMEI")
   $homeNetwork = $sqlDataReader.Item("homeNetwork")
   $passwordEnabled = $sqlDataReader.Item("PasswordEnabled")
   $blackberryServer = $sqlDataReader.Item("MachineName")
 
  if($passwordEnabled -eq 1) {
    $passwordEnabled = $true
   } else {
    $passwordEnabled = $false
   }
  
   $phoneNumber = $phoneNumber -Replace "^\+",""
  
   if(($phoneNumber).length -eq 10) {
    $phoneNumber = ("(" + ($phoneNumber).SubString(0,3) + ") " + ($phoneNumber).SubString(3,3) + "-" + ($phoneNumber).SubString(6,4))
   }
  
   if(($phoneNumber).length -eq 11 -and ($phoneNumber).SubString(0,1) -eq "1") {
    $phoneNumber = ("(" + ($phoneNumber).SubString(1,3) + ") " + ($phoneNumber).SubString(4,3) + "-" + ($phoneNumber).SubString(7,4))
   }
  
   if($homeNetwork -eq "" -or $homeNetwork -cmatch "vodafone") {
    $homeNetwork = Get-CarrierNetwork $vendorId
   }
  
   $ldapFilter = ("(&(objectCategory=person)(objectClass=user)(proxyAddresses=smtp:$proxyAddress))")
   $ldapQuery = "<$ldapBase>;$ldapFilter;$ldapAttr;$ldapScope"
  
   $objectCommand.CommandText = $ldapQuery
   $objectRecordSet = $objectCommand.Execute()
  
   while(!$objectRecordSet.EOF) {
    $domain = ((Get-ObjectADDomain $objectRecordSet.Fields.Item('distinguishedName').Value).Split(".")[0]).ToUpper()
    $exchangeServer = ((((((Get-ActiveDirectoryObject $objectRecordSet.Fields.Item('homeMDB').Value).psbase.parent).psbase.parent).psbase.parent).networkAddress[4]).ToString() -replace "ncacn_ip_tcp:","").ToLower()
    $sAMAccountName = $objectRecordSet.Fields.Item('sAMAccountName').Value
    $firstName = $objectRecordSet.Fields.Item('givenName').Value
    $lastName = $objectRecordSet.Fields.Item('sn').Value
    $telephoneNumber = $objectRecordSet.Fields.Item('telephoneNumber').Value
    $streetAddress = ($objectRecordSet.Fields.Item('streetAddress').Value -replace "`r`n",", ")
    $city = $objectRecordSet.Fields.Item('l').Value
    $state = $objectRecordSet.Fields.Item('st').Value
    $zipCode = $objectRecordSet.Fields.Item('postalCode').Value
    $country = $objectRecordSet.Fields.Item('c').Value
    $objectRecordSet.MoveNext()
   }
 
   $blackberryUser = New-Object -typeName PSObject
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Domain" -value $domain
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "User ID" -value $sAMAccountName
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "First Name" -value $firstName
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Last Name" -value $firstName
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Display Name" -value $displayName
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "E-Mail Address" -value $proxyAddress
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "PIN" -value $pin
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Cell Phone Number" -value $phoneNumber
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Desk Phone Number" -value $telephoneNumber
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Street Address" -value $streetAddress
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "City" -value $city
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "State" -value $state
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Zip Code" -value $zipCode
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Country" -value $country
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "BlackBerry Model" -value $modelName
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Carrier" -value $homeNetwork
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "IMEI" -value $imei
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Password Enabled" -value $passwordEnabled
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "Exchange Server" -value $exchangeServer
	Add-Member -inputObject $blackberryUser -type NoteProperty -name "BlackBerry Server" -value $blackberryServer
   $blackberryUsers += $blackberryUser
  }
 }  else {
  Write-Warning "Unable to obtain BES data from $sqlServer"
  exit
 }
}
# $blackberryUsers | Export-Csv -path "Blackberry Users.csv" -noTypeInformation

$blackberryUsers = $blackberryUsers | Sort-Object "BlackBerry Server", "Last Name", "First Name"
 
$excelFile = ("\\fileserver.ad.mydomain.local\it_reports\blackberry\" + (Get-Date -format yyyyMMdd) + "-BlackBerry User Report.xlsx")
 
$temporaryCsvFile = ($env:temp + "\" + ([System.Guid]::NewGuid()).ToString() + ".csv")
$blackberryUsers | Export-Csv -path $temporaryCsvFile -noTypeInformation
 
if(Test-Path -path $excelFile) { Remove-Item -path $excelFile }
 
$excelObject = New-Object -comObject Excel.Application
$excelObject.Visible = $false 
 
$workbookObject = $excelObject.Workbooks.Open($temporaryCsvFile)
$workbookObject.Title = ("BlackBerry User List for " + (Get-Date -Format D))
$workbookObject.Author = "Robert M. Toups, Jr."
 
$worksheetObject = $workbookObject.Worksheets.Item(1)
$worksheetObject.UsedRange.Columns.Autofit() | Out-Null
$worksheetObject.Name = "BlackBerry Users"
 
$listObject = $worksheetObject.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $worksheetObject.UsedRange, $null,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes,$null)
$listObject.Name = "User Table"
$listObject.TableStyle = "TableStyleMedium4" # Style Cheat Sheet in French/English: http://msdn.microsoft.com/fr-fr/library/documentformat.openxml.spreadsheet.tablestyle.aspx
 
$workbookObject.SaveAs($excelFile,51) # http://msdn.microsoft.com/en-us/library/bb241279.aspx
$workbookObject.Saved = $true
$workbookObject.Close()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbookObject) | Out-Null
 
$excelObject.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excelObject) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
 
if(Test-Path -path $temporaryCsvFile) { Remove-Item -path $temporaryCsvFile }