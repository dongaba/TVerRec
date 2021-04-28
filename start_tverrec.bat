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


@echo off
setlocal enabledelayedexpansion
cd %~dp0

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=%HostName%-pid.txt
set sleepTime=600

powershell "Get-WmiObject win32_process -filter processid=$pid | ForEach-Object{$_.parentprocessid;}" > %PIDFile%

:Loop
	rem *************************
	rem 一定間隔で実行したい処理
	rem *************************

	title TVer Recorder
	powershell -NoProfile -ExecutionPolicy Unrestricted .\src\tverrec_bulk.ps1

	timeout /T %sleepTime% /nobreak > nul
	goto Loop

:End

