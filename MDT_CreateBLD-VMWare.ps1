param(
  [parameter(Mandatory=$true)]  [ValidateSet ("Generic","Epic")][string]$VMType,
  [parameter(Mandatory=$true)]  [ValidateSet ("DC1 (Citrix)","DC2.Cluster02 (Citrix)","DC3 (Citrix)","DC EPIC (Citrix)","DC2 EPIC (Citrix)")][string]$VMCluster,
  [parameter(Mandatory=$true)]  [ValidateSet ("2012R2","2016","2019","2008R2","W10ERS","Win7SP1")][string]$OperatingSystem,
  [parameter(Mandatory=$false)] [switch]$scheduledTask
)

if ($scheduledTask) { Start-Transcript -OutputDirectory C:\swinst\MDT_CreateBLD.Log }

$ErrorActionPreference = "stop"
#region supportingCode
#region functions
function Get-FolderByPath{
  <# .SYNOPSIS Retrieve folders by giving a path .DESCRIPTION The function will retrieve a folder by it's path. The path can contain any type of leave (folder or datacenter). .NOTES Author: Luc Dekens .PARAMETER Path The path to the folder. This is a required parameter. .PARAMETER Path The path to the folder. This is a required parameter. .PARAMETER Separator The character that is used to separate the leaves in the path. The default is '/' .EXAMPLE PS> Get-FolderByPath -Path "Folder1/Datacenter/Folder2"
.EXAMPLE
  PS> Get-FolderByPath -Path "Folder1>Folder2" -Separator '>'
#>
 
  param(
  [CmdletBinding()]
  [parameter(Mandatory = $true)]
  [System.String[]]${Path},
  [parameter(Mandatory = $false)][string]$vCenter,
  [char]${Separator} = '/'
  )
 
  process{
    if (-not($vCenter)) {
        if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
          $vcs = $defaultVIServers
        }
        else{
          $vcs = $defaultVIServers[0]
        }
    } else {
        $vcs = $vcenter
    }
    
    foreach($vc in $vcs){
      foreach($strPath in $Path){
        $root = Get-Folder -Name Datacenters -Server $vc
        $strPath.Split($Separator) | %{
          $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion -ErrorAction SilentlyContinue
          if((Get-Inventory -Location $root -NoRecursion -ErrorAction SilentlyContinue | Select -ExpandProperty Name) -contains "vm"){
            $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion -ErrorAction SilentlyContinue
          }
        }
        $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
          Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc -ErrorAction SilentlyContinue
        }
      }
    }
  }
}

Function Enable-MemHotAdd($vm){
    $vmview = Get-vm $vm | Get-View 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="mem.hotadd"
    $extra.Value="true"
    $vmConfigSpec.extraconfig += $extra

    $vmview.ReconfigVM($vmConfigSpec)
}

Function Disable-vCpuHotAdd($vm){
    $vmview = Get-vm $vm | Get-View
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="vcpu.hotadd"
    $extra.Value="false"
    $vmConfigSpec.extraconfig += $extra
    $vmview.ReconfigVM($vmConfigSpec)
}
#endregion functions

#region properties
#setup KMS product keys  --> from MS
switch ( $OperatingSystem )
    {
        "2008R2"     { $pkey = 'YC6KT-GKW9T-YTKYR-T4X34-R7VHC'  }
        "2012R2"     { $pkey = 'D2N9P-3P6X9-2R39C-7RTCD-MDVJX'  }
        "2016"       { $pkey = 'WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY'  }
        "2019"       { $pkey = 'N69G4-B89J2-4G8F4-WWYCC-J464C'  }
        "W10ERS"     { $pkey = 'NJCF7-PW8QT-3324D-688JX-2YV66'  }
    }

