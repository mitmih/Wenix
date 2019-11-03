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

    
    REM set /p level="1 - clear build, 2 - insert software + Wenix, 3 - refresh Wenix & build ISO "
    
    if /i "%1" == "1" ( goto GOTO_level_1 )
    
    if /i "%1" == "2" ( goto GOTO_level_2 )
    
    if /i "%1" == "3" ( goto GOTO_level_3 )

    if /i  %1  GTR 3  ( goto GOTO_GTR)
    
    if /i  %1  LSS 1  ( goto GOTO_LSS)
    

REM сборка новой конфигурации winPE и сохранение полученного boot.wim в качестве полуфабриката clear.wim
:GOTO_level_1
    echo 1


REM добавление ПО, Wenix
:GOTO_level_2
    echo 2


REM сборка iso-файла winPE
:GOTO_level_3
    echo 3




REM завершение скрипта
    timeout 7 && exit

    :GOTO_LSS
    echo GOTO_LSS
    timeout 7 && exit

    :GOTO_GTR
    echo GOTO_GTR
    timeout 7 && exit