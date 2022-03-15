###################################################################################
#  TVerRec : TVerビデオダウンローダ
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
Set-StrictMode -Version Latest
try {
	Set-StrictMode -Version Latest
	$currentDir = Split-Path $MyInvocation.MyCommand.Path
	Set-Location $currentDir
	$configDir = $(Join-Path $currentDir '..\config')
	$sysFile = $(Join-Path $configDir 'system_setting.conf')
	$confFile = $(Join-Path $configDir 'user_setting.conf')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
} catch { Write-Host '設定ファイルの読み込みに失敗しました'; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#ダウンロード対象外ビデオ番組リストの読み込み
$ignoreTitles = (Get-Content $ignoreFile -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^;.*$') } ) `
	-as [string[]]

#ダウンロードが中断した際にできたゴミファイルは削除
Write-Host '----------------------------------------------------------------------'
Write-Host 'ダウンロードが中断した際にできたゴミファイルを削除します'
Write-Host '----------------------------------------------------------------------'
#ダウンロードが中断してしまったゴミファイルを削除
$tempFile = $downloadBasePath + '\*\*.ytdl'
Remove-Item $tempFile
$tempFile = $downloadBasePath + '\*\*.jpg'
Remove-Item $tempFile
$tempFile = $downloadBasePath + '\*\*.vtt'
Remove-Item $tempFile
$tempFile = $downloadBasePath + '\*\*temp.mp4'
Remove-Item $tempFile
$tempFile = $downloadBasePath + '\*\*.part'
Remove-Item $tempFile
$tempFile = $downloadBasePath + '\*\*mp4.part-Frag*'
Remove-Item $tempFile

#無視リストに入っている番組は削除
Write-Host '----------------------------------------------------------------------'
Write-Host '削除対象のビデオフォルダを削除します'
Write-Host '----------------------------------------------------------------------'
foreach ($ignoreTitle in $ignoreTitles) {
	$delPath = Join-Path $downloadBasePath $ignoreTitle
	Write-Host $delPath
	$ErrorActionPreference = 'silentlycontinue'
	Remove-Item -Path $delPath -Force -Recurse -ErrorAction SilentlyContinue
	$ErrorActionPreference = 'continue'
}

#空フォルダ と 隠しファイルしか入っていないフォルダを一気に削除
Write-Host '----------------------------------------------------------------------'
Write-Host '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
Write-Host '----------------------------------------------------------------------'
$all_subdirs = @(Get-ChildItem -Path $downloadBasePath -Recurse | Where-Object { $_.PSIsContainer }) | Sort-Object -Descending { $_.FullName }
foreach ($subdir in $all_subdirs) {
	if (@(Get-ChildItem -Path $subdir.FullName -Recurse | Where-Object { ! $_.PSIsContainer }).Count -eq 0) {
		Remove-Item -Path $subdir.FullName -Recurse -Force
	}
}