#setup TaskSequence ID's
switch ( $OperatingSystem )
    {
        "2008R2"     { $taskSequenceId = 'WIN2K8R2_X64'     }
        "2012R2"     { $taskSequenceId = 'WIN2K12R2_X64'    }
        "2016"       { $taskSequenceId = '010'              }
        "2019"       { $taskSequenceId = 'WIN2K19_1809_X64' }
        "W10ERS"     { $taskSequenceId = 'WIN10_ERS_17713'  }
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

$iniFile = "D:\DeploymentShare\Control\CustomSettings.ini"

if ($scheduledTask) {
    $username = "bottheory\svc_ctx_hv_prd"   #service account name for scheduled task runs
    $password = (Get-VICredentialStoreItem -Host vcenter01.bottheory.local).password  | ConvertTo-SecureString -asPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential($username,$password)
} else {
    if (-not($creds)) {
        $creds = Get-Credential -Message "Enter vCenter login credentials:"
    }
}


Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -InvalidCertificateAction Ignore -WebOperationTimeoutSeconds 3600 -WarningAction SilentlyContinue -Confirm:$false -ParticipateInCeip $false | out-null

write-host "$((Get-Date).ToLongTimeString()) : Connecting to vCenter..." -ForegroundColor Yellow
if ($global:defaultviserver -eq $null) {
    Connect-VIServer -Server vcenter01.bottheory.local -Credential $creds | out-null
    Connect-VIServer -Server vcenter02.bottheory.local -Credential $creds | out-null
}
write-host "$((Get-Date).ToLongTimeString()) : Getting Cluster : " -ForegroundColor Yellow -NoNewline
write-host "$VMCluster " -ForegroundColor Green

$cluster = Get-Cluster $VMCluster -ErrorAction Stop



write-host "$((Get-Date).ToLongTimeString()) : Getting Host : " -ForegroundColor Yellow -NoNewline
$VMHosts = $cluster | Get-VMHost 
$VMHost = $VMHosts[(Get-Random -Minimum 0 -Maximum $VMHosts.count)]
write-host "$VMHost " -ForegroundColor Green

write-host "$((Get-Date).ToLongTimeString()) : Getting Datastore : " -ForegroundColor Yellow -NoNewline
$Datastores = $cluster | Get-Datastore | where {$_.Name -like "CTX*" -or $_.Name -like "CITRIX*"}   #select our datastores we host our Citrix VM's on
$Datastore = $Datastores[(Get-Random -Minimum 0 -Maximum $Datastores.count)]
write-host "$Datastore " -ForegroundColor Green

#Get vCenter server from the host name
$vCenterServer = Get-View -ViewType HostSystem -Property Name | select Name, @{N='vCenter';E={([uri]$_.Client.ServiceUrl).Host}} | Where {$_.Name -like "*$($VMHost.Name)*"}





#Edmonton Location:
if ($VMHost.Name -like "*DCEPIC1*" -or $VMHost.Name -like "*DCEPIC2*") { 
    $location = Get-FolderByPath -Path "Edmonton/Servers/Citrix" -vCenter $vCenterServer.vCenter
}
#Calgary Location:
if ($VMHost.Name -like "*DC1*" -or $VMHost.Name -like "*DC2*") { 
    $location = Get-FolderByPath -Path "Calgary/Servers/Citrix" -vCenter $vCenterServer.vCenter
}


switch ($VMType) { 
    "Generic"   { 
        switch($OperatingSystem) {
            "2016"       { $MacAddress = "00:50:56:3F:02:F9" }
            "2008R2"     { $MacAddress = "00:50:56:3F:02:FA" }
            "2012R2"     { $MacAddress = "00:50:56:3F:02:FB" }
            "2019"       { $MacAddress = "00:50:56:3F:02:FC" }
            "W10ERS"     { $MacAddress = "00:50:56:3F:02:FE" }
        }
        $VMName = "GENERIC-$OperatingSystem"
    }

    "Epic" {
        switch($OperatingSystem) {
            "2016"       { $MacAddress = "00:50:56:3F:02:FD" }
            "2008R2"     { $MacAddress = "00:50:56:3F:02:FE" }
            "2012R2"     { $MacAddress = "00:50:56:3F:02:FF" }
            "2019"       { $MacAddress = "00:50:56:3F:02:00" }
            "W10ERS"     { $MacAddress = "00:50:56:3F:02:01" }
        }
        $VMName = "EPIC-$OperatingSystem"
    }
    "WSCTXBLD4001T" { $MacAddress = "00:50:56:3F:03:02" } 
    "WSCTXBLD4002T" { $MacAddress = "00:50:56:3F:03:03" } 
    "WSCTXBLD4003T" { $MacAddress = "00:50:56:3F:03:04" } 
}

    Write-Host "$((Get-Date).ToLongTimeString()) : Mac Address : " -ForegroundColor Yellow -NoNewline
    Write-Host "$MacAddress" -ForegroundColor Green

    write-host "$((Get-Date).ToLongTimeString()) : Getting portgroup : " -ForegroundColor Yellow -NoNewline

#defined by looking at each cluster and validating names
$networkNames = @(
"DC1XA",
"DC2XA",
"DC1EPICXA",
"DC2EPICXA"
)

$allPortGroups = Get-VDPortgroup -VDSwitch (Get-VDSwitch -VMHost $VMHost)
foreach ($portGroupName in $allPortGroups) {
    foreach ($networkName in $networkNames) {
        if ($portGroupName.Name -like "*$networkName*") {
            $portGroup = Get-VDPortgroup -VDSwitch (Get-VDSwitch -VMHost $VMHost) | where {$_.Name -like "*$networkName*"}
        }
    }
}

write-host "$portGroup " -ForegroundColor Green

Write-Host "$((Get-Date).ToLongTimeString()) : Creating VM" -ForegroundColor Yellow

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    if ($scheduledTask) {
        Get-VM -Name $VMName | Stop-VM -ErrorAction SilentlyContinue -Kill -Confirm:$false
        Get-VM -Name $VMName | Remove-VM -DeletePermanently -Confirm:$false
    } else {
        Write-Host "$((Get-Date).ToLongTimeString()) : !!!VM Already Created!!! " -ForegroundColor Cyan
        Write-Host "$((Get-Date).ToLongTimeString()) : Delete VM? " -ForegroundColor Cyan
        pause
        Get-VM -Name $VMName | Stop-VM -ErrorAction SilentlyContinue
        Get-VM -Name $VMName | Remove-VM -DeletePermanently
    }
}

