@echo off
rem ###################################################################################
rem #  TVerRec : TVerビデオダウンローダ
rem #
rem #		動画チェック処理スクリプト
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

title TVerRec Video File Checker

if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
	pwsh -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video.ps1
) else (
	powershell -Command "get-content -encoding:utf8 ..\src\common_functions.ps1 | out-file -encoding:utf8 ..\src\common_functions_5.ps1"
	powershell -Command "get-content -encoding:utf8 ..\src\validate_video.ps1 | out-file -encoding:utf8 ..\src\validate_video_5.ps1"
	powershell -NoProfile -ExecutionPolicy Unrestricted ..\src\validate_video_5.ps1

)

pause

