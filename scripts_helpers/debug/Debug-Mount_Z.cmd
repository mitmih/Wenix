@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"

REM setlocal ENABLEDELAYEDEXPANSION



REM set enviroment variables
    
    REM ipconfig
    
    set "ip_share=192.168.7.13"
    REM set "ip_winPE=192.168.37.37"
    
    
    REM network
    
    set "net_share=\\%ip_share%\mdt"
    
    set "net__user=mdt"
    
    set "net___pwd=Mm098098"



REM REM make static ip address
    
    REM netsh interface ip set address name="Ethernet" source=static addr=%ip_winPE% mask=255.255.255.0
    
    REM ipconfig /release
    
    REM ipconfig /all
    
    REM ping -n 12 %ip_share%



REM connect to network share (connect first, if not connected - exit)
    
    if ERRORLEVEL 0 (
        
        net use z: %net_share% %net___pwd% /user:%net__user%
        
        dir z:\
    )