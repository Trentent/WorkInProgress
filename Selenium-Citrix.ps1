[CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [switch]
        $CheckPrerequisites = $false,    
        [Parameter(Mandatory = $False)]
        [switch]
        $CreateCredFile = $false,
        [Parameter(Mandatory = $true)]
        [uri]
        $URL,
        [Parameter(Mandatory = $true)]
        [string]
        $username,
        [Parameter(Mandatory = $true)]
        [string]
        $Application,
        [Parameter(Mandatory = $False)]
        [switch]
        $EnableNetworkLineConditioner = $false
    )



#ToDo: Create a "config" parameter to set all the policies. This is needed to run in elevation as elevation is not required for running Selenium but it is for setting the config options

## NOTES :  If you get "WebDriver not created" or another error around that context, it's because Selenium 4.0.0 comes with a old chromedriver.exe that needs to be updated
##          This script attempts to do that, but if you get the error the chrome driver was either not updated or the update failed somewhere.

Function Get-ChromeVersion {
    # $IsWindows will PowerShell Core but not on PowerShell 5 and below, but $Env:OS does
    # this way you can safely check whether the current machine is running Windows pre and post PowerShell Core
    If ($IsWindows -or $Env:OS) {
        Try {
            (Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction Stop).'(Default)').VersionInfo.FileVersion
        }
        Catch {
            #Throw "Google Chrome not found in registry"
            return $false
        }
    }
    ElseIf ($IsLinux) {
        Try {
            # this will check whether google-chrome command is available
            Get-Command google-chrome -ErrorAction Stop | Out-Null
            google-chrome --product-version
        }
        Catch {
            #Throw "'google-chrome' command not found"
            return $false
        }
    }
    ElseIf ($IsMacOS) {
        $ChromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        If (Test-Path $ChromePath) {
            $Version = & $ChromePath --version
            $Version = $Version.Replace("Google Chrome ", "")
            $Version
        }
        Else {
            #Throw "Google Chrome not found on your MacOS machine"
            return $false
        }
    }
    Else {
        Throw "Your operating system is not supported by this script."
        return $false
    }
}

