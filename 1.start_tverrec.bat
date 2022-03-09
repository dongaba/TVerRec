@echo off
rem ###################################################################################
rem #  tverrec : TVerビデオダウンローダ
rem #
rem #		一括ダウンロード処理開始スクリプト
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

rem 文字コードをUTF8に
chcp 65001

setlocal enabledelayedexpansion
cd %~dp0

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=pid-%HostName%.txt
set sleepTime=600
title TVerRec

powershell -NoProfile -ExecutionPolicy Unrestricted "Get-WmiObject win32_process -filter processid=$pid | ForEach-Object{$_.parentprocessid;}" > %PIDFile%

:Loop

	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\tverrec_bulk.ps1
	echo %sleepTime%秒待機します...
	timeout /T %sleepTime% /nobreak > nul

:ProcessChecker
	rem yt-dlpプロセスチェック
	tasklist | findstr /i "ffmpeg yt-dlp" > nul 2>&1
	if %ERRORLEVEL% == 0 (
		echo ダウンロードが進行中です...
		tasklist /v | findstr /i "ffmpeg yt-dlp" 
		echo %sleepTime%秒待機します...
		timeout /T %sleepTime% /nobreak > nul
		goto ProcessChecker
	)

	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\validate_video.ps1
	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\validate_video.ps1

	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\move_video.ps1

	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\delete_ignored.ps1

	echo %sleepTime%秒待機します...
	timeout /T %sleepTime% /nobreak > nul

	goto Loop

:End
	del %PIDFile%
	pause
