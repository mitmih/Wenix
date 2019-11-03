@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo.

REM SETLOCAL ENABLEEXTENSIONS

REM cd "%~dp0"


REM чтобы начать "с чистого листа", нужно запустить скрипт с параметром clear
REM     Build-WinPE.cmd clear



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
    
    if /i "%1"=="iso" ( goto GOTO_ISO )
    
    
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
            
            
        REM чтобы ускорить сборку, положим рядом с этим скриптом готовый boot.wim с пакетами и назовём его clear.wim
            
            if exist "%~dp0clear.wim" (
                
                del "%wd%\amd64\media\sources\boot.wim" /F /Q
                
                xcopy "%~dp0clear.wim"  "%wd%\amd64\media\sources\" /y
                
                ren "%wd%\amd64\media\sources\clear.wim" boot.wim
                
            )
    )
    
    if errorlevel 1 (pause && exit)



REM монтаж
    
    dism /Mount-Wim /WimFile:%wd%\%arc%\media\sources\boot.wim /index:1 /MountDir:%mnt%
    
    dism /image:%mnt% /Get-ScratchSpace
    
    dism /image:%mnt% /Set-ScratchSpace:512



REM отключение сообщения о нажатии клавиши для загрузки с CD/DVD
    
    if exist "%wd%\amd64\media\Boot\bootfix.bin" ( rename %wd%\amd64\media\Boot\bootfix.bin bootfix.bin0 )



