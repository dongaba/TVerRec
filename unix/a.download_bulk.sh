#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		一括ダウンロード処理スクリプト
#
###################################################################################

echo -en "\033];TVerRec Video File Bulk Downloader\007"

pwsh -NoProfile "../src/download_bulk.ps1"

echo "Completed ..."
