#Requires -RunAsAdministrator
$AuditCategoryNames = @{}

$AuditCategoryNames.Add('69979848-797a-11d9-bed3-505054503030','Audit_System')
$AuditCategoryNames.Add('69979849-797a-11d9-bed3-505054503030','Audit_Logon')
$AuditCategoryNames.Add('6997984a-797a-11d9-bed3-505054503030','Audit_ObjectAccess')
$AuditCategoryNames.Add('6997984b-797a-11d9-bed3-505054503030','Audit_PrivilegeUse')
$AuditCategoryNames.Add('6997984c-797a-11d9-bed3-505054503030','Audit_DetailedTracking')
$AuditCategoryNames.Add('6997984d-797a-11d9-bed3-505054503030','Audit_PolicyChange')
$AuditCategoryNames.Add('6997984e-797a-11d9-bed3-505054503030','Audit_AccountManagement')
$AuditCategoryNames.Add('6997984f-797a-11d9-bed3-505054503030','Audit_DirectoryServiceAccess')
$AuditCategoryNames.Add('69979850-797a-11d9-bed3-505054503030','Audit_AccountLogon')

$AuditSubCategoryNames = @{}
$AuditSubCategoryNames.Add('0cce9210-69ae-11d9-bed3-505054503030','Security State Change')
$AuditSubCategoryNames.Add('0cce9211-69ae-11d9-bed3-505054503030','Security System Extension')
$AuditSubCategoryNames.Add('0cce9212-69ae-11d9-bed3-505054503030','System Integrity')
$AuditSubCategoryNames.Add('0cce9213-69ae-11d9-bed3-505054503030','IPsec Driver')
$AuditSubCategoryNames.Add('0cce9214-69ae-11d9-bed3-505054503030','Other System Events')
$AuditSubCategoryNames.Add('0cce9215-69ae-11d9-bed3-505054503030','Logon')
$AuditSubCategoryNames.Add('0cce9216-69ae-11d9-bed3-505054503030','Logoff')
$AuditSubCategoryNames.Add('0cce9217-69ae-11d9-bed3-505054503030','Account Lockout')
$AuditSubCategoryNames.Add('0cce9218-69ae-11d9-bed3-505054503030','IPsec Main Mode')
$AuditSubCategoryNames.Add('0cce9219-69ae-11d9-bed3-505054503030','IPsec Quick Mode')
$AuditSubCategoryNames.Add('0cce921a-69ae-11d9-bed3-505054503030','IPsec Extended Mode')
$AuditSubCategoryNames.Add('0cce921b-69ae-11d9-bed3-505054503030','Special Logon')
$AuditSubCategoryNames.Add('0cce921c-69ae-11d9-bed3-505054503030','Other Logon/Logoff Events')
$AuditSubCategoryNames.Add('0cce9243-69ae-11d9-bed3-505054503030','Network Policy Server')
$AuditSubCategoryNames.Add('0cce9247-69ae-11d9-bed3-505054503030','User / Device Claims')
$AuditSubCategoryNames.Add('0cce9249-69ae-11d9-bed3-505054503030','Group Membership')
$AuditSubCategoryNames.Add('0cce921d-69ae-11d9-bed3-505054503030','File System')
$AuditSubCategoryNames.Add('0cce921e-69ae-11d9-bed3-505054503030','Registry')
$AuditSubCategoryNames.Add('0cce921f-69ae-11d9-bed3-505054503030','Kernel Object')
$AuditSubCategoryNames.Add('0cce9220-69ae-11d9-bed3-505054503030','SAM')
$AuditSubCategoryNames.Add('0cce9221-69ae-11d9-bed3-505054503030','Certification Services')
$AuditSubCategoryNames.Add('0cce9222-69ae-11d9-bed3-505054503030','Application Generated')
$AuditSubCategoryNames.Add('0cce9223-69ae-11d9-bed3-505054503030','Handle Manipulation')
$AuditSubCategoryNames.Add('0cce9224-69ae-11d9-bed3-505054503030','File Share')
$AuditSubCategoryNames.Add('0cce9225-69ae-11d9-bed3-505054503030','Filtering Platform Packet Drop')
$AuditSubCategoryNames.Add('0cce9226-69ae-11d9-bed3-505054503030','Filtering Platform Connection')
$AuditSubCategoryNames.Add('0cce9227-69ae-11d9-bed3-505054503030','Other Object Access Events')
$AuditSubCategoryNames.Add('0cce9244-69ae-11d9-bed3-505054503030','Detailed File Share')
$AuditSubCategoryNames.Add('0cce9245-69ae-11d9-bed3-505054503030','Removable Storage')
$AuditSubCategoryNames.Add('0cce9246-69ae-11d9-bed3-505054503030','Central Policy Staging')
$AuditSubCategoryNames.Add('0cce9228-69ae-11d9-bed3-505054503030','Sensitive Privilege Use')
$AuditSubCategoryNames.Add('0cce9229-69ae-11d9-bed3-505054503030','Non Sensitive Privilege Use')
$AuditSubCategoryNames.Add('0cce922a-69ae-11d9-bed3-505054503030','Other Privilege Use Events')
$AuditSubCategoryNames.Add('0cce922b-69ae-11d9-bed3-505054503030','Process Creation')
$AuditSubCategoryNames.Add('0cce922c-69ae-11d9-bed3-505054503030','Process Termination')
$AuditSubCategoryNames.Add('0cce922d-69ae-11d9-bed3-505054503030','DPAPI Activity')
$AuditSubCategoryNames.Add('0cce922e-69ae-11d9-bed3-505054503030','RPC Events')
$AuditSubCategoryNames.Add('0cce9248-69ae-11d9-bed3-505054503030','Plug and Play Events')
$AuditSubCategoryNames.Add('0cce924a-69ae-11d9-bed3-505054503030','Token Right Adjusted Events')
$AuditSubCategoryNames.Add('0cce922f-69ae-11d9-bed3-505054503030','Audit Policy Change')
$AuditSubCategoryNames.Add('0cce9230-69ae-11d9-bed3-505054503030','Authentication Policy Change')
$AuditSubCategoryNames.Add('0cce9231-69ae-11d9-bed3-505054503030','Authorization Policy Change')
$AuditSubCategoryNames.Add('0cce9232-69ae-11d9-bed3-505054503030','MPSSVC Rule-Level Policy Change')
$AuditSubCategoryNames.Add('0cce9233-69ae-11d9-bed3-505054503030','Filtering Platform Policy Change')
$AuditSubCategoryNames.Add('0cce9234-69ae-11d9-bed3-505054503030','Other Policy Change Events')
$AuditSubCategoryNames.Add('0cce9235-69ae-11d9-bed3-505054503030','User Account Management')
$AuditSubCategoryNames.Add('0cce9236-69ae-11d9-bed3-505054503030','Computer Account Management')
$AuditSubCategoryNames.Add('0cce9237-69ae-11d9-bed3-505054503030','Security Group Management')
$AuditSubCategoryNames.Add('0cce9238-69ae-11d9-bed3-505054503030','Distribution Group Management')
$AuditSubCategoryNames.Add('0cce9239-69ae-11d9-bed3-505054503030','Application Group Management')
$AuditSubCategoryNames.Add('0cce923a-69ae-11d9-bed3-505054503030','Other Account Management Events')
$AuditSubCategoryNames.Add('0cce923b-69ae-11d9-bed3-505054503030','Directory Service Access')
$AuditSubCategoryNames.Add('0cce923c-69ae-11d9-bed3-505054503030','Directory Service Changes')
$AuditSubCategoryNames.Add('0cce923d-69ae-11d9-bed3-505054503030','Directory Service Replication')
$AuditSubCategoryNames.Add('0cce923e-69ae-11d9-bed3-505054503030','Detailed Directory Service Replication')
$AuditSubCategoryNames.Add('0cce923f-69ae-11d9-bed3-505054503030','Credential Validation')
$AuditSubCategoryNames.Add('0cce9240-69ae-11d9-bed3-505054503030','Kerberos Service Ticket Operations')
$AuditSubCategoryNames.Add('0cce9241-69ae-11d9-bed3-505054503030','Other Account Logon Events')
$AuditSubCategoryNames.Add('0cce9242-69ae-11d9-bed3-505054503030','Kerberos Authentication Service')



 

