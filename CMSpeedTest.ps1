#----------------------------------------------------------------------------------
# CMSpeedTest.ps1
#
# This script is provided AS-IS with no warrenties.
#
# Messures the network speed between the Primary and all other sites systems in a CM environment by
# copying a file to the servers and back. The script should be run from a Primary server or CAS
# 
# The output will be placed in the script root folder
#
# Frank Maxwitat, May 16, 2021
#----------------------------------------------------------------------------------

#--------------Parameters----------------------------------------------------------
[CmdletBinding()]
param(
[Parameter(Mandatory = $false)]
[boolean]$WriteCSV = $true,
[Parameter(Mandatory = $false)]
[boolean]$WriteHTML = $true
)


#--------------End Parameters-------------------------------------------------------

#--------------Definitions----------------------------------------------------------
$ScriptVersion = "Script Version 1.0"

$OKColor = "Green"
$WarningColor = "Orange"
$CriticalColor = "Red"
$TextColor= "White"
$HeaderBGColor = '#425563'
$FooterBGColor = '#425563'
$TableHeaderBGColor = '#01A982'
$TableHeaderRowBGColor = '#CCCCCC'

#--------------End Definitions------------------------------------------------------


function WriteHTMLHeader
{
[CmdletBinding()]
[Parameter(Mandatory)]
Param ($OutFile)

$ReportTitle = "Network Speed Test - Configuartion Manager Site Systems"
$date = (get-date -Format F)
$header = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>$Title</title>
<style type="text/css">
<!--
body {
font: 100%/1.4 Verdana, Arial, Helvetica, sans-serIf;
background: #FFFFFF;
margin: 0;
padding: 0;
color: #000;
}
.container {
width: 100%;
margin: 0 auto;
}
h1 {
font-size: 18px;
}
h2 {
color: #FFF;
padding: 0px;
margin: 0px;
font-size: 14px;
background-color: #006400;
}
h3 {
color: #FFF;
padding: 0px;
margin: 0px;
font-size: 14px;
background-color: #191970;
}
h4 {
color: #348017;
padding: 0px;
margin: 0px;
font-size: 10px;
font-style: italic;
}
.header {
text-align: center;
}
.container table {
width: 100%;
font-family: Verdana, Geneva, sans-serIf;
font-size: 12px;
font-style: normal;
font-weight: bold;
font-variant: normal;
text-align: center;
border: 0px solid black;
padding: 0px;
margin: 0px;
}
td {
font-weight: normal;
border: 1px solid grey;
width='25%'
}
th {
font-weight: bold;
border: 1px solid grey;
text-align: center;
}
-->
</style></head>
<body>
<div class="container">
<div class="content"> 
"@
Add-Content "$OutFile" $header 
$RptHeaderSME1 = @"
<table width='100%'><tbody>
<tr bgcolor = '$HeaderBGColor'> <td align='center'> <b> 
<Font color = 'white'> $ReportTitle </Font>
</b> </td> </tr>
</table>
"@
Add-Content $OutFile $RptHeaderSME1
}

function WriteHTMLFooter
{
[CmdletBinding()]
[Parameter(Mandatory)]
Param ($OutFile)

# Create table at end of report showing legend of colors for the Critical and Warning
$tableDescription = "
<table width='30%'>
<tr bgcolor='White'> 
<td width='10%' align='center' bgcolor='$OkColor'> <Font color = 'white'> <b> Fast: > 50 Mbps </b> </Font> </td> 
<td width='10%' align='center' bgcolor='$WarningColor'> <Font color = 'white'> <b> Medium: 10 to 50 Mbps </b> </Font> </td> 
<td width='10%' align='center' bgcolor='$CriticalColor'> <Font color = 'white'> <b> Slow: < 10 Mbps </b> </Font> </td> 
</tr>
</table>
"

Add-Content $OutFile $tableDescription 
$Footer = @"
<table width='100%' bgcolor = '$FooterBGColor'><tbody>
<tr> <td align='center'> <b> <Font color = 'white'> $ScriptVersion - $(get-date -Format F) </Font> </b> </td> </tr>
</table>
"@
Add-Content $OutFile $Footer 
}

