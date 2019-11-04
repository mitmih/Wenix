@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo.


REM скрипт добавляет загрузку winPE c RAM-диска в конфиг bootmgr`а (BCD)

REM запускать с той же папки, где лежит winPE boot.wim


echo Настройка PXE-сервера для загрузки WindowsPE

echo https://docs.microsoft.com/ru-ru/windows/deployment/configure-a-pxe-server-to-load-windows-pe

echo.


echo How to boot a Vista system from a locally stored WIM file

echo https://blog.nextxpert.com/2007/05/09/how-to-boot-a-vista-system-from-a-locally-stored-wim-file/

echo.


echo Create a Windows Vista/WinPE dual boot

echo https://blogs.technet.microsoft.com/guillaumed/2008/03/15/create-a-windows-vistawinpe-dual-boot/

echo.



REM make ramdisk object
    
    REM "Windows PreInstallation Environment, RAM DISK BOOT"
    
    bcdedit /create {ramdiskoptions} /d "Windows PE RAM Disk"
    
    bcdedit /set    {ramdiskoptions} ramdisksdidevice partition=%~d0
    
    bcdedit /set    {ramdiskoptions} ramdisksdipath %~p0boot.sdi


REM make a new GUID for the boot loader entry
    
    for /f "usebackq tokens=1-5 delims={}" %%a in (`bcdedit /create /d "Windows PE RAM Disk" /application osloader`) do (set GUID={%%b})
    
    REM Запись {e1679014-bc5a-11e9-89cf-a91b7c7227b0} успешно создана.
    REM                     or
    REM The entry {e1679018-bc5a-11e9-89cf-a91b7c7227b0} was successfully created.
    
    echo %GUID%


REM make OS loader object
    
    bcdedit /set %GUID%   device ramdisk=[%~d0]%~p0boot.wim,{ramdiskoptions}
    
    bcdedit /set %GUID% osdevice ramdisk=[%~d0]%~p0boot.wim,{ramdiskoptions}
    
    bcdedit /set %GUID% path \Windows\System32\Boot\winload.exe
    
    bcdedit /set %GUID% systemroot \Windows
    
    bcdedit /set %GUID% winpe yes
    
    bcdedit /set %GUID% detecthal yes


REM add the new boot entry to the boot menu
    
    bcdedit /displayorder %GUID% /addlast
    
    bcdedit /timeout 5


REM if errorlevel 1 (pause && exit)
