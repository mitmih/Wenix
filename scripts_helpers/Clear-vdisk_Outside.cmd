@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"



echo SDelete files
echo https://download.sysinternals.com/files/SDelete.zip
echo.
echo Full ToolSet
echo https://download.sysinternals.com/files/SysinternalsSuite.zip



REM host, in PowerShell
    & 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' modifyhd "d:\_vm\7\7.vdi" --compact
