@ECHO OFF
CHCP 1251

REM ������ ������ �������� ������������ Wenix, � ����������� �� ������� ��������.


REM ����������� ����������
	SET DeployPath=C:\
	SET Version=%~n0

REM �������� ������� ����� ������� ������
	IF EXIST "C:\Wenix_%Version%_Errors.log" DEL "C:\Wenix_%Version%_Errors.log" /q /f

REM 1. ����������� ������������� � ����� ������������
	xcopy "%~dp0Wenix" %DeployPath% /v /q /i /e /h /y /z || GOTO Error_101

REM 2. ������ �������, ������������ ����� �������� Wenix � �������� ��������
	cd %DeployPath%
	call %DeployPath%.IT\PE\Add-2nd_boot_entry.cmd || GOTO Error_102 
	CHCP 1251

REM �������� ������� ������� ������ � � ������ ��� ���������� �������� ����� ��������� ������������
	IF NOT EXIST "C:\Wenix_%Version%_Errors.log" ECHO %date% %time% - Wenix ��� ������� �������� >> C:\Wenix_%Version%_Success.log
	EXIT 0


REM ����������� ������
	:Error_101
		ECHO %date% %time% - �������� ������ ��� ����������� ������������� � ����� ������������ %DeployPath% >> C:\Wenix_%Version%_Errors.log
		EXIT 101
		
	:Error_102
		ECHO %date% %time% - �������� ������ ��� ������� �������, ������������ ����� �������� Wenix � �������� �������� >> C:\Wenix_%Version%_Errors.log
		EXIT 102