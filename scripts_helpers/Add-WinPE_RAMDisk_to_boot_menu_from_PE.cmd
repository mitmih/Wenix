@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"

setlocal ENABLEDELAYEDEXPANSION

echo WinPE: Install on a hard drive (Flat boot or Non-RAM)

echo https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-install-on-a-hard-drive--flat-boot-or-non-ram

echo.



REM Set high-performance power scheme to speed deployment
    
    call powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c



robocopy d:\.IT\PE p:\.IT\PE /MIR


REM + menu entry point to boot winPE from RAMDisk

REM - menu entry point to boot winPE from hard drive
    
    if exist P:\.IT\PE\boot.sdi (

        echo ready for ramdisk
        
        REM make ramdisk object
            
            bcdedit /create {ramdiskoptions} /d "Windows PE, RAM DISK BOOT"
            
            bcdedit /set    {ramdiskoptions} ramdisksdidevice partition=P:
            
            bcdedit /set    {ramdiskoptions} ramdisksdipath \.IT\PE\boot.sdi
            
            
        REM make a new GUID for the boot loader entry
            
            for /f "usebackq tokens=1-5 delims={}" %%a in (`bcdedit /create /d "Windows PE, RAM DISK LOADER" /application osloader`) do (set "GUID={%%b}")
            
            echo !GUID!
            
            
        REM make OS loader object
            
            bcdedit /set !GUID!   device ramdisk=[P:]\.IT\PE\boot.wim,{ramdiskoptions}
            
            bcdedit /set !GUID! osdevice ramdisk=[P:]\.IT\PE\boot.wim,{ramdiskoptions}
            
            bcdedit /set !GUID! path \Windows\System32\Boot\winload.exe
            
            bcdedit /set !GUID! systemroot \Windows
            
            bcdedit /set !GUID! winpe yes
            
            bcdedit /set !GUID! detecthal yes
            
            
        REM REM add the new boot entry to the boot menu
            
            bcdedit /displayorder !GUID! /addfirst
            
            
        REM remove default (boot PE from HD), leave only RAMDisk`s entry
            
            BCDedit /delete {default} /cleanup
    )

robocopy d:\.IT\10 p:\.IT\10 /MIR