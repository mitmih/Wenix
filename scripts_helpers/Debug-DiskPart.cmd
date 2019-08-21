@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo. && cd /D "%~dp0"

setlocal ENABLEDELAYEDEXPANSION

echo WinPE: Install on a hard drive (Flat boot or Non-RAM)

echo https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-install-on-a-hard-drive--flat-boot-or-non-ram

echo.



REM set enviroment variables
    
    REM файл действий diskpart
    
    set "DiskPartCmd=%temp%\diskpart.cmd"
    
    set "DiskPartLog=%temp%\diskpart.log"



REM Set high-performance power scheme to speed deployment
    
    call powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c



REM if files doesn`t exists - nothing to do
    
    REM REM if NOT ERRORLEVEL 0 (
    REM if NOT exist "Z:\boot.wim" (
        
    REM     pause  && exit
        
    REM ) else (
        
    REM     set "winPEWIM=P:\.IT\PE\boot.wim"
        
    REM )



REM REM prepare script for diskpart in temp dir
    type nul > %DiskPartCmd%
    
    type nul > %DiskPartLog%
    
    echo select disk 0 >> %DiskPartCmd%
    
    echo clean >> %DiskPartCmd%
    
    echo convert mbr >> %DiskPartCmd%
    
    echo.>> %DiskPartCmd%
    
    
    REM 1й partition - active, boot
    
    echo create partition primary size=2048>> %DiskPartCmd%
    
    echo format quick fs=ntfs label="1_BOOT">> %DiskPartCmd%
    
    echo assign letter="B" noerr>> %DiskPartCmd%
    
    echo active>> %DiskPartCmd%
    
    echo.>> %DiskPartCmd%
    
    
    REM 2й partition - for applying WinPE boot.wim
    
    echo create partition primary size=79872>> %DiskPartCmd%
    
    echo format quick fs=ntfs label="2_OS">> %DiskPartCmd%
    
    echo assign letter="O" noerr>> %DiskPartCmd%
    
    echo.>> %DiskPartCmd%
    
    
    REM 3й partition - for applying OS install.wim
    
    echo create partition primary>> %DiskPartCmd%
    
    echo format quick fs=ntfs label="3_PE">> %DiskPartCmd%
    
    echo assign letter="P" noerr>> %DiskPartCmd%



REM WEAK SPOT BEGIN ############################################################

REM re-partition hard drive, applying winPE image to 2nd partition
    
    diskpart /s %DiskPartCmd% > "%DiskPartLog%"
    
    xcopy "%~dp0.IT\PE"  "P:\.IT\PE\" /y
    
    set "winPEWIM=P:\.IT\PE\boot.wim"
    
    if exist %winPEWIM% (
        
        REM apply Windows PE wim-image to 2nd partition
        
        dism /Apply-Image /ImageFile:%winPEWIM% /Index:1 /ApplyDir:P:\
    )

REM WEAK SPOT END   ############################################################



REM if boot.wim applying is OK, config the BCD partition
    
    if ERRORLEVEL 0 (
        
        REM прописывание конфигурации загрузки
        
        BCDboot P:\Windows /s B: /f ALL
        
        
        REM rename entry for consistency with ramdisk entry
        
        BCDedit /set {default} description "Windows PE, HARD DRIVE BOOT"
    )



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

REM 
    xcopy "%~dp0.IT\10"  "P:\.IT\10\" /y