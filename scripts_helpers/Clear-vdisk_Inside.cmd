@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"



echo SDelete files
echo https://download.sysinternals.com/files/SDelete.zip
echo.
echo Full ToolSet
echo https://download.sysinternals.com/files/SysinternalsSuite.zip



REM guest (VM)
    if exist "c:\" (start "disk c:" "%~dp0sdelete64.exe" -c -s -z c: /accepteula)
    if exist "d:\" (start "disk d:" "%~dp0sdelete64.exe" -c -s -z d: /accepteula)
    if exist "e:\" (start "disk e:" "%~dp0sdelete64.exe" -c -s -z e: /accepteula)
    if exist "f:\" (start "disk f:" "%~dp0sdelete64.exe" -c -s -z f: /accepteula)



REM host
    REM & 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' modifyhd "d:\_vm\7\7.vdi" --compact