function Install-ChromeDriver {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]
        $ChromeDriverOutputPath,    
        [Parameter(Mandatory = $false)]
        [string]
        $ChromeVersion, 
        [Parameter(Mandatory = $false)]
        [Switch]
        $ForceDownload
    )

    # store original preference to revert back later
    $OriginalProgressPreference = $ProgressPreference
    # setting progress preference to silently continue will massively increase the performance of downloading the ChromeDriver
    $ProgressPreference = 'SilentlyContinue'

    

    # Instructions from https://chromedriver.chromium.org/downloads/version-selection
    #   First, find out which version of Chrome you are using. Let's say you have Chrome 72.0.3626.81.
    If ([string]::IsNullOrEmpty($ChromeVersion)) {
        $ChromeVersion = Get-ChromeVersion -ErrorAction Stop
        Write-Verbose "Google Chrome version $ChromeVersion found on machine"
    }

    #   Take the Chrome version number, remove the last part, 
    $ChromeVersion = $ChromeVersion.Substring(0, $ChromeVersion.LastIndexOf("."))
    #   TTYE Starting with Chrome 115 the chrome version is distributed through a different mechanism.
    #   so I'll check if the version is less than 115 and use the old method

    [version]$versionNumber = $ChromeVersion
    if ($versionNumber.Major -lt 115) {
        #   and append the result to URL "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_". 
        #   For example, with Chrome version 72.0.3626.81, you'd get a URL "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_72.0.3626".
        $ChromeDriverVersion = (Invoke-WebRequest "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$ChromeVersion").Content
        Write-Verbose "Latest matching version of Chrome Driver is $ChromeDriverVersion"

        If (($ForceDownload -eq $False) -and (Test-path $ChromeDriverOutputPath)) {
            #ChromeDriver 88.0.4324.96 (68dba2d8a0b149a1d3afac56fa74648032bcf46b-refs/branch-heads/4324@{#1784})
            $ExistingChromeDriverVersion = & $ChromeDriverOutputPath --version
            $ExistingChromeDriverVersion = $ExistingChromeDriverVersion.Split(" ")[1]
            If ($ChromeDriverVersion -eq $ExistingChromeDriverVersion) {
                Write-Verbose "Chromedriver on machine is already latest version. Skipping."
                Write-Verbose "Use -ForceDownload to reinstall regardless"
                Exit
            }
        }

        $TempFilePath = [System.IO.Path]::GetTempFileName()
        $TempZipFilePath = $TempFilePath.Replace(".tmp", ".zip")
        Rename-Item -Path $TempFilePath -NewName $TempZipFilePath
        $TempFileUnzipPath = $TempFilePath.Replace(".tmp", "")
        #   Use the URL created in the last step to retrieve a small file containing the version of ChromeDriver to use. For example, the above URL will get your a file containing "72.0.3626.69". (The actual number may change in the future, of course.)
        #   Use the version number retrieved from the previous step to construct the URL to download ChromeDriver. With version 72.0.3626.69, the URL would be "https://chromedriver.storage.googleapis.com/index.html?path=72.0.3626.69/".

        If ($IsWindows -or $Env:OS) {
            Invoke-WebRequest "https://chromedriver.storage.googleapis.com/$ChromeDriverVersion/chromedriver_win32.zip" -OutFile $TempZipFilePath
            Expand-Archive $TempZipFilePath -DestinationPath $TempFileUnzipPath
            if (Test-Path $ChromeDriverOutputPath) {
                if ($chromeDrivers = Get-Process -Name chromedriver -ErrorAction SilentlyContinue) {
                    foreach ($chromeDriver in $chromeDrivers) {
                        Stop-Process $chromeDriver -Force -ErrorAction SilentlyContinue | Out-null
                    }
                }
                Start-Sleep -Seconds 3
                Remove-Item -Path $ChromeDriverOutputPath -Force 
            }
            $chromeDriverExe = (Get-ChildItem -Path $TempFileUnzipPath -Recurse | Where {$_.name -like "chromedriver.exe"}).FullName
            Move-Item "$chromeDriverExe" -Destination $ChromeDriverOutputPath -Force
        }
        ElseIf ($IsLinux) {
            Invoke-WebRequest "https://chromedriver.storage.googleapis.com/$ChromeDriverVersion/chromedriver_linux64.zip" -OutFile $TempZipFilePath
            Expand-Archive $TempZipFilePath -DestinationPath $TempFileUnzipPath
            Move-Item "$TempFileUnzipPath/chromedriver" -Destination $ChromeDriverOutputPath -Force
        }
        ElseIf ($IsMacOS) {
            Invoke-WebRequest "https://chromedriver.storage.googleapis.com/$ChromeDriverVersion/chromedriver_mac64.zip" -OutFile $TempZipFilePath
            Expand-Archive $TempZipFilePath -DestinationPath $TempFileUnzipPath
            Move-Item "$TempFileUnzipPath/chromedriver" -Destination $ChromeDriverOutputPath -Force
        }
        Else {
            Throw "Your operating system is not supported by this script."
        }

        #   After the initial download, it is recommended that you occasionally go through the above process again to see if there are any bug fix releases.
    }
    if ($versionNumber.Major -ge 115) {
        $chromeDriverEndpoints = Invoke-WebRequest -Uri "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" -UseBasicParsing | ConvertFrom-Json
        #compare available chrome driver versions vs what is on the machine

        <# $chromeDriverEndpoints.channels.PSObject.Properties.Value
        channel version       revision downloads                                              
        ------- -------       -------- ---------                                              
        Stable  115.0.5790.98 1148114  @{chrome=System.Object[]; chromedriver=System.Object[]}
        Beta    115.0.5790.98 1148114  @{chrome=System.Object[]; chromedriver=System.Object[]}
        Dev     116.0.5845.42 1160321  @{chrome=System.Object[]; chromedriver=System.Object[]}
        Canary  117.0.5897.0  1171982  @{chrome=System.Object[]; chromedriver=System.Object[]}
        #>
        
        $chromeDriverVersion = $chromeDriverEndpoints.channels.PSObject.Properties.Value | Where-Object {$_.version -like "$ChromeVersion*"} | Select-Object -First 1

        if ($chromeDriverVersion.count -eq 0) {
            Write-Error "Unable to find a version of the Chrome Driver that matches $ChromeVersion.`n`n`nChrome Driver versions found: $($chromeDriverEndpoints.channels.PSObject.Properties.Value  | Select -Property channel,version |Out-String)"
        } else {
            Write-Verbose "Found Chrome Driver version ($($chromeDriverVersion.version)) from the $($chromeDriverVersion.channel) channel that match the version of Chrome $($ChromeVersion) installed on this system."
        }

        If (($ForceDownload -eq $False) -and (Test-path $ChromeDriverOutputPath)) {
            #ChromeDriver 88.0.4324.96 (68dba2d8a0b149a1d3afac56fa74648032bcf46b-refs/branch-heads/4324@{#1784})
            $ExistingChromeDriverVersion = & $ChromeDriverOutputPath --version
            $ExistingChromeDriverVersion = $ExistingChromeDriverVersion.Split(" ")[1]
            If ($ChromeDriverVersion -eq $ExistingChromeDriverVersion) {
                Write-Verbose "Chromedriver on machine is already latest version. Skipping."
                Write-Verbose "Use -ForceDownload to reinstall regardless"
                Exit
            }
        }

        $TempFilePath = [System.IO.Path]::GetTempFileName()
        $TempZipFilePath = $TempFilePath.Replace(".tmp", ".zip")
        Rename-Item -Path $TempFilePath -NewName $TempZipFilePath
        $TempFileUnzipPath = $TempFilePath.Replace(".tmp", "")

        #   TTYE Get the download URLs then download according to the appropriate OS
        $chromeDriverDownloadURLs = $chromeDriverVersion.downloads.chromedriver

        If ($IsWindows -or $Env:OS) {
            $Win32DownloadURL = $($($chromeDriverDownloadURLs | Where-Object -FilterScript {$_.platform -eq "win32"}).url)
            Write-Verbose "Win32 download url: $Win32DownloadURL"
            Invoke-WebRequest "$Win32DownloadURL" -OutFile $TempZipFilePath
            Expand-Archive $TempZipFilePath -DestinationPath $TempFileUnzipPath
            if (Test-Path $ChromeDriverOutputPath) {
                if ($chromeDrivers = Get-Process -Name chromedriver -ErrorAction SilentlyContinue) {
                    foreach ($chromeDriver in $chromeDrivers) {
                        Stop-Process $chromeDriver -Force -ErrorAction SilentlyContinue | Out-null
                    }
                }
                Start-Sleep -Seconds 3
                Remove-Item -Path $ChromeDriverOutputPath -Force 
            }
            $chromeDriverExe = (Get-ChildItem -Path $TempFileUnzipPath -Recurse | Where {$_.name -like "chromedriver.exe"}).FullName
            Move-Item "$chromeDriverExe" -Destination $ChromeDriverOutputPath -Force
        }
        ElseIf ($IsLinux) {
            $linux64DownloadURL = $($($chromeDriverDownloadURLs | Where-Object -FilterScript {$_.platform -eq "linux64"}).url)
            Write-Verbose "linux64 download url: $linux64DownloadURL"
            Invoke-WebRequest "$linux64DownloadURL" -OutFile $TempZipFilePath
            Expand-Archive $TempZipFilePath -DestinationPath $TempFileUnzipPath
            Move-Item "$TempFileUnzipPath/chromedriver" -Destination $ChromeDriverOutputPath -Force
        }
        ElseIf ($IsMacOS) {
            
            $processorArchitecture = uname -m
            if ($processorArchitecture -eq "arm64") {
                Write-Verbose "Found ARM architecture MacOS"
                $macDownloadURL = $($($chromeDriverDownloadURLs | Where-Object -FilterScript {$_.platform -eq "mac-arm64"}).url)
            } else {
                #assume Intel proc architecture
                Write-Verbose "Found Intel architecture MacOS"
                $macDownloadURL = $($($chromeDriverDownloadURLs | Where-Object -FilterScript {$_.platform -eq "mac-x64"}).url)
            }
            Write-Verbose "Mac download url: $macDownloadURL"
            Invoke-WebRequest "$macDownloadURL" -OutFile $TempZipFilePath
            Expand-Archive $TempZipFilePath -DestinationPath $TempFileUnzipPath
            Move-Item "$TempFileUnzipPath/chromedriver" -Destination $ChromeDriverOutputPath -Force
        }
        Else {
            Throw "Your operating system is not supported by this script."
        }


    }

    # Clean up temp files
    Remove-Item $TempZipFilePath
    Remove-Item $TempFileUnzipPath -Recurse

    # reset back to original Progress Preference
    $ProgressPreference = $OriginalProgressPreference
}

