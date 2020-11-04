[CmdLetBinding()]
Param (
    [Parameter(Mandatory=$true,HelpMessage='PackageName')][ValidateNotNullOrEmpty()]         [string]$PackageName,
    [Parameter(Mandatory=$true,HelpMessage='PackageDisplayName')][ValidateNotNullOrEmpty()]  [string]$PackageDisplayName,
    [Parameter(Mandatory=$false,HelpMessage='Version')]                                      [string]$Version = "1.1.1.0",
    [Parameter(Mandatory=$true,HelpMessage='Installer')]                                     [string]$Installer = "pathToSetup.exe",
    [Parameter(Mandatory=$true,HelpMessage='InstallLocation')]                               [string]$InstallLocation = "C:\Program Files\Notepad++",
    [Parameter(Mandatory=$true,HelpMessage='InstallerArgs')]                                 [string]$InstallerArgs = "/s"
)

$ErrorActionPreference = "stop"

Set-Service -Name wuauserv -StartupType Automatic
Start-Service -Name wuauserv -PassThru

sleep 10
    
[string]$PublisherName = "CN=Admin-Trentent Tye, OU=Domain Admins, OU=BotTheory Users, DC=bottheory, DC=local"
[string]$PublisherDisplayName = "MSIX"

$MSIXPackagingToolInstallLocation = (Get-AppxPackage -Name "Microsoft.MSIxPackagingTool*").InstallLocation
$MSIXPackagingTool = "$env:TEMP\MsixPackagingTool"
$MSIXPackagingToolSDK = "$env:TEMP\MsixPackagingTool\SDK"

Copy-Item -Path "$MSIXPackagingToolInstallLocation" -Destination $MSIXPackagingTool -Recurse -Force
Copy-Item -Path "$MSIXPackagingToolInstallLocation\SDK" -Destination $MSIXPackagingToolSDK -Recurse -Force

$MSIXPackagingToolCLI = "$MSIXPackagingTool\MsixPackagingToolCLI.exe"

[xml]$templateXML = @"
<MsixPackagingToolTemplate
    xmlns="http://schemas.microsoft.com/appx/msixpackagingtool/template/2018"
    xmlns:V2="http://schemas.microsoft.com/msix/msixpackagingtool/template/1904"
    xmlns:V3="http://schemas.microsoft.com/msix/msixpackagingtool/template/1907"
    xmlns:V4="http://schemas.microsoft.com/msix/msixpackagingtool/template/1910"
    xmlns:V5="http://schemas.microsoft.com/msix/msixpackagingtool/template/2001">

    <SaveLocation PackagePath="C:\Swinst\MSIX\Package\$PackageName.msix" />

    <Installer
        Path="C:\MyAppInstaller.msi"
        Arguments=""
        InstallLocation="" />

    <PackageInformation
        PackageName="MyAppPackageName"
        PackageDisplayName="MyApp Display Name"
        PublisherName="CN=MyPublisher"
        PublisherDisplayName="MyPublisher Display Name"
        Version="1.1.0.0">
	    
    </PackageInformation>
</MsixPackagingToolTemplate>
"@

$templateXML.MsixPackagingToolTemplate.Installer.Path      = $Installer
$templateXML.MsixPackagingToolTemplate.Installer.Arguments = $InstallerArgs
$templateXML.MsixPackagingToolTemplate.Installer.InstallLocation = $InstallLocation
$templateXML.MsixPackagingToolTemplate.PackageInformation.PackageName = $PackageName
$templateXML.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName = $PackageDisplayName
$templateXML.MsixPackagingToolTemplate.PackageInformation.PublisherName = $PublisherName
$templateXML.MsixPackagingToolTemplate.PackageInformation.PublisherDisplayName = $PublisherDisplayName
$templateXML.MsixPackagingToolTemplate.PackageInformation.Version = $Version

if (-not(Test-Path "C:\Swinst\MSIX\Package")) {
    mkdir "C:\Swinst\MSIX\Package" | Out-null
}


$templateXML.Save("C:\Swinst\MSIX\template.xml")



$msixArguments = "create-package --template `"C:\Swinst\MSIX\template.xml`""
Write-Verbose "Start-Process -FilePath $MSIXPackagingToolCLI -ArgumentList ($msixArguments) -PassThru -Wait"

$process = Start-Process -FilePath $MSIXPackagingToolCLI -ArgumentList ($msixArguments) -PassThru -Wait
write-host "MSIX package exit code:"
$process.ExitCode




$signTool = "$MSIXPackagingToolSDK\signtool.exe"

$pfxPath = "C:\Swinst\MSIX\TheoryPCMSIX.pfx"
$password = "replace_with_something"
$timeStampServer = "http://timestamp.digicert.com"
$MSIXPath = "C:\Swinst\MSIX\Package\$PackageName.msix"

<#
#expand MSIX package
. $MSIXPackagingToolSDK\makeappx unpack /p "$MSIXPath" /d "$($PackageName)Expanded"
[xml]$AppXManifest = Get-Content "$($PackageName)Expanded\AppxManifest.xml"
Write-Host "Found $($AppXManifest.Package.Applications.Application.Count) applications"

Write-host "Download Package Support Framework (PSF)..."
$NugetPage = Invoke-WebRequest "https://www.nuget.org/packages/Microsoft.PackageSupportFramework"
$downloadURL = $NugetPage.links.where({$_.innerText -eq "Download Package"}).href
Invoke-WebRequest $downloadURL | Out-File "$env:temp\psf.zip"
Expand-Archive "$env:temp\psf.zip"
#>


write-host "$signTool sign /debug -f ""$pfxPath"" -p $password -t ""$timeStampServer"" -fd SHA256 -v ""$MSIXPath"""
$signArguments = "sign /debug -f ""$pfxPath"" -p $password -t ""$timeStampServer"" -fd SHA256 -v ""$MSIXPath"""
$process = Start-Process -FilePath $signTool -ArgumentList ($signArguments) -PassThru -Wait
write-host "Signing exit code:"
$process.ExitCode


pause
