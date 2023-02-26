@echo off
SETLOCAL EnableDelayedExpansion
cd /D "%~dp0"
REM Version 0.1
REM If current electricity price is lower or equal than PriceThreshold, the script will start %ProgramToRun%.
REM If current electricity price is higher than PriceThreshold, the script will stop %ProcessName%.
REM The current price checked fron https://api.spot-hinta.fi/JustNow . Spot-hinta.fi is unreliable so added https://api.porssisahko.net as a backup.

REM Command line calculator (https://cmdlinecalc.sourceforge.io/) and Wget (https://eternallybored.org/misc/wget/) required.
REM Copy calc.exe and wget.exe to the same directory as thisS batch script. 

REM Start miner is price in euros is lower or equal than PriceThreshold. Max 4 decimals. Includes taxes.
set PriceThreshold=0.0500

REM This is the command to be run when pice is low.
set "ProgramToRun=C:\Ohjelmatiedostot\Miners\hodlminer2018v3\POOL-run - Solo Mining 2nd address.bat"

REM This is the name of the process which is shutdown when price is high.
set "ProcessName=hodlminer-avx2.exe"

REM Log file.
set "LogFile=price-scheduler.log"


REM -------------------------- CODE STARTS --------------------------

set ProgramRunning=FALSE
set PriceUnderThreshold=FALSE
set RefreshSeconds=30

goto :CheckRequiredFiles
:ReturnPointCheckRequiredFiles

:START
cls 
 
set "DateTime="
set PriceWithTax=-1

REM Check if program is running. Use this to detect if program was started or shutdown manually.This updates the variable %ProgramRunning%.
call :CheckIfRunning

REM Get current price in euros. Returns -1 if getting current price fails.
Call :GetCurrentPrice PriceWithTax DateTime

REM Convert decimal number to integer by multiplying by 10000.
for /f "tokens=*" %%i in ('calc %PriceWithTax%*10000 ') do set PriceWithTax10000=%%i
for /f "tokens=*" %%i in ('calc %PriceThreshold%*10000 ') do set PriceThreshold10000=%%i

REM IF price is lower or equal than threshold start the program. Otherwise stop the program.
IF %PriceWithTax10000% LEQ %PriceThreshold10000%  (
	echo Current price %PriceWithTax% is LOWER than price threshold %PriceThreshold%.	
	set PriceUnderThreshold=TRUE
	IF "!ProgramRunning!" == "FALSE" (
		echo Starting %ProcessName%
		call :RunProgram
	)
) ELSE (
	echo Current price %PriceWithTax% is HIGHER than price threshold %PriceThreshold%.	
	set PriceUnderThreshold=FALSE
	IF "!ProgramRunning!" == "TRUE" (
		echo Shutting down %ProcessName%
		call :StopProgram
	)
)

REM echo DateTime: %DateTime%
echo ProgramRunning: "!ProgramRunning!"

REM Refreash every %RefreshSeconds% seconds. If local computer time is ahead of api.spot-hinta.fi time,
REM Json file is redownloaded every %RefreshSeconds% until hour digits are equal.
timeout %RefreshSeconds%

goto START

GOTO :EOF


:RunProgram
REM TASKLIST /NH /FO CSV  /FI "imagename eq notepad.exe*"
REM "notepad.exe","14320","RDP-Tcp#23","1","10 516 K"

FOR /F "tokens=1,2 delims=," %%X IN (' TASKLIST /NH /FO CSV  /FI "imagename eq %ProcessName%" ') DO (
	REM %%X includes quotes.
	IF %%X == "%ProcessName%" (
		echo Process %ProcessName% IS running^^!
		set "ProgramRunning=TRUE"
	) ELSE (
		echo Process %ProcessName% IS NOT running^^!
		echo Start program %ProgramToRun%
		
		call :WriteLog "[price %PriceWithTax%] Started program %ProgramToRun%"
		start /min "%ProcessName%" "%ProgramToRun%"
		set "ProgramRunning=TRUE"
	)
)

GOTO :eof


:StopProgram

FOR /F "tokens=1,2 delims=," %%X IN (' TASKLIST /NH /FO CSV  /FI "imagename eq %ProcessName%" ') DO (
	REM %%X includes quotes.
	IF NOT %%X == "%ProcessName%" (
		echo Process %ProcessName% is not running. No shutdown needed.
		set "ProgramRunning=FALSE"
		GOTO :eof
	) 
)

REM TASKKILL /IM notepad.exe
REM SUCCESS: Sent termination signal to the process "notepad.exe" with PID 13800.
FOR /F "tokens=1,2 delims=:" %%A IN (' TASKKILL /IM "%ProcessName%" ') DO (
	REM echo SUCCESS: "%%A"
	echo %%A: %%B
 	IF "%%A" == "SUCCESS" (
 			echo Process %ProcessName%" was shutdown successfully.
 			set "ProgramRunning=FALSE"
			call :WriteLog "[price %PriceWithTax%] Stopped process %ProcessName%"
 		) ELSE (
 			echo Process did not shutdown. Forcing shutdown...
 			TASKKILL /IM %ProcessName%"
 			set "ProgramRunning=FALSE"
			call :WriteLog "[price %PriceWithTax%] Killed process %ProcessName%"
 		)
)

GOTO :eof


:CheckIfRunning
REM TASKLIST /NH /FO CSV  /FI "imagename eq notepad.exe*"
REM "notepad.exe","14320","RDP-Tcp#23","1","10 516 K"

FOR /F "tokens=1,2 delims=," %%X IN (' TASKLIST /NH /FO CSV  /FI "imagename eq %ProcessName%" ') DO (
	REM %%X includes quotes.
	IF %%X == "%ProcessName%" (
		set "ProgramRunning=TRUE"
	) ELSE (
		set "ProgramRunning=FALSE"
	)
)

GOTO :eof


:GetCurrentPrice
echo -------------------- GetCurrentPrice Starts --------------------
setlocal

set "UrlSpottiHinta=https://api.spot-hinta.fi/JustNow"
set "DateTime="

REM Returning Local Variables - How to pass return values over the ENDLOCAL barrier
REM https://www.dostips.com/DtTutoFunctions.php#FunctionTutorial.ReturningLocalVariables

set FileJustNow=JustNow.json
REM echo FileJustNow: %FileJustNow%

if not exist %FileJustNow% (
	echo Json file %FileJustNow% not found. Downloading file...
	wget -O %FileJustNow% %UrlSpottiHinta%
)

REM Get local time
REM LocalDateTime=20230222205955.560000+120
for /F "tokens=1,2 delims==" %%A in ('wmic os get LocalDateTime /VALUE 2^>NUL') do if '.%%A.'=='.LocalDateTime.' set DateString=%%B

REM echo Current Year: %DateString:~0,4%
REM echo Current Month %DateString:~4,2%
REM echo Current Day %DateString:~6,2%
REM echo Current Hour: %DateString:~8,2%
REM echo Current Minute: %DateString:~10,2%

REM DateString: 2023022220
set DateString=%DateString:~0,10%
echo Current Date:  %DateString:~0,4%.%DateString:~4,2%.%DateString:~6,2% hour %DateString:~8,2%

REM "2023-02-22T18:00:00+02:00"
FOR /F "tokens=1-2 delims= " %%A IN ('type %FileJustNow% ^| findstr /I /C:"DateTime" ' ) DO (
	set DateTime=%%B
	set DateTime=!DateTime:,=!
)
REM Echo Json Year: %DateTime:~1,4%
REM echo Json Month %DateTime:~6,2%
REM echo Json Day %DateTime:~9,2%
REM echo Json Hour: %DateTime:~12,2%
REM echo Json Minute: %DateTime:~15,2%

set DateTime=%DateTime:~1,4%%DateTime:~6,2%%DateTime:~9,2%%DateTime:~12,2%
REM DateTime=2023022220
echo Json DateTime: %DateTime:~0,4%.%DateTime:~4,2%.%DateTime:~6,2% hour %DateTime:~8,2%


REM If local computer date/time is not date/time is Json file for current price by accuracy of one hour, update the Json file.
REM Make sure your local computer time is accurate.  If local time is a head of eg. 5 minutes, the script will redownload Json file every %RefreshSeconds% seconds.
if "%DateString%" == "%DateTime%" (
	REM No need to update!
	REM Modified time from Json file. Not a standard format.
	for /F "usebackq" %%h in (' %FileJustNow% ') do set JsonFileDate=%%~th
	for /F "usebackq" %%h in (' %FileJustNow% ') do set JsonFileSize=%%~zh
	echo No need to update Json file. Last update !JsonFileDate!
	echo JsonFileSize: !JsonFileSize! bytes.
	
	FOR /F "tokens=1-2 delims= " %%A IN ('type %FileJustNow% ^| findstr /I /C:"PriceWithTax" ' ) DO (
	set PriceWithTax=%%B
	REM Remove possible ,
	set PriceWithTax=!PriceWithTax:,=!
)
	
) else (
	REM Update required!
	echo Updating Json file...
	call :WriteLog "Updating Json file %FileJustNow%."
	wget --tries=5 -O %FileJustNow% %UrlSpottiHinta%

	REM File size is 0 bytes if wget fails.
	for /F "usebackq" %%h IN (' %FileJustNow% ') DO set JsonFileSize=%%~zh
	echo JsonFileSize: !JsonFileSize! bytes.
	if !JsonFileSize! LEQ 2  (
		echo Updating Json file from https^:^/^/api.spot-hinta.fi FAILED^^! 
		echo Trying https^:^/^/api.porssisahko.net...
		call :WriteLog "Updating Json file %FileJustNow% FAILED. Trying https^:^/^/api.porssisahko.net..."
	
		REM Päivämäärä muodossa VVVV-KK-PP. Kellonaika (Suomen aikavyöhyke), numero väliltä 0 - 23. Toimii myös ilman väliviivoja https://api.porssisahko.net/v1/price.json?date=20230224&hour=02 .
		REM Output in centsS: {"price":4.949}
		set "PriceWithTax="
		FOR /F "tokens=1-2 delims=:" %%A IN ( 'wget -q -O- "https://api.porssisahko.net/v1/price.json?date=%DateString:~0,4%-%DateString:~4,2%-%DateString:~6,2%&hour=%DateString:~8,2%" ^| findstr /I /C:"price" ' ) DO (
			set PriceWithTax=%%B
			REM Remove character }
			set PriceWithTax=!PriceWithTax:}=!
		)
		REM Convert cents to euros with four decimals.
		for /f "tokens=*" %%i in ('calc round^(!PriceWithTax! ^/100 ^,4^) ') do set PriceWithTax=%%i
		
		REM Check if price is valid positive number with max four decimal accuracy.
		for /f "tokens=*" %%i in ('calc %PriceWithTax%*10000 ') do set PriceWithTax10000=%%i
		IF 1%PriceWithTax10000% NEQ +1%PriceWithTax10000% (
			echo https^:^/^/api.porssisahko.net failed^^!
			call :WriteLog "https^:^/^/api.porssisahko.net failed^^!"
			set PriceWithTax=-1
		) ELSE (
			echo https^:^/^/api.porssisahko.net succesSsfull^^!
			call :WriteLog "https^:^/^/api.porssisahko.net successfull^^!"
		)
		
	) else (
		FOR /F "tokens=1-2 delims= " %%A IN ('type %FileJustNow% ^| findstr /I /C:"PriceWithTax" ' ) DO (
		set PriceWithTax=%%B
		REM Remove possible ,
		set PriceWithTax=!PriceWithTax:,=!
		)
	)
)

