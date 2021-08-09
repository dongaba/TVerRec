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
using namespace Microsoft.VisualBasic
using namespace System.Text.RegularExpressions

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

#----------------------------------------------------------------------
#必要モジュールの読み込み
Add-Type -Path $webDriverPath
Add-Type -Path $webDriverSupportPath
Add-Type -Path $seleniumPath
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

#----------------------------------------------------------------------
#開発環境用に設定上書き
if ((Test-Path 'R:\' -PathType Container) ) {
	$chromeUserDataPath = 'R:\tverrec\ChromeUserData\' 
	$VerbosePreference = 'Continue'						#詳細メッセージ
	$DebugPreference = 'Continue'						#デバッグメッセージ
}

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
. '.\common_functions.ps1'
. '.\tverrec_functions.ps1'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Host ''
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  tverrec : TVerビデオダウンローダ                                                ' -ForegroundColor Cyan
Write-Host "                      個別一括ダウンロード版 version. $appVersion                     " -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host ''

#----------------------------------------------------------------------
#動作環境チェック
. '.\update_chromedriver.ps1'		#chromedriveの最新化チェック
. '.\update_ffmpeg.ps1'				#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック
checkGeoIP							#日本のIPアドレスでないと接続不可のためIPアドレスをチェック

#ダウンロード対象外番組リストの読み込み
$ignoreTitles = (Get-Content $ignoreFile -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^#.*$') } | `
			Where-Object { !($_ -match '^;.*$') } ) `
	-as [string[]]

#無限ループ
while ($true) {
	#いろいろ初期化
	$videoID = '' ; $videoPage = '' ; $videoName = '' ; $videoPath = ''
	$ignore = $false
	$videoLists = $null ; $newVideo = $null
	$chromeDriverService = $null ; $chromeOptions = $null ; $chromeDriver = $null
	while ((Get-Clipboard -Format Text) -ne ' ') {
		Set-Clipboard -Value ' '
		Start-Sleep -Milliseconds 300
	}

	$videoPage = Read-Host 'ビデオURLを入力してください。'
	if ($videoPage -eq '') { exit }
	$videoID = $videoPage.Replace('https://tver.jp', '').Replace('http://tver.jp', '').trim()

	#TVerの番組説明の場合はビデオがないのでスキップ
	if ($videoID -match '/episode/') {
		Write-Host 'ビデオではなくオンエア情報のようです。スキップします。' -ForegroundColor DarkGray
		continue								#次のビデオへ
	}

	#すでにダウンロードリストに存在する場合はスキップ
	$listMatch = Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoID -eq $videoID } 
	if ( $null -ne $listMatch ) {
		Write-Host '過去に処理したビデオです。スキップします。' -ForegroundColor DarkGray
		continue								#次のビデオへ
	}

	#Chrome起動と動画情報の整理
	$chromeDriverService = [OpenQA.Selenium.Chrome.ChromeDriverService]::CreateDefaultService()
	$chromeDriverService.HideCommandPromptWindow = $true						#chromedriverのWindow非表示(orコンソールに非表示)
	setChromeAttributes $chromeUserDataPath ([ref]$chromeOptions) $crxPath		#Chrome起動パラメータ作成
	try {
		$chromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($chromeDriverService, $chromeOptions)		#★エラー頻発個所
	} catch {
		Write-Error 'Chromeの起動に失敗しました。終了します'
		exit
	}
	$chromeDriver.manage().Window.Minimize()									#ChromeのWindow最小化
	openVideo ([ref]$chromeDriver) $videoPage									#URLをChromeにわたす
	$videoURL = playVideo ([ref]$chromeDriver)									#ページ読み込み待ち、再生ボタンクリック、クリップボードにビデオURLを入れる

	#ビデオ情報取得
	$title = getVideoTitle ([ref]$chromeDriver)
	$subtitle = getVideoSubtitle ([ref]$chromeDriver)
	$media = getVideoMedia ([ref]$chromeDriver)
	$broadcastDate = getVideoBroadcastDate ([ref]$chromeDriver)
	$description = getVideoDescription ([ref]$chromeDriver)

	stopChrome ([ref]$chromeDriver)									#Chrome終了
	$videoName = setVideoName $title $subtitle $broadcastDate		#保存ファイル名を設定
	$savePath = $(Join-Path $downloadBasePath (removeInvalidFileNameChars $title))
	$videoPath = $(Join-Path $savePath $videoName)

	#ビデオ情報のコンソール出力
	writeVideoInfo $videoName $broadcastDate $media $description 
	writeVideoDebugInfo $videoID $videoPage '' $title $subtitle $videoPath $(getTimeStamp) $videoURL

	if ([string]::IsNullOrEmpty($videoName)) {
		Write-Host 'ビデオタイトルを特定できませんでした。スキップします。' -ForegroundColor DarkGray
		continue			#次回再度ダウンロードをトライするためダウンロードリストに追加せずに次のビデオへ
	}
	if (Test-Path $videoPath) {
		$ignore = $true
		Write-Host 'すでにダウンロード済みのビデオです。スキップします。' -ForegroundColor DarkGray
	} 

	#無視リストに入っている番組の場合はスキップフラグを立ててダウンロードリストに書き込み処理へ
	foreach ($ignoreTitle in $ignoreTitles) {
		if ($(conv2Narrow $title) -eq $(conv2Narrow $ignoreTitle)) {
			$ignore = $true
			break
		} 
	}

	if ($ignore -eq $true) {
		#ダウンロードリストに行追加
		Write-Host '無視リストに入っているビデオです。スキップします' -ForegroundColor DarkGray
		Write-Verbose 'ダウンロード済みリストに行を追加します。'
		$newVideo = [pscustomobject]@{ 
			videoID        = $videoID ;
			videoPage      = $videoPage ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = '-- IGNORED --' ;
			videoName      = '-- IGNORED --' ;
			videoPath      = '-- IGNORED --' ;
			videoValidated = '0' ;
		}
	} else {
		#ダウンロードリストに行追加
		Write-Verbose 'ダウンロード済みリストに行を追加します。'
		$newVideo = [pscustomobject]@{ 
			videoID        = $videoID ;
			videoPage      = $videoPage ;
			genre          = '' ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp)
			videoName      = $videoName ;
			videoPath      = $videoPath ;
			videoValidated = '0' ;
		}
	}

	#ダウンロードリストCSV読み込み
	Write-Debug 'ダウンロード済みリストを読み込みます。'
	$videoLists = Import-Csv $listFile -Encoding UTF8

	#ダウンロードリストCSV書き出し
	$newList = @()
	$newList += $videoLists
	$newList += $newVideo
	$newList | Export-Csv $listFile -NoTypeInformation -Encoding UTF8


	#無視リストに入っていなければffmpeg起動
	if ($true -eq $ignore ) { 
		continue		#無視リストに入っているビデオは飛ばして次のファイルへ
	} else {

		#保存作ディレクトリがなければ作成
		if (-Not (Test-Path $savePath -PathType Container)) {
			$null = New-Item -ItemType directory -Path $savePath
		}

		#ffmpeg起動
		startFfmpeg $videoName $videoPath $videoURL '' $title $subtitle $description $media $videoPage $ffmpegPath

		#ffmpegプロセスの確認と、ffmpegのプロセス数が多い場合の待機
		getFfmpegProcessList $parallelDownloadNum

	}



	Write-Output '終わりました。'
}
