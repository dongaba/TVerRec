###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画移動処理スクリプト
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
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') { 
		$currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
	} else {
		$currentDir = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
		if (!$currentDir) { $currentDir = '.' } 
	}
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

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. '.\common_functions_5.ps1'
		. '.\tver_functions_5.ps1'
	} else {
		. '.\common_functions.ps1'
		. '.\tver_functions.ps1'
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました'; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#保存先ディレクトリの存在確認
if (Test-Path $downloadBasePath -PathType Container) {}
else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' ; exit 1 }
if (Test-Path $saveBasePath -PathType Container) {}
else { Write-Error 'ビデオ移動先フォルダにアクセスできません。終了します。' ; exit 1 }

#----------------------------------------------------------------------
#移動先フォルダのサブフォルダの取得
foreach ($moveToParentName in $moveToParentNameList) {

	$moveToParentPath = $(Join-Path $saveBasePath $moveToParentName)
	Write-Host '----------------------------------------------------------------------'
	Write-Host "$moveToParentPath を処理します"
	Write-Host '----------------------------------------------------------------------'

	#移動先フォルダを起点として、配下のフォルダを取得
	$moveToChildPathList = Get-ChildItem $moveToParentPath | Where-Object { $_.PSisContainer }

	#----------------------------------------------------------------------
	foreach ($moveToChildPath in $moveToChildPathList) {
		$targetFolderName = Split-Path -Leaf $moveToChildPath
		#同名フォルダが存在する場合は配下のファイルを移動
		$moveFromPath = $(Join-Path $downloadBasePath $targetFolderName)
		if ( Test-Path $moveFromPath) {
			$moveFromPath = $moveFromPath + '\*.mp4'
			$moveToPath = $moveToParentPath + '\' + $targetFolderName
			Write-Host "$moveFromPath を $moveToPath に移動します"
			Move-Item $moveFromPath -Destination $moveToPath -Force
		}
	}
	#----------------------------------------------------------------------
}
#----------------------------------------------------------------------

deleteEmpty		#空フォルダ と 隠しファイルしか入っていないフォルダを一気に削除
