@echo off && cls && echo Author Dmitriy Mikhaylov aka alt-air && chcp 65001>nul && echo.



REM рабочая папка
    
    set "wd=%~dp0.pe_work_dir"
    
    set "bin=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    
    
    REM 


REM архитектура
    
    if /i "%1"=="" (
        
        set arc=amd64
    
    ) else (
        
        set arc=%1
    
    )



REM формируем загрузочный iso-образ нашей winpe среды
    
    "%bin%" -m -o -u2 -l"WinPE x64 LTI" -b"%wd%\amd64\fwfiles\etfsboot.com" %wd%\%arc%\media "%~dp0Win10PE_x64_LTI.iso"

