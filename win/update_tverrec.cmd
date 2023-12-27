@echo off
rem ###################################################################################
rem #  TVerRec : TVerダウンローダ
rem #
rem #		TVerRec自動アップデート処理スクリプト
rem #
rem ###################################################################################

rem 文字コードをUTF8に
chcp 65001 > nul

setlocal enabledelayedexpansion
cd /d %~dp0

title TVerRec Updater

where /Q pwsh
if %ERRORLEVEL% neq 0 (goto :INSTALL)

pwsh -NoProfile -ExecutionPolicy Unrestricted -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1' -OutFile '..\src\functions\update_tverrec.ps1'"

rem Zone Identifierの削除
pwsh -NoProfile -ExecutionPolicy Unrestricted -Command "Get-ChildItem ..\ -Recurse | Unblock-File"

pwsh -NoProfile -ExecutionPolicy Unrestricted "..\src\functions\update_tverrec.ps1"

pause
exit

:INSTALL
	where /Q winget
	if %ERRORLEVEL% neq 0 (goto :NOWINGET)
	echo.
	echo PowerShell Coreをインストールします。インストールしたくない場合はこのままウィンドウを閉じてください。
	echo.
	pause
	winget install --id Microsoft.Powershell --source winget
	echo PowerShell Coreをインストールしました。TVerRecを再実行してください。
	echo.
	pause
	exit

:NOWINGET
	echo.
	echo PowerShell Coreを自動インストールするにはアプリインストーラーをインストールする必要があります。
	echo.
	echo https://apps.microsoft.com/detail/9NBLGGH4NNS1 に移動してアプリインストーラーをインストールしてください。
	echo.
	pause
	exit
