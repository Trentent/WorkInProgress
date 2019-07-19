Start-Transcript -Path "C:\swinst\BannedIPsLog.txt" -Append -NoClobber
$events = Get-EventLog -LogName Security -Newest 1 -InstanceId 4625
$TargetUserName = $events.ReplacementStrings[5]
$SubjectUserSid = $events.ReplacementStrings[0]
$IpAddress = $events.ReplacementStrings[19]



function Check-ForExternalLogon($event) {
    $TargetUserName = $event.ReplacementStrings[5]
    $SubjectUserSid = $event.ReplacementStrings[0]
    $IpAddress = $event.ReplacementStrings[19]
    if ((-not($TargetUserName -like "*myregularaccount*")) -and ($SubjectUserSid -eq "S-1-0-0") -and ($IpAddress -ne "-")) {
        write-output $true
    }
    else
    {
        Write-Output $false
    }
}

if (Check-ForExternalLogon($events)) {
    write-host "Bad Logon Attempt Detected : $(Get-Date)" -ForegroundColor Red
    write-host "Username       : $targetUserName"
    write-host "SubjectUserSid : $SubjectUserSid"
    write-host "IpAddress      : $IpAddress"
    write-host ""
    write-host "Blocking IP $IpAddress..."
    #create firewall rule if not valid
    if (-not(Get-NetFirewallRule -DisplayName "TTYE - Block Bad RDP Attempts" -ErrorAction SilentlyContinue)) {
        Write-Host "RDP blocking firewall rule not found.  Creating rule."
        New-NetFirewallRule -DisplayName "TTYE - Block Bad RDP Attempts" -Direction Inbound -Action Block -RemoteAddress $IpAddress | out-null
        break
    }
    $blockedAddresses = (Get-NetFirewallRule -DisplayName  "TTYE - Block Bad RDP Attempts" | Get-NetFirewallAddressFilter).RemoteAddress
    $blockAddressList = @()
    foreach ($address in $blockedAddresses) {
        $blockAddressList += $address
    }
    if ($blockAddressList.Contains($IpAddress)) {
        Write-Host "WARNING: IpAddress $IpAddress already found in Blocked List!!!!" -ForegroundColor Magenta
        continue
    }
    else {
        $blockAddressList += $IpAddress
        Write-Host "Modifying Rule to block IP Address: $IpAddress" -ForegroundColor Green
        Get-NetFirewallRule -DisplayName  "TTYE - Block Bad RDP Attempts" | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -LocalAddress Any -RemoteAddress $blockAddressList
    }
    
}
Stop-Transcript

