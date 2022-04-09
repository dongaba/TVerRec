@echo off
rem ###################################################################################
rem #  TVerRec : TVerビデオダウンローダ
rem #
rem #		一括ダウンロード処理開始スクリプト
rem #
rem #	Copyright (c) 2022 dongaba
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
cd /d %~dp0

title TVerRec

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=pid-%HostName%.txt
set retryTime=60
set sleepTime=3600

for /f "tokens=2" %%i in ('tasklist /FI "WINDOWTITLE eq TVerRec" /NH') do set myPID=%%i
echo %myPID% > %PIDFile%

:Loop

	if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_bulk.ps1
	) else (
		powershell -Command "Get-Content -Encoding:utf8 ..\conf\user_setting.ps1 | Out-File -Encoding:utf8 ..\conf\user_setting_5.ps1 -Force"
		powershell -Command "Get-Content -Encoding:utf8 ..\conf\system_setting.ps1 | Out-File -Encoding:utf8 ..\conf\system_setting_5.ps1 -Force"
		powershell -Command "Get-Content -Encoding:utf8 ..\src\functions\common_functions.ps1 | Out-File -Encoding:utf8 ..\src\functions\common_functions_5.ps1 -Force"
		powershell -Command "Get-Content -Encoding:utf8 ..\src\functions\tver_functions.ps1 | Out-File -Encoding:utf8 ..\src\functions\tver_functions_5.ps1 -Force"
		powershell -Command "Get-Content -Encoding:utf8 ..\src\functions\update_ffmpeg.ps1 | Out-File -Encoding:utf8 ..\src\functions\update_ffmpeg_5.ps1 -Force"
		powershell -Command "Get-Content -Encoding:utf8 ..\src\functions\update_ytdl-patched.ps1 | Out-File -Encoding:utf8 ..\src\functions\update_ytdl-patched_5.ps1 -Force"
		powershell -Command "Get-Content -Encoding:utf8 ..\src\tverrec_bulk.ps1 | Out-File -Encoding:utf8 ..\src\tverrec_bulk_5.ps1 -Force"
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_bulk_5.ps1
	)

:ProcessChecker
	rem youtube-dlプロセスチェック
	tasklist | findstr /i "ffmpeg youtube-dl" > nul 2>&1
	if %ERRORLEVEL% == 0 (
		echo ダウンロードが進行中です...
		tasklist /v | findstr /i "ffmpeg youtube-dl"
		echo %retryTime%秒待機します...
		timeout /T %retryTime% /nobreak > nul
		goto ProcessChecker
	)

	if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1

		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1

		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video.ps1

		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
	) else (
		powershell -Command "Get-Content -Encoding:utf8 ..\src\delete_trash.ps1 | Out-File -Encoding:utf8 ..\src\delete_trash_5.ps1 -Force"
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash_5.ps1

		powershell -Command "Get-Content -Encoding:utf8 ..\src\validate_video.ps1 | Out-File -Encoding:utf8 ..\src\validate_video_5.ps1 -Force"
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1

		powershell -Command "Get-Content -Encoding:utf8 ..\src\move_video.ps1 | Out-File -Encoding:utf8 ..\src\move_video_5.ps1 -Force"
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video_5.ps1

		powershell -Command "Get-Content -Encoding:utf8 ..\src\delete_trash.ps1 | Out-File -Encoding:utf8 ..\src\delete_trash_5.ps1 -Force"
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
	)

	echo %sleepTime%秒待機します...
	timeout /T %sleepTime% /nobreak > nul

	goto Loop

:End
	del %PIDFile%
	pause
