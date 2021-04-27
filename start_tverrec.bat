@echo off
setlocal enabledelayedexpansion
cd %~dp0

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=%HostName%-pid.txt
set sleepTime=600

powershell "Get-WmiObject win32_process -filter processid=$pid | ForEach-Object{$_.parentprocessid;}" > %PIDFile%

:Loop
	rem *************************
	rem 一定間隔で実行したい処理
	rem *************************

	title TVer Recorder
	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\tverrec_bulk.ps1

	timeout /T %sleepTime% /nobreak > nul
	goto Loop

:End

