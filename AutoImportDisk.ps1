<#
    .SYNOPSIS
      Automatically imports a vDisk and then sets the devices to those vDisks.
 
    .DESCRIPTION
      After BISF creates the vDisk image this scheduled task will be called.  It will injest a file from the Store share, "DeployVdisk-$date.xml".  
      Once the file is injested it is turned into a variable in this script and then the file deleted. Whatever vdisk is specified in the file
      is then imported, setup and then copied to the rest of the file shares.
            
    .INPUTS
        None
 
    .OUTPUTS
        None
 
    .NOTES
 
      Author: Trentent Tye
      Editor: Trentent Tye
      Company: TheoryPC
 
      History
      Last Change: 2018.08.17 TT: Script created

      Start a Powershell prompt and use Set-PvsConnection -Server localhost -Port 54321 -User amttye -Password Pa$$w0rd -Domain bottheory.local
      to set a connection under this account.
 
	.LINK
        http://theorypc.ca
    #>if (-not(Test-Path "C:\Logs")) {    mkdir "C:\Logs"}$LogFile = "C:\Logs\AutovDiskImport.log"$serial = Get-Random#load the powershell moduleif (-Not((Get-PSSnapin) -Like "Citrix.PVS.Snapin")){    if (Test-Path "$env:ProgramFiles\Citrix\Provisioning Services Console\Citrix.PVS.SnapIn.dll") {        try {            Add-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction Stop        }        catch {            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": PVS powershell module not loaded.  Attempting to load module.") | out-file $LogFile -Append            $installutil = $env:systemroot + '\Microsoft.NET\Framework64\v4.0.30319\installutil.exe'
            &$installutil "$env:ProgramFiles\Citrix\Provisioning Services Console\Citrix.PVS.SnapIn.dll"            $RetryModuleLoad = $true        }        if ($RetryModuleLoad) {            try {                Add-PSSnapin -Name Citrix.PVS.SnapIn -ErrorAction Stop            }            catch {                Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": PVS powershell module failed to load.") | out-file $LogFile -Append            }        }    }    else {        Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": PVS SnapIn was not found.") | out-file $LogFile -Append    }}Set-PvsConnection -Server localhost -Port 54321 -User amttye -Password 7Ren7en7 -Domain bottheory.local$connection = Get-PvsConnectionWrite-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $connection") | out-file $LogFile -Append$AutoImportvDiskList = ls \\ds1813.bottheory.local\FileShare\vDisks-Test\AutoImport*if ($AutoImportvDiskList.count -eq 0) {    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": No AutoImport files detected.  Aborting") | out-file $LogFile -Append    break}[xml]$vDiskXML = Get-Content $AutoImportvDiskList[0]Remove-Item $AutoImportvDiskList[0] -Force$diskName = $vDiskXML.vDiskFileName.split(".")[0]Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Detected disk name: $diskName.") | out-file $LogFile -Append$source = "\\ds1813.bottheory.local\FileShare\vDisks-Test"<#$vDiskTestStores = @("\\share1\ctx_images\vDisks-Test","\\share2\ctx_images\vDisks-Test","\\share3\ctx_images\vDisks-Test")#>## Login to PVS#add vDisk to the store ## Do not add "ServerName" property to the new-pvsdisklocator command as it will configure "Set this server to provide this vdisk"try {
    New-PvsDiskLocator -Name $diskName -StoreName "Store" -SiteName "CALGARY" -VHDX -NewDiskWriteCacheType 12 -ErrorAction Stop
}
catch {
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": New-PVSDiskLocator failed.") | out-file $LogFile -Append
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
}

#modify vdisk properties
try {
    Set-PvsDisk -Name $diskName -StoreName "Store" -SiteName "CALGARY" -WriteCacheSize 5192 -LicenseMode 2 -AdPasswordEnabled -HaEnabled  -ErrorAction Stop
}
catch {
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Set-PvsDisk failed.") | out-file $LogFile -Append
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
}

