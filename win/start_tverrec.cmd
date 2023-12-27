@echo off
rem ###################################################################################
rem #  TVerRec : TVerダウンローダ
rem #
rem #		一括ダウンロード処理開始スクリプト
rem #
rem ###################################################################################

rem 文字コードをUTF8に
chcp 65001 > nul

setlocal enabledelayedexpansion
cd /d %~dp0

title TVerRec

where /Q pwsh
if %ERRORLEVEL% neq 0 (goto :INSTALL)

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=pid-%HostName%.txt

rem Zone Identifierの削除
pwsh -Command "Get-ChildItem ..\ -Recurse | Unblock-File"

rem PIDファイルを作成するする
for /f "tokens=2" %%i in ('tasklist /FI "WINDOWTITLE eq TVerRec" /NH') do set myPID=%%i
echo %myPID% > %PIDFile% 2> nul

pwsh -NoProfile -ExecutionPolicy Unrestricted "..\src\loop.ps1"

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
