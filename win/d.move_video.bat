@echo off
rem ###################################################################################
rem #  TVerRec : TVerビデオダウンローダ
rem #
rem #		動画移動処理スクリプト
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

title TVerRec Video File Mover

rem 文字コードをWindows PowerShell用にUTF8-BOMなしファイルを作成する
powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul
powershell -Command "$allPoshFiles = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*.ps1' ).FullName ; foreach ($poshFile in $allPoshFiles) { $posh5File = $poshFile.Replace('.ps1' , '_5.ps1'); Get-Content -Encoding:utf8 $poshFile | Out-File -Encoding:utf8 $posh5File -Force }" 2>&1

where /Q pwsh
if %ERRORLEVEL% == 0 (
	pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video.ps1
) else (
	powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\move_video_5.ps1
)

rem Windows PowerShell用に作成したUTF8-BOMなしファイルを削除する
powershell -Command "$allPosh5Files = @(Get-ChildItem -Path '../' -Recurse -File -Filter '*_5.ps1' ).FullName ; foreach ($posh5File in $allPosh5Files) { Remove-Item $posh5File -Force }" 2> nul

pause
