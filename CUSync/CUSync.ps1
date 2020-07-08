<#
.SYNOPSIS
	Synchronizes ControlUp folder structure with an external source (Active Directory, Citrix, Horizon, WVD)
.DESCRIPTION
	Runs on a ControlUp Monitor computer
	Connects to an external source, retrieves the folder structure to synchronize
	Adds to ControlUp folder structure all folders and computers from the external source
	Moves folders and computers which exist in locations that differ from the external source
	Optionally, removes folders and computers which do not exist in the external source
.EXAMPLE
.CONTEXT
.MODIFICATION_HISTORY
.LINK
.COMPONENT
.NOTES
#>

#region Bind input parameters
[CmdletBinding()]
Param
(

	[Parameter(
    	Position=1,
    	Mandatory=$true,
    	HelpMessage='External source type (AD for Active Directory, XD for Citrix Apps, HZ for Horizon, or WVD)'
	)]
	[ValidateSet("AD","XD","HZ","WVD")]
	[string] $ExtSourceType,

	[Parameter(
    	Mandatory=$false,
    	HelpMessage='ControlUp root folder to sync'
	)]
	[string] $CURootFolder,

	[Parameter(
    	Mandatory=$false,
    	HelpMessage='External root folder to sync'
	)]
	[string] $ExtRootFolder,

	[Parameter(
    	Mandatory=$false,
    	HelpMessage='External folder/s to exclude'
	)]
	[string] $ExtExcludeFolders,

	[Parameter(
    	Mandatory=$false,
    	HelpMessage='External computer/s to exclude'
	)]
	[string] $ExtExcludeComputers,

 	[Parameter(
    	Mandatory=$false,
    	HelpMessage='Delete CU objects which are not in the external source'
	)]
	[switch] $Delete,

    [Parameter(
        Mandatory=$false,
        HelpMessage='Generate a report of the actions to be executed'
    )]
    [switch]$Preview

)
#endregion


#optional PreviewPath parameter to save preivew output
DynamicParam  {
    if ($PreviewOutputPath) {
        #create a new ParameterAttribute Object
        $PreviewAttribute = New-Object System.Management.Automation.ParameterAttribute
        $PreviewAttribute.Mandatory = $false
        $PreviewAttribute.HelpMessage = "Enter a path to save the preview report"
        
        #create an attributecollection object for the attribute we just created.
        $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
 
        #add our custom attribute
        $attributeCollection.Add($PreviewAttribute)
 
        #add our paramater specifying the attribute collection
        $pathParam = New-Object System.Management.Automation.RuntimeDefinedParameter('PreviewOutputPath', [string], $attributeCollection)
 
        #expose the name of our parameter
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add('PreviewOutputPath', $pathParam)
        return $paramDictionary
    }
}

