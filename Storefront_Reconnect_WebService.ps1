<#
.SYNOPSIS
   Session Reconnect Timer
   Timing how long a Citrix Reconnect takes is a painful thing
   Author: Trentent Tye
   Version: 2019.06.21
DESCRIPTION
   A Powershell v5 Script that utilizes invoke-webrequest to connect to a Citrix Storefront server and go through the logon and launch process
.PARAMETER Store 
   Storefront URL -- eg http://bottheory.local/Citrix/StoreWeb/
.PARAMETER Loop 
   Run this script forever or once
.PARAMETER Domain
    The domain for your user.  Only needed with ExplicitAuth
.PARAMETER Username
    The name of the user you're testing with.  Only needed with ExplicitAuth
.PARAMETER Password
    The password of your user.  Only needed with ExplicitAuth
.PARAMETER Application
    The name of the application as it appears in Storefront
.PARAMETER DomainAuth
    Uses Domain Pass-through Authentication
.PARAMETER ExplicitAuth
    Uses Explicit Authentication.  This parameter requires domain, username and password to be populated as well.
.PARAMETER Delay
    How long to delay between runs
.EXAMPLE
    Explicit Authentication with username abooth, domain Bottheory, launching application Microsoft Edge and looping forever with a 20 second delay between runs
   ./Stress_Storefront_WebService.ps1 -explicitAuth -domain bottheory -username abooth -password C0mp!exPass -store https://sf02.bottheory.local/Citrix/StoreWeb -application "Microsoft Edge" -loop -delay 20

   Use Domain Passthrough Authentication with the current user account, launching application Microsoft Edge and looping forever with a 30 second delay between runs
   ./Stress_Storefront_WebService.ps1 -domainAuth -store https://sf02.bottheory.local/Citrix/StoreWeb -application "Microsoft Edge" -loop -delay 30

#>
Param
(
    [string]$store,
    [string]$domain,
    [string]$username,
    [string]$password,
    [string]$application,
    [switch]$domainAuth,
    [switch]$explicitAuth,
    [switch]$loop,
    [int]$delay

)