<#  Doesn't work on MacOS.
function Save-DebugScreenshot {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    [OpenQA.Selenium.Chrome.ChromeDriver]
    $Driver
)
    $ShortDate = (get-date).ToShortDateString().Replace("/","_")
    $shortTime = (get-date).ToShortTimeString().Replace(":","_").Replace(" ","_")
    if ($IsMac)     { $HomeDir = "$($env:HOME.ToString())/Desktop/" }
    if ($IsWindows) { $HomeDir = "$($env:userprofile)\Desktop\" }
    $ScreenShotPath = "$($HomeDir)$($ShortDate)_$($ShortTime).png" 

    Write-Host "Attempting to save screenshot to: $ScreenShotPath"
    Write-Host "Unable to detect the Citrix Workspace app screen or the $Application"
    Write-Host "Saving Screenshot for debugging (hopefully)."
    $Screenshot = New-SeScreenshot 
    Save-SeScreenshot -Screenshot $Screenshot -Path "$ScreenShotPath" -ImageFormat Png
    Stop-SeDriver -Driver $Driver
}
#>

#To install Selenium on the mac run 
# Find-Module Selenium -AllowPrerelease | Install-Module -Force -AcceptLicense -Confirm:$false

## If using older version of powershell we must be on Windows...
#The Is<Vendor> variables should exist for Powershell 6+
#Untested on Linux

if (Test-Path $env:SystemDrive\Windows -ErrorAction SilentlyContinue) {
    if(-not(Get-Variable IsWindows -ErrorAction SilentlyContinue)) { $IsWindows = $true  }
    if(-not(Get-Variable IsMac -ErrorAction SilentlyContinue))     { $IsMac     = $false }
    if(-not(Get-Variable IsLinux -ErrorAction SilentlyContinue))   { $IsLinux   = $false }
}

if (Test-Path '/System/Library/CoreServices/Finder.app') {
    if(-not(Get-Variable IsWindows -ErrorAction SilentlyContinue)) { $IsWindows = $false }
    if(-not(Get-Variable IsMac -ErrorAction SilentlyContinue))     { $IsMac     = $true  }
    if(-not(Get-Variable IsLinux -ErrorAction SilentlyContinue))   { $IsLinux   = $false }
}


