param(
  [parameter(Mandatory=$true)]  [ValidateSet ("Generic")][string]$VMType,
  [parameter(Mandatory=$true)]  [ValidateSet ("2012R2","2016","2019","2008R2","W10EVD","Win7SP1","W10E")][string]$OperatingSystem,
  #[parameter(Mandatory=$false)] [switch]$scheduledTask
  [parameter(Mandatory=$false)] [string]$SwitchName = "Outbound"
)

function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

if (-not(Test-Administrator)) {
    Write-Host "Please rerun with Administrator priveleges" -ForegroundColor Red
    pause
    exit
}

#import module for hyper-v and failover clustering.  If these modules are not present you may need to install RSAT or just add the roles if on Server 2019+ or Win10 1809+
ipmo virtualmachinemanager -erroraction SilentlyContinue
ipmo FailoverClusters -erroraction SilentlyContinue
ipmo Hyper-V -erroraction SilentlyContinue



if ($scheduledTask) { Start-Transcript -OutputDirectory C:\swinst\MDT_CreateBLD.Log }

$ErrorActionPreference = "stop"
#region supportingCode
#region functions

#endregion functions

#region properties
#setup KMS product keys
switch ( $OperatingSystem )
    {
        "2008R2"     { $pkey = 'YC6KT-GKW9T-YTKYR-T4X34-R7VHC'  }
        "2012R2"     { $pkey = 'D2N9P-3P6X9-2R39C-7RTCD-MDVJX'  }
        "2016"       { $pkey = 'WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY'  }
        "2019"       { $pkey = 'N69G4-B89J2-4G8F4-WWYCC-J464C'  }
        "W10EVD"     { $pkey = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'  }
        "W10E"       { $pkey = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'  }
        "Win7SP1"    { $pkey = '33PXH-7Y6KF-2VJC9-XBBR8-HVTHH'  }
    }

#setup TaskSequence ID's
switch ( $OperatingSystem )
    {
        "2008R2"     { $taskSequenceId = 'WIN2K8R2_X64'  }
        "2012R2"     { $taskSequenceId = 'WIN2K12R2_X64'  }
        "2016"       { $taskSequenceId = '010'  }
        "2019"       { $taskSequenceId = 'WIN2K19_1809_X64' }
        "W10EVD"     { $taskSequenceId = 'WIN10_1903'  }
        "W10E"       { $taskSequenceId = 'WIN10_1903'  }
        "Win7SP1"    { $taskSequenceId = 'WIN7SP1X64'  }
    }

#endregion properties

#region INI_Reader_Editor
#taken from here: https://gallery.technet.microsoft.com/scriptcenter/Edit-old-fashioned-INI-f8fbc067
$code=@'
/* ======================================================================

C# Source File -- Created with SAPIEN Technologies PrimalScript 2011

NAME:

AUTHOR: James Vierra, DSS
DATE  : 8/30/2012

COMMENT:

Examples:
add-type -Path profileapi.cs

$sb = New-Object System.Text.StringBuilder(256)
[profileapi]::GetPrivateProfileString('section1', 'test1', 'dummy', $sb, $sb.Capacity, "$pwd\test.ini")
Write-Host ('Returned value is {0}.' -f $sb.ToString()) -ForegroundColor green

[profileapi]::WritePrivateProfileString('section2', 'test5', 'Some new value', "$pwd\test.ini")

[profileapi]::GetPrivateProfileString('section2', 'test5', 'dummy', $sb, $sb.Capacity, "$pwd\test.ini")
Write-Host ('Returned value is {0}.' -f $sb.ToString()) -ForegroundColor green

====================================================================== */
using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
public class ProfileAPI{
	
	[DllImport("kernel32.dll")]
	public static extern bool WriteProfileSection(
	string lpAppName,
		   string lpString);
	
	[DllImport("kernel32.dll")]
	public static extern bool WriteProfileString(
	string lpAppName,
		   string lpKeyName,
		   string lpString);
	
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	[return: MarshalAs(UnmanagedType.Bool)]
	public static extern bool WritePrivateProfileString(
	string lpAppName,
		   string lpKeyName,
		   string lpString,
		   string lpFileName);
	
	[DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
	public static extern uint GetPrivateProfileSectionNames(
	IntPtr lpReturnedString,
		   uint nSize,
		   string lpFileName);
	
	[DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
	static extern uint GetPrivateProfileSection(string lpAppName, IntPtr lpReturnedString, uint nSize, string lpFileName);
	
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern uint GetPrivateProfileString(
	string lpAppName,
		   string lpKeyName,
		   string lpDefault,
		   StringBuilder lpReturnedString,
		   uint nSize,
		   string lpFileName);
	public static string[] GetSectionNames(string iniFile) {
		uint MAX_BUFFER = 32767;
		IntPtr pReturnedString = Marshal.AllocCoTaskMem((int)MAX_BUFFER);
		uint bytesReturned = GetPrivateProfileSectionNames(pReturnedString, MAX_BUFFER, iniFile);
		if (bytesReturned == 0) {
			Marshal.FreeCoTaskMem(pReturnedString);
			return null;
		}
		string local = Marshal.PtrToStringAnsi(pReturnedString, (int)bytesReturned).ToString();
		char[] c = new char[1];
		c[0] = '\x0';
		return local.Split(c, System.StringSplitOptions.RemoveEmptyEntries);
		//Marshal.FreeCoTaskMem(pReturnedString);
		//use of Substring below removes terminating null for split
		//char[] c = local.ToCharArray();
		//return MultistringToStringArray(ref c);
		//return c;
		//return local; //.Substring(0, local.Length - 1).Split('\0');
	}
	
	public static string[] GetSection(string iniFilePath, string sectionName) {
		uint MAX_BUFFER = 32767;
		IntPtr pReturnedString = Marshal.AllocCoTaskMem((int)MAX_BUFFER);
		uint bytesReturned = GetPrivateProfileSection(sectionName, pReturnedString, MAX_BUFFER, iniFilePath);
		if (bytesReturned == 0) {
			Marshal.FreeCoTaskMem(pReturnedString);
			return null;
		}
		string local = Marshal.PtrToStringAnsi(pReturnedString, (int)bytesReturned).ToString();
		char[] c = new char[1] { '\x0' };
		return local.Split(c, System.StringSplitOptions.RemoveEmptyEntries);
	}
	
}
'@

add-type $code
#endregion INI_Reader_Editor
#endregion supportingCode
 
$iniFile = "C:\DeploymentShare\Control\CustomSettings.ini"


#Set VM Generation
switch($OperatingSystem) {
    "2016"       { $Generation = 2 }
    "2008R2"     { $Generation = 1 }
    "2012R2"     { $Generation = 2 }
    "2019"       { $Generation = 2 }
    "W10E"       { $Generation = 2 }
    "W10EVD"     { $Generation = 2 }
    "Win7SP1"    { $Generation = 1 }
}

switch ($VMType) { 
    "Generic"   { 
        switch($OperatingSystem) {
            "2016"       { $MacAddress = "00:50:56:3F:02:F9" }
            "2008R2"     { $MacAddress = "00:50:56:3F:02:FA" }
            "2012R2"     { $MacAddress = "00:50:56:3F:02:FB" }
            "2019"       { $MacAddress = "00:50:56:3F:02:FC" }
            "W10EVD"     { $MacAddress = "00:50:56:3F:02:FE" }
            "W10E"       { $MacAddress = "00:50:56:3F:02:FF" }
            "Win7SP1"    { $MacAddress = "00:50:56:3F:02:FD" }
        }
        $VMName = "$VMType-$OperatingSystem"
    }
}

    Write-Host "$((Get-Date).ToLongTimeString()) : Mac Address : " -ForegroundColor Yellow -NoNewline
    Write-Host "$MacAddress" -ForegroundColor Green

   
$SCVMM = "SCVMM.bottheory.local"
write-host "$((Get-Date).ToLongTimeString()) : Getting List of Hosts : " -ForegroundColor Yellow -NoNewline
$VMHosts = Get-SCVMHost -VMMServer $SCVMM | Where {$_.OverallStateString -eq "OK"}
write-host " Done. " -ForegroundColor Green

write-host "$((Get-Date).ToLongTimeString()) : Getting Host : " -ForegroundColor Yellow -NoNewline
$VMHost = ($VMHosts)[(Get-Random -Maximum ($VMHosts.Count) -Minimum 0)]
write-host " $($VMHost.Name) " -ForegroundColor Green

$VMTemplate = Get-SCVMTemplate -VMMServer $SCVMM | Where {$_.Name -eq "PVS_Gen$($Generation)"}

$VMPath = (Get-SCStorageFileShare).SharePath
if ($VMPath.Count -gt 1) {
    $VMPath = $VMPath[(Get-Random -Minimum 0 -Maximum $VMPath.Count)]
}
Write-Host "$((Get-Date).ToLongTimeString()) : VM Path:" -ForegroundColor Yellow -NoNewline
write-host " $VMPath" -ForegroundColor Green

#delete existing VM's if present
Write-Host "$((Get-Date).ToLongTimeString()) : Testing for existing VM resources" -ForegroundColor Yellow
if ((Get-SCVirtualMachine -Name $VMName -VMMServer $SCVMM).Count -ge 1) {
    Write-Host "$((Get-Date).ToLongTimeString()) : VM Already exists!  Removing..." -ForegroundColor Red
    $VMs = @(Get-SCVirtualMachine -Name $VMName -VMMServer $SCVMM)
    $VMs | Stop-SCVirtualMachine -Force -ErrorAction SilentlyContinue | out-null
    $VMs | Remove-SCVirtualMachine | Out-Null
}

Write-Host "$((Get-Date).ToLongTimeString()) : Cloning VM from $($VMTemplate.Name) : " -ForegroundColor Yellow -NoNewline
New-SCVirtualMachine -VMTemplate $VMTemplate -Name $VMName -VMHost $VMHost -Path "$VMPath\Hyper-V" -VMMServer $SCVMM | Out-Null
$VM = Get-SCVirtualMachine -Name $VMName -VMMServer $SCVMM
if ((Get-SCVirtualMachine -Name $VMName -VMMServer $SCVMM).Count -ge 1) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failed!" -ForegroundColor Red
}

#region Configure Hyper-V NIC for PVS

    Write-Host "$((Get-Date).ToLongTimeString()) : Adding NIC configured for PVS : " -ForegroundColor Yellow -NoNewline
	
    #The well known PVS Virtual System Identifier for the Streaming synthetic NIC 
    $VSIGuid = "{c40165e3-3bce-43f6-81ec-8733731ddcba}"

    #Retrieve the Hyper-V Management Service, The ComputerSystem class for the VM and the VM’s SettingData class. 
    $Msvm_VirtualSystemManagementService = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService -ComputerName $VMHost.Name

    $Msvm_ComputerSystem = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'" -ComputerName $VMHost.Name

    $Msvm_VirtualSystemSettingData = ($Msvm_ComputerSystem.GetRelated("Msvm_VirtualSystemSettingData", "Msvm_SettingsDefineState", $null, $null, "SettingData", "ManagedElement", $false, $null) | % {$_})

    #Retrieve the default (primordial) resource pool for Synthetic Ethernet Port’s 
    $Msvm_ResourcePool = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ResourcePool -Filter "ResourceSubType = 'Microsoft:Hyper-V:Synthetic Ethernet Port' and Primordial = True" -ComputerName $VMHost.Name

    #Retrieve the AllocationCapabilities class for the Resource Pool 
    $Msvm_AllocationCapabilities = ($Msvm_ResourcePool.GetRelated("Msvm_AllocationCapabilities", "Msvm_ElementCapabilities", $null, $null, $null, $null, $false, $null) | % {$_}) 

    #Query the relationships on the AllocationCapabilities class and find the default class (ValueRole = 0) 
    $Msvm_SettingsDefineCapabilities = ($Msvm_AllocationCapabilities.GetRelationships("Msvm_SettingsDefineCapabilities") | Where-Object {$_.ValueRole -eq "0"}) 

    #The PartComponent is the Default SyntheticEthernetPortSettingData class values 
    $Msvm_SyntheticEthernetPortSettingData = [WMI]$Msvm_SettingsDefineCapabilities.PartComponent 

    #Specify a unique identifier, a friendly name and specify dynamic mac addresses 
    $Msvm_SyntheticEthernetPortSettingData.VirtualSystemIdentifiers = $VSIGuid 
    $Msvm_SyntheticEthernetPortSettingData.ElementName = "PVS Streaming Adapter" 
    $Msvm_SyntheticEthernetPortSettingData.StaticMacAddress = $true 
    $Msvm_SyntheticEthernetPortSettingData.Address = $MacAddress.Replace(":","")

    #Add the network adapter to the VM 
    $AddNicResult = $Msvm_VirtualSystemManagementService.AddResourceSettings($Msvm_VirtualSystemSettingData, $Msvm_SyntheticEthernetPortSettingData.GetText(1))


    if ($addNicResult.ReturnValue -eq 0) {
        Write-Host "Success!" -ForegroundColor Green
    } else {
        Write-Host "Failed!" -ForegroundColor Red
    }


  Write-Host "$((Get-Date).ToLongTimeString()) : Attaching NIC To Network : " -ForegroundColor Yellow -NoNewline
    ##attach network
    #refreshData
    $Msvm_VirtualSystemSettingData = ($Msvm_ComputerSystem.GetRelated("Msvm_VirtualSystemSettingData", ` 
         "Msvm_SettingsDefineState", ` 
          $null, ` 
          $null, ` 
         "SettingData", ` 
         "ManagedElement", ` 
          $false, $null) | % {$_})

    #Retrieve the VirtualSwitch class the NIC will Connect to 
    $Msvm_VirtualEthernetSwitch = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualEthernetSwitch -Filter "ElementName='$switchName'"  -ComputerName $VMHost.Name

    #Retrieve the NetworkAdapterPortSettings Associated to the VM. 
    $Msvm_SyntheticEthernetPortSettingData = ($Msvm_VirtualSystemSettingData.GetRelated("Msvm_SyntheticEthernetPortSettingData")  | Where-Object {$_.ElementName -eq "PVS Streaming Adapter"})

    #Retrieve the default (primordial) resource pool for the Ethernet Connection 
    $Msvm_ResourcePool = (Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ResourcePool -Filter "ResourceSubType = 'Microsoft:Hyper-V:Ethernet Connection' and Primordial = True"  -ComputerName $VMHost.Name | % {$_})

    #Retrieve the AllocationCapabilities class for the Resource Pool 
    $Msvm_AllocationCapabilities = ($Msvm_ResourcePool.GetRelated("Msvm_AllocationCapabilities", ` 
         "Msvm_ElementCapabilities", ` 
          $null, ` 
          $null, ` 
          $null, ` 
          $null, ` 
          $false, ` 
          $null) | % {$_})

    #Query the relationships on the AllocationCapabilities class and find the default class (ValueRole = 0) 
    $Msvm_SettingsDefineCapabilities = ($Msvm_AllocationCapabilities.GetRelationships("Msvm_SettingsDefineCapabilities") | Where-Object {$_.ValueRole -eq "0"})

    #The PartComponent is the Default SyntheticEthernetPortSettingData class values 
    $Msvm_EthernetPortAllocationSettingData = [WMI]$Msvm_SettingsDefineCapabilities.PartComponent

    #Specify the NIC's Port Setting and the Switch Path 
    $Msvm_EthernetPortAllocationSettingData.Parent = $Msvm_SyntheticEthernetPortSettingData 
    $Msvm_EthernetPortAllocationSettingData.HostResource = $Msvm_VirtualEthernetSwitch

    #Add the connection object which connects the NIC 
    $AttachNetworkResult = $Msvm_VirtualSystemManagementService.AddResourceSettings($Msvm_VirtualSystemSettingData, $Msvm_EthernetPortAllocationSettingData.GetText(2)) 

    if ($AttachNetworkResult.ReturnValue -eq 0) {
        Write-Host "Success!" -ForegroundColor Green
    } else {
        Write-Host "Failed!" -ForegroundColor Red
    }

 #endregion PVS NIC

 
 #might need to add logic to check for gen 1 machines?  Or legacy nics?
Write-Host "$((Get-Date).ToLongTimeString()) : Removing original cloned NIC : " -ForegroundColor Yellow -NoNewline
Remove-VMNetworkAdapter -VMName $VMName -ComputerName $VMHost.Name -Name $VMName | Out-Null
if ((Get-VMNetworkAdapter -VMName $VMName -ComputerName $VMHost.Name).count -eq 1) {  #there is a weird thing where creating the NIC above in WMI doesn't get captured in the powershell cmdlet.
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}

<#   Might need the set mac address code for Gen1 machines
Write-Host "$((Get-Date).ToLongTimeString()) : Setting MacAddress : " -ForegroundColor Yellow -NoNewline
Set-SCVirtualNetworkAdapter -VirtualNetworkAdapter (Get-VirtualNetworkAdapter -VM $VM) -MACAddress $MacAddress -MACAddressType "Static" | Out-Null
if ((Get-VirtualNetworkAdapter -VM $VM).MACAddress -eq $MacAddress) {
    Write-Host "$MacAddress : " -ForegroundColor Cyan -NoNewline
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}
#>


Write-Host "$((Get-Date).ToLongTimeString()) : Creating and Attaching Boot Hard Disk : " -ForegroundColor Yellow -NoNewline
if ($Generation -eq "1") {
    New-SCVirtualDiskDrive -VM $VM -VirtualHardDiskFormatType VHDX -IDE -Dynamic -VirtualHardDiskSizeMB 60000 -Bus 0 -LUN 0 -FileName "$VMName.vhdx" | Out-Null
} 
if ($Generation -eq "2") {
    New-SCVirtualDiskDrive -VM $VM -VirtualHardDiskFormatType VHDX -SCSI -Dynamic -VirtualHardDiskSizeMB 60000 -Bus 0 -LUN 0 -FileName "$VMName.vhdx" | Out-Null
} 



if ((Get-SCVirtualDiskDrive -VM $VM).count -eq 1) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}

Write-Host "$((Get-Date).ToLongTimeString()) : Creating and Attaching Write Cache Hard Disk : " -ForegroundColor Yellow -NoNewline
if ($Generation -eq "1") {
    New-SCVirtualDiskDrive -VM $VM -VirtualHardDiskFormatType VHDX -IDE -Dynamic -VirtualHardDiskSizeMB 60000 -Bus 0 -LUN 1 -FileName "$($VMName)_WC.vhdx" | Out-Null
} 
if ($Generation -eq "2") {
    New-SCVirtualDiskDrive -VM $VM -VirtualHardDiskFormatType VHDX -SCSI -Dynamic -VirtualHardDiskSizeMB 60000 -Bus 0 -LUN 1 -FileName "$($VMName)_WC.vhdx" | Out-Null
} 
if ((Get-SCVirtualDiskDrive -VM $VM).count -eq 2) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}



Write-Host "$((Get-Date).ToLongTimeString()) : Creating DVD Drive : " -ForegroundColor Yellow -NoNewline
if ($Generation -eq "1") {
    New-SCVirtualDVDDrive -VM $VM -Bus 1 -LUN 1 | Out-Null
} 
if ($Generation -eq "2") {
    New-SCVirtualDVDDrive -VM $VM -Bus 0 -LUN 2 | Out-Null
} 

if ((Get-SCVirtualDVDDrive -VM $VM).count -eq 1) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}

$DVDDrive = Get-SCVirtualDVDDrive -VM $VM
Write-Host "$((Get-Date).ToLongTimeString()) : Getting LiteTouch ISO : " -ForegroundColor Yellow -NoNewline
$ISO = Get-SCISO | Where {$_.Name -eq "LiteTouchPE_x64.iso"}
if (($ISO.count) -eq 1) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}

Write-Host "$((Get-Date).ToLongTimeString()) : Attaching ISO : " -ForegroundColor Yellow -NoNewline
Set-SCVirtualDVDDrive -VirtualDVDDrive $DVDDrive -ISO $ISO  | Out-Null
if (Get-SCVirtualDVDDrive -VM $VM | Where {$_.ISO -ne $null}) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}


if ($Generation -eq 1) {
    Set-VMBios -VMName $VMName -StartupOrder @("IDE","CD", "LegacyNetworkAdapter","Floppy" ) -ComputerName $VMHost
} else {
    $BootDVDDrive = Get-VMDvdDrive -VMName $VMName -ComputerName $VMHost
    Set-VMFirmware -VMName $VMName -FirstBootDevice $BootDVDDrive -ComputerName $VMHost
}


#disable secure boot for 2008R2
<#
if ($OperatingSystem -eq "2008R2") {
    Write-Host "$((Get-Date).ToLongTimeString()) : Disabling Secure Boot for 2008R2 " -foregroundcolor "Yellow"
    Set-VMFirmware -VMName $VMName -EnableSecureBoot Off  -ComputerName $VMHost
}
#>

Write-Host "$((Get-Date).ToLongTimeString()) : Configuring CustomSettings.ini file" -foregroundcolor "Yellow"
Write-Host "$((Get-Date).ToLongTimeString()) : Setting Section : " -foregroundcolor "Yellow" -NoNewline
Write-Host "$MacAddress" -ForegroundColor Green
Write-Host "$((Get-Date).ToLongTimeString()) : TaskSequence ID : " -foregroundcolor "Yellow" -NoNewline
Write-Host "$taskSequenceId" -ForegroundColor Green
Write-Host "$((Get-Date).ToLongTimeString()) : OSDComputerName : " -foregroundcolor "Yellow" -NoNewline
Write-Host "$VMName" -ForegroundColor Green
[ProfileAPI]::WritePrivateProfileString($MacAddress,'TaskSequenceID',$taskSequenceId,$iniFile)
[ProfileAPI]::WritePrivateProfileString($MacAddress,'ProductKey',$pkey,$iniFile)
[ProfileAPI]::WritePrivateProfileString($MacAddress,'OSDComputername',"$VMName",$iniFile)

Write-Host "$((Get-Date).ToLongTimeString()) : Starting $VMName..." -foregroundcolor "Yellow"

$VMToStart = Get-VM -Name $VMName
Start-VM -VM $VMToStart | out-null

# sleep 2 mins then change CD to BDM CD so that PVS attaches it's driver


Write-Host "$((Get-Date).ToLongTimeString()) : Sleeping for 10 minutes" -ForegroundColor Yellow
sleep 600

$DVDDrive = Get-SCVirtualDVDDrive -VM $VM
Write-Host "$((Get-Date).ToLongTimeString()) : Getting BDM ISO : " -ForegroundColor Yellow -NoNewline
$ISO = Get-SCISO | Where {$_.Name -eq "BDM.iso"}
if (($ISO.count) -eq 1) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}

Write-Host "$((Get-Date).ToLongTimeString()) : Attaching ISO : " -ForegroundColor Yellow -NoNewline
Set-SCVirtualDVDDrive -VirtualDVDDrive $DVDDrive -ISO $ISO  | Out-Null
if (Get-SCVirtualDVDDrive -VM $VM | Where {$_.ISO -ne $null}) {
    Write-Host "Success!" -ForegroundColor Green
} else {
    Write-Host "Failure!" -ForegroundColor Red
}


if ($Generation -eq 1) {
    Set-VMBios -VMName $VMName -StartupOrder @("CD","IDE", "LegacyNetworkAdapter","Floppy" ) -ComputerName $VMHost
} else {
    $BootDVDDrive = Get-VMDvdDrive -VMName $VMName -ComputerName $VMHost
    Set-VMFirmware -VMName $VMName -FirstBootDevice $BootDVDDrive -ComputerName $VMHost
}


