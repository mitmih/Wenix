@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo.

REM выбор уровня сборки iso-файла
REM     скрипт реализует три уровня сборки winPE iso-файла, разной степени длительности:
REM         1 - самый долгий - сборка winPE "с нуля" из исходных файлов Windows ADK
REM         нужные пакеты интегрируются в чистый boot.wim (достаточно длительная процедура)
REM         полученный образ дублируется в полуфабрикат semi1.wim
REM
REM         2 - самый средний - используется собранный с нужными пакетами semi1.wim
REM         в него добавляется ПО и актуальная версия Wenix`а
REM         полученный образ дублируется в полуфабрикат semi2.wim
REM
REM         3 - самый быстрый - пересборка iso-файла, используется последний доступный semi2.wim
REM         новая версия Wenix`а копируется в "iso-root:\.IT\PE\Wenix"


REM установка переменных среды исполнения
    
    REM архитектура
    
        set "arc=amd64"
    
    
    REM рабочая папка
    
        set "wd=%~dp0..\winPE\.pe_work_dir"
    
    
    REM папка монтирования wim-образа
    
        set "mnt=%~dp0..\winPE\.pe_mount_point"
    
    
    REM папки устнановленного Kits
        
        set "adk=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
        
        set "dsm=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\%arc%\DISM"
        
        set "wpe=%adk%\Windows Preinstallation Environment"
        
        set "cab=%wpe%\%arc%"
        
        set "iso=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    
    
    REM полуфабрикаты 1 и 2
        
        set "semi1=%~dp0..\winPE\semi1.wim"
        
        set "semi2=%~dp0..\winPE\semi2.wim"
    
    
    REM PoSh-калькулятор md5-хэшей файлов, сохраняет результат в file.ext.md5
        
        set "md5calc=%~dp0Make-MD5File.ps1"
    
    
    REM для использования copype.cmd нужно установить переменные среды, которые обычно устанавливает DandISetEnv.bat
        
        set "WinPERoot=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
        
        set "OSCDImgRoot=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\%arc%\Oscdimg"


REM переход на указанный уровень сборки
    
    if /i "%1" == "1" ( goto GOTO_level_1 )
    
    if /i "%1" == "2" ( goto GOTO_level_2 )
    
    if /i "%1" == "3" ( goto GOTO_level_3 )

    if /i  %1  GTR 3  ( goto GOTO_GTR)
    
    if /i  %1  LSS 1  ( goto GOTO_LSS)


REM сборка новой конфигурации winPE и сохранение полученного boot.wim в качестве полуфабриката clear.wim
    
    :GOTO_level_1
    
    echo. & echo GOTO_level_1
    
    
    REM очистка на случай если остались какие-то ранее смонтированные образы
        
        dism /Cleanup-Wim
        
        if errorlevel 1 ( pause && exit )
        
        
        REM очистка рабочей папки
            
            if exist "%wd%\" ( rmdir /s /q "%wd%" )
        
        
        REM удаление папки при ошибочном применения wim-файла
            
            if exist "%mnt%\" (
                
                takeown /F "%mnt%\*" /A /R /D Y /SKIPSL >nul 2>&1
                
                icacls "%mnt%" /reset
                
                icacls "%mnt%" /grant:r "%USERNAME%:(OI)(CI)F" /inheritance:e /Q /C /T /L >nul 2>&1
                
                pushd "%mnt%" && ( rd /S /Q "%mnt%" 2>nul & popd )
            )
        
        if not exist "%mnt%\" (mkdir "%mnt%")
        
        
        REM копируем winpe
            
            call "%wpe%\copype.cmd" %arc% "%wd%\%arc%"
    
    
    REM монтирование, увеличение размера свободного места на ram-диске до 512 MB для манипулирования файлами
        
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
        
        
    REM фиксация изменений 1-го уровня
        
        dism /unmount-wim /mountdir:%mnt% /commit
    
    
    REM сжатие и подсчёт MD5
        
        if errorlevel 0 (
            
            ren "%wd%\%arc%\media\sources\boot.wim" boot0.wim
            
            dism /Export-image /SourceImageFile:"%wd%\%arc%\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\%arc%\media\sources\boot.wim" /compress:max
            
            del "%wd%\%arc%\media\sources\boot0.wim" /F /Q
            
        ) else ( pause )
        
        
    REM полуфабрикат1
        
        if exist "%semi1%*"     ( del "%semi1%*"     /F /Q )
        
        mklink /h "%semi1%" "%wd%\%arc%\media\sources\boot.wim"
        
        del "%wd%\%arc%\media\sources\boot.wim" /F /Q
        
        start "%~n0" powershell -command "& {%md5calc% -path '%semi1%'}"


