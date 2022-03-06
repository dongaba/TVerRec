###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		個別ダウンロード処理スクリプト
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
$currentDir = Split-Path $MyInvocation.MyCommand.Path
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
#必要モジュールの読み込み
Add-Type -AssemblyName Microsoft.VisualBasic

#----------------------------------------------------------------------
#開発環境用に設定上書き
if ((Test-Path 'R:\' -PathType Container) ) {
	$VerbosePreference = 'Continue'						#詳細メッセージ
	$DebugPreference = 'Continue'						#デバッグメッセージ
}

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
. '.\common_functions.ps1'
. '.\tver_functions.ps1'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Host ''
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  tverrec : TVerビデオダウンローダ                                                ' -ForegroundColor Cyan
Write-Host "                      個別ダウンロード版 version. $appVersion                     " -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host ''

#----------------------------------------------------------------------
#動作環境チェック
if ($isWin) {
	. '.\update_ffmpeg.ps1'				#ffmpegの最新化チェック
	. '.\update_yt-dlp.ps1'				#yt-dlpの最新化チェック
}
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック
#checkGeoIP							#日本のIPアドレスでないと接続不可のためIPアドレスをチェック

#ダウンロード対象外番組リストの読み込み
$ignoreTitles = (Get-Content $ignoreFile -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^;.*$') } ) `
	-as [string[]]

#無限ループ
while ($true) {
	#いろいろ初期化
	$videoID = '' ; $videoPage = '' ; $videoName = '' ; $videoPath = '' ; $videoPageLP = '' ;
	$broadcastDate = '' ; $title = '' ; $subtitle = '' ; $media = '' ; $description = '' ;
	$videoInfo = $null
	$ignore = $false ; $skip = $false
	$newVideo = $null

	#保存先ディレクトリの存在確認
	if (Test-Path $downloadBasePath -PathType Container) {} else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' ; exit 1 }

	$genre = ''

	#yt-dlpプロセスの確認と、yt-dlpのプロセス数が多い場合の待機
	getYtdlpProcessList $parallelDownloadNum

	$videoPage = Read-Host 'ビデオURLを入力してください。'
	if ($videoPage -eq '') { exit }
	$videoID = $videoPage.Replace('https://tver.jp', '').Replace('http://tver.jp', '').trim()

	#TVerの番組説明の場合はビデオがないのでスキップ
	if ($videoPage -match '/episode/') {
		Write-Host 'ビデオではなくオンエア情報のようです。スキップします。' -ForegroundColor DarkGray
		continue			#次のビデオへ
	}

	#URLがすでにダウンロードリストに存在する場合はスキップ
	try {
		$listMatch = Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoPage -eq $videoPage } 
	} catch {
		Write-Host 'ダウンロードリストを読み書きできなかったのでスキップしました。'
		continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
	}
	if ( $null -ne $listMatch ) {
		Write-Host '過去に処理したビデオです。スキップします。' -ForegroundColor DarkGray
		continue			#次のビデオへ
	}

	#TVerのAPIを叩いてビデオ情報取得
	try {
		$videoInfo = callTVerAPI ($videoID)
	} catch {
		Write-Host 'TVerから情報を取得できませんでした。スキップします。' -ForegroundColor DarkGray
		continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
	}

	#LPがすでにダウンロードリストに存在する場合はスキップ
	try {
		$listMatch = Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoPageLP -eq $videoPageLP } 
	} catch {
		Write-Host 'ダウンロードリストを読み書きできなかったのでスキップしました。'
		continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
	}
	if ( $null -ne $listMatch ) {
		Write-Host '過去に処理したビデオです。スキップします。' -ForegroundColor DarkGray
		continue			#次のビデオへ
	}

	#取得したビデオ情報を整形
	$broadcastDate = getBroadcastDate ($videoInfo)
	$title = $(conv2Narrow ($videoInfo.title).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！')).trim()
	$subtitle = $(conv2Narrow ($videoInfo.subtitle).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！')).trim()
	$media = $(conv2Narrow ($videoInfo.media).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '')).trim()
	$description = $(conv2Narrow ($videoInfo.note.text).Replace('&amp;', '&')).trim()
	$videoPageLP = getVideoPageLP ($videoInfo)

	#ビデオファイル情報をセット
	$videoName = setVideoName $title $subtitle $broadcastDate		#保存ファイル名を設定
	$savePath = $(Join-Path $downloadBasePath (removeInvalidFileNameChars $title))
	$videoPath = $(Join-Path $savePath $videoName)

	#ビデオ情報のコンソール出力
	writeVideoInfo $videoName $broadcastDate $media $description 
	writeVideoDebugInfo $videoPage $videoPageLP $genre $title $subtitle $videoPath $(getTimeStamp)

	#ビデオタイトルが取得できなかった場合はスキップ次のビデオへ
	if ($videoName -eq '.mp4') {
		Write-Host 'ビデオタイトルを特定できませんでした。スキップします。' -ForegroundColor DarkGray
		continue			#次回再度ダウンロードをトライするためダウンロードリストに追加せずに次のビデオへ
	}

	#ファイルが既に存在する場合はスキップフラグを立ててダウンロードリストに書き込み処理へ
	if (Test-Path $videoPath) {
		$skip = $true
		Write-Host 'すでにダウンロード済みのビデオです。スキップします。' -ForegroundColor DarkGray
	} else {
		#無視リストに入っている番組の場合はスキップフラグを立ててダウンロードリストに書き込み処理へ
		foreach ($ignoreTitle in $ignoreTitles) {
			if ($(conv2Narrow $title) -eq $(conv2Narrow $ignoreTitle)) {
				$ignore = $true
				Write-Host '無視リストに入っているビデオです。スキップします。' -ForegroundColor DarkGray
				break
			} 
		}
	}

	#スキップフラグが立っているかチェック
	if ($ignore -ne $true) {
		#ダウンロードリストに行追加
		Write-Verbose 'ダウンロードするファイルをダウンロードリストに追加します。'
		$newVideo = [pscustomobject]@{ 
			videoPage      = $videoPage ;
			videoPageLP    = $videoPageLP ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = $videoName ;
			videoPath      = $videoPath ;
			videoValidated = '0' ;
		}
	} elseif ($skip -ne $true) {
		#ダウンロードリストに行追加
		Write-Verbose '無視したファイルをダウンロードリストに追加します。'
		$newVideo = [pscustomobject]@{ 
			videoPage      = $videoPage ;
			videoPageLP    = $videoPageLP ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = '-- IGNORED --' ;
			videoPath      = '-- IGNORED --' ;
			videoValidated = '0' ;
		}
	} else {
		#ダウンロードリストに行追加
		Write-Verbose 'スキップしたファイルをダウンロードリストに追加します。'
		$newVideo = [pscustomobject]@{ 
			videoPage      = $videoPage ;
			videoPageLP    = $videoPageLP ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = '-- SKIPPED --' ;
			videoPath      = $videoPath ;
			videoValidated = '0' ;
		}
	}

	try {
		#ダウンロードリストCSV書き出し
		$newVideo | Export-Csv $listFile -NoTypeInformation -Encoding UTF8 -Append
		Write-Debug 'ダウンロードリストを書き込みました。'
	} catch {
		Write-Host 'ダウンロードリストを読み書きできなかったのでスキップしました。'
		continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
	}

	#スキップや無視対象でなければyt-dlp起動
	if (($ignore -eq $true ) -Or ($skip -eq $true)) { 
		continue			#スキップや無視対象は飛ばして次のファイルへ
	} else {
		#保存作ディレクトリがなければ作成
		if (-Not (Test-Path $savePath -PathType Container)) {
			$null = New-Item -ItemType directory -Path $savePath
		}
		#yt-dlp起動
		startYtdlp $videoPath $videoPage $ytdlpPath

	}

	Write-Output '処理を終了しました。'
}