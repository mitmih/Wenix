@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo.

REM выбор уровня сборки iso-файла
REM     скрипт реализует три подхода (уровня) при сборке итогового iso-файла, разной степени длительности:
REM         1 - самый долгий - сборка winPE с самого начала
REM         нужные пакеты интегрируются в чистый boot.wim (достаточно длительная процедура)
REM         полученный образ дублируется в файл-полуфабрикат semi1.wim
REM
REM         2 - самый средний - используется собранный с нужными пакетами semi1.wim
REM         в него добавляется ПО и актуальная версия Wenix`а
REM         полученный образ дублируется в semi2.wim
REM
REM         3 - самый быстрый - пересборка iso-файла, используется последний доступный semi2.wim
REM         новая версия Wenix`а копируется в "iso-root:\.IT\PE\Wenix"
    
    if /i "%1" == "1" ( goto GOTO_level_1 )
    
    if /i "%1" == "2" ( goto GOTO_level_2 )
    
    if /i "%1" == "3" ( goto GOTO_level_3 )

    if /i  %1  GTR 3  ( goto GOTO_GTR)
    
    if /i  %1  LSS 1  ( goto GOTO_LSS)
    

REM сборка новой конфигурации winPE и сохранение полученного boot.wim в качестве полуфабриката clear.wim
    :GOTO_level_1
    
    echo GOTO_level_1
    
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
    
    
        REM полуфабрикаты 1 и 2
        
            set "semi1=%~dp0semi1.wim"
            
            set "semi2=%~dp0semi2.wim"
    
    
    REM очистка на случай если остались какие-то ранее смонтированные образы
        
        dism /Cleanup-Wim
        
        if errorlevel 1 ( pause && exit )
        
        
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
    
    
    REM монтаж, увеличение размера свободного места на ram-диске до 512 MB для манипулирования файлами
        
        dism /Mount-Wim /WimFile:%wd%\%arc%\media\sources\boot.wim /index:1 /MountDir:%mnt%
        
        dism /image:%mnt% /Get-ScratchSpace
        
        dism /image:%mnt% /Set-ScratchSpace:512
    
    
    REM отключение сообщения о нажатии клавиши для загрузки с CD/DVD
        
        if exist "%wd%\amd64\media\Boot\bootfix.bin" ( rename %wd%\amd64\media\Boot\bootfix.bin bootfix.bin0 )
    
    
    REM установка доп. пакетов и их локализаций, ПОРЯДОК ИМЕЕТ ЗНАЧЕНИЕ !!!
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
        
        dism /unmount-wim /mountdir:%mnt% /commit
    
    
    REM сжатие и подсчёт MD5
        
        if errorlevel 0 (
            
            ren "%wd%\%arc%\media\sources\boot.wim" boot0.wim
            
            dism /Export-image /SourceImageFile:"%wd%\%arc%\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\%arc%\media\sources\boot.wim" /compress:max
            
            start "%~n0" powershell -command "& {%~dp0Make-Wim_md5.ps1 -path '%wd%\%arc%\media\sources\boot.wim'}"
            
            del "%wd%\%arc%\media\sources\boot0.wim" /F /Q
            
        ) else ( pause )
        
        
    REM полуфабрикат1
        
        if exist "%semi1%"     ( del "%semi1%"     /F /Q )
        
        if exist "%semi1%.md5" ( del "%semi1%.md5" /F /Q )
        
        mklink /h "%semi1%" "%wd%\%arc%\media\sources\boot.wim"
        
        start "%~n0" powershell -command "& {%~dp0Make-Wim_md5.ps1 -path '%semi1%'}"


REM добавление ПО, Wenix
    :GOTO_level_2
    echo 2


REM сборка iso-файла winPE
    :GOTO_level_3
    echo 3


REM завершение рабоыт скрипта
    timeout 7 && exit

:GOTO_LSS
    echo GOTO_LSS
    timeout 7 && exit

:GOTO_GTR
    echo GOTO_GTR
    timeout 7 && exit