REM установка доп. пакетов, порядок важен!
    
    if /i "%1"=="clear" (
        
        if exist "%~dp0clear.wim" (
            
            echo NOT NEED TO INSTALL PACKAGES
            
        ) else (
            
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
    )



REM добавление в корень системного диска WinPE: конфиг оболочки, профиль PowerShell, скрипты, etc
    
    xcopy "%~dp0Windows"    "%mnt%\Windows\"  /e /y
    
    xcopy "%~dp0..\Wenix"   "%mnt%\Windows\System32\config\systemprofile\Documents\WindowsPowerShell\Modules\Wenix\"  /e /y
    
    xcopy "%~dp0UltraVNC"   "%mnt%\UltraVNC\" /e /y
    
    xcopy "%~dp0Far"        "%mnt%\Far\"      /e /y
    
    REM xcopy "%~dp0..\scripts_helpers\debug\Debug-Mount_Z.cmd"  "%mnt%\" /y



REM REM to be or not to be
    
REM     set /p action="1 - commit, 0 = discard: "
    
REM     if /i %action% EQU 1 (
        
        dism /unmount-wim /mountdir:%mnt% /commit
    
REM     ) else (
        
REM         dism /unmount-wim /mountdir:%mnt% /discard
        
REM         exit
REM     )



REM compress and calculate MD5
    if errorlevel 0 (
        
        ren "%wd%\amd64\media\sources\boot.wim" boot0.wim
        
        dism /Export-image /SourceImageFile:"%wd%\amd64\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\amd64\media\sources\boot.wim" /compress:max
        
        powershell -command "& {%~dp0Make-Wim_md5.ps1}"
        
        del "%wd%\amd64\media\sources\boot0.wim" /F /Q
        
    ) else ( pause )


:GOTO_ISO

REM echo before ISO making... && pause >nul

REM make iso-file
    
    if errorlevel 0 (
        
        if exist "%wd%\%arc%\media\.IT\PE\" ( rd /s /q "%wd%\%arc%\media\.IT\PE" )
        
        mkdir "%wd%\%arc%\media\.IT\PE"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\boot.wim"                "%wd%\%arc%\media\sources\boot.wim"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\boot.wim.md5"            "%wd%\%arc%\media\sources\boot.wim.md5"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\boot.sdi"                "%wd%\%arc%\media\Boot\boot.sdi"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\Add-2nd_boot_entry.cmd"  "%wd%\..\..\scripts_helpers\Add-WinPE_RAMDisk_to_boot_menu_from_WINDOWS.cmd"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\BootStrap.csv"           "%wd%\..\BootStrap.csv"
        
        mklink /J "%wd%\%arc%\media\.IT\PE\Wenix"                   "%wd%\..\..\Wenix"
        
        
        rd /s /q "%wd%\%arc%\media\ru-ru"
        rd /s /q "%wd%\%arc%\media\boot\ru-ru"
        
        rd /s /q "%wd%\%arc%\media\bg-bg"
        rd /s /q "%wd%\%arc%\media\cs-cz"
        rd /s /q "%wd%\%arc%\media\da-dk"
        rd /s /q "%wd%\%arc%\media\de-de"
        rd /s /q "%wd%\%arc%\media\el-gr"
        rd /s /q "%wd%\%arc%\media\en-gb"
        rd /s /q "%wd%\%arc%\media\es-es"
        rd /s /q "%wd%\%arc%\media\es-mx"
        rd /s /q "%wd%\%arc%\media\et-ee"
        rd /s /q "%wd%\%arc%\media\fi-fi"
        rd /s /q "%wd%\%arc%\media\fr-ca"
        rd /s /q "%wd%\%arc%\media\fr-fr"
        rd /s /q "%wd%\%arc%\media\hr-hr"
        rd /s /q "%wd%\%arc%\media\hu-hu"
        rd /s /q "%wd%\%arc%\media\it-it"
        rd /s /q "%wd%\%arc%\media\ja-jp"
        rd /s /q "%wd%\%arc%\media\ko-kr"
        rd /s /q "%wd%\%arc%\media\lt-lt"
        rd /s /q "%wd%\%arc%\media\lv-lv"
        rd /s /q "%wd%\%arc%\media\nb-no"
        rd /s /q "%wd%\%arc%\media\nl-nl"
        rd /s /q "%wd%\%arc%\media\pl-pl"
        rd /s /q "%wd%\%arc%\media\pt-br"
        rd /s /q "%wd%\%arc%\media\pt-pt"
        rd /s /q "%wd%\%arc%\media\ro-ro"
        rd /s /q "%wd%\%arc%\media\sk-sk"
        rd /s /q "%wd%\%arc%\media\sl-si"
        rd /s /q "%wd%\%arc%\media\sr-latn-rs"
        rd /s /q "%wd%\%arc%\media\sv-se"
        rd /s /q "%wd%\%arc%\media\tr-tr"
        rd /s /q "%wd%\%arc%\media\uk-ua"
        rd /s /q "%wd%\%arc%\media\zh-cn"
        rd /s /q "%wd%\%arc%\media\zh-tw"
        
        rd /s /q "%wd%\%arc%\media\boot\bg-bg"
        rd /s /q "%wd%\%arc%\media\boot\cs-cz"
        rd /s /q "%wd%\%arc%\media\boot\da-dk"
        rd /s /q "%wd%\%arc%\media\boot\de-de"
        rd /s /q "%wd%\%arc%\media\boot\el-gr"
        rd /s /q "%wd%\%arc%\media\boot\en-gb"
        rd /s /q "%wd%\%arc%\media\boot\es-es"
        rd /s /q "%wd%\%arc%\media\boot\es-mx"
        rd /s /q "%wd%\%arc%\media\boot\et-ee"
        rd /s /q "%wd%\%arc%\media\boot\fi-fi"
        rd /s /q "%wd%\%arc%\media\boot\fr-ca"
        rd /s /q "%wd%\%arc%\media\boot\fr-fr"
        rd /s /q "%wd%\%arc%\media\boot\hr-hr"
        rd /s /q "%wd%\%arc%\media\boot\hu-hu"
        rd /s /q "%wd%\%arc%\media\boot\it-it"
        rd /s /q "%wd%\%arc%\media\boot\ja-jp"
        rd /s /q "%wd%\%arc%\media\boot\ko-kr"
        rd /s /q "%wd%\%arc%\media\boot\lt-lt"
        rd /s /q "%wd%\%arc%\media\boot\lv-lv"
        rd /s /q "%wd%\%arc%\media\boot\nb-no"
        rd /s /q "%wd%\%arc%\media\boot\nl-nl"
        rd /s /q "%wd%\%arc%\media\boot\pl-pl"
        rd /s /q "%wd%\%arc%\media\boot\pt-br"
        rd /s /q "%wd%\%arc%\media\boot\pt-pt"
        rd /s /q "%wd%\%arc%\media\boot\ro-ro"
        rd /s /q "%wd%\%arc%\media\boot\sk-sk"
        rd /s /q "%wd%\%arc%\media\boot\sl-si"
        rd /s /q "%wd%\%arc%\media\boot\sr-latn-rs"
        rd /s /q "%wd%\%arc%\media\boot\sv-se"
        rd /s /q "%wd%\%arc%\media\boot\tr-tr"
        rd /s /q "%wd%\%arc%\media\boot\uk-ua"
        rd /s /q "%wd%\%arc%\media\boot\zh-cn"
        rd /s /q "%wd%\%arc%\media\boot\zh-tw"
        
        "%iso%" -m -o -u2 -l"WinPE x64 LTI" -b"%wd%\amd64\fwfiles\etfsboot.com" %wd%\%arc%\media "%~dp0WinPE_10_x64_LTI.iso"
    
    ) else ( pause )




REM "МАТРЁШКА" скорее всего не понадобится, т.к. можно выделить до 512 МБ на ram-диске параметром
REM     dism /image:%mnt% /Set-ScratchSpace:512
REM для копирования boot.wim в X:\.IT\PE\boot.wim ДО переразбивки и обратного копирования на ЖД сразу ПОСЛЕ,
REM чтобы как можно скорее заново прописать ram-диск в загрузочное меню и тем самым пройти опасный этап,
REM когда комп перестаёт грузиться в PE из-за переразметки диска


REM REM "МАТРЁШКА"

REM REM     для скорейшего прохождения критического этапа, когда ЖД перезамечен, а загрузчика ещё нет, WinPE должна снова организовать собственную загрузку через RAM-диск, для этого на перезамеченный ЖД средствами модуля Wenix будут скопированы

REM REM         загрузчик   X:\Windows\System32\Boot\*

REM REM         файлы PE    X:\.IT\PE\*
    
REM     dism /Mount-Wim /WimFile:%wd%\%arc%\media\sources\boot.wim /index:1 /MountDir:%mnt%
    
REM     xcopy "%wd%\%arc%\media\sources\boot*" "%mnt%\.IT\PE\" /y
    
REM     xcopy "%wd%\%arc%\media\Boot\boot.sdi"    "%mnt%\.IT\PE\" /y
    
REM     xcopy "%~dp0..\scripts_helpers\Add-WinPE_RAMDisk_to_boot_menu_from_WINDOWS.cmd"  "%mnt%\.IT\PE\" /y
    
REM     dism /unmount-wim /mountdir:%mnt% /commit



REM REM compress and calculate MD5
REM     if errorlevel 0 (
        
REM         ren "%wd%\amd64\media\sources\boot.wim" boot0.wim
        
REM         dism /Export-image /SourceImageFile:"%wd%\amd64\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\amd64\media\sources\boot.wim" /compress:max
        
REM         powershell -command "& {%~dp0Make-Wim_md5.ps1}"
        
REM         del "%wd%\amd64\media\sources\boot0.wim" /F /Q
        
REM         ) else ( pause )


REM make 2nd iso
    if errorlevel 0 (
        
        REM REM 10
        
        REM if not exist "%wd%\%arc%\media\.IT\10\" ( mkdir "%wd%\%arc%\media\.IT\10" )
        
        REM mklink /h "%wd%\%arc%\media\.IT\10\install.wim"  "%wd%\..\..\..\..\..\..\_iso\10_mod\iso\sources\install.wim"
        
        REM mklink /h "%wd%\%arc%\media\.IT\10\install.wim.md5"  "%wd%\..\..\..\..\..\..\_iso\10_mod\iso\sources\install.wim.md5"
        
        
        REM REM 7
        
        REM if not exist "%wd%\%arc%\media\.IT\7\" ( mkdir "%wd%\%arc%\media\.IT\7" )
        
        REM mklink /h "%wd%\%arc%\media\.IT\7\install.wim"  "%wd%\..\..\..\..\..\..\_iso\7_mod\iso\sources\install.wim"
        
        REM mklink /h "%wd%\%arc%\media\.IT\7\install.wim.md5"  "%wd%\..\..\..\..\..\..\_iso\7_mod\iso\sources\install.wim.md5"
        
        
        REM "%iso%" -m -o -u2 -l"WinPE x64 LTI" -b"%wd%\amd64\fwfiles\etfsboot.com" %wd%\%arc%\media "%~dp0UNIVERSAL.iso"
    
    ) else ( pause )
