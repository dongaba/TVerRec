@echo off
rem ###################################################################################
rem #  TVerRec : TVerビデオダウンローダ
rem #
rem #		一括ダウンロード処理開始スクリプト
rem #
rem #	Copyright (c) 2022 dongaba
rem #
rem #	Licensed under the MIT License;
rem #	Permission is hereby granted, free of charge, to any person obtaining a copy
rem #	of this software and associated documentation files (the "Software"), to deal
rem #	in the Software without restriction, including without limitation the rights
rem #	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
rem #	copies of the Software, and to permit persons to whom the Software is
rem #	furnished to do so, subject to the following conditions:
rem #
rem #	The above copyright notice and this permission notice shall be included in
rem #	all copies or substantial portions of the Software.
rem #
rem #	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
rem #	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
rem #	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
rem #	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
rem #	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
rem #	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
rem #	THE SOFTWARE.
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

:LOOP

	rem 文字コードをWindows PowerShell用にUTF8-BOMなしファイルを作成する
	powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul

	title TVerRec - Downloading
	where /Q pwsh
	if %ERRORLEVEL% == 0 (
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_bulk.ps1
	) else (
		powershell -Command "$allPoshFiles = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*.ps1' ).FullName ; foreach ($poshFile in $allPoshFiles) { $posh5File = $poshFile.Replace('.ps1' , '_5.ps1'); Get-Content -Encoding:utf8 $poshFile | Out-File -Encoding:utf8 $posh5File -Force }" 2>&1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_bulk_5.ps1
	)

	goto :PROCESSCHECKER

:PROCESSCHECKER
	rem youtube-dlプロセスチェック
	tasklist | findstr /i "ffmpeg youtube-dl" > nul 2>&1
	if %ERRORLEVEL% == 0 (
		echo ダウンロードが進行中です...
		tasklist /v | findstr /i "ffmpeg youtube-dl" 2> nul
		echo %retryTime%秒待機します...
		timeout /T %retryTime% /nobreak > nul 2> nul
		goto :PROCESSCHECKER
	)

	where /Q pwsh
	if %ERRORLEVEL% == 0 (
		title TVerRec - Deleting
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
		title TVerRec - Validating
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1
		title TVerRec - Moving
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video.ps1
		title TVerRec - Deleting
		pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash.ps1
	) else (
		title TVerRec - Deleting
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash_5.ps1
		title TVerRec - Validating
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1
		title TVerRec - Moving
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video_5.ps1
		title TVerRec - Deleting
		powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\delete_trash_5.ps1
	)

	rem Windows PowerShell用に作成したUTF8-BOMなしファイルを削除する
	powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul

	title TVerRec
	echo 終了するには Y と入力してください。何も入力しなければ処理を継続します。

	choice /C YN /T %sleepTime% /D N /M "%sleepTime%秒待機します..."
	goto OPTION-%errorlevel%

:OPTION-1
	goto :END

:OPTION-2
	goto :LOOP

:END
	rem PIDファイルを削除する
	del %PIDFile% 2> nul
