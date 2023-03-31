#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		dockerコンテナ作成準備処理スクリプト
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

#旧モジュールの削除
rm -rf TVerRec/*

#TVerRecの取得
cp -r ../img ../src ../unix ../win ../VERSION ./TVerRec
mkdir TVerRec/bin
mkdir TVerRec/conf
cp -r ../conf/keyword.sample.conf ../conf/ignore.sample.conf ../conf/system_setting.ps1 ./TVerRec/conf/.
mkdir TVerRec/db
cp -r ../db/history.lock ../db/history.sample.csv ../db/list.lock ./TVerRec/db/.
mkdir TVerRec/list
cp -r ../list/list.sample.csv ./TVerRec/list/.

#unix配下の設定変更
sed -i -e 's#\.\./src#/app/TVerRec/src#g' ./TVerRec/unix/*.sh

#conf配下の設定変更
sed -i -e "s#'TVerRec'#'TVerRecContainer'#g" ./TVerRec/conf/system_setting.ps1
sed -i -e "s#'W:'#'/mnt/Work'#g" ./TVerRec/conf/system_setting.ps1
sed -i -e "s#=\ \$env:TMP#=\ '/mnt/Temp'#g" ./TVerRec/conf/system_setting.ps1
sed -i -e "s#'V:'#'/mnt/Video'#g" ./TVerRec/conf/system_setting.ps1

#コンテナイメージ作成
#docker build --no-cache -t dongaba/tverrec:latest .
docker-compose build #--no-cache
