@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"



echo SDelete files
echo https://download.sysinternals.com/files/SDelete.zip
echo.
echo Full ToolSet
echo https://download.sysinternals.com/files/SysinternalsSuite.zip



REM guest (VM)
    if exist "c:\" (start "disk C:" "%~dp0sdelete64.exe" -c -s -z C: /accepteula)
    if exist "d:\" (start "disk C:" "%~dp0sdelete64.exe" -c -s -z C: /accepteula)
    if exist "e:\" (start "disk C:" "%~dp0sdelete64.exe" -c -s -z C: /accepteula)
    if exist "f:\" (start "disk C:" "%~dp0sdelete64.exe" -c -s -z C: /accepteula)



rem host
rem & 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' modifyhd "C:\!vb\w7x64\w7x64.vdi" --compact