Begin {
    function Write-CULog {
        <#
        .SYNOPSIS
	        Write the Logfile
        .DESCRIPTION
	        Helper Function to Write Log Messages to Console Output and corresponding Logfile
	        use get-help <functionname> -full to see full help
        .EXAMPLE
	        Write-CULog -Msg "Warining Text" -Type W
        .EXAMPLE
	        Write-CULog -Msg "Text would be shown on Console" -ShowConsole
        .EXAMPLE
	        Write-CULog -Msg "Text would be shown on Console in Cyan Color, information status" -ShowConsole -Color Cyan
        .EXAMPLE
	        Write-CULog -Msg "Error text, script would be existing automaticaly after this message" -Type E
        .EXAMPLE
	        Write-CULog -Msg "External log contenct" -Type L
        .NOTES
	        Author: Matthias Schlimm
	        Company:  EUCWeb.com
	        History:
	        dd.mm.yyyy MS: function created
	        07.09.2015 MS: add .SYNOPSIS to this function
	        29.09.2015 MS: add switch -SubMSg to define PreMsg string on each console line
	        21.11.2017 MS: if Error appears, exit script with Exit 1
            08.07.2020 TT: Borrowed Write-BISFLog and modified to meet the purpose for this script
        .LINK
	        https://eucweb.com
        #>

        Param(
	        [Parameter(Mandatory = $True)][Alias('M')][String]$Msg,
	        [Parameter(Mandatory = $False)][Alias('S')][switch]$ShowConsole,
	        [Parameter(Mandatory = $False)][Alias('C')][String]$Color = "",
	        [Parameter(Mandatory = $False)][Alias('T')][String]$Type = "",
	        [Parameter(Mandatory = $False)][Alias('B')][switch]$SubMsg
        )
    
        $LogType = "INFORMATION..."
        IF ($Type -eq "W" ) { $LogType = "WARNING........."; $Color = "Yellow" }
        IF ($Type -eq "E" ) { $LogType = "ERROR..............."; $Color = "Red" }

        IF (!($SubMsg)) {
	        $PreMsg = "+"
        }
        ELSE {
	        $PreMsg = "`t>"
        }
        
        $date = Get-Date -Format G
        if (-not([string]::IsNullOrEmpty($Global:PreviewOutputPath))) {
            Write-Output "$date | $LogType | $Msg"  | Out-file $($Global:PreviewOutputPath) -Append
        }


        If (!($ShowConsole)) {
	        IF (($Type -eq "W") -or ($Type -eq "E" )) {
		        IF ($VerbosePreference -eq 'SilentlyContinue') {
			        Write-Host "$PreMsg $Msg" -ForegroundColor $Color
			        $Color = $null
		        }
	        }
	        ELSE {
		        Write-Verbose -Message "$PreMsg $Msg"
		        $Color = $null
	        }

        }
        ELSE {
	        if ($Color -ne "") {
		        IF ($VerbosePreference -eq 'SilentlyContinue') {
			        Write-Host "$PreMsg $Msg" -ForegroundColor $Color
			        $Color = $null
		        }
	        }
	        else {
		        Write-Host "$PreMsg $Msg"
	        }
        }
    }

    if ($PSBoundParameters.ContainsKey("PreviewOutputPath")) {
        $Global:PreviewOutputPath = $PSBoundParameters.PreviewOutputPath
        Write-Host "Saving Output to: $Global:PreviewOutputPath"
        if (-not(Test-Path $($PSBoundParameters.PreviewOutputPath))) {
            Write-CULog -Msg "Creating Log File" #Attempt to create the file
            if (-not(Test-Path $($PSBoundParameters.PreviewOutputPath))) {
                Write-Error "Unable to create the report file" -ErrorAction Stop
            }
        } else {
            Write-CULog -Msg "Beginning Synchronization"
        }
        Write-CULog -Msg "Detected the following parameters:"
        foreach($psbp in $PSBoundParameters.GetEnumerator())
        {
            Write-CULog -Msg $("Parameter={0} Value={1}" -f $psbp.Key,$psbp.Value)
        }
    }
}
    