New-VM -vmhost $VMHost -Name $VMName -Datastore $datastore -Location $location -DiskGB 60 -MemoryGB 16 -NumCpu 6 -CoresPerSocket 3 -DiskStorageFormat Thin2GB -Portgroup $portGroup -ErrorAction Stop -RunAsync:$false | out-null

#set VM to be in the GoldVM group if it's not.
<#
$DrsClusterGroup = Get-DrsClusterGroup
foreach ($group in $DrsClusterGroup) {
    if ($group.cluster.name -eq $VMCluster) {
        if ($group.name -like "*GOLDVM*") {
            Write-Host "$((Get-Date).ToLongTimeString()) : Found Gold VM group: $group" -ForegroundColor Yellow
            try {
                Get-DrsClusterGroup -Cluster $cluster -Name "GoldVM" -VM $VMName
            }
            catch {
                Write-Host "$((Get-Date).ToLongTimeString()) : Adding VM to the GoldVM group" -ForegroundColor Yellow
                Set-DrsClusterGroup -DrsClusterGroup $group -VM $VMName -Add
            }
        }
    }
}
#>

$VM = Get-VM -Name $VMName

#Set Guest OS Type
if ($OperatingSystem -eq "2008R2")                           { $GuestID = "windows7Server64Guest" }
if ($OperatingSystem -eq "2012R2")                           { $GuestID = "windows8Server64Guest" }
if ($OperatingSystem -eq "2016")                             { $GuestID = "windows9Server64Guest" }
if ($OperatingSystem -eq "2019")                             { $GuestID = "windows9Server64Guest" }
if ($OperatingSystem -eq "W10ERS")                           { $GuestID = "windows9Server64Guest" }
if (($OperatingSystem -eq "Win10_1709") -and (-not $x86))    { $GuestID = "windows9Server64Guest" }
if (($OperatingSystem -eq "Win10_1709") -and ($x86))         { $GuestID = "windows9_64Guest"      }
if (($OperatingSystem -eq "Win7SP1") -and (-not $x86))       { $GuestID = "windows7Server64Guest" }
if (($OperatingSystem -eq "Win7SP1") -and ($x86))            { $GuestID = "windows7Guest"         }