$AuditDefinitions = @"


    /// <summary>
    /// The AuditEnumerateCategories function enumerates the available audit-policy categories.
    /// </summary>
    /// <param name="ppAuditCategoriesArray">A pointer to a single buffer that contains both an array of pointers to GUID structures and the structures themselves. </param>
    /// <param name="pCountReturned">A pointer to the number of elements in the ppAuditCategoriesArray array.</param>
    /// <returns>A System.Boolean value that indicates whether the function completed successfully.</returns>
    /// <remarks>https://msdn.microsoft.com/en-us/library/windows/desktop/aa375636(v=vs.85).aspx</remarks>
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AuditEnumerateCategories(out IntPtr ppAuditCategoriesArray, out uint pCountReturned);


    /// <summary>
    /// The AuditLookupCategoryName function retrieves the display name of the specified audit-policy category.
    /// </summary>
    /// <param name="pAuditCategoryGuid">A pointer to a GUID structure that specifies an audit-policy category.</param>
    /// <param name="ppszCategoryName">The address of a pointer to a null-terminated string that contains the display name of the audit-policy category specified by the pAuditCategoryGuid function.</param>
    /// <returns>A System.Boolean value that indicates whether the function completed successfully.</returns>
    /// <remarks>https://msdn.microsoft.com/en-us/library/windows/desktop/aa375687(v=vs.85).aspx</remarks>
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AuditLookupCategoryName(ref Guid pAuditCategoryGuid, out StringBuilder ppszCategoryName);


    /// <summary>
    /// The AuditEnumerateSubCategories function enumerates the available audit-policy subcategories.
    /// </summary>
    /// <param name="pAuditCategoryGuid">The GUID of an audit-policy category for which subcategories are enumerated. If the value of the bRetrieveAllSubCategories parameter is TRUE, this parameter is ignored.</param>
    /// <param name="bRetrieveAllSubCategories">TRUE to enumerate all audit-policy subcategories; FALSE to enumerate only the subcategories of the audit-policy category specified by the pAuditCategoryGuid parameter.</param>
    /// <param name="ppAuditSubCategoriesArray">A pointer to a single buffer that contains both an array of pointers to GUID structures and the structures themselves. The GUID structures specify the audit-policy subcategories available on the computer.</param>
    /// <param name="pCountReturned">A pointer to the number of audit-policy subcategories returned in the ppAuditSubCategoriesArray array.</param>
    /// <returns>A System.Boolean value that indicates whether the function completed successfully.</returns>
    /// <remarks>https://msdn.microsoft.com/en-us/library/windows/desktop/aa375648(v=vs.85).aspx</remarks>
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AuditEnumerateSubCategories(ref Guid pAuditCategoryGuid, bool bRetrieveAllSubCategories, out IntPtr ppAuditSubCategoriesArray, out uint pCountReturned);


    /// <summarThe AuditLookupSubCategoryName function retrieves the display name of the specified audit-policy subcategory. y>
    /// The AuditLookupSubCategoryName function retrieves the display name of the specified audit-policy subcategory.
    /// </summary>
    /// <param name="pAuditSubCategoryGuid">A pointer to a GUID structure that specifies an audit-policy subcategory.</param>
    /// <param name="ppszSubCategoryName">The address of a pointer to a null-terminated string that contains the display name of the audit-policy subcategory specified by the pAuditSubCategoryGuid parameter.</param>
    /// <returns>A System.Boolean value that indicates whether the function completed successfully.</returns>
    /// <remarks>https://msdn.microsoft.com/en-us/library/windows/desktop/aa375693(v=vs.85).aspx</remarks>
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AuditLookupSubCategoryName(ref Guid pAuditSubCategoryGuid, out StringBuilder ppszSubCategoryName);


    /// <summary>
    /// The AuditFree function frees the memory allocated by audit functions for the specified buffer.
    /// </summary>
    /// <param name="buffer">A pointer to the buffer to free.</param>
    /// <remarks>https://msdn.microsoft.com/en-us/library/windows/desktop/aa375654(v=vs.85).aspx</remarks>
    [DllImport("advapi32.dll")]
    public static extern void AuditFree(IntPtr buffer);


    /// <summary>
    /// The AuditQuerySystemPolicy function retrieves system audit policy for one or more audit-policy subcategories.
    /// </summary>
    /// <param name="pSubCategoryGuids">A pointer to an array of GUID values that specify the subcategories for which to query audit policy. </param>
    /// <param name="PolicyCount">The number of elements in each of the pSubCategoryGuids and ppAuditPolicy arrays.</param>
    /// <param name="ppAuditPolicy">A pointer to a single buffer that contains both an array of pointers to AUDIT_POLICY_INFORMATION structures and the structures themselves. </param>
    /// <returns>https://msdn.microsoft.com/en-us/library/windows/desktop/aa375702(v=vs.85).aspx</returns>
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AuditQuerySystemPolicy(Guid pSubCategoryGuids, uint PolicyCount, out IntPtr ppAuditPolicy);



