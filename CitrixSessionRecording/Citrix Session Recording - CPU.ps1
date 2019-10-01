<#
    .SYNOPSIS
        Creates an annotation for Citrix Session Recording 

    .DESCRIPTION
        Creates an annotation for Citrix Session Recording.  The annotation contains information relevant to the performance details described.

    .PARAMETER SessionID

    .PARAMETER CPU

    .EXAMPLE
        . .\AnnotateCitrixSession.ps1 -SessionId 4 -CPU 75
        Record an event for session Id 4 that the CPU is at 75%

    .CONTEXT
        Session

    .MODIFICATION_HISTORY
        Created TTYE : 2019-08-06


    AUTHOR: Trentent Tye
#>



[CmdLetBinding()]
Param (
    [Parameter(Mandatory=$true,HelpMessage='Session ID')][ValidateNotNullOrEmpty()]                                                                [int]$SessionID,
    [Parameter(Mandatory=$true,HelpMessage='CPU')][ValidateNotNullOrEmpty()]                                                    [int]$CPU
)


Set-StrictMode -Version Latest
###$ErrorActionPreference = "Stop"

If (-not(Test-Path "$env:ProgramFiles\Citrix\SessionRecording\Agent\Bin\Interop.UserApi.dll")) {
    Write-Error "Unable to find `"$env:ProgramFiles\Citrix\SessionRecording\Agent\Bin\Interop.UserApi.dll`""
    Exit 1
}

$assembly = [Reflection.Assembly]::LoadFile("C:\Program Files\Citrix\SessionRecording\Agent\Bin\Interop.UserApi.dll")

$SessionRec = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

using Interop.UserApi;	// Interop derived from IUserApi.idl

namespace UserApiSample
{
    /// <summary>
    /// Class for logging Session Recording Event Data
    /// </summary>
    public class EventDataLogger
    {
        /// <summary>
        /// ProgID for Session Recording Event API
        /// </summary>
        private const string EventApiProgID = "Citrix.SmartAuditor.Agent.UserApi";

        /// <summary>
        /// COM interface for calling the Session Recording Event API
        /// </summary>
        private IUserApi m_EventApi = null;

        /// <summary>
        /// Log event data for specified session
        /// </summary>
        /// <param name="sessionId">session ID</param>
        /// <param name="dataType1">part 1 of event data type</param>
        /// <param name="dataType2">part 2 of event data type</param>
        /// <param name="dataType3">part 3 of event data type</param>
        /// <param name="textData">event text data</param>
        /// <param name="binaryData">event binary data</param>
        /// <param name="searchable">indicate whether text data is searchable</param> 
        public void LogData(
            int sessionId, string dataType1, string dataType2, string dataType3, string textData, byte[]
                binaryData, bool searchable)
        {
            try
            {
                if (null == m_EventApi)
                {
                    // create instance of Event API COM object
                    Type type = Type.GetTypeFromProgID(EventApiProgID, true);
                    if (null != type)
                    {
                        object obj = Activator.CreateInstance(type);
                        m_EventApi = (IUserApi)obj;
                    }
                }
                if (null != m_EventApi)
                {
                    m_EventApi.LogData(
                        sessionId,
                        dataType1,
                        dataType2,
                        dataType3,
                        textData,
                        ref binaryData,
                        Convert.ToByte(searchable)
                    );
                }
                else
                {
                    Debug.WriteLine("Uninitialized Event API object");
                    throw new InvalidComObjectException("Uninitialized Event API object");
                }
            }
            catch ( System.Exception ex)
            {
                Debug.WriteLine(ex.Message);
                throw ex;
            }
        }
    }
}
"@

$SessionRecC = Add-Type -ReferencedAssemblies $assembly -TypeDefinition $SessionRec

$newLogger = [UserApiSample.EventDataLogger]::new()

#Annotate events
$newLogger.LogData($SessionId, "ControlUp","AA","Trigger","High Stress CPU: $($CPU)%",[byte]0,$true)
Write-Output -Message "High Stress CPU: $($CPU)%"  #Write-Output for ControlUp Auditing to capture