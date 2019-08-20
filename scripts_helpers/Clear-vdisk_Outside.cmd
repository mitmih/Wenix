@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"



REM host, in PowerShell
    & 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' modifyhd "d:\_vm\7\7.vdi" --compact