Write-Host "$((Get-Date).ToLongTimeString()) : Guest OS Type : " -ForegroundColor Yellow -NoNewline
write-host "$GuestId " -ForegroundColor Green
Set-VM -VM $VM -GuestId $GuestID -Confirm:$false | out-null


#disable CPU HotAdd...  CPU HotAdd disables NUMA
Write-Host "$((Get-Date).ToLongTimeString()) : Disabling CPU Hot-add" -ForegroundColor Yellow
Disable-vCpuHotAdd -vm $VM

Write-Host "$((Get-Date).ToLongTimeString()) : Enabling Hot-add Memory" -ForegroundColor Yellow
Enable-MemHotAdd -vm $VM

Write-Host "$((Get-Date).ToLongTimeString()) : Changing SCSI Controller to Paravirtual" -ForegroundColor Yellow
$SCSIController = Get-ScsiController -VM $VM 
Get-ScsiController -VM $VM | Set-ScsiController -Type ParaVirtual | out-null
$SCSIController = Get-ScsiController -VM $VM 

#The C drive needs to be the second drive.  The Citrix BDM Iso attempts to boot the last disk available.
New-HardDisk -CapacityGB 60 -StorageFormat Thin2GB -VM $VM | out-null

Write-Host "$((Get-Date).ToLongTimeString()) : Setting NIC to vmxNet3" -ForegroundColor Yellow
$VM | Get-NetworkAdapter | Set-NetworkAdapter -Type Vmxnet3 -StartConnected:$true -Confirm:$false -MacAddress $MacAddress  | out-null

Write-Host "$((Get-Date).ToLongTimeString()) : Attaching CD Drive with LiteTouch ISO..." -foregroundcolor "Yellow"

if ($cluster.Name -like "DC1*") {
    $ISOPath = "[DC1] BootImages/LiteTouchPE_x64.iso"
}
if ($cluster.Name -like "DC2*") {
    $ISOPath = "[DC2] BootImages/LiteTouchPE_x64.iso"
}
if ($cluster.Name -like "DC1EPIC.*") {
    $ISOPath = "[DC1EPIC] BootImages/LiteTouchPE_x64.iso"
}

if ($cluster.Name -like "DC2EPIC.*") {
    $ISOPath = "[DC2EPIC] LiteTouchPE_x64.iso"
}

New-CDDrive -VM $VM -StartConnected -IsoPath $ISOPath -ErrorAction Stop | out-null

Write-Host "$((Get-Date).ToLongTimeString()) : Configuring CustomSettings.ini file" -foregroundcolor "Yellow"
Write-Host "$((Get-Date).ToLongTimeString()) : Setting Section : " -foregroundcolor "Yellow" -NoNewline
Write-Host "$MacAddress" -ForegroundColor Green
Write-Host "$((Get-Date).ToLongTimeString()) : TaskSequence ID : " -foregroundcolor "Yellow" -NoNewline
Write-Host "$taskSequenceId" -ForegroundColor Green
Write-Host "$((Get-Date).ToLongTimeString()) : OSDComputerName : " -foregroundcolor "Yellow" -NoNewline
Write-Host "$VMName" -ForegroundColor Green

#modify the INI file
[ProfileAPI]::WritePrivateProfileString($MacAddress,'TaskSequenceID',$taskSequenceId,$iniFile)
[ProfileAPI]::WritePrivateProfileString($MacAddress,'ProductKey',$pkey,$iniFile)
[ProfileAPI]::WritePrivateProfileString($MacAddress,'OSDComputername',"$VMName",$iniFile)

Write-Host "$((Get-Date).ToLongTimeString()) : Starting $VMName..." -foregroundcolor "Yellow"

Start-VM -VM $VM | out-null

if ($scheduledTask) { Stop-Transcript }

if (-not($scheduledTask)) {
    Open-VMConsoleWindow -VM $VM

    pause

    Remove-VM -DeletePermanently -VM $VM
}