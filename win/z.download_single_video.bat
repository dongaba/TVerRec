@echo off
rem ###################################################################################
rem #  TVerRec : TVerビデオダウンローダ
rem #
rem #		個別ダウンロードスクリプト
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

title TVerRec Video File Downloader

rem 文字コードをWindows PowerShell用にUTF8-BOMなしファイルを作成する
powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul
powershell -Command "$allPoshFiles = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*.ps1' ).FullName ; foreach ($poshFile in $allPoshFiles) { $posh5File = $poshFile.Replace('.ps1' , '_5.ps1'); Get-Content -Encoding:utf8 $poshFile | Out-File -Encoding:utf8 $posh5File -Force }" 2>&1

where /Q pwsh
if %ERRORLEVEL% == 0 (
	pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_single.ps1
) else (
	powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\tverrec_single_5.ps1
)

rem Windows PowerShell用に作成したUTF8-BOMなしファイルを削除する
powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul

pause
