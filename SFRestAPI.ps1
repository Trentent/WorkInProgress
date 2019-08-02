 <#
        .SYNOPSIS
            Login and launch Citrix applications using the new Store Service API 3
        .DESCRIPTION
            Login and launch Citrix applications using the new Store Service API 3
        .PARAMETER store
            The path to the Store.  Typically "https://storefront.bottheory.local/Citrix/Store"
        .PARAMETER username
            Specifies the username in DOMAIN\USERNAME format.
        .PARAMETER password
            Password for the user
        .PARAMETER application
            The applications title.
        .EXAMPLE
            SFRestAPI.ps1 -store "https://storefront.bottheory.local/Citrix/Store" -username BOTTHEORY\amttye -password This4sAcomplex! -application "RemoteDisplayAnalyzer"
        .NOTES
            Copyright (c) Trentent Tye. All rights reserved.
        #>
param(
  [parameter(Mandatory=$true)]  [string]$store,
  [parameter(Mandatory=$true)]  [string]$username,
  [parameter(Mandatory=$true)]  [string]$password,
  [parameter(Mandatory=$true)]  [string]$application

)

function Invoke-SFRestAPI {
    Param
    (
        [Parameter(Mandatory=$true)] [string]$URI,
        [Parameter(Mandatory=$true)] [hashtable]$headers,
        [Parameter(Mandatory=$true)][ValidateSet("GET","POST")] [string]$method,
        [Parameter(Mandatory=$false)] $body,
        [Parameter(Mandatory=$false)] [string]$ContentType,
        [Parameter(Mandatory=$false)] [switch]$sfsession
    )

    if ([bool]($body -as [xml])) {
        $body = [xml]$body
    }

    if ($body) {
        try {
        if ($sfsession) {
            Invoke-WebRequest -Uri $URI -Method $method -Headers $headers -SessionVariable script:sfsession -ContentType $ContentType -Body $body -UseBasicParsing -OutVariable webResult
            } else {
            Invoke-WebRequest -Uri $URI -Method $method -Headers $headers -WebSession $script:sfsession -ContentType $ContentType -Body $body -UseBasicParsing -OutVariable webResult
            }
        } catch {
            $Failure = $_.Exception.Response
            return $Failure
        }
        return $webResult
    } else {
        try {
        if ($sfsession) {
            Invoke-WebRequest -Uri $URI -Method $method -Headers $headers -SessionVariable script:sfsession -UseBasicParsing -OutVariable webResult
            } else {
            Invoke-WebRequest -Uri $URI -Method $method -Headers $headers -WebSession $script:sfsession -UseBasicParsing -OutVariable webResult
            }
        } catch {
            $Failure = $_.Exception.Response
            return $Failure
        }
        return $webResult
    }
}


function Generate-AuthXML {
    Param
    (
        [Parameter(Mandatory=$true)] [string]$forService,
        [Parameter(Mandatory=$true)] [string]$forServiceUrl
    )

    [xml]$body = @"
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<requesttoken xmlns="http://citrix.com/delivery-services/1-0/auth/requesttoken">
  <for-service>$forService</for-service>
  <for-service-url>$forServiceUrl</for-service-url>
  <reqtokentemplate></reqtokentemplate>
  <requested-lifetime>0.20:00:00</requested-lifetime>
</requesttoken>
"@

    return $body
}

function Get-XMLFromWebResponse {
#this function is needed as invoke-webrequest won't return the content of the web request in the exception object
    Param
    (
        [Parameter(Mandatory=$true)] [PSObject]$Response
    )

    $Stream = $Response.GetResponseStream()
    $Stream.Position = 0
    $Reader = [System.IO.StreamReader]::new($Stream)
    $result = $Reader.ReadToEnd()

    return $result
}

function Create-Cookie($name, $value, $domain, $path="/"){
    $c=New-Object System.Net.Cookie;
    $c.Name=$name;
    $c.Path=$path;
    $c.Value = $value
    $c.Domain =$domain;
    return $c;
}

$host.ui.RawUI.WindowTitle = “$application - $username”






## https://developer-docs.citrix.com/projects/storefront-authentication-sdk/en/latest/security-token-services-api/#wire-level-examples
#region Request to Service Provider 1
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.resources+xml"
    }


$Result = Invoke-SFRestAPI -Uri ($store + "/resources/v2") -Method GET -Headers $headers -sfsession

