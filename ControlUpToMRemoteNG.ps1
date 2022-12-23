#####################################
# Authors: David Sparer & Jack Denton
# Summary:
#   This is intended to be a template for creating connections in bulk. This uses the serializers directly from the mRemoteNG binaries.
#   You will still need to create the connection info objects, but the library will handle serialization. It is expected that you
#   are familiar with PowerShell. If this is not the case, reach out to the mRemoteNG community for help.
# Usage:
#   Replace or modify the examples that are shown toward the end of the script to create your own connection info objects.
#####################################

foreach ($Path in 'HKLM:\SOFTWARE\WOW6432Node\mRemoteNG', 'HKLM:\SOFTWARE\mRemoteNG') {
    Try {
        $mRNGPath = (Get-ItemProperty -Path $Path -Name InstallDir -ErrorAction Stop).InstallDir
        break
    }
    Catch {
        continue
    }
}
    
$null = [System.Reflection.Assembly]::LoadFile((Join-Path -Path $mRNGPath -ChildPath "mRemoteNG.exe"))
Add-Type -Path (Join-Path -Path $mRNGPath -ChildPath "BouncyCastle.Crypto.dll")

#ControlUp PS Module Import and test Module is running correctly
try {
	Get-Item "$((get-childitem 'C:\Program Files\Smart-X\ControlUpMonitor\' -Directory)[-1].fullName)\*powershell*.dll"|import-module
	$global:cuSites = get-cusites
}catch{if($_){throw $_}}

function ConvertTo-mRNGSerializedXml {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [mRemoteNG.Connection.ConnectionInfo[]]
        $Xml
)

    function Get-ChildNodes {
        Param ($Xml)

        $Xml

        if ($Xml -is [mRemoteNG.Container.ContainerInfo] -and $Xml.HasChildren()) {
            foreach ($Node in $Xml.Children) {
                Get-ChildNodes -Xml $Node
            }
        }
    }

    $AllNodes = Get-ChildNodes -Xml $Xml
    if (
        $AllNodes.Password -or
        $AllNodes.RDGatewayPassword -or
        $AllNodes.VNCProxyPassword
    ) {
        ## Modified to avoid password prompts
        $Password = [securestring]::new()
        #$Password = Read-Host -Message 'If you have password protected your ConfCons.xml please enter the password here otherwise just press enter' -AsSecureString
    }
    else {
        $Password = [securestring]::new()
    }
    $CryptoProvider = [mRemoteNG.Security.SymmetricEncryption.AeadCryptographyProvider]::new()
    $SaveFilter = [mRemoteNG.Security.SaveFilter]::new()
    $ConnectionNodeSerializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionNodeSerializer26]::new($CryptoProvider, $Password, $SaveFilter)
    $XmlSerializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionsSerializer]::new($CryptoProvider, $ConnectionNodeSerializer)

    $RootNode = [mRemoteNG.Tree.Root.RootNodeInfo]::new('Connection')
    foreach ($Node in $Xml) {
        $RootNode.AddChild($Node)
    }
    $XmlSerializer.Serialize($RootNode)
}

function New-mRNGConnection {
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    Param (
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter(Mandatory)]
        [string]
        $Hostname,

        [Parameter(Mandatory)]
        [mRemoteNG.Connection.Protocol.ProtocolType]
        $Protocol,

        [Parameter(ParameterSetName = 'Credential')]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName = 'InheritCredential')]
        [switch]
        $InheritCredential,

        [Parameter()]
        [mRemoteNG.Container.ContainerInfo]
        $ParentContainer,

        [Parameter()]
        [switch]
        $PassThru
    )

    $Connection = [mRemoteNG.Connection.ConnectionInfo]@{
        Name     = $Name
        Hostname = $Hostname
        Protocol = $Protocol
    }

    if ($Credential) {
        $Connection.Username = $Credential.GetNetworkCredential().UserName
        $Connection.Domain = $Credential.GetNetworkCredential().Domain
        $Connection.Password = $Credential.GetNetworkCredential().Password
    }

    if ($InheritCredential) {
        $Connection.Inheritance.Username = $true
        $Connection.Inheritance.Domain = $true
        $Connection.Inheritance.Password = $true
    }

    if ($ParentContainer) {
        $ParentContainer.AddChild($Connection)

        if ($PSBoundParameters.ContainsKey('PassThru')) {
            $Connection
        }
    }
    else {
        $Connection
    }
}

