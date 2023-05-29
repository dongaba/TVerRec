#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		一括ダウンロード処理開始スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the MIT License;
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in
#	all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#	THE SOFTWARE.
#
###################################################################################

echo -en "\033];TVerRec\007"

export HostName="$(hostname)"
export PIDFile="pid-$HostName.txt"
export retryTime=60
export sleepTime=3600

echo $PPID > "$PIDFile"

while true
do
	pwsh -NoProfile -ExecutionPolicy Unrestricted "../src/download_bulk.ps1"

	#youtube-dlプロセスチェック
	while [ "$(ps | grep -E "ffmpeg|youtube-dl" | grep -v grep | grep -c ^)" -gt 0 ]
	do
		echo "ダウンロードが進行中です..."
		ps | grep -E "ffmpeg|youtube-dl" | grep -v grep
		echo $retryTime "秒待機します..."
		sleep $retryTime
	done

	pwsh -NoProfile -ExecutionPolicy Unrestricted "../src/delete_trash.ps1"

	pwsh -NoProfile -ExecutionPolicy Unrestricted "../src/validate_video.ps1"
	pwsh -NoProfile -ExecutionPolicy Unrestricted "../src/validate_video.ps1"

	pwsh -NoProfile -ExecutionPolicy Unrestricted "../src/move_video.ps1"

	pwsh -NoProfile -ExecutionPolicy Unrestricted "../src/delete_trash.ps1"

	echo $sleepTime "秒待機します。すぐに処理を再開するにはEnterを押してください。"
	read -r -t $sleepTime

done