try {
    Set-PvsDiskLocator -DiskLocatorName $diskName -StoreName "Store" -SiteName "CALGARY" -RebalanceEnabled -RebalanceTriggerPercent 25 -Enabled -SubnetAffinity 0  -ErrorAction Stop
}
catch {
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Set-PvsDiskLocator failed.") | out-file $LogFile -Append
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
}

<#
#copy vDisks to all other locations
Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Copying $diskName to other shares.") | out-file $LogFile -Append
foreach ($location in $vDiskTestStores) {
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ":  Starting copy : $diskName from $source to $location.") | out-file $LogFile -Append
    Start-Process -filePath ROBOCOPY.exe -ArgumentList ("$source","$location","$diskName*","/MIR","/R:5","/W:0","/XF *.lok","/XD WriteCache","/V","/NP") -NoNewWindow -Wait
    Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ":  Copy complete.") | out-file $LogFile -Append
}
#>


#add all the vdisk to all the sites now.
$sites = Get-PvsSite

foreach ($site in $sites) {
    if ($site.name -ne "CALGARY") {
        try {
            New-PvsDiskLocator -Name $diskName -StoreName "Store" -SiteName $site.Name -VHDX -NewDiskWriteCacheType 9 -ErrorAction Stop
        }
        catch {
            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": New-PVSDiskLocator failed at $($site.name).") | out-file $LogFile -Append
            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
        }

        #modify vdisk properties
        try {
            Set-PvsDisk -Name $diskName -StoreName "Store" -SiteName $site.Name -WriteCacheSize 5192 -LicenseMode 2 -AdPasswordEnabled -HaEnabled  -ErrorAction Stop
        }
        catch {
            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Set-PvsDisk failed at $($site.name).") | out-file $LogFile -Append
            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
        }

        try {
            Set-PvsDiskLocator -DiskLocatorName $diskName -StoreName "Store" -SiteName $site.Name -RebalanceEnabled -RebalanceTriggerPercent 25 -Enabled -SubnetAffinity 0  -ErrorAction Stop
        }
        catch {
            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Set-PvsDiskLocator failed at $($site.name).") | out-file $LogFile -Append
            Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
        }

    }
}

#assign the vDisk to the appropriate device collections.
$Role = $diskName.Split("-")[0]
$OS = $diskName.Split("-")[1]

switch ($Role) {
    "GENERIC" { $Role = "GEN"  }
    "EPIC"    { $Role = "EPIC" }
}

switch ($OS) {
    W10E      { $OS = "10E"  }   #clean up the naming of these two OS's --> the other OS's are fine
    W10EVD    { $OS = "10EVD" }  #clean up the naming of these two OS's --> the other OS's are fine
}

$collectionNamingScheme = "W$OS-$ROLE"
Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Updating device collections with prefix: $collectionNamingScheme") | out-file $LogFile -Append

#get all collections
$DeviceCollections = (Get-PvsDeviceInfo).CollectionName | sort -Unique

foreach ($collection in $DeviceCollections) {
    if ($collection -like "$collectionNamingScheme*") {
    Write-Host "Here"
        $Devices = Get-PvsDeviceInfo | Where {$_.CollectionName -like "$collection"} | Select DeviceName,SiteName,DiskLocatorName
        foreach ($Device in $Devices){
            try {
                Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Assigning $diskname to $($device.deviceName) at $($device.siteName).") | out-file $LogFile -Append
                Add-PvsDiskLocatorToDevice -DiskLocatorName $diskName -DeviceName $Device.DeviceName -SiteName $device.siteName -StoreName "Store" -RemoveExisting  -ErrorAction Stop
            }
            catch {
                Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": Add-PvsDiskLocatorToDevice failed.") | out-file $LogFile -Append
                Write-output  $([DateTime]::Now.toString("yyyy-MM-dd_HHmmss") + " - $serial " + ": $($error[0]).") | out-file $LogFile -Append
            }
        }
    }
}