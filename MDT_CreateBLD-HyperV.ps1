param(
  [parameter(Mandatory=$true)]  [ValidateSet ("Generic")][string]$VMType,
  [parameter(Mandatory=$true)]  [ValidateSet ("2012R2","2016","2019","2008R2","W10ERS","Win7SP1")][string]$OperatingSystem
  #[parameter(Mandatory=$false)] [switch]$scheduledTask
)

#import module for hyper-v and failover clustering.  If these modules are not present you may need to install RSAT or just add the roles if on Server 2019+ or Win10 1809+
ipmo FailoverClusters
ipmo Hyper-V



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
        "W10ERS"     { $pkey = 'NJCF7-PW8QT-3324D-688JX-2YV66'  }
        "Win7SP1"    { $pkey = '33PXH-7Y6KF-2VJC9-XBBR8-HVTHH'  }
    }

#setup TaskSequence ID's
switch ( $OperatingSystem )
    {
        "2008R2"     { $taskSequenceId = 'WIN2K8R2_X64'  }
        "2012R2"     { $taskSequenceId = 'WIN2K12R2_X64'  }
        "2016"       { $taskSequenceId = '010'  }
        "2019"       { $taskSequenceId = 'WIN2K19_1809_X64' }
        "W10ERS"     { $taskSequenceId = 'WIN10_ERS_17713'  }
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


write-host "$((Get-Date).ToLongTimeString()) : Getting Cluster : " -ForegroundColor Yellow -NoNewline
$Cluster = Get-Cluster -Domain BOTTHEORY.LOCAL
write-host "$Cluster " -ForegroundColor Green

write-host "$((Get-Date).ToLongTimeString()) : Getting Host : " -ForegroundColor Yellow -NoNewline

$VMHosts = ($Cluster | Get-ClusterNode) | Where {$_.State -eq "Up"}
$VMHost = ($VMHosts | Where {$_.State -eq "Up"})[(Get-Random -Maximum ($VMHosts.Count) -Minimum 0)]

write-host "$VMHost " -ForegroundColor Green

write-host "$((Get-Date).ToLongTimeString()) : Getting Datastore : " -ForegroundColor Yellow -NoNewline
$Datastore = (Get-VMHost $VMHost.Name).VirtualMachinePath
write-host "$Datastore " -ForegroundColor Green


switch ($VMType) { 
    "Generic"   { 
        switch($OperatingSystem) {
            "2016"       { $MacAddress = "00:50:56:3F:02:F9" }
            "2008R2"     { $MacAddress = "00:50:56:3F:02:FA" }
            "2012R2"     { $MacAddress = "00:50:56:3F:02:FB" }
            "2019"       { $MacAddress = "00:50:56:3F:02:FC" }
            "W10ERS"     { $MacAddress = "00:50:56:3F:02:FE" }
            "Win7SP1"    { $MacAddress = "00:50:56:3F:02:FD" }
        }
        $VMName = "$VMType-$OperatingSystem"
    }
}

    Write-Host "$((Get-Date).ToLongTimeString()) : Mac Address : " -ForegroundColor Yellow -NoNewline
    Write-Host "$MacAddress" -ForegroundColor Green

    write-host "$((Get-Date).ToLongTimeString()) : Getting Switch Name : " -ForegroundColor Yellow -NoNewline

#defined by looking at each cluster and validating names
$SwitchName =  ((Get-VMHost $VMHost.Name).ExternalNetworkAdapters).SwitchName

write-host "$SwitchName " -ForegroundColor Green

Write-Host "$((Get-Date).ToLongTimeString()) : Testing for existing VM resources" -ForegroundColor Yellow
#delete existing VM's if present
if ($ExistingClusteredVM = Get-ClusterGroup -Cluster $cluster -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Host "$((Get-Date).ToLongTimeString()) : Found Clustered VM resources" -ForegroundColor Red
    Write-Host "$((Get-Date).ToLongTimeString()) : Stopping VM" -ForegroundColor Red
    Stop-VM -ComputerName $ExistingClusteredVM.OwnerNode -Name $ExistingClusteredVM.Name -TurnOff -Force
    Write-Host "$((Get-Date).ToLongTimeString()) : Removing VM" -ForegroundColor Red
    Remove-VM -ComputerName $ExistingClusteredVM.OwnerNode -Name $VMName -Force
    Write-Host "$((Get-Date).ToLongTimeString()) : Removing VM from Cluster" -ForegroundColor Red
    Remove-VMFromCluster -Cluster $cluster -Name $VMName -RemoveResources -Force
    if (Test-Path "$Datastore\$VMName") {
        Write-Host "$((Get-Date).ToLongTimeString()) : Removing $Datastore\$VMName" -ForegroundColor Red
        Remove-Item -Path "$Datastore\$VMName" -Recurse -Force
    }
}

Write-Host "$((Get-Date).ToLongTimeString()) : Creating VM" -ForegroundColor Yellow

if (Get-VM –ComputerName (Get-ClusterNode –Cluster $Cluster) -Name $VMName -ErrorAction SilentlyContinue) {
        Write-Host "$((Get-Date).ToLongTimeString()) : !!!VM Already Created!!! " -ForegroundColor Cyan
        Write-Host "$((Get-Date).ToLongTimeString()) : Delete VM? " -ForegroundColor Cyan
        pause
        Stop-VM –ComputerName (Get-ClusterNode –Cluster $Cluster) -Name $VMName -ErrorAction SilentlyContinue
        Remove-VM –ComputerName (Get-ClusterNode –Cluster $Cluster) -Name $VMName -Force
}

if ($OperatingSystem -eq "2008R2" -or $OperatingSystem -eq "Win7SP1") {
    $Generation = 1
} else {
    $Generation = 2
}


New-VM -Name $VMName -MemoryStartupBytes 1024MB -SwitchName $SwitchName -Generation $Generation -ComputerName $VMHost -Path "$datastore" -BootDevice VHD  | out-null

Write-Host "$((Get-Date).ToLongTimeString()) : Creating VHD" -ForegroundColor Yellow
New-VHD -Path "$datastore\$VMName\Virtual Hard Disks\$VMName.vhdx" -SizeBytes 60000000000 -ComputerName $VMHost  | out-null

$VMGuid = (get-vm -Name $VMName -ComputerName $VMHost).Id.Guid

Write-Host "$((Get-Date).ToLongTimeString()) : Setting VM Permissions" -ForegroundColor Yellow
Invoke-Command -ComputerName $VMHost -ScriptBlock {
    $objACL = Get-ACL $args[0]
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($args[1],"FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
    $objACL.AddAccessRule($rule)
    Set-ACL $args[0] $objACL
} -ArgumentList ("$datastore\$VMName", $VMGuid)

Write-Host "$((Get-Date).ToLongTimeString()) : Attaching VHD" -ForegroundColor Yellow
Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path "$datastore\$VMName\Virtual Hard Disks\$VMName.vhdx" -ComputerName $VMHost

#New-VM -Name $VMName -MemoryStartupBytes 1024MB -NewVHDPath "$datastore\$VMName\Virtual Hard Disks\$VMName.vhdx" -NewVHDSizeBytes 60000000000 -SwitchName $SwitchName -Generation $Generation -ComputerName $VMHost -Path "$datastore" -BootDevice VHD
Write-Host "$((Get-Date).ToLongTimeString()) : Adding VM to Failover Cluster" -ForegroundColor Yellow
(get-vm -Name $VMName -ComputerName $VMHost) | Add-ClusterVirtualMachineRole -Cluster $Cluster
Write-Host "$((Get-Date).ToLongTimeString()) : Setting Compatible Processor to True" -ForegroundColor Yellow
Get-VMProcessor $VMName -Computername $VMHost | Set-VMProcessor -CompatibilityForMigrationEnabled 1 -Count 4 | out-null
Write-Host "$((Get-Date).ToLongTimeString()) : Enabling Dynamic Memory" -ForegroundColor Yellow
Set-VMMemory -VMName $VMName -ComputerName $VMHost -DynamicMemoryEnabled $true | out-null
Write-Host "$((Get-Date).ToLongTimeString()) : Setting Static MacAddress" -ForegroundColor Yellow
Set-VMNetworkAdapter -VMName $VMName -ComputerName $VMHost -StaticMacAddress $MacAddress.Replace(":","") | out-null

Write-Host "$((Get-Date).ToLongTimeString()) : Creating 2nd drive" -ForegroundColor Yellow
#The C drive needs to be the second drive.  The Citrix BDM Iso attempts to boot the last disk available.
New-VHD -SizeBytes 60GB -Path "$datastore\$VMName\Virtual Hard Disks\$($VMName)_2.vhdx" -Dynamic -ComputerName $VMHost | out-null
Add-VMHardDiskDrive  -ComputerName $VMHost -VMName $VMName -Path "$datastore\$VMName\Virtual Hard Disks\$($VMName)_2.vhdx" | out-null


Write-Host "$((Get-Date).ToLongTimeString()) : Attaching CD Drive with LiteTouch ISO..." -foregroundcolor "Yellow"

$ISOPath = "\\x58-server.bottheory.local\Volume1\LiteTouchPE_x64.iso"
Add-VMDvdDrive -VMName $VMName -ComputerName $VMHost -Path "$ISOPath"
$DVDDrive = Get-VMDvdDrive -VMName $VMName -ComputerName $VMHost

Write-Host "$((Get-Date).ToLongTimeString()) : Setting CD Drive as the first in the boot order" -foregroundcolor "Yellow"
if ($Generation -eq 1) {
    Set-VMBios -VMName $VMName -StartupOrder @("IDE","CD", "LegacyNetworkAdapter","Floppy" ) -ComputerName $VMHost
} else {
    Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive -ComputerName $VMHost
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

$VM = Get-VM -Name $VMName -ComputerName $VMHost
Start-VM -VM $VM | out-null

if ($scheduledTask) { Stop-Transcript }
