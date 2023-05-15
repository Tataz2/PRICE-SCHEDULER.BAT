@echo off
SETLOCAL EnableDelayedExpansion
cd /D "%~dp0"

REM Version 0.4

REM Condition 1:
REM If current electricity price is lower or equal than PriceThreshold, ConditionPrice is TRUE.
REM If current electricity price is higher than PriceThreshold, ConditionPrice is FALSE.
REM Condition 2:
REM If current rank is lower or equal than RankThreshold, ConditionRank is TRUE.
REM If current rank is higher than RankThreshold, ConditionRank is TRUE.
REM Result:
REM If ConditionPrice and ConditionRank is FALSE, the script will stop %ProcessName%. Otherwise the script will start %ProgramToRun%.

REM The current price is checked fron https://api.spot-hinta.fi/TodayAndDayforward. Spot-hinta.fi is/was unreliable so added https://api.porssisahko.net as a backup. Rank is not get from porssisahko.net.

REM Command line calculator (https://cmdlinecalc.sourceforge.io/) and Wget (https://eternallybored.org/misc/wget/) required.
REM Copy calc.exe and wget.exe to the same directory as thisS batch script. 

REM Start ProgramToRun if price in euros is lower or equal than PriceThreshold. Max 4 decimals. Includes taxes.
set PriceThreshold=0.0300

REM Start ProgramToRun is rank is lower or equal than RankThreshold. Rank 1 is the cheapest of 24 hours, 2 is the second cheapest etc.
set RankThreshold=2

REM This is the command to be run when pice is low.
set "ProgramToRun=C:\Ohjelmatiedostot\Miners\hodlminer2018v3\POOL-run - Solo Mining 2nd address.bat"

REM This is the name of the process which is shutdown when price is high.
set "ProcessName=hodlminer-avx2.exe"

REM Log file.
set "LogFile=price-scheduler.log"

REM Default price which is used if current price is not solved. Eg. -1 if you want to run %ProgramToRun% when price is not solved. Eg. 999 if you want to stop %ProcessName%.
set DefaultPrice=999

REM Default rank which is used if current rank is not solved. Eg. 24 if you want to run %ProgramToRun% when price is not solvess Eg. 0 if you want to stop %ProcessName%.
set DefaultRank=0

REM -------------------------- CODE STARTS --------------------------

set ProgramRunning=FALSE
set ConditionPrice=FALSE
set ConditionRank=FALSE
set RefreshSeconds=30

set "UrlSpottiHinta=https://api.spot-hinta.fi/TodayAndDayforward"
set FileJson=TodayAndDayforward.json

set CurrentRank=-1

REM An hour accuracy 2023022220 (yyymmddhh)
set "LastJsonUpdate="

goto :CheckRequiredFiles
:ReturnPointCheckRequiredFiles

REM %~nx0 is the filename of this batch script..
call :WriteLog "Starting %~nx0 main loop."
call :WriteLog "Price threshold is %PriceThreshold% and rank threshold is %RankThreshold%."



:start

REM Check if program is running. Use this to detect if program was started or shutdown manually.This updates the variable %ProgramRunning%.
call :CheckIfRunning

REM Get current date/time yyyymmddhh.
for /F "tokens=1,2 delims==" %%A in ('wmic os get LocalDateTime /VALUE 2^>NUL') do if '.%%A.'=='.LocalDateTime.' set DateString=%%B
set "DateString=!DateString:~0,10!"
REM echo DateString: "%DateString%"

cls

echo -------------------- GetCurrentPrice Starts --------------------
REM Get current price in euros. Returns -1 if getting price fails.
call :GetPriceByDate "!DateString!" PriceWithTax CurrentRank
if "!PriceWithTax!" == "-1"  (
	set "PriceWithTax=%DefaultPrice%"
)
if "!CurrentRank!" == "-1"  (
	set "CurrentRank=%DefaultRank%"
)
echo -------------------- GetCurrentPrice Ends--------------------

REM Convert decimal number to integer by multiplying by 10000.
for /f "tokens=*" %%i in ('calc %PriceWithTax%*10000 ') do set PriceWithTax10000=%%i
for /f "tokens=*" %%i in ('calc %PriceThreshold%*10000 ') do set PriceThreshold10000=%%i

REM IF price is lower or equal than threshold start the program. Otherwise stop the program.
IF %PriceWithTax10000% LEQ %PriceThreshold10000%  (
	echo Current price %PriceWithTax% is LOWER than price threshold %PriceThreshold%.	
	set ConditionPrice=TRUE

) ELSE (
	echo Current price %PriceWithTax% is HIGHER than price threshold %PriceThreshold%.	
	set ConditionPrice=FALSE
)

REM IF rank is lower or equal than threshold start the program. Otherwise stop the program.
IF %CurrentRank% LEQ %RankThreshold%  (
	echo Current rank %CurrentRank% is LOWER than rank threshold %RankThreshold%.	
	set ConditionRank=TRUE

) ELSE (
	echo Current rank %CurrentRank% is HIGHER than rank threshold %RankThreshold%.	
	set ConditionRank=FALSE
)


REM Stop the process if ConditionRank and ConditionPrice is FALSE. Otherwise start the program.
if "!ConditionPrice!" == "FALSE" (
	if "!ConditionRank!" == "FALSE" (
		IF "!ProgramRunning!" == "TRUE" (
			echo Shutting down %ProcessName%
			call :StopProgram
		)
	) else (
		IF "!ProgramRunning!" == "FALSE" (
			echo Starting %ProcessName%
			call :RunProgram
		)
	)
) else (
	IF "!ProgramRunning!" == "FALSE" (
		echo Starting %ProcessName%
		call :RunProgram
	)
)


REM echo DateTime: %DateTime%
echo ProgramRunning: "!ProgramRunning!"


timeout %RefreshSeconds%

goto start


GOTO :END


REM -------------------------- FUNCTIONS --------------------------

:RunProgram
REM TASKLIST /NH /FO CSV  /FI "imagename eq notepad.exe*"
REM "notepad.exe","14320","RDP-Tcp#23","1","10 516 K"

FOR /F "tokens=1,2 delims=," %%X IN (' TASKLIST /NH /FO CSV  /FI "imagename eq %ProcessName%" ') DO (
	REM %%X includes quotes.
	IF %%X == "%ProcessName%" (
		echo Process %ProcessName% IS already running^^!
		call :WriteLog "[price %PriceWithTax%, rank %CurrentRank%] Process "%ProcessName%" is already running. No need to start program %ProgramToRun%"
		set "ProgramRunning=TRUE"
	) ELSE (
		echo Process %ProcessName% IS NOT running^^!
		echo Start program %ProgramToRun%
		
		call :WriteLog "[price %PriceWithTax%, rank %CurrentRank%] Started program %ProgramToRun%"
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
		call :WriteLog "[price %PriceWithTax%, rank %CurrentRank%] Process %ProcessName%" is not running. Not shutdown needed.
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
			call :WriteLog "[price %PriceWithTax%, rank %CurrentRank%] Stopped process %ProcessName%"
 		) ELSE (
 			echo Process did not shutdown. Forcing shutdown...
 			TASKKILL /IM %ProcessName%"
 			set "ProgramRunning=FALSE"
			call :WriteLog "[price %PriceWithTax%, rank %CurrentRank%] Killed process %ProcessName%"
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



:GetPriceByDate
REM Finds the price from %FileJson% for a date which is given as an argument. Format 2023022220 (yyyymmddhh). 
REM Json DateFormat:
REM    "Rank": 6,
REM    "DateTime": "2023-03-02T00:00:00+02:00",
REM    "PriceNoTax": 0.0213,
REM    "PriceWithTax": 0.0234
REM https://stackoverflow.com/questions/41847418/batch-find-string-in-file-then-read-x-number-of-next-lines

REM If getting price fails return -1.

call :UpdateJsonFile

setlocal

SET SearchDate=%~1
SET SearchDate=%SearchDate:~0,4%-%SearchDate:~4,2%-%SearchDate:~6,2%T%SearchDate:~8,2%

set "PriceWithTax=-1"
set "CurrentRank=-1"

REM Limits that only four lines are read (from Rank to PriceWithTax).
SET LinesToRead=4

echo SearchDate: %SearchDate%

REM Line number where searched date was found. -1 if not found.
set MatchedLine=-1

REM /n adds line numbers. If SearchDate is not found MattchedLine is not modified.
for /f "delims=:" %%A in (' findstr /n /i /c:"!SearchDate!" "%FileJson%" ') do (
	set MatchedLine=%%A
	echo SearchDate !SearchDate! found at line !MatchedLine!.
)

REM Move two lines up so Rank can be read.
set /a MatchedLine=!MatchedLine! - 2

REM Let's skip for loop if no match.
IF !MatchedLine! LEQ -1 GOTO :BreakGetPriceByDate

REM Delim is : and space. Read only two lines after MatchedLine.
FOR /F "skip=%MatchedLine% tokens=1-2 delims=: " %%H IN (' type %FileJson% ') DO (
	SET /A LinesToRead=!LinesToRead!-1
	REM echo LinesToRead: !LinesToRead!
	REM echo %%~H %%I
	REM ~ stips extra quotes.
	IF "%%~H"=="PriceWithTax" (
		set PriceWithTax=%%I
		REM Remove possible , and spaces.
		set PriceWithTax=!PriceWithTax:,=!
		set PriceWithTax=!PriceWithTax: =!
		REM	echo PriceWithTax: "!PriceWithTax!"
	)
	IF "%%~H"=="Rank" (
		set CurrentRank=%%I
		REM Remove possible , and spaces.
		set CurrentRank=!CurrentRank:,=!
		set CurrentRank=!CurrentRank: =!
		REM	echo PriceWithTax: "!PriceWithTax!"
	)
	IF !LinesToRead! LEQ 0 GOTO :BreakGetPriceByDate
	
)

:BreakGetPriceByDate

if "!PriceWithTax!" == "-1"  (
	echo Getting price from https^:^/^/api.spot-hinta.fi FAILED^^! 
	echo Trying https^:^/^/api.porssisahko.net...
	call :WriteLog "Getting price from api.spot-hinta.fi FAILED. Trying api.porssisahko.net..."
	
	REM Päivämäärä muodossa VVVV-KK-PP. Kellonaika (Suomen aikavyöhyke), numero väliltä 0 - 23. Toimii myös ilman väliviivoja https://api.porssisahko.net/v1/price.json?date=20230224&hour=02 .
	REM Output in cents: {"price":4.949}
	FOR /F "tokens=1-2 delims=:" %%A IN ( 'wget --tries=5 -q -O- "https://api.porssisahko.net/v1/price.json?date=%SearchDate:~0,4%-%SearchDate:~5,2%-%SearchDate:~8,2%&hour=%SearchDate:~11,2%" ^| findstr /I /C:"price" ' ) DO (
		set "tempv=nul"
		set tempv=%%~A
		REM Remove { and quotes.
		set tempv=!tempv:{=!
		set tempv=!tempv:"=!
		if "!tempv!" == "price" (
			set PriceWithTax=%%B
			REM Remove character }
			set PriceWithTax=!PriceWithTax:}=!
			REM echo Porssisahko.netin PirceWithTax: "!PriceWithTax!"
			REM Convert cents to euros with four decimals.
			for /f "tokens=*" %%i in ('calc round^(!PriceWithTax! ^/100 ^,4^) ') do set PriceWithTax=%%i
		) else (
			set PriceWithTax=-1
		)
	)
	REM echo Got price !PriceWithTax! from api.porssisahko.net.
	call :WriteLog "Got price !PriceWithTax! from api.porssisahko.net."
)

REM Check if price is valid positive number with max four decimal accuracy.
for /f "tokens=*" %%i in ('calc %PriceWithTax%*10000 ') do set PriceWithTax10000=%%i
IF 1%PriceWithTax10000% NEQ +1%PriceWithTax10000% (
	echo Getting price failed^^!
	call :WriteLog "Getting price failed."
	set PriceWithTax=-1
) ELSE (
	echo Getting price %PriceWithTax% successfull^^!
	REM call :WriteLog "Getting price successfull."
)

( endlocal
	set "%2=%PriceWithTax%"
	set "%3=%CurrentRank%"
)
goto :eof



:UpdateJsonFile
REM Downloads Json file %UrlSpottiHinta% to a file %FileJson% and updates the file when hour changes.

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

if not exist %FileJson% (
	echo Json file %FileJson% not found. Downloading file...
	call :WriteLog "Json file %FileJson% not found. Downloading file..."
	wget --tries=5 -O %FileJson% %UrlSpottiHinta%
	
	REM Get %FileJson% file size in bytes.
	for /F "usebackq" %%h in (' %FileJson% ') do set JsonFileSize=%%~zh
	REM If wget could not connect file size is 0 bytes. 100 bytes threshold will include small error messages.S
	if !JsonFileSize! LEQ 1500  (
		echo Downloadin Json file from https^:^/^/api.spot-hinta.fi FAILED^^! 
		call :WriteLog "Downloading Json file %FileJson% FAILED. File size !JsonFileSize! bytes."
	) else (
		set "LastJsonUpdate=%DateString%"
	)
)

REM echo DateString: "%DateString%"
REM echo LastJsonUpdate: "%LastJsonUpdate%"

REM Update Json file when hour changes.
if "!DateString!" == "!LastJsonUpdate!" (
	REM No update.
	echo No need to update Json file %FileJson%. 
	REM Last update !LastJsonUpdate!
) else (
	echo Updating Json file... Last update !LastJsonUpdate!
	REM call :WriteLog "Downloading Json file %FileJson%."
	wget --tries=5 -O %FileJson%.temp %UrlSpottiHinta%
	
	REM Get %FileJson% file size in bytes.
	for /F "usebackq" %%h in (' %FileJson%.temp ') do set JsonFileSize=%%~zh
	REM If wget could not connect file size is 0 bytes. 100 bytes threshold will include small error messages.S
	if !JsonFileSize! LEQ 1500  (
		echo Updating Json file from https^:^/^/api.spot-hinta.fi FAILED^^! 
		call :WriteLog "Updating Json file %FileJson% FAILED. File size !JsonFileSize! bytes."
	) else (
		REM Downloaded Json file ok, replace old file.
		move /Y %FileJson%.temp %FileJson%
		echo Update successful.
		call :WriteLog "Updating Json file %FileJson% successfull. File size !JsonFileSize! bytes."
		set LastJsonUpdate=!DateString!
	)
)	

REM Modified time from Json file. Not a standard format.
for /F "usebackq" %%h in (' %FileJson% ') do set JsonFileDate=%%~th
echo Json file was modified !JsonFileDate!.
echo JsonFileSize: !JsonFileSize! bytes.

goto :eof



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
