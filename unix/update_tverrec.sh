#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		TVerRec自動アップデート処理スクリプト
#
###################################################################################

echo -en "\033];TVerRec Updater\007"

pwsh -NoProfile -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1' -OutFile '..\src\functions\update_tverrec.ps1'"

pwsh -NoProfile "../src/functions/update_tverrec.ps1"

echo "Completed ..."
