REM wpeinit


wpeutil InitializeNetwork
REM /NoWait

wpeutil DisableFirewall

start "VNC" %SystemDrive%\UltraVNC\winvnc.exe
