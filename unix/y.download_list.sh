#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		リストダウンロード処理スクリプト
#
###################################################################################

echo -en "\033];TVerRec List Based Video File Downloader\007"

pwsh -NoProfile "../src/download_list.ps1"

echo "Finished ..."
