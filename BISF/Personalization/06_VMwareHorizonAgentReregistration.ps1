<#
	.SYNOPSIS
		Configures the Horizon Agent for Reregistration
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author: Trentent Tye

	.LINK
		https://theorypc.ca
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
    $connectionServer = "hzncon01.bottheory.local"

}

Process {
    Write-BISFLog -Msg "===========================$script_name===========================" -ShowConsole -Color DarkCyan -SubMsg
       
    if ($Env:COMPUTERNAME -like "*RDS*" -and (Test-BISFVMwareHorizonViewSoftware)) {
        Write-BISFLog -Msg "Found RDSH Server with Horizon Agent installed."  -ShowConsole -Color Cyan 
        Write-BISFLog -Msg "Stopping WSNM service"  -ShowConsole -SubMsg
        Stop-Service -Name WSNM -Force

        if (-not(Test-Path "HKLM:\SOFTWARE\Policies\VMware, Inc.")) {
            mkdir "HKLM:\SOFTWARE\Policies\VMware, Inc."
        }
        if (-not(Test-Path "HKLM:\SOFTWARE\Policies\VMware, Inc.\VMware VDM")) {
            mkdir "HKLM:\SOFTWARE\Policies\VMware, Inc.\VMware VDM"
        }
        if (-not(Test-Path "HKLM:\SOFTWARE\Policies\VMware, Inc.\VMware VDM\Log")) {
            mkdir "HKLM:\SOFTWARE\Policies\VMware, Inc.\VMware VDM\Log"
        }

        # Set "newly installed" values
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Management Port"-PropertyType String -Value 32111 -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Managed"-PropertyType Dword -Value 0 -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Broker Public Key" -PropertyType String -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Server Pool DN" -PropertyType String -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "DisconnectLimitMinutes" -PropertyType String -Value 0 -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "IdleLimitMinutes" -PropertyType String -Value 0 -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "MS Mode" -PropertyType String -Value "OFF" -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Broker SSL Certificate Thumbprint" -PropertyType String -Force | Out-null

        New-Item "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager\Agent\Configuration" -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager\Agent\Configuration" -Name "Broker" -PropertyType String -Value "$connectionServer" -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager\Agent\Configuration" -Name "InitialBroker" -PropertyType String -Force | Out-null
        
        Write-BISFLog -Msg "Generating LDAP connection"  -ShowConsole -SubMsg
        Write-BISFLog -Msg "Connection Server : $connectionServer"  -ShowConsole -SubMsg

        #region Query Connection Server
        # Create an ADSI Search
        $Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher

        # Get FQDN
        $DNSLookup = [Net.DNS]::GetHostEntry("$($env:COMPUTERNAME)")
        if ($DNSLookup.HostName.count -eq 1) {
            $FQDN = $DNSLookup.HostName
        } else {
            $FQDN = $DNSLookup.HostName[0]
        }

        # Get only the Group objects
        $Searcher.Filter = "(&(objectclass=pae-PM)(ipHostNumber=$($FQDN)))"


        # Limit the output to 50 objects
        $Searcher.SizeLimit = '50'

        # Get the current domain
        $DomainDN = "LDAP://$connectionServer/DC=vdi, DC=vmware, DC=int"

        # Create an object "DirectoryEntry" and specify the domain, username and password
        $Domain = New-Object `
         -TypeName System.DirectoryServices.DirectoryEntry `
         -ArgumentList $DomainDN

        # Add the Domain to the search
        $Searcher.SearchRoot = "LDAP://$connectionServer/ou=servers,dc=vdi,dc=vmware,dc=int"

        # Execute the Search
        $results = $Searcher.FindAll()
        Write-BISFLog -Msg "LDAP Query Results `n $($results.properties | Out-String)"  -ShowConsole -SubMsg -Color DarkCyan
        #agent Identity

        $ADSPATH = $results.properties.'adspath'
        #endregion

        Write-BISFLog -Msg "Generating Agent Keys"  -ShowConsole -SubMsg -Color DarkCyan
        $guid = $results.Properties.name
        if (Test-Path -Path "$env:ProgramFiles\VMware\VMware View\Agent\jre\bin\java.exe") {
            $commandString = '/c start "MakeAgentKeyPair" /B /WAIT "{0}\VMware\VMware View\Agent\jre\bin\java.exe" -cp "{0}\VMware\VMware View\Agent\lib\messagesecurity.jar";"{0}\VMware\VMware View\Agent\lib\securitymanager.jar";"{0}\VMware\VMware View\Agent\lib\commonutils.jar";"{0}\VMware\VMware View\Agent\lib\jms-9.3.1.jar";"{0}\VMware\VMware View\Agent\lib\log4j-api-2.13.3.jar";"{0}\VMware\VMware View\Agent\lib\log4j-core-2.13.3.jar";"{0}\VMware\VMware View\Agent\lib\log4j-slf4j-impl-2.13.3.jar";"{0}\VMware\VMware View\Agent\lib\slf4j-api-1.7.29.jar";"{0}\VMware\VMware View\Agent\lib\vmw-hzn-log4j2-binding-1.0.jar";"{0}\VMware\VMware View\Agent\lib\vmw-hzn-logger-common-1.0.jar";"{0}\VMware\VMware View\Agent\lib\vmw-hzn-logger-impl-1.0.jar" com.vmware.vdi.messagesecurity.MakeAgentKeyPair ' -f $env:ProgramFiles
            $commandString += $guid
        } else {
            Write-BISFLog -Msg "Unable to find the path: $env:ProgramFiles\VMware\VMware View\Agent\jre\bin\java.exe" -Type E
        }

        Start-Process -FilePath cmd.exe -ArgumentList $commandString -PassThru -NoNewWindow -RedirectStandardOutput "$env:temp\makeagentkeyoutput.txt" -Wait |Out-Null
        $makeAgentKeyPair = (Get-Content "$env:temp\makeagentkeyoutput.txt").Split("|")
        
        Write-BISFLog -Msg "Generated Keys:`n   Agent Identity    : $($makeAgentKeyPair[0])`n   Agent Public Key  : $($makeAgentKeyPair[1])`n   Agent Private Key : $($makeAgentKeyPair[2])"  -ShowConsole -SubMsg -Color DarkCyan

        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Agent Identity" -PropertyType String -Value $makeAgentKeyPair[0] -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Agent Public Key" -PropertyType String -Value $makeAgentKeyPair[1] -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Agent Private Key" -PropertyType String -Value $makeAgentKeyPair[2] -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Agent Key Reference" -PropertyType String -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Server DN" -PropertyType String -Value $results.properties.'distinguishedname' -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Agent\Configuration" -Name "InitialBroker" -PropertyType String -Value "$connectionServer" -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Agent\Configuration" -Name "Broker" -PropertyType String -Value "$connectionServer" -Force | Out-null
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Broker SSL Certificate Thumbprint"-PropertyType String -Force | Out-null

        #Set identical public keys on ldap obj and this registry
        $serverObj = [adsi]($ADSPATH | Out-String)
        $serverObj.'pae-MsgSecPublicKey' = $makeAgentKeyPair[1]
        $serverObj.SetInfo()
        $results = $Searcher.FindAll()
        Write-BISFLog -Msg "Set LDAP pae-MsgSecPublicKey to:`n                       $($results.properties.'pae-msgsecpublickey')"  -ShowConsole -SubMsg -Color DarkCyan
        if ($results.properties.'pae-msgsecpublickey' -ne $makeAgentKeyPair[1]) {
            Write-Error "Failure to set LDAP Value!"
        }

        
        ## Get Public Key
        $Searcher.Filter = "(&(objectclass=pae-VDMProperties))"
        $Searcher.SearchRoot = "LDAP://$connectionServer/cn=Common,ou=Global,ou=Properties,dc=vdi,dc=vmware,dc=int"
        $results = $Searcher.FindAll()
        ## this will populate the HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager\Broker Public Key registry value
        Write-BISFLog -Msg "Setting Broker Public Key $($results.properties.'pae-msgsecpublickey')"  -ShowConsole -SubMsg -Color DarkCyan
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "Broker Public Key" -PropertyType String -Value $results.Properties.'pae-msgsecpublickey' -Force | Out-null


        ## then set MS MODE to ENHANCED
        New-ItemProperty "HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Node Manager" -Name "MS Mode" -PropertyType String -Value "ENHANCED" -Force | Out-null


        $Searcher.Filter = "(&(objectclass=pae-VDMProperties))"
        $Searcher.SearchRoot = "LDAP://$connectionServer/OU=Server,OU=Properties,DC=vdi,DC=vmware,DC=int"
        $results = $Searcher.FindAll()


        ## Get local certificates from:    (Get-ChildItem -Path 'Cert:\LocalMachine\VMware Horizon View Certificates\')[0]  ## There might be one or two...
        ## Do we need to recreate the certificates?  Do they have all the proper properties?  Or should this be blanked before starting the service and it'll
        ## autocreate the certs?

        Write-BISFLog -Msg "Getting Local Certs"  -ShowConsole -SubMsg -Color DarkCyan
        $certificates = invoke-command {gci "cert:\LocalMachine\VMware Horizon View Certificates" -recurse | where {$_.Subject -like "*router*"}} -computername $connectionServer
        Write-BISFLog -Msg "$($certificates | Out-String)"  -ShowConsole -SubMsg -Color DarkCyan

        #$certificates = (Get-ChildItem -Path 'Cert:\LocalMachine\VMware Horizon View Certificates\')
        $certThumbPrints = ""
        if ($certificates.count -ge 2) {
            foreach ($cert in $certificates) {
                $SHA256 = [Security.Cryptography.SHA256]::Create()
                $Bytes = $cert.GetRawCertData()
                $HASH = $SHA256.ComputeHash($Bytes)
                $thumbprint = ([BitConverter]::ToString($HASH).Replace('-',':')).ToLower()
                if ($cert.Thumbprint -ne $certificates[-1].Thumbprint) {  ##this if statement is for line breaks...
                    $certThumbPrints += "$thumbprint#SHA_256`n"
                } else {
                    $certThumbPrints += "$thumbprint#SHA_256"
                }
            }
        } else {
            $certificate = (Get-ChildItem -Path 'Cert:\LocalMachine\VMware Horizon View Certificates\')[0]
            $SHA256 = [Security.Cryptography.SHA256]::Create()
            $Bytes = $Certificate.GetRawCertData()
            $HASH = $SHA256.ComputeHash($Bytes)
            $thumbprint = [BitConverter]::ToString($HASH).Replace('-',':')
            $certThumbPrints += "$thumbprint#SHA_256"
        }

        Write-BISFLog -Msg "Certificate Thumbprint(s): $certThumbPrints"  -ShowConsole -SubMsg -Color DarkCyan
        $serverObj.'pae-AgentRegistrationStatus' = 1
        $serverobj.setInfo()
        $serverObj.RefreshCache()
        $serverobj.putex(1,"pae-SwiftmqSSLThumbprints",0)
        $serverobj.setInfo()
        $serverObj.RefreshCache()
        foreach ($certThumbPrint in $($certThumbPrints).split("`r`n")) {
            $serverobj.putex(3,"pae-SwiftmqSSLThumbprints",@($certThumbPrint))
            $serverobj.setInfo()
        }
        <#
        $thumbprintString = ""
        for ($i=0;$i -lt ($results.Properties.'pae-swiftmqroutersslthumbprints').count; $i++) {
            if ($i -eq 0) {
                $thumbprintString = ($results.Properties.'pae-swiftmqroutersslthumbprints')[$i]
            } else {
                $thumbprintString = $thumbprintString + ";" + ($results.Properties.'pae-swiftmqroutersslthumbprints')[$i]
            }
        }
        #>
        Write-BISFLog -Msg "Starting Horizon Agent Service."  -ShowConsole -SubMsg -Color DarkCyan
        Start-Service -Name WSNM
    }
}

End {
	Add-BISFFinishLine
}
