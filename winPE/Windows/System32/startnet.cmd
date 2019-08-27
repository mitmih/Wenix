REM wpeinit


wpeutil InitializeNetwork /NoWait
wpeutil DisableFirewall
start "VNC" %SystemDrive%\UltraVNC\winvnc.exe
