@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo.

REM SETLOCAL ENABLEEXTENSIONS

REM cd "%~dp0"


REM чтобы начать "с чистого листа", нужно запустить скрипт с параметром clear
REM     Make-Wim.cmd clear



REM установка переменных среды исполнения
    
    REM рабочая папка
    
        set "wd=%~dp0.pe_work_dir"
    
    
    REM архитектура
    
        set "arc=amd64"
    
    
    REM папка монтажа wim-образа
    
        set "mnt=%~dp0.pe_mount_point"
    
    
    REM папки устнановленного Kits
    
        set "adk=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
    
        set "dsm=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\%arc%\DISM"
    
        set "wpe=%adk%\Windows Preinstallation Environment"
    
        set "cab=%wpe%\%arc%"
    
        set "iso=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"



REM очистка на случай если остались какие-то ранее смонтированные образы
    
    dism /Cleanup-Wim
    
    if errorlevel 1 ( pause && exit )
    
    
    if /i "%1"=="clear" (
        
        REM для использования copype.cmd нужно установить переменные среды, которые обычно устанавливает DandISetEnv.bat
        
        set "WinPERoot=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
        
        set "OSCDImgRoot=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\AMD64\Oscdimg"
        
        
        REM очистка
        
        if exist "%wd%\" (rmdir /s /q "%wd%")
        
        if exist "%mnt%\" (
            
            REM удаление папки при ошибочном применения wim-файла
            
            takeown /F "%mnt%\*" /A /R /D Y /SKIPSL >nul 2>&1
            
            icacls "%mnt%" /reset
            
            icacls "%mnt%" /grant:r "%USERNAME%:(OI)(CI)F" /inheritance:e /Q /C /T /L >nul 2>&1
            
            pushd "%mnt%" && ( rd /S /Q "%mnt%" 2>nul & popd )
            
            )
        
        if not exist "%mnt%\" (mkdir "%mnt%")
        
        
        REM копируем winpe
        
        call "%wpe%\copype.cmd" %arc% "%wd%\%arc%"
    )
    
    if errorlevel 1 (pause && exit)



REM монтаж
    
    dism /Mount-Wim /WimFile:%wd%\%arc%\media\sources\boot.wim /index:1 /MountDir:%mnt%



REM отключение сообщения о нажатии клавиши для загрузки с CD/DVD
    
    if exist "%wd%\amd64\media\Boot\bootfix.bin" ( rename %wd%\amd64\media\Boot\bootfix.bin bootfix.bin0 )



REM установка доп. пакетов, порядок важен!
    
    if /i "%1"=="clear" (
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\WinPE-wmi.cab"
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\Winpe_OCS\en-us\WinPE-WMI_en-us.cab"
        
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\WinPE-netfx.cab"
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\Winpe_OCS\en-us\WinPE-NetFx_en-us.cab"
        
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\WinPE-Scripting.cab"
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\Winpe_OCS\en-us\WinPE-Scripting_en-us.cab"
        
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\WinPE-PowerShell.cab"
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab"
        
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\WinPE-DismCmdlets.cab"
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab"
        
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\WinPE-StorageWMI.cab"
        
        dism /image:%mnt% /add-package /packagepath:"%cab%\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab"
    )



REM добавление в корень системного диска WinPE:
    REM  Far, конфиг оболочки, профиль PowerShell, скрипты, etc
    
    echo  "%CD%"
    
    xcopy "%~dp0Windows"    %mnt%\Windows\  /e /y
    
    xcopy "%~dp0..\Wenix"    %mnt%\Windows\System32\config\systemprofile\Documents\Modules\  /e /y
    
    xcopy "%~dp0Far"        %mnt%\Far\      /e /y
    
    xcopy "%~dp0UltraVNC"   %mnt%\UltraVNC\ /e /y
    
    xcopy "%~dp0..\scripts_helpers\debug\Debug-Mount_Z.cmd"  %mnt%\ /y



REM to be or not to be
    
    set /p action="1 - commit, 0 = discard: "
    
    if /i %action% EQU 1 (
        
        dism /unmount-wim /mountdir:%mnt% /commit
    
    ) else (
        
        dism /unmount-wim /mountdir:%mnt% /discard
    
    )



REM compress and calculate MD5
    if errorlevel 0 (
        
        ren "%wd%\amd64\media\sources\boot.wim" boot0.wim
        
        dism /Export-image /SourceImageFile:"%wd%\amd64\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\amd64\media\sources\boot.wim" /compress:max
        
        powershell -command "& {%~dp0Make-Wim_md5.ps1}"
        
        del "%wd%\amd64\media\sources\boot0.wim" /F /Q
        
        ) else ( pause )



REM make iso-file
    if errorlevel 0 (
        
        "%iso%" -m -o -u2 -l"WinPE x64 LTI" -b"%wd%\amd64\fwfiles\etfsboot.com" %wd%\%arc%\media "%~dp0Win10PE_x64_LTI_1_SINGLE.iso"

    ) else ( pause )




REM "МАТРЁШКА"

REM     для скорейшего прохождения критического этапа, когда ЖД перезамечен, а загрузчика ещё нет, WinPE должна снова организовать собственную загрузку через RAM-диск, для этого на перезамеченный ЖД средствами модуля Wenix будут скопированы

REM         загрузчик   X:\Windows\System32\Boot\*

REM         файлы PE    X:\.IT\PE\*
    
    dism /Mount-Wim /WimFile:%wd%\%arc%\media\sources\boot.wim /index:1 /MountDir:%mnt%
    
    xcopy "%wd%\%arc%\media\sources\boot.wim" "%mnt%\.IT\PE\" /y
    xcopy "%wd%\%arc%\media\Boot\boot.sdi"    "%mnt%\.IT\PE\" /y
    xcopy "%~dp0..\scripts_helpers\Add-WinPE_RAMDisk_to_boot_menu_from_WINDOWS.cmd"  "%mnt%\.IT\PE\" /y
    
    
    if /i %action% EQU 1 (
        
        dism /unmount-wim /mountdir:%mnt% /commit
    
    ) else (
        
        dism /unmount-wim /mountdir:%mnt% /discard
    
    )
    
    
REM compress and calculate MD5
    if errorlevel 0 (
        
        ren "%wd%\amd64\media\sources\boot.wim" boot0.wim
        
        dism /Export-image /SourceImageFile:"%wd%\amd64\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\amd64\media\sources\boot.wim" /compress:max
        
        powershell -command "& {%~dp0Make-Wim_md5.ps1}"
        
        del "%wd%\amd64\media\sources\boot0.wim" /F /Q
        
        ) else ( pause )
    
    
REM make 2nd iso
    if errorlevel 0 (
        
        "%iso%" -m -o -u2 -l"WinPE x64 LTI" -b"%wd%\amd64\fwfiles\etfsboot.com" %wd%\%arc%\media "%~dp0Win10PE_x64_LTI_2_DOUBLE.iso"

    ) else ( pause )
    
    
    REM 