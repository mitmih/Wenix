REM wpeinit

wpeutil InitializeNetwork
wpeutil DisableFirewall

start "VNC" %SystemDrive%\UltraVNC\winvnc.exe
