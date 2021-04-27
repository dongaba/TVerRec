@echo off
setlocal enabledelayedexpansion
cd %~dp0

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=%HostName%-pid.txt

if exist "%PIDFile%" (
	set /p targetPID=<%PIDFile%

	tasklist /fi "PID eq !targetPID!" | find "cmd.exe" > nul
	if not ERRORLEVEL 1 (
		goto RUNNING
	) else (
		del %PIDFile%
		goto NOT_RUNNING
	)

) else (
	goto NOT_RUNNING

)

:RUNNING
	echo kill process: !targetPID!
	taskkill /F /T /PID !targetPID!
	del !PIDFile!
	goto END

:NOT_RUNNING
	echo not running
	del !PIDFile!
	goto END

:END
	pause

