@echo off
rem ###################################################################################
rem #  tverrec : TVerビデオダウンローダ
rem #
rem #		動画移動処理スクリプト
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


setlocal enabledelayedexpansion
cd %~dp0

title TVerRec Video File Mover
powershell -NoProfile -ExecutionPolicy Unrestricted .\src\move_video.ps1

pause