REM FOR /F "tokens=1-2 delims= " %%A IN ('type %FileJustNow% ^| findstr /I /C:"DateTime" ' ) DO (
REM 	set DateTime=%%B
REM	REM Removes comma
REM	set DateTime=!DateTime:,=!
REM )

REM Check if price is valid positive number with max four decimal accuracy.
for /f "tokens=*" %%i in ('calc %PriceWithTax%*10000 ') do set PriceWithTax10000=%%i
IF 1%PriceWithTax10000% NEQ +1%PriceWithTax10000% (
	echo Price is not a valid number^^!
	set PriceWithTax=-1
)

( endlocal
  set "%1=%PriceWithTax%"
  set "%2=%DateTime%"
)

echo -------------------- GetCurrentPrice Ends --------------------
GOTO :eof


:WriteLog
REM Generates time stamp and writes first argument %~1 to log file %LogFile%.
REM Usage: call :WriteLog "texto to write"
setlocal

REM Get current date/time
for /F "tokens=1,2 delims==" %%A in ('wmic os get LocalDateTime /VALUE 2^>NUL') do if '.%%A.'=='.LocalDateTime.' set DateStringLog=%%B
set "DateStringLog=!DateStringLog:~0,4!-!DateStringLog:~4,2!-!DateStringLog:~6,2! !DateStringLog:~8,2!:!DateStringLog:~10,2!:!DateStringLog:~12,2!"
>>%LogFile% echo !DateStringLog! %~1
		
endlocal
		
goto :eof


:CheckRequiredFiles
REM Check if wget and calc if found. This cannot be used by call because then exit /b won't work stop the batch execution.

WHERE wget.exe >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
	echo Error: wget.exe not found^^!
	timeout 5
	REM Exit /b will stop batch.
	exit /b
)

IF NOT EXIST calc.exe (
	echo Error: calc.exe not found in current directory^^!
	timeout 5
	exit /b
)

goto :ReturnPointCheckRequiredFiles


:END
