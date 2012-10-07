cls

#dir E:\PowerShell\PoShScripts | ? {$_.extension.trim().length -gt 0 -and $_.length -gt 0} | select extension, length | .\Out-ExcelPivotTable
#ps | ?{$_.company -ne $null} | select company, pm | .\Out-ExcelPivotTable

#Function New-Person ($dept, $name, [double]$salary, [int]$yearsEmployeed) {
#    New-Object PSObject  |
#        Add-Member -PassThru Noteproperty Dept $dept |
#        Add-Member -PassThru Noteproperty Name $name |
#        Add-Member -PassThru Noteproperty Salary $salary |
#        Add-Member -PassThru Noteproperty YearsEmployeed $yearsEmployeed 
#}

#$(
#    New-Person IT Doug 100 10
#    New-Person IT John 200 5
#    New-Person IT Tom 300 6 
#    New-Person IT Dick 400 7

#    New-Person Sales Jane 1100 8 
#    New-Person Sales Tina 1200 9
#    New-Person Sales Tammy 1300 11
#    New-Person Sales Dawn 1400 12
    
#) | .\Out-ExcelPivotTable

$people = Import-Csv .\people.csv | 
    select Dept, Name, @{
        n="Salary"
        e={[double]$_.Salary}
    }, @{
        n="YearsEmployeed"
        e={[int]$_.yearsEmployeed}
    } 

$people | .\Out-ExcelPivotTable
$people | .\Out-ExcelPivotTable name dept salary
$people | .\Out-ExcelPivotTable -values YearsEmployeed