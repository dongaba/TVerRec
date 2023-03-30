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
rm -rf bin img lib src unix VERSION

#新モジュールの再配置
cp -rf ../bin ../img ../lib ../src ../unix ../conf ../db ../list ../VERSION .

#unix配下の設定変更
sed -i -e 's#\.\./src#/app/TVerRec/src#g' ./unix/*.sh

#conf配下の設定変更
sed -i -e "s#'TVerRec'#'TVerRecContainer'#g" ./conf/system_setting.ps1
sed -i -e "s#'W:'#'/mnt/Work'#g" ./conf/system_setting.ps1
sed -i -e "s#=\ \$env:TMP#=\ '/mnt/Temp'#g" ./conf/system_setting.ps1
sed -i -e "s#'V:'#'/mnt/Video'#g" ./conf/system_setting.ps1

#コンテナイメージの作成
#docker image build --no-cache -t tverrec .
docker-compose build --no-cache

#コンテナ起動
#docker container run -it tverrec
docker-compose up -d

#掃除
rm -rf bin img lib src unix VERSION