function TestNetworkSpeed()
{
#requires -Version 3.0
[CmdletBinding()]
Param (
[Parameter(Mandatory,ValueFromPipeline,HelpMessage="Enter UNC's to server to test (dummy file will be saved in this path)")]
[String[]]$Computer,
[ValidateRange(1,1000)]
[int]$Size = 50,
[boolean]$WriteCSV = $true,
[boolean]$WriteHTML = $true,
[String]$OutPath = $env:windir + 'Logs\SpeedTest',
[String]$RolesList
)
[string]$OutFileHTML = $OutPath + '\SpeedTest.html'
[string]$OutFileCSV = $OutPath + '\SpeedTest.csv'

if((Test-Path $OutPath) -eq $NULL) 
{
New-Item -Path $OutPath -ItemType Directory
}

Write-Verbose "$(Get-Date): Test-NetworkSpeed Script begins"
Write-Verbose "$(Get-Date): Create dummy file, Size: $($Size)MB"

$Path = '\\' + $Computer + '\c$\windows\temp'
$Source = 'c:\temp'
Remove-Item $Source\Test.txt -ErrorAction SilentlyContinue
Set-Location $Source
$DummySize = $Size * 1048576
$CreateMsg = fsutil file createnew test.txt $DummySize

Try {
$TotalSize = (Get-ChildItem $Source\Test.txt -ErrorAction Stop).Length
}
Catch {
Write-Warning "Unable to locate dummy file"
Write-Warning "Create Message: $CreateMsg"
Write-Warning "Last error: $($Error[0])"
Exit
}
Write-Verbose "$(Get-Date): Source for dummy file: $Source\Test.txt"
$RunTime = Get-Date

ForEach ($ServerPath in $Path)
{ 
$Server = $ServerPath.Split("\")[2]
$Target = "$ServerPath\CMSpeedTest"
Write-Verbose "$(Get-Date): Checking speed for $Server..."
Write-Verbose "$(Get-Date): Destination: $Target"

If (-not (Test-Path $Target))
{ Try {
New-Item -Path $Target -ItemType Directory -ErrorAction Stop | Out-Null
}
Catch {
Write-Warning "Problem creating $Target folder because: $($Error[0])"
[PSCustomObject]@{
Server = $Server
TimeStamp = $RunTime
Status = "$($Error[0])"
WriteTime = New-TimeSpan -Days 0
WriteMbps = 0
ReadTime = New-TimeSpan -Days 0
ReadMbps = 0
}
Continue
}
}

Try { 
Write-Verbose "$(Get-Date): Write Test..."
$WriteTest = Measure-Command { 
Copy-Item $Source\Test.txt $Target -ErrorAction Stop
}

Write-Verbose "$(Get-Date): Read Test..."
$ReadTest = Measure-Command {
Copy-Item $Target\Test.txt $Source\TestRead.txt -ErrorAction Stop
}
$Status = "OK"
$WriteMbps = [Math]::Round((($TotalSize * 8) / $WriteTest.TotalSeconds) / 1048576,2)
$ReadMbps = [Math]::Round((($TotalSize * 8) / $ReadTest.TotalSeconds) / 1048576,2) 
} 
Catch {
Write-Warning "Problem during speed test: $($Error[0])"
$Status = "$($Error[0])"
$WriteMbps = $ReadMbps = 0
$WriteTest = $ReadTest = New-TimeSpan -Days 0
LogIt -message ("NetspeedTest failed on" + $OutputPath) -component "NetSpeedTest()" -type 1
}

[PSCustomObject]@{
Server = $Server
TimeStamp = $RunTime
Status = "OK"
WriteTime = $WriteTest
WriteMbps = $WriteMbps
ReadTime = $ReadTest
ReadMbps = $ReadMbps
}

Remove-Item $Target\Test.txt -ErrorAction SilentlyContinue
Remove-Item $Source\TestRead.txt -ErrorAction SilentlyContinue

$OKColor = "Green"
$WarningColor = "Orange"
$CriticalColor = "Red"
if($ReadMbps -ge 50){$color = $OKColor}
if(($WriteMbps -lt 50) -and ($WriteMbps -ge 10)){$color = $WarningColor }
if($WriteMbps -le 10){$color = $CriticalColor}

$allroles = ''
$count = 1

if($WriteHTML){ 

$Row=@"
<table width='100%' border = 0 > <tbody>
<tr>
<td width='20%' align='left'>&nbsp$Server</td>
<td width='45%' align='center'>$RolesList</td>
<td width='15%' align='center'>$ReadMbps</td>
<td width='15%' align='center'>$WriteMbps</td>
<td width='5%' align='center' bgcolor='$color'> <Font color ='$TextColor'> $Status </Font> </td>
</tr>
</table>
"@
Add-Content "$OutFileHTML" $Row 
}

if($WriteCSV){ 
$Message = " " + $Computer + ";" + $RolesList + ";" + $WriteMbps + ";" + $ReadMbps + ";"
$Message | Out-File $OutFileCSV -Append
}
}

Write-Verbose "$(Get-Date): Test-NetworkSpeed completed!" 
}

# ---Script starts here-----------------------------------------------------------------------------------------------

$OutputDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)