function New-mRNGContainer {
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    Param (
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Credential')]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName = 'InheritCredential')]
        [switch]
        $InheritCredential,

        [Parameter()]
        [mRemoteNG.Container.ContainerInfo]
        $ParentContainer
    )

    $Container = [mRemoteNG.Container.ContainerInfo]@{
        Name = $Name
    }

    if ($Credential) {
        $Container.Username = $Credential.GetNetworkCredential().UserName
        $Container.Domain = $Credential.GetNetworkCredential().Domain
        $Container.Password = $Credential.GetNetworkCredential().Password
    }

    if ($InheritCredential) {
        $Container.Inheritance.Username = $true
        $Container.Inheritance.Domain = $true
        $Container.Inheritance.Password = $true
    }

    if ($ParentContainer) {
        $ParentContainer.AddChild($Container)
    }
    
    $Container
}

function Export-mRNGXml {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path,

        [Parameter()]
        [string]
        $SerializedXml
    )

    $FilePathProvider = [mRemoteNG.Config.DataProviders.FileDataProvider]::new($Path)
    $filePathProvider.Save($SerializedXml)
}

$CUComputers = Get-CUComputers # add a filter on path so only computers within the $rootfolder are used


<#
$Connections = foreach ($i in 1..5) {
    # Create new connection
    $Splat = @{
        Name              = 'Server-{0:D2}' -f $i
        Hostname          = 'Server-{0:D2}' -f $i
        Protocol          = 'RDP'
        InheritCredential = $true
    }
    New-mRNGConnection @Splat
}

# Serialize the connections
$SerializedXml = ConvertTo-mRNGSerializedXml -Xml $Connections

# Write the XML to a file ready to import into mRemoteNG
Export-mRNGXml -Path "$ENV:APPDATA\mRemoteNG\PowerShellGenerated.xml" -SerializedXml $SerializedXml

# Now open up mRemoteNG and press Ctrl+O and open up the exported XML file
#>



#----------------------------------------------------------------
# Example 2: serialize a container which has connections
# You can also create containers and add connections and containers to them, which will be nested correctly when serialized
# If you specify the ParentContainer parameter for new connections then there will be no output unless the PassThru parameter is also used