function ReconnectSessionTest {
    Param
    (
        [string]$store,
        [string]$domain,
        [string]$username,
        [string]$password,
        [string]$application,
        [switch]$domainAuth,
        [switch]$explicitAuth
    )

    $VerbosePreference = "silentlyContinue"
    $ErrorActionPreference = "stop"
    if ($store.EndsWith("/")) {
        Write-host "Store:           $store" -ForegroundColor Cyan
    } else {
        $store = $store + "/"
        Write-host "Store:           $store" -ForegroundColor Cyan
    }

    if ($domainAuth) {
        Write-Host "Authentication : Domain Pass-Through" -ForegroundColor Cyan
    }
    if ($explicitAuth) {
        Write-Host "Authentication : Explicit" -ForegroundColor Cyan
        if ($username -eq $null) { Write-Error "Username parameter is required" } else {Write-host "Username:         $username" -ForegroundColor Cyan}
        if ($domain -eq $null)   { Write-Error "Domain parameter is required"   } else {Write-host "Domain:           $domain" -ForegroundColor Cyan}
        if ($password -eq $null) { Write-Error "Password parameter is required" } 
    }
    Write-Host "Application :    $application" -ForegroundColor Cyan

    #perf enhancement - disable invoke-webrequest progress bar
    $ProgressPreference = 'SilentlyContinue'

    #are we using http or https?  This is need for the X-Citrix-IsUsingHTTPS cookie.
    $httpOrhttps = $store.split(":")
    if ($httpOrhttps[0] -eq "https") {
        $httpOrhttps = "Yes"
    } else {
        $httpOrhttps = "No"
    }

    $StartMs = Get-Date

    #properties for stats to export to CSV
    $prop = New-Object System.Object
    $prop  | Add-Member -type NoteProperty -name "Runtime" -value $StartMs



    
    $stage = "Initial Connection"
    #First connection to root of site
    $headers = @{
        "Accept"='application/xml, text/xml, */*; q=0.01';
        "Content-Length"="0";
        "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    }
    write-host  -ForegroundColor Yellow "Stage: $stage"
    $duration = measure-command {Invoke-WebRequest -Uri $store -Method GET -Headers $headers -SessionVariable SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds



    <#
    https://citrix.github.io/storefront-sdk/requests/#client-configuration
    Client Configuration
    #>
    $stage = "Client Configuration"
    $headers = @{
    "Accept"='application/xml, text/xml, */*; q=0.01';
    "Content-Length"="0";
    "X-Requested-With"="XMLHttpRequest";
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Referer"=$store;
    }
    write-host  -ForegroundColor Yellow "Stage: $stage"
    $duration = measure-command {Invoke-WebRequest -Uri ($store + "Home/Configuration") -Method POST -Headers $headers -ContentType "application/x-www-form-urlencoded" -WebSession $sfsession -UseBasicParsing}  -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds

    
    # csrf cookie
    $csrf = $sfsession.cookies.GetCookies($store)|where{$_.name -like "CsrfToken"}
    $cookiedomain = $csrf.Domain



    <#
    https://citrix.github.io/storefront-sdk/requests/#authentication-methods
    Note
    The client must first make a POST request to /Resources/List. Since the user is not yet authenticated, this returns a challenge in the form of a CitrixWebReceiver- Authenticate header with the GetAuthMethods URL in the location field.
    #>
    $stage = "Get Authentication Methods"
    $headers = @{
    "Content-Type"='application/x-www-form-urlencoded; charset=UTF-8';
    "Accept"='application/json, text/javascript, */*; q=0.01';
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Csrf-Token"=$csrf.value;
    "Referer"=$store;
    "format"='json&resourceDetails=Default';
    }

    write-host  -ForegroundColor Yellow "Stage: $stage"
    $duration = measure-command {Invoke-WebRequest -Uri ($store + "Resources/List") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds




    <#
    https://citrix.github.io/storefront-sdk/requests/#example-get-auth-methods
    #>
    $stage = "Get Auth Methods"
    #Gets authentication methods
    $headers = @{
    "Accept"='application/xml, text/xml, */*; q=0.01';
    "Content-Length"="0";
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Referer"=$store;
    "Csrf-Token"=$csrf.value;
    }
    write-host -ForegroundColor Yellow "Stage: $stage"
    
    $duration = measure-command {Invoke-WebRequest -Uri ($store + "Authentication/GetAuthMethods") -Method POST -Headers $headers -WebSession $sfsession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds



    if ($ExplicitAuth) {
        <#
        https://citrix.github.io/storefront-sdk/requests/#domain-pass-through-and-smart-card-authentication
        Explicit Authentication
        #>
        $stage = "Explicit Authentication - Get PostBack URL"
        write-host  -ForegroundColor Yellow "$stage"
        #Start Login Process
        $headers = @{
        "Accept"="application/xml, text/xml, */*; q=0.01";
        "Csrf-Token"=$csrf.Value;
        "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
        "Content-Length"="0";
        "X-Citrix-AM-CredentialTypes"="none, username, domain, password, newpassword, passcode, savecredentials, textcredential, webview, webview";
        "X-Citrix-AM-LabelTypes"="none, plain, heading, information, warning, error, confirmation, image";
        }

        #Add cookies that would normally prompt
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsUserPreferredClient"
        $cookie.Value = "Native"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsClientDetectionDone"
        $cookie.Value = "true"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsHasUpgradeBeenShown"
        $cookie.Value = "true"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        write-host  -ForegroundColor Yellow "Stage: $stage"
        $duration = measure-command {$explicit = Invoke-WebRequest -Uri ($store + "ExplicitAuth/Login") -Method POST -Headers $headers -WebSession $SFSession -UseDefaultCredentials -UseBasicParsing} -ErrorAction Stop
        $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds
        $explictPostBack = ([xml]$explicit.Content).AuthenticateResponse.AuthenticationRequirements.PostBack



   


        $stage = "Explicit Authentication - LoginAttempt"
        #Start Login Process
        $headers = @{
        "Accept"="application/xml, text/xml, */*; q=0.01";
        "Csrf-Token"=$csrf.Value;
        "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
        "Content-Length"="0";
        "X-Citrix-AM-CredentialTypes"="none, username, domain, password, newpassword, passcode, savecredentials, textcredential, webview, webview";
        "X-Citrix-AM-LabelTypes"="none, plain, heading, information, warning, error, confirmation, image";
        }

        #Add cookies that would normally prompt
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsUserPreferredClient"
        $cookie.Value = "Native"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsClientDetectionDone"
        $cookie.Value = "true"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsHasUpgradeBeenShown"
        $cookie.Value = "true"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $body = @{
        "username"="$domain" + "\" + "$username";
        "password"=$password;
        "saveCredentials"=$false;
        "loginBtn"="Log On";
        "StateContext"="";
        }
        write-host  -ForegroundColor Yellow "Stage: $stage"
        $duration = measure-command {$explicitLogin = Invoke-WebRequest -Uri ($store + "$explictPostBack") -Method POST -Headers $headers -Body $body -WebSession $SFSession -UseDefaultCredentials -UseBasicParsing} -ErrorAction Stop
        $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds

        <#
        https://citrix.github.io/storefront-sdk/how-the-api-works/#cookies
        CtxsAuthId - HttpOnly - Response indicating successful authentication - Protects against session fixation attacks
        #>
        #set CtxsAuthId cookie because we authenticated.
        foreach ($item in $explicitLogin.Headers.'Set-Cookie'.Split(";")) {
            $values = $item.split("=")
            if ($values[0] -eq "CtxsAuthId") {
            $cookie = New-Object System.Net.Cookie
            $cookie.Name = "$($values[0])"
            $cookie.Value = "$($values[1])"
            $cookie.Domain = $cookiedomain
            $sfsession.Cookies.Add($cookie)
            }
        }
    }


    if ($domainAuth) {
        <#
        https://citrix.github.io/storefront-sdk/requests/#domain-pass-through-and-smart-card-authentication
        Domain Pass-Through and Smart Card Authentication
        #>
    
        $stage = "Domain Pass-Through and Smart Card Authentication"
        write-host  -ForegroundColor Yellow "$stage"
        #Start Login Process
        $headers = @{
        "Accept"="application/xml, text/xml, */*; q=0.01";
        "Csrf-Token"=$csrf.Value;
        "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
        "Content-Length"="0";
        }

        #Add cookies that would normally prompt
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsUserPreferredClient"
        $cookie.Value = "Native"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsClientDetectionDone"
        $cookie.Value = "true"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "CtxsHasUpgradeBeenShown"
        $cookie.Value = "true"
        $cookie.Domain = $cookiedomain
        $sfsession.Cookies.Add($cookie)

        write-host  -ForegroundColor Yellow "Stage: $stage"
        $duration = measure-command {$domainPassthroughLogin = Invoke-WebRequest -Uri ($store + "DomainPassthroughAuth/Login") -Method POST -Headers $headers -WebSession $SFSession -UseDefaultCredentials -UseBasicParsing}
         
        $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds

        <#
        https://citrix.github.io/storefront-sdk/how-the-api-works/#cookies
        CtxsAuthId - HttpOnly - Response indicating successful authentication - Protects against session fixation attacks
        #>
        #set CtxsAuthId cookie because we authenticated.
        foreach ($item in $domainPassthroughLogin.Headers.'Set-Cookie'.Split(";")) {
            $values = $item.split("=")
            if ($values[0] -eq "CtxsAuthId") {
            $cookie = New-Object System.Net.Cookie
            $cookie.Name = "$($values[0])"
            $cookie.Value = "$($values[1])"
            $cookie.Domain = $cookiedomain
            $sfsession.Cookies.Add($cookie)
            }
        }

    }
    $username = $env:Username

    <#
    https://citrix.github.io/storefront-sdk/requests/#resource-enumeration
    Typically, this request requires an authenticated session, indicated by the cookies ASP.NET_SessionId and CtxsAuthId. However, when the Web Proxy is configured to use an unauthenticated Store, an authenticated session is not required.
    The Web Proxy always performs a fresh enumeration for the user by communicating with the StoreFront Store service to pick up any changes that may have occurred.
    #>
    $stage = "Resource Enumeration"
    #Gets resources and required ICA URL
    $headers = @{
    "Content-Type"='application/x-www-form-urlencoded; charset=UTF-8';
    "Accept"='application/json, text/javascript, */*; q=0.01';
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Csrf-Token"=$csrf.value;
    "Referer"=$store;
    "X-Requested-With"="XMLHttpRequest";
    }

    $body = @{
    "format"='json';
    "resourceDetails"='Default';
    }

    write-host -ForegroundColor Yellow "Component $stage"
    $duration = measure-command { $content = Invoke-WebRequest -Uri ($store + "Resources/List") -Method POST -Headers $headers -body $body -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds


    #save the list of applications we got from Storefront
    $resources = $content.content | ConvertFrom-Json
    write-host  -ForegroundColor Yellow "Found $($resources.resources.count) applications"


    <#
    https://citrix.github.io/storefront-sdk/requests/#get-user-name
    Use this request to obtain the full user name, as configured in Active Directory. If the full user name is unavailable, the user's logon name is returned instead.
    This request requires an authenticated session, indicated by the cookies ASP.NET_SessionId and CtxsAuthId. When using an unauthenticated Store, no user has actually logged on and an HTTP 403 response is returned.
    The Web Proxy uses the StoreFront Token Validation service to obtain the user name from the authentication token.
    #>
    $stage = "Get User Name - 1"
    #getUserName
    $headers = @{
    "Accept"='text/plain, */*; q=0.01';
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Csrf-Token"=$csrf.value;
    "Referer"=$store;
    "X-Requested-With"="XMLHttpRequest";
    }

    write-host -ForegroundColor Yellow "Stage $stage"
    $duration = measure-command { $content = Invoke-WebRequest -Uri ($store + "Authentication/GetUserName") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds


    <#
    undocumented?  For password self reset?
    #>
    $stage = "AllowSelfServiceAccountManagement"
    #AllowSelfServiceAccountManagement?
    $headers = @{
    "Accept"='text/plain, */*; q=0.01';
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Csrf-Token"=$csrf.value;
    "Referer"=$store;
    "X-Requested-With"="XMLHttpRequest";
    }

    write-host -ForegroundColor Yellow "Stage: $stage"

    $duration = measure-command { $content = Invoke-WebRequest -Uri ($store + "ExplicitAuth/AllowSelfServiceAccountManagement") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds

    <#
    https://citrix.github.io/storefront-sdk/requests/#get-user-name
    Use this request to obtain the full user name, as configured in Active Directory. If the full user name is unavailable, the user's logon name is returned instead.
    This request requires an authenticated session, indicated by the cookies ASP.NET_SessionId and CtxsAuthId. When using an unauthenticated Store, no user has actually logged on and an HTTP 403 response is returned.
    The Web Proxy uses the StoreFront Token Validation service to obtain the user name from the authentication token.
    #>
    $stage = "Get User Name - 2"
    $headers = @{
    "Accept"='text/plain, */*; q=0.01';
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Csrf-Token"=$csrf.value;
    "Referer"=$store;
    "X-Requested-With"="XMLHttpRequest";
    }

    Write-Host "Stage: $stage"  -ForegroundColor Yellow
    $duration = measure-command {$content = Invoke-WebRequest -Uri ($store + "Authentication/GetUserName") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds



    <#
    List any existing sessions
    #>
    $stage = "Session Enumeration"
    $headers = @{
    "Accept"='text/plain, */*; q=0.01';
    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
    "Csrf-Token"=$csrf.value;
    "Referer"=$store;
    "X-Requested-With"="XMLHttpRequest";
    }

    $body = @{
    "excludeActive"="$true";
    }

    Write-Host "Stage: $stage"  -ForegroundColor Yellow
    $duration = measure-command {$content = Invoke-WebRequest -Uri ($store + "Sessions/ListAvailable ") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds

    $sessions = $content.Content | ConvertFrom-Json

    if ($sessions.count -ge 1) {  #We've found at least 1 session to reconnect to!
        Write-Host "Found $($sessions.Count) session(s):" -ForegroundColor Cyan
        foreach ($session in $sessions) {
            Write-Host "  $($session.initialApp)" -ForegroundColor Cyan
        }

        $foundSession = $false #we'll use this variable to see if we can find the application.

        #check if app matches our requested app.  The intial app name maybe truncated so we'll be searching with wild cards... hopefully there aren't any name clashes!
        foreach ($session in $sessions) {
            if ("$application" -like "$($session.initialapp)*" ) {
                $foundSession = $true
                #reconnect to disconnected session!

                $stage = "Session Reconnection - Launch Status"
                $headers = @{
                "Accept"='text/plain, */*; q=0.01';
                "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
                "Csrf-Token"=$csrf.value;
                "Referer"=$store;
                "X-Requested-With"="XMLHttpRequest";
                }

                Write-Host "Stage: $stage"  -ForegroundColor Yellow
                $duration = measure-command {$content = Invoke-WebRequest -Uri ($store + "$($session.launchstatusurl) ") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
                $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds

                $result = $content | ConvertFrom-Json
                if ($result.status -eq "success") {
                    #session is ready for reconnection
                    #attempting reconnection
                    $stage = "Session Reconnection - LaunchUrl"
                    $headers = @{
                    "Accept"='text/plain, */*; q=0.01';
                    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
                    "Csrf-Token"=$csrf.value;
                    "Referer"=$store;
                    "X-Requested-With"="XMLHttpRequest";
                    }

                    Write-Host "Stage: $stage" -ForegroundColor Yellow
                    $duration = measure-command {$content = Invoke-WebRequest -Uri ($store + "$($session.LaunchUrl)" + "?CsrfToken=$($headers.'Csrf-Token')&launchId=$(Get-Date -UFormat %s -Millisecond 0)") -Method Get -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
                    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds


                    #attempt to reconnect to session
                    $fileName = $session.LaunchUrl | Split-Path -Leaf
                    $icaFileContent = [System.Text.Encoding]::UTF8.GetString($content.content)

                    $icaFileContent | Out-File "$env:temp\$fileName" -Encoding utf8 -Force

                    $sessionFound = $false

                    $launchServer = (($icaFileContent | Out-String | Select-string -Pattern "Address=.+" | % { $_.Matches } | % { $_.Value }) -split ("=") -split (":"))[1]
                    Write-Host "Connected to Server : $launchServer" -ForegroundColor Cyan

                    $userState = quser /server:$launchServer
                    if ($VerbosePreference -eq "continue") {
                        $userState
                    }
                    $loopCount = 0
                    if ($userState | select-string -Pattern "$username.+Disc" -Quiet) {
                        Write-Host "Session found in disconnected state.  Attempting to reconnect..." -ForegroundColor Green
                        . "$env:temp\$fileName"  #ICA file
                        do {
                            $loopCount = $loopCount+1
                            sleep 1
                            $userState = quser /server:$launchServer   #get SessionState
                            if ($userState | select-string -Pattern "$username.+Active" -Quiet) {
                                #session found active (that means we reconnected successfully)
                                $sessionFound = $true 
                            }
                            if ($loopCount -eq 30) {
                                Write-Error "Unable to reconnect to session."
                            }
                        } until ($sessionFound -eq $true)
                        Write-Host "Reconnected!" -ForegroundColor Green
                    } else {
                        Write-Host "Session was found in an Active state.  Attempting to Disconnect..." -ForegroundColor Green
                    }


                    $userState = quser /server:$launchServer
                    if ($VerbosePreference -eq "continue") {
                        $userState
                    }
                    #disconnect from all sessions
                    $stage = "Session Disconnect"
                    $headers = @{
                    "Accept"='text/plain, */*; q=0.01';
                    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
                    "Csrf-Token"=$csrf.value;
                    "Referer"=$store;
                    "X-Requested-With"="XMLHttpRequest";
                    }

                    Write-Host "Stage: $stage" -ForegroundColor Yellow
                    $duration = measure-command {$content = Invoke-WebRequest -Uri ($store + "Sessions/Disconnect") -Method Get -Headers $headers -WebSession $SFSession -UseBasicParsing} -ErrorAction Stop
                    write-verbose $content.content
                    $prop  | Add-Member -type NoteProperty -name "$stage" -value $duration.TotalSeconds
                    $SessionFound = $false
                    $loopCount = 0
                    do {
                        $loopCount = $loopCount+1
                        sleep 1
                        $userState = quser /server:$launchServer   #need to get session state
                        $content = Invoke-WebRequest -Uri ($store + "Sessions/Disconnect") -Method Get -Headers $headers -WebSession $SFSession -UseBasicParsing
                        write-verbose $content.content
                        if ($userState | select-string -Pattern "$username.+Disc" -Quiet) {
                            $sessionFound = $true 
                            
                        }
                        if ($loopCount -eq 4) {
                            Start-Process quser.exe -argumentList @("/server:$launchServer") -NoNewWindow -Wait
                            Write-Host "Attempting to disconnect session with tsdiscon"
                            foreach ($line in ($userState | select-string -Pattern "$username.+Active")) { #looking for active sessions to disconnect
                                $sessionLine = $line -split "\s+"
                                Start-Process tsdiscon.exe -ArgumentList @("$($sessionLine[3])", "/server:$launchServer") -NoNewWindow -Wait
                                Start-Process quser.exe -argumentList @("/server:$launchServer") -NoNewWindow -Wait
                            }
                        }

                    } until (($sessionFound -eq $true) -or ($loopCount -ge 5))
                }
            }
        }
    }
    
    if (-not($foundSession)) {
        #no existing session found - let's launch the application
        <#
        List all resources
        #>
        $stage = "Resources List"
        $headers = @{
        "Accept"='text/plain, */*; q=0.01';
        "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
        "Csrf-Token"=$csrf.value;
        "Referer"=$store;
        "X-Requested-With"="XMLHttpRequest";
        }

        $body = @{
        "excludeActive"="$true";
        }

        Write-Host "Stage: $stage"  -ForegroundColor Yellow
        $content = Invoke-WebRequest -Uri ($store + "/Resources/List ") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing
        $resources = ($content.Content | convertfrom-json).resources

        foreach ($resource in $resources) {
            if ($resource.name -eq $application) {
                $stage = "Resource - Launch Status"
                $headers = @{
                "Accept"='text/plain, */*; q=0.01';
                "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
                "Csrf-Token"=$csrf.value;
                "Referer"=$store;
                "X-Requested-With"="XMLHttpRequest";
                }
                $capture = $resource
                Write-Host "Stage: $stage"  -ForegroundColor Yellow
                $content = Invoke-WebRequest -Uri ($store + "$($resource.launchstatusurl) ") -Method POST -Headers $headers -WebSession $SFSession -UseBasicParsing
                $result = $content | ConvertFrom-Json
                
                if ($result.status -eq "success") {
                    #resource is ready
                    #attempting launch
                    $stage = "Resource - LaunchUrl"
                    $headers = @{
                    "Accept"='text/plain, */*; q=0.01';
                    "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
                    "Csrf-Token"=$csrf.value;
                    "Referer"=$store;
                    "X-Requested-With"="XMLHttpRequest";
                    }

                    Write-Host "Stage: $stage" -ForegroundColor Yellow
                    $content = Invoke-WebRequest -Uri ($store + "$($resource.LaunchUrl)" + "?CsrfToken=$($headers.'Csrf-Token')&launchId=$(Get-Date -UFormat %s -Millisecond 0)") -Method Get -Headers $headers -WebSession $SFSession -UseBasicParsing
                    $fileName = $resource.LaunchUrl | Split-Path -Leaf
                    #connecting to new application
                    $icaFileContent = [System.Text.Encoding]::UTF8.GetString($content.content)
                    $icaFileContent | Out-File "$env:temp\$fileName" -Encoding utf8 -Force
                    . "$env:temp\$fileName"  #ICA file

                    $launchServer = (($icaFileContent | Out-String | Select-string -Pattern "Address=.+" | % { $_.Matches } | % { $_.Value }) -split ("=") -split (":"))[1]

                    $sessionFound = $false
                    do {
                        sleep 1
                        $userfound = Start-process quser.exe -argumentList @("/server:$launchServer") -Wait -WindowStyle Minimized   #need to get server IP from ICA file
                        if ($userfound | select-string "$username" | Select-String "Active" -Quiet) {
                            #session found active (that means we reconnected successfully)
                            $sessionFound = $true 
                        }
                    } until ($sessionFound -eq $true)

                    #disconnect from all sessions
                    $stage = "Session Disconnect"
                    $headers = @{
                        "Accept"='text/plain, */*; q=0.01';
                        "X-Citrix-IsUsingHTTPS"="$httpOrhttps";
                        "Csrf-Token"=$csrf.value;
                        "Referer"=$store;
                        "X-Requested-With"="XMLHttpRequest";
                    }
                    Write-Host "Stage: $stage" -ForegroundColor Magenta
                    $content = Invoke-WebRequest -Uri ($store + "Sessions/Disconnect") -Method Get -Headers $headers -WebSession $SFSession -UseBasicParsing
                    write-host $content.content
                }
            }
        }
    }

    <#
    Export information to CSV
    #>
    $EndMs = Get-Date
    write-host "Loop took $($EndMs - $StartMs)"
    $prop  | Add-Member -type NoteProperty -name "Total Runtime" -value $($EndMs - $StartMs)
    $prop  | export-csv StressStorefront.csv -NoTypeInformation -Append -Force

}


Write-Host "DomainAuth: $domainAuth"
Write-Host "explicitAuth: $explicitAuth"

if ($loop) {
    while ($true) {
        if ($domainAuth -eq $true) {
            ReconnectSessionTest -store $store -domainAuth -application $application
        }
        if ($explicitAuth -eq $true) {
            ReconnectSessionTest -store $store -explicitAuth -application $application -username $username -domain $domain -password $password
        }
        if ($delay -ne $null) {
            Write-Host "Sleeping for $delay seconds"
            Start-Sleep $delay
        }
    }
} else {
    if ($domainAuth -eq $true) {
        Write-Host "DomainAuth: $domainAuth"
        ReconnectSessionTest -store $store -domainAuth -application $application
    }
    if ($explicitAuth  -eq $true) {
        Write-Host "explicitAuth: $explicitAuth"
        ReconnectSessionTest -store $store -explicitAuth -application $application -username $username -domain $domain -password $password
    }
}