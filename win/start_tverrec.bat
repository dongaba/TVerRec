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

rem PIDファイルを作成するする
for /f "tokens=2" %%i in ('tasklist /FI "WINDOWTITLE eq TVerRec" /NH') do set myPID=%%i
echo %myPID% > %PIDFile% 2> nul

rem 文字コードをWindows PowerShell用にUTF8-BOMなしファイルを作成する
powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul
powershell -Command "$allPoshFiles = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*.ps1' ).FullName ; foreach ($poshFile in $allPoshFiles) { $posh5File = $poshFile.Replace('.ps1' , '_5.ps1'); Get-Content -Encoding:utf8 $poshFile | Out-File -Encoding:utf8 $posh5File -Force }" 2>&1

:Loop

	if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_bulk.ps1
	) else (
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_bulk_5.ps1
	)

:ProcessChecker
	rem youtube-dlプロセスチェック
	tasklist | findstr /i "ffmpeg youtube-dl" > nul 2>&1
	if %ERRORLEVEL% == 0 (
		echo ダウンロードが進行中です...
		tasklist /v | findstr /i "ffmpeg youtube-dl" 2> nul
		echo %retryTime%秒待機します...
		timeout /T %retryTime% /nobreak > nul 2> nul
		goto ProcessChecker
	)

	where /Q pwsh
	if %ERRORLEVEL% == 0 (
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video.ps1
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
	) else (
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash_5.ps1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video_5.ps1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
	)

	echo %sleepTime%秒待機します...
	timeout /T %sleepTime% /nobreak > nul

	goto Loop

:End
	rem PIDファイルを削除する
	del %PIDFile% 2> nul
	rem Windows PowerShell用に作成したUTF8-BOMなしファイルを削除する
	powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul
	pause
