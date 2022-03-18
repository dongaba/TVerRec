###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		一括ダウンロード処理スクリプト
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
using namespace System.Text.RegularExpressions

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

	#Windowsの判定
	Set-StrictMode -Off
	$isWin = $PSVersionTable.Platform -match '^($|(Microsoft )?Win)'
	Set-StrictMode -Version Latest

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if ((Test-Path 'R:\' -PathType Container) ) {
		$VerbosePreference = 'Continue'						#詳細メッセージ
		$DebugPreference = 'Continue'						#デバッグメッセージ
	}

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
Write-Host ''
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  tverrec : TVerビデオダウンローダ                                                ' -ForegroundColor Cyan
Write-Host "                      一括ダウンロード版 version. $appVersion                     " -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host ''

#----------------------------------------------------------------------
#動作環境チェック
checkLatestTool ($isWin)	#yt-dlpとffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック
#checkGeoIP							#日本のIPアドレスでないと接続不可のためIPアドレスをチェック
$keywords = loadKeywordList			#ダウンロード対象ジャンルリストの読み込み

#----------------------------------------------------------------------
#個々のジャンルページチェックここから
foreach ($keyword in $keywords) {

	#ジャンルページチェックタイトルの表示
	Write-Host ''
	Write-Host '=================================================================================='
	Write-Host "【 $keyword 】 のダウンロードを開始します。"
	Write-Host '=================================================================================='

	Write-Host $keyword
	$genre = $keyword.Replace('https://tver.jp/', '').Replace('http://tver.jp/', '')

	$videoLinks = getVideoLinks

	#----------------------------------------------------------------------
	#個々のビデオダウンロードここから
	$videoNum = 0						#ジャンル内の処理中のビデオの番号
	$videoTotal = $videoLinks.Length	#ジャンル内のトータルビデオ数
	foreach ($videoID in $videoLinks) {

		#いろいろ初期化
		$videoNum = $videoNum + 1		#ジャンル内のビデオ番号のインクリメント
		$videoPage = '' 

		#保存先ディレクトリの存在確認
		if (Test-Path $downloadBasePath -PathType Container) {} 
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します' ; exit 1 }

		Write-Host '----------------------------------------------------------------------'
		Write-Host "[ $genre - $videoNum / $videoTotal ] をダウンロードします。 ( $(getTimeStamp) )"
		Write-Host '----------------------------------------------------------------------'

		#yt-dlpプロセスの確認と、yt-dlpのプロセス数が多い場合の待機
		getYtdlpProcessList $parallelDownloadNum

		$videoPage = 'https://tver.jp' + $videoID
		Write-Host $videoPage

		downloadTVerVideo $genre				#TVerビデオダウンロードのメイン処理

	}
	#----------------------------------------------------------------------

}
#----------------------------------------------------------------------

#yt-dlpのプロセスが終わるまで待機
waitTillYtdlpProcessIsZero ($isWin)

Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '処理を終了しました。                                                              ' -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
