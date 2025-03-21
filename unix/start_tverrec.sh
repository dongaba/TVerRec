#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		一括ダウンロード処理開始スクリプト
#
###################################################################################

echo -en "\033];TVerRec\007"

export HostName="$(hostname)"
export PIDFile="pid-$HostName.txt"

echo $PPID > "$PIDFile"

pwsh -NoProfile "../src/loop.ps1"

echo "Completed ..."
