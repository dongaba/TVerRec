@echo off
rem ###################################################################################
rem #  tverrec : TVerビデオダウンローダ
rem #
rem #		一括ダウンロード処理停止スクリプト
rem #
rem #	Copyright (c) 2021 dongaba
rem #
rem #	Licensed under the Apache License, Version 2.0 (the "License");
rem #	you may not use this file except in compliance with the License.
rem #	You may obtain a copy of the License at
rem #
rem #		http://www.apache.org/licenses/LICENSE-2.0
rem #
rem #	Unless required by applicable law or agreed to in writing, software
rem #	distributed under the License is distributed on an "AS IS" BASIS,
rem #	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem #	See the License for the specific language governing permissions and
rem #	limitations under the License.
rem #
rem ###################################################################################

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
