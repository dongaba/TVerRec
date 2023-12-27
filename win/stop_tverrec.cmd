@echo off
rem ###################################################################################
rem #  TVerRec : TVerダウンローダ
rem #
rem #		一括ダウンロード処理停止スクリプト
rem #
rem ###################################################################################

rem 文字コードをUTF8に
chcp 65001 > nul

setlocal enabledelayedexpansion
cd /d %~dp0

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=pid-%HostName%.txt

if exist %PIDFile% (
	set /p targetPID=<%PIDFile%
	tasklist /fi "PID eq !targetPID!" > nul 2> nul
	if not ERRORLEVEL 1 (
		goto :RUNNING
	) else (
		del %PIDFile%
		goto :NOT_RUNNING
	)
) else (
	goto :NOT_RUNNING
)

:RUNNING
	echo kill process: !targetPID!
	taskkill /F /T /PID !targetPID! 2> nul
	del !PIDFile! 2> nul
	goto :END

:NOT_RUNNING
	echo not running
	del !PIDFile! 2> nul
	goto :END

:END
	exit
