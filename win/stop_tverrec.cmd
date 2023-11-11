@echo off
rem ###################################################################################
rem #  TVerRec : TVerダウンローダ
rem #
rem #		一括ダウンロード処理停止スクリプト
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
chcp 65001 > nul

setlocal enabledelayedexpansion
cd /d %~dp0

for /f %%i in ('hostname') do set HostName=%%i
set PIDFile=pid-%HostName%.txt

if exist %PIDFile% (
	set /p targetPID=<%PIDFile%
	tasklist /fi "PID eq !targetPID!" > nul 2> nul
	if not ERRORLEVEL 1 (
		goto :RUNNING
	) else (
		del %PIDFile%
		goto :NOT_RUNNING
	)
) else (
	goto :NOT_RUNNING
)

:RUNNING
	echo kill process: !targetPID!
	taskkill /F /T /PID !targetPID! 2> nul
	del !PIDFile! 2> nul
	goto :END

:NOT_RUNNING
	echo not running
	del !PIDFile! 2> nul
	goto :END

:END
	exit