if ($Result.StatusCode -eq "Unauthorized") {
    $UnauthorizedHeaders = $Result.Headers.GetValues("WWW-Authenticate")
    $UHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    foreach ($object in ($UnauthorizedHeaders -split ",")) {
        $UHeaders.Add("$($($object -split "=")[0])",$($($object -split "=")[1] -replace "`"",""))
    }
}

$xml = Generate-AuthXML -forService $UHeaders.'CitrixAuth realm' -forServiceUrl $UHeaders.' serviceroot-hint'

$resourcesForService = $UHeaders.'CitrixAuth realm'

#endregion




#region Request to Authentication Service 1
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.requesttokenresponse+xml, application/vnd.citrix.requesttokenchoices+xml"
}

$Result = Invoke-SFRestAPI -Uri $UHeaders.' locations' -Method POST -Headers $headers -body $xml -ContentType "application/vnd.citrix.requesttoken+xml"
if ($Result.StatusCode -eq "Unauthorized") {
    $UnauthorizedHeaders = $Result.Headers.GetValues("WWW-Authenticate")
    $UHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    foreach ($object in ($UnauthorizedHeaders -split ",")) {
        $UHeaders.Add("$($($object -split "=")[0])",$($($object -split "=")[1] -replace "`"",""))
    }
}
#endregion



#region Request to Authentication Service 2
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.requesttokenresponse+xml, application/vnd.citrix.requesttokenchoices+xml"
}

$Result = Invoke-SFRestAPI -Uri $UHeaders.' locations' -Method POST -Headers $headers -body $xml -ContentType "application/vnd.citrix.requesttoken+xml"

# Hence, the result of this sequence is another challenge, because the client has not presented the security token required to access the token issuing service. The client must therefore parse the challenge again to construct another Request Security Token message and POST it to the indicated URI

if ($Result.StatusCode -eq "Unauthorized") {
    $UnauthorizedHeaders = $Result.Headers.GetValues("WWW-Authenticate")
    $UHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    foreach ($object in ($UnauthorizedHeaders -split ",")) {
        $UHeaders.Add("$($($object -split "=")[0])",$($($object -split "=")[1] -replace "`"",""))
    }
}

$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.requesttokenresponse+xml, application/vnd.citrix.requesttokenchoices+xml"
}
$xml = Generate-AuthXML -forService $UHeaders.'CitrixAuth realm' -forServiceUrl $UHeaders.' serviceroot-hint'

$Result = Invoke-SFRestAPI -Uri $UHeaders.' locations' -Method POST -Headers $headers -body $xml -ContentType "application/vnd.citrix.requesttoken+xml"

$explicitAuth = $false
if ($Result.StatusCode -eq "MultipleChoices") {
    [xml]$choices = Get-XMLFromWebResponse -Response $Result
    foreach ($choice in $choices.requesttokenchoices.choices.choice) {
        if ($choice.protocol -like "ExplicitForms") {
            Write-Host "Explict Authentication found!"
            $explicitAuth = $true
            $explicitAuthURL = $choice.location
        }
    }
}

if ((([xml]$Result.content).requesttokenresponse.choices.choice.protocol) -like "ExplicitForms") { 
    $explicitAuth = $true
    $explicitAuthURL = ([xml]$Result.content).requesttokenresponse.choices.choice.location
}
if ($explicitAuth -eq $false) {
    Write-Host "Unable to continue without Explicit Authentication"
}

Write-Host "ExplicitAuth URL : $explicitAuthURL"


#endregion





#region Resend request token message to the authentication endpoint
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.requesttokenresponse+xml, text/xml, application/vnd.citrix.authenticateresponse-1+xml"
}
$xml = Generate-AuthXML -forService $UHeaders.'CitrixAuth realm' -forServiceUrl $UHeaders.' serviceroot-hint'
$Result = Invoke-SFRestAPI -Uri $explicitAuthURL -Method POST -Headers $headers -body $xml -ContentType "application/vnd.citrix.requesttoken+xml"

$Citrix_AuthSvc = $sfsession.cookies.GetCookies($store + "Auth/ExplicitForms/Start")|where{$_.name -like "Citrix_AuthSvc"}
$cookiedomain = $Citrix_AuthSvc.Domain
$Citrix_AuthSvcCookie = Create-Cookie -name "Citrix_AuthSvc" -value "$($Citrix_AuthSvc.value)" -domain "$cookiedomain"
$script:sfsession.Cookies.Add($Citrix_AuthSvcCookie)

$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.requesttokenresponse+xml, text/xml, application/vnd.citrix.authenticateresponse-1+xml"
}
$body = "StateContext=&loginBtn=Log%20On&password=$password&saveCredentials=true&username=$($username.Split("\")[0])%5C$($username.Split("\")[1])"
$AuthPostBack = ([xml]$Result[0].Content).AuthenticateResponse.AuthenticationRequirements.PostBack
$AuthURI = "$(([uri]$store).scheme)://$(([uri]$store).host)" + $AuthPostBack


$Result = Invoke-SFRestAPI -Uri $AuthURI -Method POST -Headers $headers -body $body -ContentType "application/x-www-form-urlencoded"
#endregion




#region Request to Authentication Service - The client can then use this data to request a token from the token issuing service as follows
$xml = Generate-AuthXML -forService $resourcesForService -forServiceUrl ($store + "/resources/v2")
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.requesttokenresponse+xml, application/vnd.citrix.requesttokenchoices+xml"
    "Authorization"="CitrixAuth $($([xml]$Result[0].Content).requesttokenresponse.token)"
}

