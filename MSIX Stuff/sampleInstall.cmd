REM pass install.cmd to MSIX Package creator

::Microsoft_SystemCenterVirtualMachineManager_1801_x64

pushd %~dp0
cd /d "System Center Virtual Machine Manager\amd64"
setupvmm.exe /client /i /f VMClient.ini /IACCEPTSCEULA
msiexec.exe /update kb4569534_AdminConsole_amd64.msp
popd

REM Use PSFTooling to fix package here!
pause

exit /b 0
