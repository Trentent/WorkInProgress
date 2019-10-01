﻿<#
    .SYNOPSIS
        Creates an annotation for Citrix Session Recording 

    .DESCRIPTION
        Creates an annotation for Citrix Session Recording.  The annotation contains information relevant to the performance details described.

    .PARAMETER SessionID

    .PARAMETER SessionState
    
    .PARAMETER IdleTime

    .EXAMPLE
        . .\AnnotateCitrixSession.ps1 -SessionId 4 -SessionState Disconnected -IdleTime 0
        Record an event for session Id 4 that the Session State is now Disconnected 

    .EXAMPLE
        . .\AnnotateCitrixSession.ps1 -SessionId 4 -SessionState Active -IdleTime 15
        Record an event for session Id 4 that the Session State is now Idle 

    .CONTEXT
        Session

    .MODIFICATION_HISTORY
        Created TTYE : 2019-08-06


    AUTHOR: Trentent Tye
#>



[CmdLetBinding()]
Param (
    [Parameter(Mandatory=$true,HelpMessage='Session ID')][ValidateNotNullOrEmpty()]                                                                [int]$SessionID,
    [Parameter(Mandatory=$true,HelpMessage='Session State, either Active or Disconnected')][ValidateNotNullOrEmpty()]                              [string]$SessionState,
    [Parameter(Mandatory=$true,HelpMessage='Idle Time (mins)')][ValidateNotNullOrEmpty()]                                                          [int]$IdleTime
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
if ($IdleTime -ge 1) {
    if ($SessionState -eq "Active") {
        $newLogger.LogData($SessionId, "ControlUp","AA","Trigger","Session State Changed to: Idle - $($IdleTime) mins",[byte]0,$true)
        Write-Output "Session State Changed to: Idle - $($IdleTime) mins for session $SessionID"  #Write-Output for ControlUp Auditing to capture
        break
    }
    else {
        $newLogger.LogData($SessionId, "ControlUp","AA","Trigger","Session State $($SessionState): Idle - $($IdleTime) mins",[byte]0,$true)
        Write-Output "Session State $($SessionState): Idle - $($IdleTime) mins for session $SessionID"  #Write-Output for ControlUp Auditing to capture
        break
    }
    $newLogger.LogData($SessionId, "ControlUp","AA","Trigger","Session State Changed to: $($SessionState)",[byte]0,$true)
     Write-Output "Session State Changed to: $($SessionState) for session $SessionID"  #Write-Output for ControlUp Auditing to capture
} else {
    $newLogger.LogData($SessionId, "ControlUp","AA","Trigger","Session State Changed to: $($SessionState)",[byte]0,$true)
    Write-Output "Session State Changed to: $($SessionState) for session $SessionID"  #Write-Output for ControlUp Auditing to capture
}