/// <summary>
/// The AUDIT_POLICY_INFORMATION structure specifies a security event type and when to audit that type.
/// </summary>
/// <remarks>https://msdn.microsoft.com/en-us/library/windows/desktop/aa965467(v=vs.85).aspx</remarks>
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct AUDIT_POLICY_INFORMATION
{

    /// <summary>
    /// A GUID structure that specifies an audit subcategory.
    /// </summary>
    public Guid AuditSubCategoryGuid;

    /// <summary>
    /// A set of bit flags that specify the conditions under which the security event type specified by the AuditSubCategoryGuid and AuditCategoryGuid members are audited.
    /// </summary>
    public AUDIT_POLICY_INFORMATION_TYPE AuditingInformation;

    /// <summary>
    /// A GUID structure that specifies an audit-policy category.
    /// </summary>
    public Guid AuditCategoryGuid;

}



/// <summary>
/// Represents the auditing type.
/// </summary>
[Flags]
public enum AUDIT_POLICY_INFORMATION_TYPE
{

    /// <summary>
    /// Do not audit the specified event type.
    /// </summary>
    None = 0,

    /// <summary>
    /// Audit successful occurrences of the specified event type.
    /// </summary>
    Success = 1,

    /// <summary>
    /// Audit failed attempts to cause the specified event type.
    /// </summary>
    Failure = 2,


}
"@

