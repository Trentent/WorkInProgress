# the delegate helper is required to create powershell runspaces for the callback's. This allows you to run powershell code in the call back. 
#  https://stackoverflow.com/questions/53788232/system-threading-timer-kills-the-powershell-console/53789011

# casting script block to delegate: 
# https://stackoverflow.com/questions/16281955/using-asynccallback-in-powershell/16974738

# for the callbacks we WriteOutput to a text file to see results. Since it runs in a different runspace it does not echo out to original console
$DelegateHelper = @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Management.Automation.Runspaces;

public class RunspacedDelegateFactory
{
    public static Delegate NewRunspacedDelegate(Delegate _delegate, Runspace runspace)
    {
        Action setRunspace = () => Runspace.DefaultRunspace = runspace;
        return ConcatActionToDelegate(setRunspace, _delegate);
    }

    private static Expression ExpressionInvoke(Delegate _delegate, params Expression[] arguments)
    {
        var invokeMethod = _delegate.GetType().GetMethod("Invoke");
        return Expression.Call(Expression.Constant(_delegate), invokeMethod, arguments);
    }

    public static Delegate ConcatActionToDelegate(Action a, Delegate d)
    {
        var parameters =
            d.GetType().GetMethod("Invoke").GetParameters()
            .Select(p => Expression.Parameter(p.ParameterType, p.Name))
            .ToArray();
        Expression body = Expression.Block(ExpressionInvoke(a), ExpressionInvoke(d, parameters));
        var lambda = Expression.Lambda(d.GetType(), body, parameters);
        var compiled = lambda.Compile();
        return compiled;
    }
}
'@
Add-Type -TypeDefinition $DelegateHelper

#State Object for reading the client data asynchronously
$StateObjectTemplate = @"
using System.Net.Sockets;
using System.Text; 

    public class StateObject {  
    // Client  socket.  
    public Socket workSocket = null;  
    // Size of receive buffer.  
    public const int BufferSize = 1024;  
    // Receive buffer.  
    public byte[] buffer = new byte[BufferSize];  
    // Received data string.  
    public StringBuilder sb = new StringBuilder();
} 
"@
Add-Type -TypeDefinition $StateObjectTemplate

#thread signal
[System.Threading.ManualResetEvent]$Global:AllDone = New-Object System.Threading.ManualResetEvent($false)


$AcceptCallback = [System.AsyncCallback] {
    param([IAsyncResult]$ar)
    Write-Output "AcceptCallback" | Out-File C:\Test.txt -Append
    #Signal the main thread to continue
    $Global:AllDone.Set()

    #Get the socket that handles the client request
    [System.Net.Sockets.Socket]$listener = [System.Net.Sockets.Socket]$ar.AsyncState
    [System.Net.Sockets.Socket]$handler = $listener.EndAccept($ar)

    #create the state object.
    [StateObject]$state = New-Object StateObject
    $state.workSocket = $handler
    $handler.BeginReceive($state.buffer, 0, [StateObject]::BufferSize, 0, $ReadCallBackDelegate , $state)
}
$AcceptCallbackDelegate = [RunspacedDelegateFactory]::NewRunspacedDelegate($AcceptCallback, [Runspace]::DefaultRunspace)


$ReadCallback = [System.AsyncCallback]{
    param([IAsyncResult]$ar)

    Write-Output "ReadCallback" | Out-File "C:\Test.txt" -Append
    [string]$content = [string]::Empty

    # Retrieve the state object and the handler socket
    # from the asynchronous state object
    [StateObject]$state = [StateObject]$ar.AsyncState
    [System.Net.Sockets.Socket]$handler = $state.workSocket

    # Read data from the client socket
    [int]$bytesRead = $handler.EndReceive($ar)

    if ($bytesRead -gt 0) {
        # there might be more data, so store the data received so far.
        $state.sb.Append([System.Text.Encoding]::ASCII.GetString($state.buffer, 0, $bytesRead))

        $content = $state.sb.ToString()
        if ($content.IndexOf("<EOF>") -gt -1) {
            # All the data has been read from the client. Display it on the console.
            Write-Output "Read $($content.Length) bytes from socket. `n Data: $($content)" | Out-File "C:\Test.txt" -Append
            
            #echo the data back to the client. the Send functin has been embedded here as it's not passed from the main script to this delegates runspace
            # Convert the string data to byte data using ASCII encoding.
            [byte[]]$byteData = [System.Text.Encoding]::ASCII.GetBytes($content)

            # Begin sending the data to the remote device.
            $handler.BeginSend($byteData, 0, $byteData.Length, 0, $SendCallBackDelegate, $handler)
            Write-Output "Sent Data" | Out-File "C:\Test.txt" -Append
        } else {
            # Not all data received. Get More.
            $handler.BeginReceive($state.buffer, 0, [StateObject]::BufferSize, 0, $ReadCallBackDelegate, $state)
        }
    }
}
$ReadCallBackDelegate = [RunspacedDelegateFactory]::NewRunspacedDelegate($ReadCallback, [Runspace]::DefaultRunspace)

$SendCallBack = [System.AsyncCallback]{
    param ([IAsyncResult]$ar)
    Write-Output "SendCallback" | Out-File C:\Test.txt -Append
    try {
        # Retrieve the socket from the state object
        [System.Net.Sockets.Socket]$handler = [System.Net.Sockets.Socket]$ar.AsyncState

        # Complete sending the data to the remote device
        [int]$bytesSent = $handler.EndSend($ar)
        Write-Output "Sent $bytesSent bytes to client." | Out-File C:\Test.txt -Append

        $handler.Shutdown([System.Net.Sockets.SocketShutdown]::Both)
        $handler.Close()
    } catch {
        Write-Output "SendCallback-Exception : $($_.Exception.ToString())" | Out-File C:\Test.txt -Append
    }
}
$SendCallBackDelegate = [RunspacedDelegateFactory]::NewRunspacedDelegate($SendCallBack, [Runspace]::DefaultRunspace)



#instead of function "StartListening" I just made this the main script.
#async Listener  ## taken from here: https://docs.microsoft.com/en-us/dotnet/framework/network-programming/asynchronous-server-socket-example
<#
Establish the local endpoint for the socket.
The DNS name of the computer
running the listener is "host.contoso.com"
#>
[System.Net.IPHostEntry]$IPHostInfo = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName())
[ipaddress]$ipAddress = $IPHostInfo.AddressList[0] #this seems to be coming up as the IPv6 address. Not sure what would happen if IPv6 is disabled.
[IPEndpoint]$localEndPoint = [IPEndpoint]::new($ipAddress,11004)  #note the port number to telnet to is the integer value in IPEndpoint::new

#Create a TCPIP Socket
[System.Net.Sockets.Socket]$listener = [System.Net.Sockets.Socket]::new($ipAddress.AddressFamily, [System.Net.Sockets.SocketType]::Stream,[System.Net.Sockets.ProtocolType]::Tcp)

#bind the socket to the local endpoint and listen for incoming connections
try {
    $listener.Bind($localEndPoint)
    $listener.listen(100)

    while ($true) {
        [void]$Global:AllDone.Reset()
        [System.Console]::WriteLine("Waiting for a connection...")
        [void]$listener.BeginAccept($AcceptCallbackDelegate, $listener)
        #Wait until a connection is made before continuing
        [void]$Global:AllDone.WaitOne()
    }
} catch {

    [System.Console]::WriteLine($_.Exception.ToString())
}

[System.Console]::WriteLine("\n Press ENTER to continue...")
Read-Host