$Result = Invoke-SFRestAPI -Uri ($store + "Auth/auth/v1/token") -Method POST -Headers $headers -body $xml -ContentType "application/vnd.citrix.requesttoken+xml"
#endregion



#region Request to Service Provider (resources)
$token ="$($([xml]$Result[0].Content).requesttokenresponse.token)"
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="application/vnd.citrix.resources+xml"
    "Authorization"="CitrixAuth $token"
    "Accept-Encoding"= "gzip, deflate"
}

$Result = Invoke-SFRestAPI -Uri ($store + "/resources/v2") -Method GET -Headers $headers 
#endregion


#get launchURL 
foreach ($resource in ([xml]$Result[0].Content).resources.resource) {
    if ($resource.title -like $application) { 
        $launchICA = $resource.launchica.url
    }
}

#region Request to Service Provider (resources)
$headers = @{
    "User-Agent"="CitrixReceiver/19.3.0.65534 Windows/10.0 SelfService/19.3.0.4 (Release) X1Class CWACapable"
    "Accept"="*/*"
    "Authorization"="CitrixAuth $token"
    "Accept-Encoding"= "gzip, deflate"
}


#set some custom client names
$ClientNames = @(
    "M456342",
    "U584947",
    "M430984",
    "M455534",
    "M451221",
    "M457777",
    "U569343",
    "M460012",
    "M454214",
    "M454973",
    "M457355",
    "M458141",
    "M456052",
    "M463378"
)

$ClientName = $ClientNames[(Get-Random -Minimum 0 -Maximum ($ClientNames.count-1))]

if ($ClientName.StartsWith("M")) {
    $IPAddress = "10.0.0.$(Get-Random -Minimum 1 -Maximum 230)"
}

if ($ClientName.StartsWith("U")) {
    $IPAddress = "172.6.5.$(Get-Random -Minimum 1 -Maximum 230)"
}


#launch parameters here  -  https://developer-docs.citrix.com/projects/storefront-services-api/en/latest/launch/
[xml]$launchParams = @"
<?xml version="1.0" encoding="utf-8"?>
<q1:launchparams xmlns:q1="http://citrix.com/delivery-services/1-0/launchparams">
    <q1:deviceId>$ClientName</q1:deviceId>
    <q1:clientName>$ClientName</q1:clientName>
    <q1:clientAddress>$IPAddress</q1:clientAddress>
    <q1:display>percent</q1:display>
    <q1:displayPercent>50</q1:displayPercent>
    <q1:showDesktopViewer>true</q1:showDesktopViewer>
    <q1:audio>off</q1:audio>
</q1:launchparams>
"@
#endregion


$Result = Invoke-SFRestAPI -Uri $launchICA -Method POST -Headers $headers -body $launchParams -ContentType "application/vnd.citrix.launchparams+xml"

$random = Get-Random -Minimum 10000 -Maximum 20000
([xml]$Result[0].content).launch.result.ica | Out-File -Encoding ascii -FilePath "$env:TEMP\testlaunch-$random.ica"


#need to find a way to do proper logic for whether it's an IP address or FQDN
$ICAFile = Get-Content "$env:TEMP\testlaunch-$random.ica"
$ICAServerAddr = (($ICAFile | Select-String "^Address=") -split "=" -split ":")[1]

<#
if ( [System.Net.Dns]::GetHostByName($ICAServerAddr) ) {
    
} 

try { 
    $ICAServerName = (Resolve-DnsName $ICAServerAddr).NameHost
    } catch {
    Write-Error "Failed to resolve DNS for $ICAServerAddr, probably because it failed earlier in this process"
    Write-Error $ICAFile
    pause
}
#>
Write-Host "Connecting to Server: $ICAServerAddr"


Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 10)
#Stop-Process -Name wfcrun32 -Force
write-host "$env:TEMP\testlaunch-$random.ica"

$runProcess = @(
 #"C:\Swinst\ICA Client - 12.1\wfica32.exe"
 #"C:\Swinst\ICA Client - 4.9\wfica32.exe",
 #"C:\Swinst\ICA Client - 4.12\wfica32.exe",
 #"C:\Swinst\ICA Client - 1808\wfica32.exe",
 "C:\Program Files (x86)\Citrix\ICA Client\wfica32.exe"
)

