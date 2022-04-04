###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		一括ダウンロード処理スクリプト
#
#	Copyright (c) 2022 dongaba
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
		$global:currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$global:currentDir = Convert-Path .
	}
	Set-Location $global:currentDir
	$global:confDir = $(Join-Path $global:currentDir '..\conf')
	$global:sysFile = $(Join-Path $global:confDir 'system_setting.conf')
	$global:confFile = $(Join-Path $global:confDir 'user_setting.conf')
	$global:devDir = $(Join-Path $global:currentDir '..\dev')
	$global:devConfFile = $(Join-Path $global:devDir 'dev_setting.conf')
	$global:devFunctionFile = $(Join-Path $global:devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $global:sysFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression
	Get-Content $global:confFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $global:devConfFile) {
		Get-Content $global:devConfFile -Encoding UTF8 `
		| Where-Object { $_ -notmatch '^\s*$' } `
		| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
		| Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $global:currentDir '.\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $global:currentDir '.\tver_functions_5.ps1'))
		if (Test-Path $global:devFunctionFile) { 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  PowerShell Coreではありません                         ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	} else {
		. $(Convert-Path (Join-Path $global:currentDir '.\common_functions.ps1'))
		. $(Convert-Path (Join-Path $global:currentDir '.\tver_functions.ps1'))
		if (Test-Path $global:devFunctionFile) { 
			. $global:devFunctionFile 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  開発ファイルを読み込みました                          ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Host ''
Write-Host '===========================================================================' -ForegroundColor Cyan
Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  TVerRec : TVerビデオダウンローダ                                         ' -ForegroundColor Cyan
Write-Host "                      一括ダウンロード版 version. $global:appVersion              " -ForegroundColor Cyan
Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '===========================================================================' -ForegroundColor Cyan
Write-Host ''

#----------------------------------------------------------------------
#動作環境チェック
checkLatestYtdlp					#yt-dlpの最新化チェック
checkLatestFfmpeg					#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック
#checkGeoIP							#日本のIPアドレスでないと接続不可のためIPアドレスをチェック

$local:keywordNames = loadKeywordList			#ダウンロード対象ジャンルリストの読み込み

$local:timer = [System.Diagnostics.Stopwatch]::StartNew()
$local:keywordNum = 0						#キーワードの番号
if ($global:keywordNames -is [array]) {
	$local:keywordTotal = $global:keywordNames.Length	#トータルキーワード数
} else { $local:keywordTotal = 1 }

#======================================================================
#個々のジャンルページチェックここから
foreach ($local:keywordName in $local:keywordNames) {

	#ジャンルページチェックタイトルの表示
	Write-Host ''
	Write-Host '==========================================================================='
	Write-Host "【 $local:keywordName 】 のダウンロードを開始します。"
	Write-Host '==========================================================================='

	$local:keywordNum = $local:keywordNum + 1		#キーワード数のインクリメント

	if ($local:timer.Elapsed.TotalMilliseconds -ge 1000) {
		Write-Progress `
			-Id 1 `
			-Activity "$($local:keywordNum)/$($local:keywordTotal)" `
			-PercentComplete $($( $local:keywordNum / $local:keywordTotal ) * 100) `
			-Status 'キーワードの動画を取得中'
		$local:timer.Reset(); $local:timer.Start()
	}

	getToken
	$local:videoLinks = getVideoLinksFromKeyword ($local:keywordName)
	$local:keywordName = $local:keywordName.Replace('https://tver.jp/', '').Replace('http://tver.jp/', '')

	$local:videoNum = 0						#ジャンル内の処理中のビデオの番号
	if ($local:videoLinks -is [array]) {
		$local:videoTotal = $local:videoLinks.Length	#ジャンル内のトータルビデオ数
	} else { $local:videoTotal = 1 }

	#----------------------------------------------------------------------
	#個々のビデオダウンロードここから
	foreach ($local:videoLink in $local:videoLinks) {

		#いろいろ初期化
		$local:videoNum = $local:videoNum + 1		#ジャンル内のビデオ番号のインクリメント
		$local:videoPageURL = ''

		if ($local:timer.Elapsed.TotalMilliseconds -ge 1000) {
			Write-Progress `
				-Id 2 `
				-ParentId 1 `
				-Activity "$($local:videoNum)/$($local:videoTotal)" `
				-PercentComplete $($( $local:videoNum / $local:videoTotal ) * 100) `
				-Status $local:keywordName
			$local:timer.Reset(); $local:timer.Start()
		}

		Write-Host '----------------------------------------------------------------------'
		Write-Host "[ $local:keywordName - $local:videoNum / $local:videoTotal ] をダウンロードします。 ($(getTimeStamp))"
		Write-Host '----------------------------------------------------------------------'

		#保存先ディレクトリの存在確認
		if (Test-Path $global:downloadBaseDir -PathType Container) {}
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します' -ForegroundColor Green ; exit 1 }

		#yt-dlpプロセスの確認と、yt-dlpのプロセス数が多い場合の待機
		waitTillYtdlpProcessGetFewer $global:parallelDownloadFileNum

		$local:videoPageURL = 'https://tver.jp' + $local:videoLink
		Write-Host $local:videoPageURL

		downloadTVerVideo $local:keywordName $local:videoPageURL $local:videoLink				#TVerビデオダウンロードのメイン処理

		Start-Sleep -Seconds 1
	}
	#----------------------------------------------------------------------

}
#======================================================================

#yt-dlpのプロセスが終わるまで待機
waitTillYtdlpProcessIsZero

Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '処理を終了しました。                                                       ' -ForegroundColor Cyan
Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