if((Test-Path $OutputDir) -ne $true){
New-Item -ItemType Directory $OutputDir -Force
}

get-WMIObject -Namespace "root\SMS" -Class "SMS_ProviderLocation" | foreach-object{ 
if ($_.ProviderForLocalSite -eq $true){$SiteCode=$_.sitecode} 
} 
if ($SiteCode -eq '') { 
throw ("Sitecode of ConfigMgr Site at " + $ComputerName + " could not be determined.") 
$Server = Read-Host -Prompt 'Could not determine the site code from WMI. This is unexpected. Please enter it manually (3 letters)'
}

$SMSSiteNameSpaceRoot = 'root/sms/site_' + $SiteCode

$sitesystemRoles = Get-WmiObject -Namespace $SMSSiteNameSpaceRoot -Class SMS_systemresourcelist | Select-Object servername, RoleName #
if($sitesystemRoles.Count -eq 0)
{
Write-Host 'Please run this script on a site server' -BackgroundColor red -ForegroundColor Yellow
}

$sitesystems = Get-WmiObject -Namespace $SMSSiteNameSpaceRoot -Class SMS_systemresourcelist | Select-Object servername # | Sort-Object 

$Serverlist = @()
$n=0
foreach ($role in $sitesystemRoles)
{
if($ServerList.Contains($role.ServerName) -eq $false)
{ 
$Serverlist += $role.ServerName
}
else
{
#$Serverlist 
}
#$n++; $i=($n/$sitesystemRoles.Count *100)
#Write-Progress -Activity "Building Server list" -Status "$i% Complete:" -PercentComplete $i
}

$HostFQN= ((Get-WmiObject win32_computersystem).DNSHostName + '.' + (Get-WmiObject win32_computersystem).Domain).ToLower()

if($WriteHTML)
{ 
[string]$OutFileHTML = $OutputDir + '\SpeedTest.html'
if((Test-Path $OutFileHTML) -ne $NULL){Remove-Item $OutFileHTML -ErrorAction SilentlyContinue}
WriteHTMLHeader -OutFile $OutFileHTML

$blockheader=@"
<table width='100%'><tbody>
<tr bgcolor=$TableHeaderBGColor> <td> <b> <Font color = 'white'> Speed Test Details </Font> </b> </td> </tr>
</table>
<table width='100%' border = 0 > <tbody>
<tr bgcolor=$TableHeaderRowBGColor> 
<td width='20%'>ServerName</td>
<td width='45%'>Roles</td>
<td width='15%'>ReadSpeed/Mbps</td>
<td width='15%'>WriteSpeed/Mbps</td>
<td width='5%'>State</td>
</tr>
</table>
"@
Add-Content "$OutFileHTML" $blockheader

}
if($WiteHTML -or $WriteCSV)
{
Write-Host 'Writing output to ' $OutputDir
}
if($WriteCSV) 
{
[string]$OutFileCSV = $OutputDir + '\SpeedTest.csv'
if((Test-Path $OutFileCSV) -eq $true){Remove-Item $OutFileCSV -Force -ErrorAction SilentlyContinue}
'Server Name,Roles,ReadSpeed, WriteSpeed' | Out-File $OutFileCSV
}

$AllRoles = ''
$n = 0
foreach ($Server in $ServerList)
{ 
if($Server.ToLower() -ne $HostFQN)
{ 
$AllRoles=''; $count = 0;
foreach($SiteSystemRole in $SiteSystemRoles)
{
if(($SiteSystemRole.ServerName -eq $Server) -and ($SiteSystemRole.RoleName -ne 'SMS Component Server') -and ($SiteSystemRole.RoleName -ne 'SMS Site System'))
{ 
if($count){$AllRoles += ','}
$count++
$AllRoles += $SiteSystemRole.RoleName 
}
}
TestNetworkSpeed -Computer $Server -Size 100 -OutPath $OutputDir -RolesList $AllRoles
}
#$n++; $i=($n/$ServerList.Count *100)
#Write-Progress -Activity "Running speed tests" -Status "$i% Complete:" -PercentComplete $i
}
if($WriteHTML)
{
WriteHTMLFooter -OutFile $OutFileHTML
}