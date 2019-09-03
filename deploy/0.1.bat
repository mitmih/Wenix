@ECHO OFF
CHCP 1251

REM Данный скрипт копирует дистрибутивы Wenix, в зависимости от текущей ситуации.


REM Определение переменных
	SET DeployPath=C:\
	SET Version=%~n0

REM Удаление старого файла журнала ошибок
	IF EXIST "C:\Wenix_%Version%_Errors.log" DEL "C:\Wenix_%Version%_Errors.log" /q /f

REM 1. Копирование дистрибутивов в папку развёртывания
	xcopy "%~dp0Wenix" %DeployPath% /v /q /i /e /h /y /z || GOTO Error_101

REM 2. Запуск скрипта, добавляющего пункт загрузки Wenix в менеджер загрузки
	cd %DeployPath%
	call %DeployPath%.IT\PE\Add-2nd_boot_entry.cmd || GOTO Error_102 
	CHCP 1251

REM Проверка наличия журнала ошибок и в случае его отсутствия создание файла успешного развёртывания
	IF NOT EXIST "C:\Wenix_%Version%_Errors.log" ECHO %date% %time% - Wenix был успешно развёрнут >> C:\Wenix_%Version%_Success.log
	EXIT 0


REM Обработчики ошибок
	:Error_101
		ECHO %date% %time% - Возникла ошибка при копировании дистрибутивов в папку развёртывания %DeployPath% >> C:\Wenix_%Version%_Errors.log
		EXIT 101
		
	:Error_102
		ECHO %date% %time% - Возникла ошибка при запуске скрипта, добавляющего пункт загрузки Wenix в менеджер загрузки >> C:\Wenix_%Version%_Errors.log
		EXIT 102