# C# definition from here: https://www.codeproject.com/Articles/18179/Using-the-Local-Security-Authority-to-Enumerate-Us

$LSADefinitions = @"

[DllImport("secur32.dll", SetLastError = false)]
public static extern uint LsaFreeReturnBuffer(IntPtr buffer);

[DllImport("Secur32.dll", SetLastError = false)]
public static extern uint LsaEnumerateLogonSessions
        (out UInt64 LogonSessionCount, out IntPtr LogonSessionList);

[DllImport("Secur32.dll", SetLastError = false)]
public static extern uint LsaGetLogonSessionData(IntPtr luid, 
    out IntPtr ppLogonSessionData);

[StructLayout(LayoutKind.Sequential)]
public struct LSA_UNICODE_STRING
{
    public UInt16 Length;
    public UInt16 MaximumLength;
    public IntPtr buffer;
}

[StructLayout(LayoutKind.Sequential)]
public struct LUID
{
    public UInt32 LowPart;
    public UInt32 HighPart;
}

[StructLayout(LayoutKind.Sequential)]
public struct SECURITY_LOGON_SESSION_DATA
{
    public UInt32 Size;
    public LUID LoginID;
    public LSA_UNICODE_STRING Username;
    public LSA_UNICODE_STRING LoginDomain;
    public LSA_UNICODE_STRING AuthenticationPackage;
    public UInt32 LogonType;
    public UInt32 Session;
    public IntPtr PSiD;
    public UInt64 LoginTime;
    public LSA_UNICODE_STRING LogonServer;
    public LSA_UNICODE_STRING DnsDomainName;
    public LSA_UNICODE_STRING Upn;
}

public enum SECURITY_LOGON_TYPE : uint
{
    Interactive = 2,        //The security principal is logging on 
                            //interactively.
    Network,                //The security principal is logging using a 
                            //network.
    Batch,                  //The logon is for a batch process.
    Service,                //The logon is for a service account.
    Proxy,                  //Not supported.
    Unlock,                 //The logon is an attempt to unlock a workstation.
    NetworkCleartext,       //The logon is a network logon with cleartext 
                            //credentials.
    NewCredentials,         //Allows the caller to clone its current token and
                            //specify new credentials for outbound connections.
    RemoteInteractive,      //A terminal server session that is both remote 
                            //and interactive.
    CachedInteractive,      //Attempt to use the cached credentials without 
                            //going out across the network.
    CachedRemoteInteractive,// Same as RemoteInteractive, except used 
                            // internally for auditing purposes.
    CachedUnlock            // The logon is an attempt to unlock a workstation.
}

"@

$Secure32 = Add-Type -MemberDefinition $LSADefinitions -Name 'Secure32' -Namespace 'Win32' -UsingNamespace System.Text -PassThru

$count = [UInt64]0
$luidPtr = [IntPtr]::Zero


[Win32.Secure32]::LsaEnumerateLogonSessions([ref]$count, [ref]$luidPtr) | Out-Null

[IntPtr] $iter = $luidPtr
$sessions = @()

for ([uint64]$i = 0; $i -lt $count; $i++) {
    $sessionData = [IntPtr]::Zero
    [Win32.Secure32]::LsaGetLogonSessionData($iter, [ref]$sessionData) | Out-Null
    $data = [System.Runtime.InteropServices.Marshal]::PtrToStructure($sessionData, [type][Win32.Secure32+SECURITY_LOGON_SESSION_DATA])

    #if we have a valid logon
    if ($data.PSiD -ne [IntPtr]::Zero) {
        #get the security identifier for further use
        $sid = [System.Security.Principal.SecurityIdentifier]::new($Data.PSiD)

        #extract some useful information from the session data struct
        $username = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($data.Username.buffer) #get the account name
        $domain = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($data.LoginDomain.buffer) #get the domain name
        $authPackage = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($data.AuthenticationPackage.buffer) #get the authentication package
        $session = $data.Session #get the session number
        $logonServer = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($data.LogonServer.buffer) #get the logon server
        $DnsDomainName = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($data.DnsDomainName.buffer) #get the DNS Domain Name
        $upn = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($data.upn.buffer) #get the User Principal Name

        try { 
            $secType = [Win32.Secure32+SECURITY_LOGON_TYPE]$data.LogonType
        } catch {
            $secType = "Unknown"
        }
        $origin = New-Object -Type DateTime -ArgumentList 1601, 1, 1, 0, 0, 0, 0  #win32 systemdate  #get the datetime the session was logged in
        $loginTime = $origin.AddTicks([int64]$data.LoginTime)  #GMT Time
        $loginTime = $loginTime.ToLocalTime() #convert to localTime

        #return data as an object
        $return = New-Object PSObject
        $return | Add-Member -MemberType NoteProperty -Name Sid -Value $sid
        $return | Add-Member -MemberType NoteProperty -Name Username -Value $username
        $return | Add-Member -MemberType NoteProperty -Name Domain -Value $domain
        $return | Add-Member -MemberType NoteProperty -Name Session -Value $session
        $return | Add-Member -MemberType NoteProperty -Name LogonServer -Value $logonServer
        $return | Add-Member -MemberType NoteProperty -Name DnsDomainName -Value $DnsDomainName
        $return | Add-Member -MemberType NoteProperty -Name UPN -Value $upn
        $return | Add-Member -MemberType NoteProperty -Name AuthPackage -Value $authPackage
        $return | Add-Member -MemberType NoteProperty -Name SecurityType -Value $secType
        $return | Add-Member -MemberType NoteProperty -Name LoginTime -Value $LoginTime
        $sessions += $return
    }
    $iter = $iter.ToInt64() + [System.Runtime.InteropServices.Marshal]::SizeOf([type][Win32.Secure32+LUID])  #move to next pointer
    [Win32.Secure32]::LsaFreeReturnBuffer($sessionData) | Out-Null
}
[Win32.Secure32]::LsaFreeReturnBuffer($luidPtr) | Out-Null


$sessions | ft