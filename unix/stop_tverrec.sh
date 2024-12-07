#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		一括ダウンロード処理停止スクリプト
#
###################################################################################

echo -en "\033];TVerRec\007"

export HostName="$(hostname)"
export PIDFile="pid-$HostName.txt"

if [ -e "$PIDFile" ] ; then
	export targetPPID=$(pgrep -P $(cat "$PIDFile"))
	export targetPID=$(pgrep -P "$targetPPID")
	kill -9 "$targetPID"
	kill -9 "$targetPPID"
	rm -f "$PIDFile"
else
	rm -f "$PIDFile"
fi