$Containers = ($CUComputers).Path | Sort -Unique
$global:mRemoteNGContainers = @{}
$global:rootContainer = $null
$findChildObject = $false
$parentContainer = $null
$simplifiedContainers = $Containers | Split-Path | Sort-Object -Unique
[int]$ContainerCount = 0
Foreach ($Container in $Containers) {
    $PathArray = $Container.Split("\")
    Write-Verbose -Message "$($Container) has $($PathArray.count) levels"
    #iterate through the path list and attempt to add them to the hash table. Format will be Name, PathDepth
    [int]$PathDepth = -1
    
    foreach ($Path in $PathArray) {
        $PathDepth = $PathDepth + 1
        if ($PathDepth -eq 0) {
            $PathRoot = $Path
            $PathName = $PathRoot
            $ParentPath = ""
        }
        if ($PathDepth -eq 1) {
            $ParentPath = $PathName
            $PathName = $PathRoot + "\" + $Path
        }
        if ($PathDepth -ge 2) {
            $ParentPath = $PathName
            $PathName = $PathName + "\" + $Path
        }
        
        #Write-Host "PathName: $PathName" -ForegroundColor Green
        [int]$ContainerCount = $ContainerCount + 1
        Write-Host "Working on "  -NoNewline
        Write-Host "$Path " -ForegroundColor Yellow -NoNewline
        Write-Host "With ParentPath - " -NoNewline
        Write-Host "`"$PathName`" " -ForegroundColor Green -NoNewline
        Write-Host "at a depth of $PathDepth - $ContainerCount"
        if ($global:mRemoteNGContainers.ContainsKey($PathName)) {
            Write-Host "Found matching path $pathName" 
        } else {
            #Add-Member -InputObject $global:mRemoteNGContainers -NotePropertyName $pathName -NotePropertyValue @{Container=$container; Path=$path; PathDepth=$PathDepth}
            if ($PathDepth -eq 0) {
                $global:mRemoteNGContainers.Add($PathName, @{Container=$container;  ParentPath=$ParentPath; Path="$path"; Name=$path; PathDepth=$PathDepth})
            } else {
                $global:mRemoteNGContainers.Add($PathName, @{Container=$container;  ParentPath=$ParentPath; Path="$ParentPath\$path"; Name=$path; PathDepth=$PathDepth})
            }
        }
    }
}


#we now have a full list of the containers to add to mRemoteNG. Now we just need to add them with each iteration checking to see if the Path was already added


$deepestPath = (($global:mRemoteNGContainers.Values.PathDepth) | Sort-Object -Unique -Descending)[0]

class mRemoteNGPath {
    [int]$PathDepth
    [string]$Name
    [string]$Path
    [string]$ParentPath
    [string]$Container
}


$mRemoteContainerPaths = New-Object PSCustomObject
$mRemoteContainerPathsComplete = [System.Collections.ArrayList]@()
$mRemoteContainerCount = 0
for ($i=0; $i -le $deepestPath; $i++){
    if ($i -eq 0) {
        $RootPath = ($global:mRemoteNGContainers.Values.Where({$_.PathDepth -like 0})).Path ## there should only be 1 entry...
        $RootPathContainer = New-mRNGContainer -Name $RootPath
        if ($CUComputers.path.Contains("$($RootPath)")) {
            foreach ($CUComputer in $CUComputers.Where({$_.path -eq "$($RootPath)"})) {
                # Create new connection
                $Splat = @{
                    Name              = $CUComputer.Name
                    Hostname          = $CUComputer.FQDN
                    Protocol          = 'RDP'
                    InheritCredential = $true
                    ParentContainer   = $RootPathContainer
                    PassThru          = $true
                }

                # Specified the PassThru parameter in order to catch the connection and change a property
                $Connection = New-mRNGConnection @Splat
                $Connection.Resolution = 'FullScreen'
            }
        }
        #$mRemoteContainerPaths.Add($RootPath, $RootPathContainer)
        Add-Member -InputObject $mRemoteContainerPaths -NotePropertyName $RootPath -NotePropertyValue @{Container=$RootPathContainer; Path=$RootPath; Index=$mRemoteContainerCount}
        $mRemoteContainerPathsComplete.Add($RootPathContainer)

    } else {
        #make a PSObject out of the hashtable entries so we can sort it alphabetically at each level. Or else the hash table will be pretty random for placement
        $mRemoteContainerSortedPaths = [System.Collections.ArrayList]@()
        ($global:mRemoteNGContainers.Values.Where({$_.PathDepth -eq $i})).foreach{ 
            $PathsFoundAtLevel = New-Object mRemoteNGPath
            $PathsFoundAtLevel.Name = $_.Name
            $PathsFoundAtLevel.Path = $_.Path
            $PathsFoundAtLevel.ParentPath = $_.ParentPath
            $PathsFoundAtLevel.PathDepth = $_.PathDepth
            $PathsFoundAtLevel.Container = $_.Container
            $mRemoteContainerSortedPaths.Add($PathsFoundAtLevel) | Out-Null
        }

        $mRemoteContainerSortedPaths = $mRemoteContainerSortedPaths | sort -Property Path
        foreach ($object in $mRemoteContainerSortedPaths) {
            if ($mRemoteContainerPaths."$($object.ParentPath)") {
                Write-Host "mRemoteContainerPaths contains path: $($object.ParentPath)"
                if (Get-Variable PathContainer -ErrorAction SilentlyContinue) { Remove-Variable PathContainer }
                write-Host "New-mRNGContainer -Name $($object.Name) -ParentContainer $($mRemoteContainerPaths."$($Object.ParentPath)".container.name)" -ForegroundColor Yellow
                $PathContainer = New-mRNGContainer -Name $($object.Name) -ParentContainer $($mRemoteContainerPaths."$($Object.ParentPath)".container)

                if ($CUComputers.path.Contains("$($object.Path)")) {
                    write-Host "CUComputers has $($object.Path)" -ForegroundColor Green
                    foreach ($CUComputer in $CUComputers.Where({$_.path -eq "$($object.Path)"})) {
                        # Create new connection
                        $Splat = @{
                            Name              = $CUComputer.Name
                            Hostname          = $CUComputer.FQDN
                            Protocol          = 'RDP'
                            InheritCredential = $true
                            ParentContainer   = $PathContainer
                            PassThru          = $true
                        }

                        # Specified the PassThru parameter in order to catch the connection and change a property
                        $Connection = New-mRNGConnection @Splat
                    }
                }
                #$mRemoteContainerPaths.Add($Object.Path, $PathContainer)
                Add-Member -InputObject $mRemoteContainerPaths -NotePropertyName $Object.Path -NotePropertyValue @{Container=$PathContainer; Path=$Object.Path; Index=$mRemoteContainerCount}
                $mRemoteContainerPathsComplete.Add($PathContainer)
            }
        }
    }
}

$SerializedXml = ConvertTo-mRNGSerializedXml -Xml $RootPathContainer
Export-mRNGXml -Path "\\mwss01.jupiterlab.com\Fileshare\DeployableApplications\mRemoteNG\Generated.xml" -SerializedXml $SerializedXml

