###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		無視対象ビデオ削除処理スクリプト
#
#	Copyright (c) 2021 dongaba
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#Set-StrictMode -Off
Set-StrictMode -Version Latest
$currentDir = Split-Path $MyInvocation.MyCommand.Path
Set-Location $currentDir
$configDir = $(Join-Path $currentDir '..\config')
$sysFile = $(Join-Path $configDir 'system_setting.ini')
$iniFile = $(Join-Path $configDir 'user_setting.ini')

#----------------------------------------------------------------------
#外部設定ファイル読み込み
Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
		Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
		Invoke-Expression
Get-Content $iniFile | Where-Object { $_ -notmatch '^\s*$' } | `
		Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
		Invoke-Expression

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#ダウンロード対象外ビデオ番組リストの読み込み
$ignoreTitles = (Get-Content $ignoreFile -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^#.*$') } | `
			Where-Object { !($_ -match '^;.*$') } ) `
	-as [string[]]

#無視リストに入っている番組の場合はスキップフラグを立ててダウンロードリストに書き込み処理へ
Write-Host '削除対象のビデオフォルダを削除します'
foreach ($ignoreTitle in $ignoreTitles) {
	$delPath = Join-Path $saveBasePath $ignoreTitle
	Write-Host $delPath
	Remove-Item -Path $delPath -Force -Recurse -ErrorAction SilentlyContinue
}

#空フォルダ と 隠しファイルしか入っていないフォルダを一気に削除
Write-Host '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
$all_subdirs = @(Get-ChildItem -Path $saveBasePath -Recurse | Where-Object { $_.PSIsContainer }) | Sort-Object -Descending { $_.FullName }
foreach ($subdir in $all_subdirs) {
	if (@(Get-ChildItem -Path $subdir.FullName -Recurse | Where-Object { ! $_.PSIsContainer }).Count -eq 0) {
		Remove-Item -Path $subdir.FullName -Recurse -Force
	}
}
