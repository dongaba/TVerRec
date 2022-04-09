#!/bin/bash

###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		一括ダウンロード処理開始スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
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
	pwsh -NoProfile -ExecutionPolicy Unrestricted ../src/tverrec_bulk.ps1

	#youtube-dlプロセスチェック
	while [ "$(ps | grep -E "ffmpeg|yt-dlp" | grep -v grep | grep -c)" -gt 0 ]
	do
		echo "ダウンロードが進行中です..."
		ps | grep -E "ffmpeg|yt-dlp" | grep -v grep
		echo $retryTime "秒待機します..."
		sleep $retryTime
	done

	pwsh -NoProfile -ExecutionPolicy Unrestricted ../src/delete_trash.ps1

	pwsh -NoProfile -ExecutionPolicy Unrestricted ../src/validate_video.ps1
	pwsh -NoProfile -ExecutionPolicy Unrestricted ../src/validate_video.ps1

	pwsh -NoProfile -ExecutionPolicy Unrestricted ../src/move_video.ps1

	pwsh -NoProfile -ExecutionPolicy Unrestricted ../src/delete_trash.ps1

	echo $sleepTime "秒待機します..."
	sleep $sleepTime

done
