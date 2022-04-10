#!/bin/bash

###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		一括ダウンロード処理停止スクリプト
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

if [ -e "$PIDFile" ]; then
	export targetPID=$(cat "$PIDFile")
fi

if [ "$(pgrep -F "$PIDFile" | wc -l)" -gt 0 ]; then
	pkill -TERM -P "$targetPID"
	rm -f "$PIDFile"
else
	rm -f "$PIDFile"
fi


