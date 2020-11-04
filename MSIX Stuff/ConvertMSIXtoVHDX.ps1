<#
.SYNOPSIS
The script create a VHD/X File and copy the MSIX Data in it
.DESCRIPTION
Use this script to create a MSIX App Attach Container
.NOTES
  Version:        1.0
  Author:         Manuel Winkel <www.deyda.net>
  Creation Date:  2020-06-04

  $vhdSrc – Target path where the container file (here a VHDX) should be stored
$packageName – Name of the package created via MSIX Packaging Tool
$parentFolder – Name of the folder to be created in the container. The MSIX files are not allowed to be stored directly in the root of the container. Of course the package name or similar can be placed here.
$msixmgrPath – Local path to the MSIX mgr tool
$msixPath – Local path to the MSIX package

  Purpose/Change:
  ## https://www.deyda.net/index.php/en/2020/06/16/msix-app-attach-with-windows-10-version-2004-in-citrix-environments/
#>

[CmdLetBinding()]
Param (
    
    [Parameter(Mandatory=$false,HelpMessage='packageName')][ValidateNotNullOrEmpty()]  [string]$packageName = "NotepadPlusPlus789",
    [Parameter(Mandatory=$false,HelpMessage='parentFolder')]                           [string]$parentFolder = "$packageName",
    [Parameter(Mandatory=$false,HelpMessage='msixmgrPath')]                            [string]$msixmgrPath = "$((Get-Location).Path)\msixmgr_x64",
    [Parameter(Mandatory=$false,HelpMessage='msixPackagePath')]                        [string]$msixPackagePath = "\\ds1813\fileshare\MSIX\MSIXPackages\$packageName.msix",
    [Parameter(Mandatory=$false,HelpMessage='vhdSrc')][ValidateNotNullOrEmpty()]       [string]$vhdSrc = "\\ds1813.bottheory.local\fileshare\MSIX\VHDPackages\$packageName.vhdx"
    
)

#region variables

if (-not(Test-Path "$msixmgrPath\msixmgr.exe")) {
    Write-Error "Could not find msixmgr.exe`n`n$msixmgrPath\msixmgr.exe"
    pause
}
$ErrorActionPreference = "stop"

$parentFolder = "\" + $parentFolder
$parts = $packageName.split("_")
$volumeName = "MSIX-" + $parts[0]
#endregion

#Generate a VHD or VHDX package for MSIX
new-vhd -sizebytes 2048MB -path $vhdSrc -dynamic -confirm:$false
$vhdObject = Mount-VHD $vhdSrc -Passthru
$disk = Initialize-Disk -Passthru -Number $vhdObject.Number
$partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $disk.Number
Format-Volume -FileSystem NTFS -Confirm:$false -DriveLetter $partition.DriveLetter -Force
$Path = $partition.DriveLetter + ":" + $parentFolder

#Create a folder with Package Parent Folder Variable as the name of the folder in root drive mounted above
new-item -path $Path -ItemType Directory
Set-Volume -DriveLetter $partition.DriveLetter -NewFileSystemLabel $volumeName


#Expand MSIX in CMD in Admin cmd prompt - Get the full package name
& "$msixmgrPath\msixmgr.exe" -Unpack -packagePath $msixPackagePath -destination $Path -applyacls

$volumeGUID = $partition.guid
$vhdxPackageName = (dir "$($partition.AccessPaths[0])\$packageName").Name

$Object = New-Object PSObject -Property @{
    vhdxPackageName   = $vhdxPackageName
    volumeGUID        = $volumeGUID
    packageName       = $packageName
    parentFolder      = $parentFolder
    vhdSrc            = $vhdSrc
}

$vhddisk = $vhdObject | Get-Disk
Dismount-VHD $vhddisk.number



$Object | ConvertTo-Json | Out-File "\\ds1813.bottheory.local\fileshare\MSIX\VHDPackages\$packageName.json"