Process {
    <#
    ## For debugging uncomment
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'continue'
    $DebugPreference = 'SilentlyContinue'    Set-StrictMode -Version Latest    #>

    #region Dot-source functions for each external source
    . ".\Get-ExternalTree.ps1"  # source-agnostic stuff like Get-ExternalTree, Out-CUConsole, Apply-CUBatchUpdate
    #endregion

    #region Load ControlUp PS Module
    try {
	    # Importing the latest ControlUp PowerShell Module
	    $pathtomodule = (Get-ChildItem "$($env:ProgramFiles)\Smart-X\ControlUpMonitor\*\ControlUp.PowerShell.User.dll" -Recurse | Sort-Object LastWriteTime -Descending)[0]
	    Import-Module $pathtomodule
    }
    catch {
        Write-CULog -Msg 'The required ControlUp PowerShell module was not found or could not be loaded. Please make sure this is a ControlUp Monitor machine.' -ShowConsole -Type E
    }
    #endregion

    
    #Ensure WVD is in the CURootFolder --> Needed for Virtual Expert Actions
    if ($ExtSourceType -eq "WVD") {
        $CURootFolder = "$CURootFolder\WVD"
    }

    #region Retrieve ControlUp folder structure
    try {
        $CUComputers = Get-CUComputers # add a filter on path so only computers within the $rootfolder are used
    } catch {
        Write-Error "Unable to get computers from ControlUp"
        break
    }
    Write-CULog -Msg  "CU Computers Count: $($CUComputers.count)" -ShowConsole -Color Cyan

    #create a hashtable out of the CUMachines object as it's much faster to query. This is critical when looking up Machines when ControlUp contains ten's of thousands of machines.
    $CUComputersHashTable = @{}
    foreach ($machine in $CUComputers) {
        foreach ($obj in $machine) {
            $CUComputersHashTable.Add($Obj.Name, $obj)
        }
    }

    $CUFolders   = Get-CUFolders # add a filter on path so only folders within the rootfolder are used
    #endregion

    $OrganizationName = ($CUFolders)[0].path
    Write-CULog -Msg "Organization Name: $OrganizationName"

    #region Retrieve external folder structure
    $ExternalTreeTime = Measure-Command {
        $ExternalTree = Get-ExternalTree -SourceType $ExtSourceType #-ConnectionParameters $ExtConnectionParams
    }
    Write-CULog -Msg "Getting External Tree data took $($ExternalTreeTime.TotalSeconds) Seconds" -ShowConsole -Color Blue
    #endregion


    $ExtTreeHashTable = @{}
    foreach ($ExtObj in $ExternalTree) {
        foreach ($obj in $ExtObj) {
            $ExtTreeHashTable.Add($Obj.Name, $obj)
        }
    }

    #region Prepare items for synchronization

    # Build folders batch
    $ExtFolderPaths = New-Object System.Collections.Generic.List[PSObject]
    foreach ($folderPath in $ExternalTree.FolderPath) {
        $ExtFolderPaths.Add("$("$OrganizationName\$CURootFolder")\$folderPath")
    }

    $ExtFolderPaths = $ExtFolderPaths | Select-Object -Unique

    if ($ExtExcludeFolders) {
	    $ExtFolderPaths   = $ExtFolderPaths   | Where-Object {$_ -notin $ExtExcludeFolders}
    }

    if ($ExtRootFolder) {
	    $ExtFolderPaths   = $ExtFolderPaths   | Where-Object {$_ -notin $ExtExcludeFolders}
    }

    foreach ($ExtFolderPath in $ExtFolderPaths) {
	    $depth = ($ExtFolderPath.ToCharArray() -eq '\').Count
        if ($depth -eq 0) {  # if we have root folder listed in the externaltree object without slash we need to check for it
            $ExtFolderPaths += $ExtFolderPath
        } else {
	        for ($n = 0; $n -le $depth; $n++) {
    	        $ExtFolderPaths += $ExtFolderPath.Substring(0,$ExtFolderPath.LastIndexOf("\"))
            }
	    }
    }
    $ExtFolderPaths = $ExtFolderPaths | Select-Object -Unique | Sort-Object

    $FoldersBatch = New-CUBatchUpdate
    $FoldersToAdd = New-Object System.Collections.Generic.List[PSObject]

    foreach ($ExtFolderPath in $ExtFolderPaths) {
        if ("$ExtFolderPath" -notin $($CUFolders.Path)) {  ##check if folder doesn't already exist
	        $LastBackslashPosition = $ExtFolderPath.LastIndexOf("\")
	        if ($LastBackslashPosition -gt 0) {  
                Add-CUFolder -Name $ExtFolderPath.Substring($LastBackslashPosition+1) -ParentPath $ExtFolderPath.Substring(0,$LastBackslashPosition) -Batch $FoldersBatch
                $FoldersToAdd.Add("Add-CUFolder -Name $($ExtFolderPath.Substring($LastBackslashPosition+1)) -ParentPath `"$($ExtFolderPath.Substring(0,$LastBackslashPosition))`"")
	        }   
        }
    }

    # Build computers batch
    $ComputersBatch = New-CUBatchUpdate

    $ExtComputers = $ExternalTree.Where{$_.Type -eq "Computer"}

    if ($ExtExcludeComputers) {
	    $ExtComputers = $ExtComputers.Where{$_.Name -notin $ExtExcludeComputers}
    }
    Write-CULog -Msg "Number of externally sourced computers: $($ExtComputers.count)"

    #we'll output the statistics at the end -- also helps with debugging
    $MachinesToMove = New-Object System.Collections.Generic.List[PSObject]
    $MachinesToAdd = New-Object System.Collections.Generic.List[PSObject]
    $MachinesToRemove = New-Object System.Collections.Generic.List[PSObject]

    foreach ($ExtComputer in $ExtComputers) {
	    if (($CUComputersHashTable.Contains("$($ExtComputer.Name)"))) {
    	    if ("$("$OrganizationName\$CURootFolder")\$($ExtComputer.FolderPath)" -notlike $($CUComputersHashTable[$($ExtComputer.name)].Path)) {
        	    Move-CUComputer -Name $ExtComputer.Name -FolderPath "$("$OrganizationName\$CURootFolder")\$($ExtComputer.FolderPath)" -Batch $ComputersBatch
                $MachinesToMove.Add("Move-CUComputer -Name $($ExtComputer.Name) -FolderPath `"$("$OrganizationName\$CURootFolder")\$($ExtComputer.FolderPath)`"")
    	    }
	    } else {
    	    Add-CUComputer -Domain $ExtComputer.Domain -Name $ExtComputer.Name -FolderPath "$("$OrganizationName\$CURootFolder")\$($ExtComputer.FolderPath)" -Batch $ComputersBatch
            $MachinesToAdd.Add("Add-CUComputer -Domain $($ExtComputer.Domain) -Name $($ExtComputer.Name) -FolderPath `"$("$OrganizationName\$CURootFolder")\$($ExtComputer.FolderPath)`"")
	    }
    }

    $FoldersToRemove = New-Object System.Collections.Generic.List[PSObject]
    if ($Delete -or $Preview) {
	    # Build batch for folders which are in ControlUp but not in the external source
	    $FoldersToRemoveBatch = New-CUBatchUpdate
        $CUFolderSyncRoot = $CUFolders.where{$_.Path -like "$("$OrganizationName\$CURootFolder")\*"} ## Get CUFolders filtered to targetted sync path
	    foreach ($CUFolder in $($CUFolderSyncRoot.Path)) {
    	    if ($CUFolder -notin $ExtFolderPaths) {
                if ($Delete) {
        	        Remove-CUFolder -FolderPath "$CUFolder" -Force -Batch $FoldersToRemoveBatch
                    $FoldersToRemove.Add("Remove-CUFolder -FolderPath `"$CUFolder`" -Force")
                }
		    # TODO After testing, add to the bottom: Publish-CUUpdates $FoldersToRemoveBatch
    	    }
	    }
	    # Build batch for computers which are in ControlUp but not in the external source
	    $ComputersToRemoveBatch = New-CUBatchUpdate
	    foreach ($CUComputer in $CUComputers) {
            if ($CUComputer.path -like "$("$OrganizationName\$CURootFolder")\$($ExtComputer.FolderPath)") {
    	        if (-not($ExtTreeHashTable.Contains("$($CUComputer.name)"))) {
                    if ($Delete) {
        	            Remove-CUComputer -Name $($CUComputer.Name) -Force -Batch $ComputersToRemoveBatch
                        $MachinesToRemove.Add("Remove-CUComputer -Name $($CUComputer.Name) -Force")
                    }
                }
    # TODO After testing, add to the bottom: Publish-CUUpdates $ComputersToRemoveBatch
    	    }
	    }
    }
    #endregion

    if ($Preview) {
        Write-CULog -Msg "Folders to Add     : $($FoldersToAdd.Count)" -ShowConsole -Color White
        foreach ($obj in $FoldersToAdd) {
            Write-CULog -Msg "$obj" -ShowConsole -Color Green
        }
        Write-CULog -Msg "Folders to Remove  : $($FoldersToRemove.Count)" -ShowConsole -Color White
        foreach ($obj in $FoldersToRemove) {
            Write-CULog -Msg "$obj" -ShowConsole -Color Red
        }
        Write-CULog -Msg "Computers to Add   : $($MachinesToAdd.Count)" -ShowConsole -Color White
        foreach ($obj in $MachinesToAdd) {
            Write-CULog -Msg "$obj" -ShowConsole -Color Green
        }
        Write-CULog -Msg "Computers to Move  : $($MachinesToMove.Count)" -ShowConsole -Color White
        foreach ($obj in $MachinesToMove) {
            Write-CULog -Msg "$obj" -ShowConsole -Color DarkYellow
        }
        Write-CULog -Msg "Computers to Remove: $($MachinesToRemove.Count)" -ShowConsole -Color White
        foreach ($obj in $MachinesToRemove) {
            Write-CULog -Msg "$obj" -ShowConsole -Color Red
        }
    }
    #region Commit the changes
    # TODO implement handling batch size
    #Publish-CUUpdates $FoldersBatch
    #Publish-CUUpdates $ComputersBatch
    #endregion
}