$Advapi32 = Add-Type -MemberDefinition $AuditDefinitions -Name 'Advapi32' -Namespace 'Win32' -UsingNamespace System.Text -PassThru

function Get-CategoryDisplayName([Guid]$Guid) {
    if ([Win32.Advapi32]::AuditLookupCategoryName([ref]$Guid,[ref]$ppszCategoryName)) {
        return $ppszCategoryName
    }
}



function Get-SubCategoryIdentifiers ([Guid]$categoryGuid) {
    [array]$identifiers = @()
    $guid  = [System.Int64]::MinValue            ### or ### [System.Int64]0
    $count = [System.Int32]::MaxValue            ### or ### [System.Int64]0

    $aux = [Win32.Advapi32]::AuditEnumerateCategories([ref]$guid, [ref]$count)

    $guidArr = @()                               ### array to store GUIDs
    $buffer = [int64]$guid

    $guidPtr = [int64]$guid                      ### pointer to next GUID
    $guidOff = [System.Runtime.InteropServices.Marshal]::SizeOf([type][guid])
    if([Win32.Advapi32]::AuditEnumerateSubCategories([ref]$categoryGuid, $false, [ref]$buffer, [ref]$pCountReturned)) {
        $elemOffs = [int64]$buffer
        for ( $i=0; $i -lt $pCountReturned; $i++ ) {
            
            $elemOffsGuid = [System.Runtime.InteropServices.Marshal]::PtrToStructure( [System.IntPtr]$elemOffs,[type][guid] )


            $guidAux = [System.Runtime.InteropServices.Marshal]::PtrToStructure( [System.IntPtr]$guidPtr,[type][guid] )
            $guidArr += $guidAux           ### update array of GUIDs for future use
            $guidPtr += $guidOff           ### shift pointer to next GUID

            $identifiers += $elemOffsGuid
            $elemOffs += [System.Runtime.InteropServices.Marshal]::SizeOf([type][guid])

        }
    }
    [Win32.Advapi32]::AuditFree($buffer)
    return $identifiers
}


