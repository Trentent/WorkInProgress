[CmdletBinding()]
    param (
        [parameter(Mandatory=$true)] [ValidateSet ("LocalGateway","ISPGateway","GoogleDNS","TotalSessionLatency","Everything")]
        [string]$HopToApplyLatency,   
        [Parameter(Mandatory = $False)]
        [uri]$CitrixGateway,
        [Parameter(Mandatory = $False)]
        [string]$PathToClumsyExe,
        [Parameter(Mandatory = $False)]
        [int]$LagInMilliseconds = $(Get-Random -Minimum 75 -Maximum 250),
        [Parameter(Mandatory = $False)]
        [int]$DroppedPacketsPercentage = 0
    )

Write-Verbose "Lag In Milliseconds       : $LagInMilliseconds"
Write-Verbose "Dropped Packets Percentage: $DroppedPacketsPercentage"

if (-not(Test-Path $PathToClumsyExe)) {
    Write-Verbose "Unable to find clumsy.exe... going to download and create the folder structure"
    $CreatePathToClumsy = $PathToClumsyExe -split ("\\")
    #create directory structure if needed
    $PathBuilder = [System.Text.StringBuilder]::new()
    foreach ($object in $CreatePathToClumsy) {
        if(-not($object.EndsWith(".exe"))) {
            [void]$PathBuilder.Append("$object\")
            if (-not(Test-Path $PathBuilder)) {
                Write-Verbose "Creating Folder $PathBuilder"
                New-Item -Path $PathBuilder -ItemType Directory -Force | Out-null
            }
        }
    }
    Write-Verbose "Downloading Clumsy"
    Invoke-WebRequest "https://github.com/jagt/clumsy/releases/download/0.3rc4/clumsy-0.3rc4-win64-a.zip" -UseBasicParsing -OutFile "$env:temp/clumsy0.3rc4.zip"
    Write-Verbose "Expanding $env:temp/clumsy0.3rc4.zip to $($PathBuilder.ToString())"
    Expand-Archive -Path "$env:temp/clumsy0.3rc4.zip" -DestinationPath $PathBuilder
    if (Test-Path $PathToClumsyExe) {
        Write-Verbose "Clumsy successfully installed."
    } else {
        Write-Error "Failed to download/install clumsy."
    }
}

if (-not ($HopToApplyLatency)) {
    Write-Host "What would you like to add latency to?
    1 - Local Gateway
    2 - ISP Gateway
    3 - Google DNS
    4 - Total Session Latency
    5 - All Devices
    6 - ISP Gateway and hops after
    "
    $Option = Read-Host "Enter a number from 1 to 6"


    Write-Host "What is the process name hosting the connection?"
    Write-Host "1) Citrix"
    Write-Host "2) AVD     - msrdc.exe"
    Write-Host "3) Horizon - we can't manipulate the Total Session Metric"
    Write-Host ""
    $VDITech = Read-Host "What technology are you using?"
}

$TotalSessionLatencyIPs = [System.Collections.Generic.List[object]]::new()
If (($VDITech -eq 1) -and ($CitrixGateway.count -eq 0)) {
    [uri]$GatewayURL = Read-Host "What is the Citrix Gateway you are using?"
    $TotalSessionLatencyIPs.add((Resolve-DnsName -Name $GatewayURL.DnsSafeHost).IPAddress)
}

if ($CitrixGateway.count -ge 1) {
    Write-Verbose "Found 1 Citrix Gateway"
    $TotalSessionLatencyIPs.add((Resolve-DnsName -Name $CitrixGateway.DnsSafeHost).IPAddress)
    Write-Verbose "Citrix Gateway IP Resolved to: $TotalSessionLatencyIPs"
}

if ((Get-Process -Name msrdc -ErrorAction SilentlyContinue).count -ge 1) {
    Write-Verbose "Found a RDP connection using the AVD RemoteDesktop client"
    $TotalSessionLatencyIPs.add(((Get-NetTCPConnection -OwningProcess (Get-Process -Name msrdc).Id -LocalAddress $(Get-NetAdapter | Get-NetIPAddress -AddressFamily IPv4).IPAddress).RemoteAddress))
    Write-Verbose "AVD Session Resolved to: $TotalSessionLatencyIPs"
}

$originalprogressPreference = $progressPreference
$progressPreference = 'silentlyContinue'
Write-Verbose "Running Trace Route to GoogleDNS"
$localNetwork = (Test-NetConnection -ComputerName 8.8.8.8 -traceroute)
$progressPreference = $originalprogressPreference

function Test-PrivateIP {
    <#
        .SYNOPSIS
            Use to determine if a given IP address is within the IPv4 private address space ranges.

        .DESCRIPTION
            Returns $true or $false for a given IP address string depending on whether or not is is within the private IP address ranges.

        .PARAMETER IP
            The IP address to test.

        .EXAMPLE
            Test-PrivateIP -IP 172.16.1.2

        .EXAMPLE
            '10.1.2.3' | Test-PrivateIP
    #>
    param(
        [parameter(Mandatory,ValueFromPipeline)]
        [string]
        $IP
    )
    process {

        if ($IP -Match '(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)') {
            $true
        }
        else {
            $false
        }
    }    
}


function Get-LocalGateway ([object]$localNetwork) {
    return $localNetwork.TraceRoute[0]
}

function Get-ISPGateway ([object]$localNetwork) {
    foreach ($IP in $localNetwork.TraceRoute) {
        If (Test-PrivateIP -IP $IP) {
            continue
        } else {
            return $IP
        }
    }
}


Write-Verbose "Finding Local Gateway:"
$LocalGateway = Get-LocalGateway -localNetwork $localNetwork
Write-Verbose "$LocalGateway"

Write-Verbose "Finding ISP Gateway:"
$ISPGateway = Get-ISPGateway -localNetwork $localNetwork
Write-Verbose "$ISPGateway"

Write-Host "Detected the following:"
Write-Host "Local Network Gateway      : $LocalGateway"
Write-Host "ISP Network Gateway        : $ISPGateway"


$clumsyTotalSessionIPs = [System.Text.StringBuilder]::new()
if (($TotalSessionLatencyIPs.count -eq 1) -and ($HopToApplyLatency -eq "TotalSessionLatency")) {
    Write-Host "Session Gateway            : $TotalSessionLatencyIPs"
    [void]$clumsyTotalSessionIPs.Append( "ip.DstAddr == $TotalSessionLatencyIPs" )
}
if (($TotalSessionLatencyIPs.count -eq 1) -and ($HopToApplyLatency -ne "TotalSessionLatency")) {
    Write-Host "Session Gateway            : $TotalSessionLatencyIPs"
    [void]$clumsyTotalSessionIPs.Append( "or ip.DstAddr == $TotalSessionLatencyIPs" )
}

if (($TotalSessionLatencyIPs.count -ge 2) -and ($HopToApplyLatency -ne "TotalSessionLatency")) {
    foreach ($IP in $TotalSessionLatencyIPs) {
        Write-Host "Session Gateway            : $IP"
        [void]$clumsyTotalSessionIPs.Append( "or ip.DstAddr == $IP" )
    }
}

if (($TotalSessionLatencyIPs.count -ge 2) -and ($HopToApplyLatency -eq "TotalSessionLatency")) {
    $firstItem = 0
    foreach ($IP in $TotalSessionLatencyIPs) {
        Write-Host "Session Gateway            : $IP"
        if ($firstItem -eq 0) {
            [void]$clumsyTotalSessionIPs.Append( "ip.DstAddr == $IP" )
            $firstItem = 1
        } else {
            [void]$clumsyTotalSessionIPs.Append( "or ip.DstAddr == $IP" )
        }
    }
}

Write-Host ""
Write-Host "Clumsy arguments:"



switch ($HopToApplyLatency) {
"Everything"          { $clumsyArgs = "outbound" }
"LocalGateway"        { $clumsyArgs = "ip.DstAddr == $LocalGateway or ip.DstAddr == $ISPGateway or ip.DstAddr == 8.8.8.8 $clumsyTotalSessionIPs" }
"ISPGateway"          { $clumsyArgs = "ip.DstAddr == $ISPGateway or ip.DstAddr == 8.8.8.8 $clumsyTotalSessionIPs" }
"GoogleDNS"           { $clumsyArgs = "ip.DstAddr == 8.8.8.8" }
"TotalSessionLatency" { $clumsyArgs = "$clumsyTotalSessionIPs" }
}

Write-Host "$clumsyArgs"

## Buildling command line argument
$clumsyCommandLineArgument = [System.Text.StringBuilder]::new()
[void]$clumsyCommandLineArgument.Append("--filter `"$clumsyArgs`"")
if ($LagInMilliseconds -ge 1) {
    [void]$clumsyCommandLineArgument.Append(" --lag on --lag-time $LagInMilliseconds")
}
if ($DroppedPacketsPercentage -ge 1) {
    [void]$clumsyCommandLineArgument.Append(" --drop on --drop-chance $DroppedPacketsPercentage.0")
}
$clumsyCommandLineArguments = $clumsyCommandLineArgument.ToString()

Write-Host "`n`n"
Write-Host "Starting: " -NoNewline
Write-Host "$PathToClumsyExe $clumsyCommandLineArguments" -ForegroundColor Yellow

#if clumsy is running we'll kill it first
if ($(Get-Process -Name clumsy -ErrorAction SilentlyContinue).count -ge 1) {
    Write-Verbose "Found an existing instance of clumsy. Terminating..."
    Stop-Process -Name clumsy -Force
}

Start-Process -FilePath $PathToClumsyExe -ArgumentList ("$clumsyCommandLineArguments")

<#
Switch ($Option) {
    1 { Write-Host "ip.DstAddr == $LocalGateway"  }
    2 { Write-Host "ip.DstAddr == $ISPGateway"      }
    3 { Write-Host "ip.DstAddr == 8.8.8.8"              }
    4 { Write-Host "ip.DstAddr == $TotalSessionLatencyIP"        }
    5 { Write-Host "ip.DstAddr == $LocalGateway or ip.DstAddr == $ISPGateway or ip.DstAddr == 8.8.8.8 or ip.DstAddr == $TotalSessionLatencyIP"  }
    6 { Write-Host "ip.DstAddr == $ISPGateway or ip.DstAddr == 8.8.8.8 or ip.DstAddr == $TotalSessionLatencyIP"  }
}
#>

<#
Switch ($Option) {
    1 { Write-Host "(ip.DstAddr == $LocalGateway or ip.SrcAddr == $LocalGateway)"  }
    2 { Write-Host "(ip.DstAddr == $ISPGateway or ip.SrcAddr == $ISPGateway)"      }
    3 { Write-Host "(ip.DstAddr == 8.8.8.8 or ip.SrcAddr == 8.8.8.8)"              }
    4 { Write-Host "(ip.DstAddr == $TotalSessionLatencyIP or ip.SrcAddr == $TotalSessionLatencyIP)"        }
    5 { Write-Host "(ip.DstAddr == $LocalGateway or ip.SrcAddr == $LocalGateway) or (ip.DstAddr == $ISPGateway or ip.SrcAddr == $ISPGateway) or (ip.DstAddr == 8.8.8.8 or ip.SrcAddr == 8.8.8.8) or (ip.DstAddr == $TotalSessionLatencyIP or ip.SrcAddr == $TotalSessionLatencyIP)"  }
    6 { Write-Host "(ip.DstAddr == $ISPGateway or ip.SrcAddr == $ISPGateway) or (ip.DstAddr == 8.8.8.8 or ip.SrcAddr == 8.8.8.8) or (ip.DstAddr == $TotalSessionLatencyIP or ip.SrcAddr == $TotalSessionLatencyIP)"  }
}
#>