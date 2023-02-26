@echo off
cd /D "%~dp0"
REM This batch file runs 'price-scheduler.bat' in a hidden cmd window.
REM This is achived by using CMDH utility. http://www.gate2.net/tools/cmdh/cmdh.html
REM Priority is set normal [/low | /normal | /high | /realtime | /abovenormal | belownormal].
REM /B starts an application without opening a new Command Prompt window.
REM To make it work more like a system service add scheduled task, configure it to run at startup and select 'Run whether user is logged on or not'.

:START
cmdh.exe start "price-scheduler" /NORMAL /B price-scheduler.bat



goto :END

:CheckRequiredFiles
WHERE wget.exe >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
	echo Error: cmdh.exe not found^^!
	timeout 5
	REM Exit /b will stop batch.
	exit /b
)
goto :START

:END