function Get-SubCategoryDisplayName([Guid]$guid) {
    $buffer = [System.Text.StringBuilder]::new()
    if ([Win32.Advapi32]::AuditLookupSubCategoryName([ref]$guid, [ref]$buffer)) {
    $subCategoryDisplayName = $buffer.ToString()
    $buffer = $null
    return $subCategoryDisplayName
    }
}


function Get-SystemPolicy([Guid]$subCategoryGuid) {
    $guid  = [System.Int64]::MinValue
    $buffer = [int64]$guid
    if ([Win32.Advapi32]::AuditQuerySystemPolicy($subCategoryGuid, 1, [ref]$buffer)) {
        $policyInformation = [System.Runtime.InteropServices.Marshal]::PtrToStructure( [System.IntPtr]$buffer,[type][Win32.Advapi32+AUDIT_POLICY_INFORMATION] )
    }

    [Win32.Advapi32]::AuditFree($buffer)
    return $policyInformation
}




$guid  = [System.Int64]::MinValue            ### or ### [System.Int64]0
$count = [System.Int32]::MaxValue            ### or ### [System.Int64]0

$aux = [Win32.Advapi32]::AuditEnumerateCategories([ref]$guid, [ref]$count)
$buffer = [int64]$guid  

$guidArr = @()                               ### array to store GUIDs

$guidPtr = [int64]$guid                      ### pointer to next GUID
$guidOff = [System.Runtime.InteropServices.Marshal]::SizeOf([type][guid])
$ppszCategoryName = [System.Text.StringBuilder]::new()

$int = 0
$pCountReturned = 0

for ( $i=0; $i -lt $count; $i++ ) {
    $guidAux = [System.Runtime.InteropServices.Marshal]::
                      PtrToStructure( [System.IntPtr]$guidPtr,[type][guid] )
    $guidArr += $guidAux           ### update array of GUIDs for future use
    $guidPtr += $guidOff           ### shift pointer to next GUID

    

    ### debugging: try another method of [Win32.Advapi32] Runtime Type 
    #$foo = [Win32.Advapi32]::AuditLookupCategoryName([ref]$guidAux,[ref]$ppszCategoryName)
    ### debugging: show partial results
    #Write-Host $('{0} {1,4} {2,4}' -f $guidAux.Guid, $ppszCategoryName.Capacity, $ppszCategoryName.Length)
}

$policyResultsReadable = @()
foreach ($guidElement in $guidArr) {
    $category = Get-CategoryDisplayName -Guid $guidElement
    $SubCategoryID =  Get-SubCategoryIdentifiers -categoryGuid $guidElement
    foreach ($SubCategory in $SubCategoryID) {
        $policyResults = Get-SystemPolicy -subCategoryGuid $SubCategory
        $policyResultsMember = New-Object -TypeName psobject
        $policyResultsMember | Add-Member -MemberType NoteProperty -Name Category -Value $($AuditCategoryNames[$policyResults.AuditCategoryGuid.Guid])
        $policyResultsMember | Add-Member -MemberType NoteProperty -Name SubCategory -Value $($AuditSubCategoryNames[$policyResults.AuditSubCategoryGuid.Guid])
        $policyResultsMember | Add-Member -MemberType NoteProperty -Name Policy -Value $($policyResults.AuditingInformation)
        $policyResultsReadable += $policyResultsMember
    }
}

$policyResultsReadable


<#
foreach ($guidElement in $guidArr) {
    $category = Get-CategoryDisplayName -Guid $guidElement
    $SubCategoryID =  Get-SubCategoryIdentifiers -categoryGuid $guidElement
    foreach ($SubCategory in $SubCategoryID) {
        $policyResults = Get-SystemPolicy -subCategoryGuid $SubCategory
        $policyResultsMember = New-Object -TypeName psobject
        Write-Host "$guidElement - $SubCategory - " -NoNewline
        Get-SubCategoryDisplayName -guid $policyResults.AuditSubCategoryGuid.Guid
        
    }
}
#>