REM добавление ПО, Wenix
    
    :GOTO_level_2
    
    echo. & echo GOTO_level_2
    
    
    REM если отсутствует полуфабрикат1 - GOTO_level_1
        if not exist %semi1% ( goto GOTO_level_1 )
    
    
    REM используем полуфабрикат1
        
        if exist "%wd%\%arc%\media\sources\*" ( del "%wd%\%arc%\media\sources\*" /F /Q )
        
        xcopy "%semi1%" "%wd%\%arc%\media\sources\" /y
        
        ren "%wd%\%arc%\media\sources\semi1.wim" boot.wim
    
    
    REM монтирование
        dism /Mount-Wim /WimFile:%wd%\%arc%\media\sources\boot.wim /index:1 /MountDir:%mnt%
    
    
    REM настройка PoSh-профиля, запуска winPE, добавление Wenix`а и ПО
        
        xcopy "%wd%\..\Windows"    "%mnt%\Windows\"  /e /y
        
        xcopy "%wd%\..\..\Wenix"   "%mnt%\Windows\System32\config\systemprofile\Documents\WindowsPowerShell\Modules\Wenix\"  /e /y
        
        xcopy "%wd%\..\Far"        "%mnt%\Far\"      /e /y
        
        xcopy "%wd%\..\UltraVNC"   "%mnt%\UltraVNC\" /e /y
        
        REM xcopy "%wd%\..\..\scripts_helpers\debug\Debug-Mount_Z.cmd"  "%mnt%\" /y
    
    
    REM фиксация изменений 2-го уровня
        
        dism /unmount-wim /mountdir:%mnt% /commit
    
    
    REM сжатие и подсчёт MD5
        
        if errorlevel 0 (
            
            ren "%wd%\%arc%\media\sources\boot.wim" boot0.wim
            
            dism /Export-image /SourceImageFile:"%wd%\%arc%\media\sources\boot0.wim" /SourceIndex:1 /DestinationImageFile:"%wd%\%arc%\media\sources\boot.wim" /compress:max /CheckIntegrity
            REM /DestinationName:"Wenix version a.b.c.d"
            
            
            del "%wd%\%arc%\media\sources\boot0.wim" /F /Q
            
        ) else ( pause )
    
    
    REM полуфабрикат2 (жёсткая ссылка быстрее файлового копирования)
        
        if exist "%semi2%"     ( del "%semi2%"     /F /Q )
        
        if exist "%semi2%.md5" ( del "%semi2%.md5" /F /Q )
        
        mklink /h "%semi2%" "%wd%\%arc%\media\sources\boot.wim"
        
        del "%wd%\%arc%\media\sources\boot.wim" /F /Q
        
        start "%~n0" powershell -command "& {%md5calc% -path '%semi2%'}"


REM сборка iso-файла winPE
    
    :GOTO_level_3
    
    echo. & echo GOTO_level_3
    
    
    REM если отсутствует полуфабрикат2 - GOTO_level_2
        if not exist %semi2% ( goto GOTO_level_2 )
    
    
    REM используем полуфабрикат2
        
        if exist "%wd%\%arc%\media\sources\*" ( del "%wd%\%arc%\media\sources\*" /F /Q )
        
        xcopy "%semi2%" "%wd%\%arc%\media\sources\" /y
        
        ren "%wd%\%arc%\media\sources\semi2.wim" boot.wim
        
        start "%~n0" /wait powershell -command "& {%md5calc% -path '%wd%\%arc%\media\sources\boot.wim'}"
    
    
    REM готовим папку .IT\PE с файлами ram-диска в корне ISO - она понадобится Wenix`у во время поиска установочных файлов на дисках и флешках на этапе проверки готовности к (пере)установке ОС
    
        if exist "%wd%\%arc%\media\.IT\PE\" ( rd /s /q "%wd%\%arc%\media\.IT\PE" )
        
        mkdir "%wd%\%arc%\media\.IT\PE"
        
        mkdir "%wd%\%arc%\media\.IT\10"
        
        mkdir "%wd%\%arc%\media\.IT\7"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\boot.wim"                "%wd%\%arc%\media\sources\boot.wim"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\boot.wim.md5"            "%wd%\%arc%\media\sources\boot.wim.md5"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\boot.sdi"                "%wd%\%arc%\media\Boot\boot.sdi"
        
        mklink /h "%wd%\%arc%\media\.IT\PE\Add-2nd_boot_entry.cmd"  "%wd%\..\..\scripts_helpers\Add-2nd_boot_entry.cmd"
        
        mklink /J "%wd%\%arc%\media\.IT\PE\Wenix"                   "%wd%\..\..\Wenix"
    
        
        REM какой сетевой конфиг включать в ISO-файл: по-умолчанию пример конфига
        
        if /i "%2" == "" (
            
            mklink /h "%wd%\%arc%\media\.IT\PE\BootStrap.csv"       "%wd%\..\BootStrap.csv.example"
        
        ) else (
            
            mklink /h "%wd%\%arc%\media\.IT\PE\BootStrap.csv"       "%wd%\..\BootStrap.csv"
        
        )
    
    
    REM вырезаем "лишние" локализации
        
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
    
    
    REM сборка iso-файла winPE, подсчёт md5-хэша
        
        "%iso%" -m -o -u2 -l"Wenix WinPE x64 LTI" -b"%wd%\amd64\fwfiles\etfsboot.com" "%wd%\%arc%\media" "%wd%\..\WinPE_10_x64_LTI.iso"
        
        if not errorlevel 0 ( pause )
        
        start "%~n0" powershell -command "& {%md5calc% -path '%wd%\..\WinPE_10_x64_LTI.iso'}"


REM завершение работы скрипта
    
    :GOTO_EXIT
        
        REM pause
        
        timeout 7 & exit
    
    
    :GOTO_LSS
        
        echo. & echo GOTO_LSS
        
        goto GOTO_EXIT
    
    
    :GOTO_GTR
        
        echo. & echo GOTO_GTR
        
        goto GOTO_EXIT