$ShortDate = (get-date).ToShortDateString().Replace("/","_")
$shortTime = (get-date).ToShortTimeString().Replace(":","_").Replace(" ","_")
if ($IsMac)     { $HomeDir = "$($env:HOME.ToString())/Desktop/SeleniumLog/" }
if ($IsWindows) { $HomeDir = "$($env:userprofile)\Desktop\SeleniumLog\" }

if (-not(Test-Path $HomeDir)) {
    New-Item -Path $HomeDir -ItemType Directory -Force
}

Start-Transcript -Path "$($HomeDir)$($ShortDate)_$($ShortTime).txt" -Force -IncludeInvocationHeader -Confirm:$false



## To Create Credential File
#CredPath
if ($IsWindows) { $CredPath = "$($env:userprofile)" + "$("\" + $URL.host.replace(".","_"))"}
if ($IsMac) { $CredPath = "$($($env:HOME).ToString() + "/" + $($username.split("\")[1])  + "_" + $URL.Host.replace(".","_"))"}

if (($CreateCredFile) -or (-not(Test-Path "$CredPath"))) {
    $CredFileOutput = Get-Credential -Message "Enter Username as %DOMAIN%\%username%"
    Export-Clixml -InputObject $CredFileOutput -Path $CredPath
} else {
    $CredFileOutput = Import-Clixml -Path $CredPath
    $Username = $CredFileOutput.UserName.split("\")[1]
    Write-Host "Username: $username"
}

#region prerequisites
##TTYE - Checks that all prerequistes are here (Powershell 7, Selenium Powershell Module, Selenium)

#region check for Powershell 7  #only applicable on Windows as you shouldn't be able to run this on the other OS's without PS7...
Write-Host "Checking Powershell Version..." -ForegroundColor Green -NoNewline
if ($PSVersionTable.PSVersion.Major -le 5) {
    
    If (-not(Test-Path $env:ProgramFiles\PowerShell\7)) {
        Write-Host "We require Powershell 7 for this to work... Installing Powershell 7..."

        #install for Powershell 7 on Windows
        winget install --id Microsoft.Powershell --source winget
    }
    Write-Host "Please re-run this script with PS7. This script will now exit" -ForegroundColor Cyan
    pause
    exit
}
Write-Host " Success!" -ForegroundColor Blue
#endregion check for Powershell 7

#region Check for Google Chrome
Write-Host "Checking for Google Chrome..." -ForegroundColor Green -NoNewline
if (-not(Get-ChromeVersion)) {
    if ($IsMac    ) { 
        Write-Host "Chrome was not found on this Mac... Installing Chrome..."
        Invoke-WebRequest -Uri "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg" -OutFile "googlechrome.dmg"
        Start-Process hdiutil -ArgumentList @("attach","googlechrome.dmg") -Wait
        Start-Process ditto -ArgumentList '-rsrc "/Volumes/Google Chrome/Google Chrome.app" "/Applications/Google Chrome.app"' -Wait
        Start-Process hdiutil -ArgumentList 'detach "/Volumes/Google Chrome" -force' -wait
        Remove-Item -Path googlechrome.dmg
    }
    if ($IsWindows) {
        $uri = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
        Invoke-WebRequest -Uri $uri -OutFile ".\ChromeSetup.exe"
        Start-Process ".\ChromeSetup.exe" -argumentList "/install" -NoNewWindow -Wait 
        Remove-Item ".\ChromeSetup.exe"
        Sleep -Seconds 5
        Stop-Process -Name chrome -Force
     }
}
Write-Host " Success!" -ForegroundColor Blue
#endregion Check for Google Chrome

#region Check for Selenium Powershell Module  ## TTYE - Need to install the prelease selenium module for maximum compatibility...
Write-Host "Checking for Selenium Powershell Module..." -ForegroundColor Green -NoNewline
if (-not(Get-InstalledModule -Name Selenium)) {
    Write-Host "We require the Selenium Powershell Module... Installing..."
    Find-Module Selenium -AllowPrerelease | Install-Module -Force -AcceptLicense -Confirm:$false
    if ($IsMac) {
        #Test to see if selenium ps module installed...
        if ((-not(Test-Path ('/usr/local/share/powershell/Modules/selenium'))) -or (-not(Test-Path ("$($($env:HOME).ToString())" + "/.local/share/powershell/Modules/selenium"))) -or (-not(Test-Path ("$($($env:HOME).ToString())" + "/.local/share/powershell/Modules/Selenium")))) {
            Write-Host "Selenium Powershell Module not detected at '/usr/local/share/powershell/Modules/selenium'" -ForegroundColor Cyan
            Write-Host "Selenium Powershell Module not detected at $($($env:HOME).ToString())/.local/share/powershell/Modules/selenium" -ForegroundColor Cyan
            Write-Host "Selenium Powershell Module not detected at $($($env:HOME).ToString())/.local/share/powershell/Modules/Selenium" -ForegroundColor Cyan
            pause
            exit
        }
    }
    if ($IsWindows) {
        #Test to see if selenium ps module installed...
        if (-not(Get-InstalledModule -Name Selenium)) {
            Write-Host "Selenium Powershell Module not detected!" -ForegroundColor Cyan
            pause
            exit
        }
    }
}
Write-Host " Success!" -ForegroundColor Blue
#endregion Check for Selenium Powershell Module

#region Check for Selenium  ## Taken a lot of code from the beautiful work done here: https://swimburger.net/blog/dotnet/download-the-right-chromedriver-version-and-keep-it-up-to-date-on-windows-linux-macos-using-csharp-dotnet
Write-Host "Checking for the Selenium WebDriver" -ForegroundColor Green -NoNewline
if ($IsMac    ) { 
    if (Test-Path -Path /usr/local/share/powershell/Modules/selenium/assemblies/macos)             { Install-ChromeDriver -ChromeDriverOutputPath /usr/local/share/powershell/Modules/selenium/assemblies/macos/chromedriver -ForceDownload }
    if (Test-Path -Path $env:HOME/.local/share/powershell/Modules/Selenium/4.0.0/assemblies/macos) { Install-ChromeDriver -ChromeDriverOutputPath $env:HOME/.local/share/powershell/Modules/Selenium/4.0.0/assemblies/macos/chromedriver -ForceDownload }
}
if ($IsWindows) { Install-ChromeDriver -ChromeDriverOutputPath "$env:userprofile\Documents\PowerShell\Modules\Selenium\4.0.0\assemblies\chromedriver.exe" -ForceDownload }
Write-Host " Success!" -ForegroundColor Blue
#endregion Check for Selenium

#region Policy Configuration
## Configure Edge/Chrome on Windows so that we are NOT prompted for the "This site is trying to open..." dialog and it will auto-download the ICA file instead
Write-Host "Checking for the Policy Configuration" -ForegroundColor Green -NoNewline

if ($IsWindows) { $DownloadDir = "$env:userprofile\Downloads"}
if ($IsMac)     { $DownloadDir = "$env:HOME/Downloads"}

$ICAFiles = Get-ChildItem "$DownloadDir" -Filter "*.ica"
Foreach ($file in $ICAFiles) {
    Remove-Item -Path $file.fullName -Force
}

if ($IsWindows) {
#region Edge Settings
    #Disable the "Always open this file in... dialog in Edge"
    if (-not(Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge)) {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge -Force  | Out-Null
    }

    if (-not(Get-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge).GetValue("ExternalProtocolDialogShowAlwaysOpenCheckbox")) {
        New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge -Name ExternalProtocolDialogShowAlwaysOpenCheckbox -PropertyType DWord -Value 0 -Force  | Out-Null
    }

    if (-not(Get-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge).GetValue("AutoLaunchProtocolsFromOrigins")) {
        New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Edge -Name AutoLaunchProtocolsFromOrigins -PropertyType String -Value '[{"allowed_origins": ["https://myapps.acmeorg.net"], "protocol": "receiver"}, {"allowed_origins": ["https://citrix.getcontrolup.com"], "protocol": "receiver"}]' -Force  | Out-Null
    }
#endregion Edge Settings

#region Chrome Settings
    if (-not(Test-Path -Path HKLM:\SOFTWARE\Policies\Google\Chrome)) {
        New-Item -Path HKLM:\SOFTWARE\Policies\Google\Chrome -Force  | Out-Null
    }

    if (-not(Get-Item -Path HKLM:\SOFTWARE\Policies\Google\Chrome).GetValue("ExternalProtocolDialogShowAlwaysOpenCheckbox")) {
        New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Google\Chrome -Name ExternalProtocolDialogShowAlwaysOpenCheckbox -PropertyType DWord -Value 0 -Force  | Out-Null
    }

    if (-not(Get-Item -Path HKLM:\SOFTWARE\Policies\Google\Chrome).GetValue("AutoLaunchProtocolsFromOrigins")) {
        New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Google\Chrome -Name AutoLaunchProtocolsFromOrigins -PropertyType String -Value '[{"allowed_origins": ["*"], "protocol": "receiver"}]' -Force  | Out-Null

#        New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Google\Chrome -Name AutoLaunchProtocolsFromOrigins -PropertyType String -Value '[{"allowed_origins": ["https://myapps.acmeorg.net"], "protocol": "receiver"}, {"allowed_origins": ["https://citrix.getcontrolup.com"], "protocol": "receiver"}]' -Force  | Out-Null
    }
#endregion Chrome Settings
}

if ($IsMac) {
    Write-Host "Found Mac Host"
    #region Mac Chrome Policy
    if ((Test-Path -Path '/Applications/Google Chrome.app') -and (-not(Test-Path -Path '/Library/Preferences/com.google.Chrome.plist'))) {
$comGoogleChromePlist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AutoLaunchProtocolsFromOrigins</key>
    <array>
        <dict>
            <key>allowed_origins</key>
            <array>
                <string>https://myapps.acmeorg.net</string>
                <string>https://citrix.getcontrolup.com</string>
            </array>
            <key>protocol</key>
            <string>receiver</string>
        </dict>
    </array>
</dict>
</plist>
"@
        $comGoogleChromePlist | Out-File -FilePath '/Library/Preferences/com.google.Chrome.plist' -Force -ErrorAction Stop
        if  (-not(Test-Path -Path '/Library/Preferences/com.google.Chrome.plist')) {
            Write-Host "## Unable to set preferences. Run this script with sudo?"
            pause
        }
    }
    #endregion Mac Chrome Policy
}
Write-Host " Success!" -ForegroundColor Blue
#endregion Policy Configuration
#endregion prerequisites
$CDViewerProcesses = get-process -Name cdviewer -ErrorAction SilentlyContinue
$wfica32Processes = get-process -Name wfica32 -ErrorAction SilentlyContinue


Write-Host "Starting web automation..."
Import-Module -Name Selenium

## As of Selenium Powershell 4.0.0 preview3 the Mac version does not set Icognito Mode. I can work around that...
if ($IsMac) {
    $Options = New-SEDriverOptions -Browser Chrome
    $Options.AddArgument("--incognito")
    $Driver = Start-SEDriver -StartURL "$($URL.AbsoluteUri)" -Browser Chrome -Options $Options -size 800x600 -DefaultDownloadPath "$env:HOME/Downloads"
}
if ($IsWindows) {
    $Driver = Start-SEDriver -StartURL "$($URL.AbsoluteUri)" -Browser Chrome -PrivateBrowsing -size 800x600
}

## it's easier to just work on making Selenium work on the specific URL then making a generic one with uniqueness checks

if ($URL.Host -like "myapps.acmeorg.net") {

    Start-Sleep -Seconds 5
    $XPathString = "//img[@alt='" + $Application + "']" 
    $ApplicationName = Get-SeElement -By Xpath -Value "$XPathString" -ErrorAction SilentlyContinue
    if ($ApplicationName.count -eq 0) {

        #detecting username button 
        Write-Host "Detect Username Field..."  -ForegroundColor Yellow
        $count = 0
        do {
            $count = $count+1
            $EnterUserNameField = Get-SeElement -By Id -Value "Enter user name" -errorAction SilentlyContinue
            Write-Host "Loop number                                   : $count" -ForegroundColor Yellow
            Write-Host "Enter User Name Element Detected              : $($EnterUserNameField.count)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            if ($count -eq 5) {
                Write-Host "It's been 50 seconds since we tried loading the gateway page and no user name field has been detected..."
                Write-Host "Attempting to reload... Hopefully it works a second time."
                Set-SeURL -URL "$($URL.AbsoluteUri)"
            }
        } until (($count -ge 7) -or ($EnterUserNameField.count -ge 1))

        if ($count -ge 7) {
            Write-Error "Unable to detect username field after 7 attempts"
            pause
        }

        $currentElement = $EnterUserNameField }
        Invoke-SeClick -Element $currentElement
        Invoke-SeKeys -Element $currentElement -Keys "$($username)" -ClearFirst
        $currentElement = Get-SeElement -By Id -Value "passwd"
        Invoke-SeClick -Element $currentElement
        Invoke-SeKeys -Element $currentElement -Keys "$(ConvertFrom-SecureString -SecureString $($CredFileOutput.Password) -AsPlainText)"

        Write-Host "Detect Logon Button..."  -ForegroundColor Green
        $count = 0
        do {
            $count = $count+1
            $LogonField = Get-SeElement -By Id -Value "Log_On" -errorAction SilentlyContinue
            Write-Host "Loop number                                   : $count" -ForegroundColor Green
            Write-Host "Logon Field Element Detected                  : $($LogonField.count)"  -ForegroundColor Green
            Start-Sleep -Seconds 10
        } until (($count -ge 7) -or ($LogonField.count -ge 1))

        if ($count -ge 7) {
            Write-Error "Unable to detect logon button after 7 attempts"
            pause
        }
        Invoke-SeClick -Element $LogonField
    



    #see if we bypassed the "Detect Citrix Workspace App" screen
    Start-Sleep -Seconds 20
    $XPathString = "//img[@alt='" + $Application + "']" 
    $ApplicationName = Get-SeElement -By Xpath -Value "$XPathString" -ErrorAction SilentlyContinue

    if ($ApplicationName.count -eq 0) {
        #Detect Citrix Workspace App screen -- Wait 60-ish seconds
        $count = 0
        Write-Host "Detect Citrix Workspace App screen..."  -ForegroundColor Cyan
        do {
            $count = $count+1
        
            #protocolhandler-welcome-installButton
            $WelcomeInstall = Get-SeElement  -By XPath -Value "//*[contains(@id, 'protocolhandler-welcome-installButton')]" -Single -errorAction SilentlyContinue
            Write-Host "Loop number                                   : $count" -ForegroundColor Cyan
            Write-Host "Detect Citrix Workspace App Elements Detected : $($WelcomeInstall.count)" -ForegroundColor Cyan
            Start-Sleep -Seconds 10
        } until (($count -ge 7) -or ($WelcomeInstall.count -ge 1))
    

        if ($count -ge 7) {
            Write-Error "Unable to detect the Citrix Workspace app screen"

            pause
            #Start-Process osascript -ArgumentList 'tell app "System Events" to restart'
        }

        if ($WelcomeInstall.count -eq 1) {
            Write-Host "Click on Detect Workspace App/Reciever" -ForegroundColor Cyan
            Invoke-SeClick -Element $WelcomeInstall
            $currentElement = Get-SeElement -By Id "protocolhandler-detect-alreadyInstalledLink" -errorAction SilentlyContinue
            Invoke-SeClick -Element $currentElement -errorAction SilentlyContinue
        }
    }

    Write-Host "Waiting for enumeration... (120 second timeout)"  -ForegroundColor Magenta
    $XPathString = "//img[@alt='" + $Application + "']" 
    $elementExistsCount = 0
    do {
        $WaitResult = Wait-SeElement -By XPath -Value "$XPathString" -Condition ElementExists -Timeout 120
        $elementExistsCount = $elementExistsCount+1
    } until (($WaitResult -eq $true) -or ($elementExistsCount -ge 5))

    #TTYE - Selenium seems to have issues with the reciever:// custom handler. For whatever reason when I run selenium on my Win10 box it will not autolaunch the citrix wfica32 or cdviewer.exe apps
    # to resolve this, we can delete the cookie "CtxsClientVersion" which will force a ICA file to be downloaded
    $driver.Manage().Cookies.DeleteCookieNamed("CtxsClientVersion")
    $driver.Manage().Cookies.AddCookie([OpenQA.Selenium.Cookie]::new("CtxsUserPreferredClient","Native"))

    #Start-Sleep -Seconds 10
    #we should be logged in here and can click on the $Application
    $ApplicationName = Get-SeElement -By XPath -Value "$XPathString"
    if ($ApplicationName.count -eq 1) {
        Write-Host "Clicking on $Application"
        Invoke-SeClick -Element $ApplicationName
    }


    $count = 0
    $newlyLaunchedProcess = $false
    do {
        $count = $count+1
        $ICAFiles = Get-ChildItem "$DownloadDir" -Filter "*.ica"
        Write-Host "Waiting for ICA file to download or new Citrix process to spawn" -ForegroundColor Magenta

        ## Hopefully, if this script is used multiple times this "counting" of Citrix processes will detect the new connection and continue successfully
        $CDViewerLaunchCount = Get-Process CDViewer -ErrorAction SilentlyContinue
        $wfica32LaunchCount = Get-Process wfica32 -ErrorAction SilentlyContinue
        if ($CDViewerLaunchCount.count -gt $CDViewerProcesses.count) { $newlyLaunchedProcess = $true }
        if ($wfica32LaunchCount.count -gt $wfica32Processes.count) { $newlyLaunchedProcess = $true }
        ## Hopefully, if this script is used multiple times this "counting" of Citrix processes will detect the new connection and continue successfully
        Start-Sleep 5
    } until (($ICAFiles.count -ge 1) -or ($count -ge 24) -or ($newlyLaunchedProcess -eq $true))
}




if ($URL.Host -like "citrix.getcontrolup.com") {

    Start-Sleep -Seconds 5
    $XPathString = "//img[@alt='" + $Application + "']" 
    $ApplicationName = Get-SeElement -By Xpath -Value "$XPathString" -ErrorAction SilentlyContinue
    if ($ApplicationName.count -eq 0) {

        #detecting username button 
        Write-Host "Detect Username Field..."  -ForegroundColor Yellow
        $count = 0
        do {
            $count = $count+1
            $EnterUserNameField = Get-SeElement -By XPath -Value "//*[@id='login']" -errorAction SilentlyContinue
            Write-Host "Loop number                                   : $count" -ForegroundColor Yellow
            Write-Host "Enter User Name Element Detected              : $($EnterUserNameField.count)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            if ($count -eq 5) {
                Write-Host "It's been 50 seconds since we tried loading the gateway page and no user name field has been detected..."
                Write-Host "Attempting to reload... Hopefully it works a second time."
                Set-SeURL -URL "$($URL.AbsoluteUri)"
            }
        } until (($count -ge 7) -or ($EnterUserNameField.count -ge 1))

        if ($count -ge 7) {
            Write-Error "Unable to detect username field after 7 attempts"
            pause
        }

        $currentElement = $EnterUserNameField }
        Invoke-SeClick -Element $currentElement
        Invoke-SeKeys -Element $currentElement -Keys "$($username)" -ClearFirst
        $currentElement = Get-SeElement -By Id -Value "passwd"
        Invoke-SeClick -Element $currentElement
        Invoke-SeKeys -Element $currentElement -Keys "$(ConvertFrom-SecureString -SecureString $($CredFileOutput.Password) -AsPlainText)"

        Write-Host "Detect Logon Button..."  -ForegroundColor Green
        $count = 0
        do {
            $count = $count+1
            $LogonField = Get-SeElement -By XPath -Value "//*[@id='nsg-x1-logon-button']" -errorAction SilentlyContinue
            Write-Host "Loop number                                   : $count" -ForegroundColor Green
            Write-Host "Logon Field Element Detected                  : $($LogonField.count)"  -ForegroundColor Green
            Start-Sleep -Seconds 10
        } until (($count -ge 7) -or ($LogonField.count -ge 1))

        if ($count -ge 7) {
            Write-Error "Unable to detect logon button after 7 attempts"
            pause
        }
        Invoke-SeClick -Element $LogonField
    



    #see if we bypassed the "Detect Citrix Workspace App" screen
    Start-Sleep -Seconds 20
    $XPathString = "//img[@alt='" + $Application + "']" 
    $ApplicationName = Get-SeElement -By Xpath -Value "$XPathString" -ErrorAction SilentlyContinue

    if ($ApplicationName.count -eq 0) {
        #Detect Citrix Workspace App screen -- Wait 60-ish seconds
        $count = 0
        Write-Host "Detect Citrix Workspace App screen..."  -ForegroundColor Cyan
        do {
            $count = $count+1
        
            #protocolhandler-welcome
            $WelcomeInstall = Get-SeElement  -By Id -Value "protocolhandler-welcome" -Single -errorAction SilentlyContinue
            Write-Host "Loop number                                   : $count" -ForegroundColor Cyan
            Write-Host "Detect Citrix Workspace App Elements Detected : $($WelcomeInstall.count)" -ForegroundColor Cyan
            if ($WelcomeInstall.count -eq 0) { Start-Sleep -Seconds 10 }

        } until (($count -ge 7) -or ($WelcomeInstall.count -ge 1))
    

        if ($count -ge 7) {
            Write-Error "Unable to detect the Citrix Workspace app screen"

            pause
            #Start-Process osascript -ArgumentList 'tell app "System Events" to restart'
        }

        if ($WelcomeInstall.count -eq 1) {
            Write-Host "Click on Detect Workspace App/Reciever" -ForegroundColor Cyan
            Invoke-SeClick -Element $WelcomeInstall
            Start-Sleep -Seconds 5
            Write-Host "Click on 'Already Installed' (if needed)" -ForegroundColor Cyan
            $AlreadyInstalled  = Get-SeElement -By XPath "//a[text()='Already iunstalled']" -errorAction SilentlyContinue
            if ($AlreadyInstalled.count -ge 1) {
                Invoke-SeClick -Element $currentElement -errorAction SilentlyContinue
            }
        }
    }

    Write-Host "Waiting for enumeration... (120 second timeout)"  -ForegroundColor Magenta
    $XPathString = "//img[@alt='" + $Application + "']"

    $elementExistsCount = 0
    do {
        $WaitResult = Wait-SeElement -By XPath -Value "$XPathString" -Condition ElementExists -Timeout 120
        $elementExistsCount = $elementExistsCount+1
    } until (($WaitResult -eq $true) -or ($elementExistsCount -ge 5))
    #TTYE - Selenium seems to have issues with the reciever:// custom handler. For whatever reason when I run selenium on my Win10 box it will not autolaunch the citrix wfica32 or cdviewer.exe apps
    # to resolve this, we can delete the cookies "CtxsClientVersion" and ensure "CtxsUserPreferredClient" is set to Native which will force a ICA file to be downloaded
    $driver.Manage().Cookies.DeleteCookieNamed("CtxsClientVersion")
    $driver.Manage().Cookies.AddCookie([OpenQA.Selenium.Cookie]::new("CtxsUserPreferredClient","Native"))
    #Start-Sleep -Seconds 10
    #we should be logged in here and can click on the $Application
    $ApplicationName = Get-SeElement -By XPath -Value "$XPathString"
    if ($ApplicationName.count -eq 1) {
        Write-Host "Clicking on $Application"
        Invoke-SeClick -Element $ApplicationName
    }


    $count = 0
    $newlyLaunchedProcess = $false
    do {
        $count = $count+1
        $ICAFiles = Get-ChildItem "$DownloadDir" -Filter "*.ica"
        Write-Host "Waiting for ICA file to download or new Citrix process to spawn" -ForegroundColor Magenta

        ## Hopefully, if this script is used multiple times this "counting" of Citrix processes will detect the new connection and continue successfully
        $CDViewerLaunchCount = Get-Process CDViewer -ErrorAction SilentlyContinue
        $wfica32LaunchCount = Get-Process wfica32 -ErrorAction SilentlyContinue
        if ($CDViewerLaunchCount.count -gt $CDViewerProcesses.count) { $newlyLaunchedProcess = $true }
        if ($wfica32LaunchCount.count -gt $wfica32Processes.count) { $newlyLaunchedProcess = $true }
        ## Hopefully, if this script is used multiple times this "counting" of Citrix processes will detect the new connection and continue successfully
        Start-Sleep 5
    } until (($ICAFiles.count -ge 1) -or ($count -ge 24) -or ($newlyLaunchedProcess -eq $true))
}


if ($count -ge 24) {
    Write-Error "Failed to find ICA files... we probably failed to download it. Maybe the 'cannot start desktop' error message?"
    Stop-SeDriver -Driver $Driver
} else {
    Write-Host "Found $($ICAFiles.Count) ICA files..." -ForegroundColor Magenta

    . "$($ICAFiles.FullName)"

    Stop-SeDriver -Driver $Driver
}



#Start Network Link Conditioner if it exists
if ($EnableNetworkLineConditioner) {
    if (($IsMac) -and (Test-Path "$($($env:HOME).ToString())/Desktop/Enable Network Link Conditioner.app")) {
        Write-Host "Attempting to set the Network Link Conditioner..."
        Start-Process "$($($env:HOME).ToString())/Desktop/Enable Network Link Conditioner.app/Contents/MacOS/applet"
    }
}



Stop-Transcript