Start-Process -FilePath $runProcess[(Get-Random -Minimum 0 -Maximum ($runProcess.count))] -ArgumentList "$env:TEMP\testlaunch-$random.ica"

Write-Host "Pausing until $((Get-Date).AddSeconds(30))"
sleep 30





if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") { 
    Write-Error "Must use 32bit Powershell or else we cannot attach to the ICA COM Object!"
    pause
    }
## need to use 32bit powershell...
[System.Reflection.Assembly]::LoadFile("C:\Program Files (x86)\Citrix\ICA Client\WfIcaLib.dll")
$ICA = New-Object WFICALib.ICAClientClass

#You can use the Keys enumeration which is available in the System.Windows.Forms .Net namespace. This makes the code a bit more “readable”. By default, the System.Windows.Forms namespace is not loaded in PowerShell
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$ICA.OutputMode = [WFICALib.OutputMode]::OutputModeNormal
[int]$EnumHandle = $ICA.EnumerateCCMSessions()
[int]$numSessions = $ICA.GetEnumNameCount($EnumHandle)
Write-Host "Number of live CCM sessions are:$NumSessions"
#[string]$sessionIDs = [string]$numSessions
if ($numSessions -eq 1) {
    $sessionid = $ICA.GetEnumNameByIndex($EnumHandle, $index)
    $ICA.StartMonitoringCCMSession($sessionid, $true)
    $StartTime = Get-Date
    $RandomSessionLength = Get-Random -Minimum 300 -Maximum 360
    Write-Host "Start Time: $StartTime"
    While ($true) {
        sleep (Get-Random -Minimum 2 -Maximum 8)
            if ($StartTime.AddMinutes($RandomSessionLength) -ge ($(Get-Date))) {  #3 hours of activity
                Write-Host "Time remaining: $($StartTime.AddMinutes($RandomSessionLength)-$(Get-Date))"
                try { $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::A) }
                catch { 
                    Write-Host "An error occured (session disconnected?) Disconnecting from automation"
                    $ICA.StopMonitoringCCMSession($sessionid)
                    $ICA.CloseEnumHandle($EnumHandle)
                    break
                }
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::W)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::E)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::S)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::O)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::M)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::E)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::Return)
                sleep 1
                $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::Space)
                sleep 1
            } else {
                Write-Host "Disconnecting from automation"
                $ICA.StopMonitoringCCMSession($sessionid)
                $ICA.CloseEnumHandle($EnumHandle)
                break
            }
        }
} else {
    Write-host "Session IDs for live sessions are:"
    #Get session IDs into an array of strings
    [array]$SessionIDs = @()
    for( $index = 0; $index -lt $NumSessions ; $index++) {
        #Obtain the sessionID by calling GetEnumNameByIndex method
        $SessionID = $ICA.GetEnumNameByIndex($EnumHandle, $index)
        $ICA.StartMonitoringCCMSession($SessionID, $true)
        $ICAusername = $ICA.GetSessionString(1)
        Write-Host "SessionID : $($SessionID)"
        Write-Host "$IcaUsername"
        Write-Host "$($($username -split "\\")[1])"
        if (($username -split "\\")[1] -like $ICAUsername) {
            $StartTime = Get-Date
            $RandomSessionLength = Get-Random -Minimum 60 -Maximum 120
            Write-Host "Start Time: $StartTime"
            While ($true) {
            sleep (Get-Random -Minimum 2 -Maximum 8)
                if ($StartTime.AddMinutes($RandomSessionLength) -ge ($(Get-Date))) {  #3 hours of activity
                    Write-Host "Time remaining: $($StartTime.AddMinutes($RandomSessionLength)-$(Get-Date))"
                    try { $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::A) }
                    catch { 
                        Write-Host "An error occured (session disconnected?) Disconnecting from automation"
                        $ICA.StopMonitoringCCMSession($sessionid)
                        $ICA.CloseEnumHandle($EnumHandle)
                        break
                    }
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::W)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::E)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::S)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::O)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::M)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::E)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::Return)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                    $ICA.Session.Keyboard.SendKeyDown([int][System.Windows.Forms.Keys]::Space)
                    sleep (Get-Random -Minimum 0 -Maximum 8)
                } else {
                    Write-Host "Disconnecting from automation"
                    $ICA.StopMonitoringCCMSession($sessionid)
                    $ICA.CloseEnumHandle($EnumHandle)
                    break
                }
            }
        }
    }
    #Start monitoring the current session with the above sessionID
    $ICA.StartMonitoringCCMSession($SessionID, $true)
    $ICA.StopMonitoringCCMSession($sessionid)
    $ICA.CloseEnumHandle($EnumHandle)
}
Write-Host "Connected?"
$ICA.Connected
