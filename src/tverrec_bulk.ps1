###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		一括ダウンロード処理スクリプト
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
using namespace System.Text.RegularExpressions

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$script:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$script:scriptRoot = Convert-Path .
	}
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '..\conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '..\dev')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting_5.ps1'))
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting_5.ps1'))
		. $script:sysFile
		. $script:confFile
	} else {
		$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:sysFile
		. $script:confFile
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\tver_functions_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\common_functions.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\tver_functions.ps1'))
	}

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons_5.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting_5.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '  開発ファイル用共通関数ファイルを読み込みました' white DarkGreen
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '  開発ファイル用設定ファイルを読み込みました' white DarkGreen
		}
	} else {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '  開発ファイル用共通関数ファイルを読み込みました' white DarkGreen
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '  開発ファイル用設定ファイルを読み込みました' white DarkGreen
		}
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-ColorOutput ''
Write-ColorOutput '===========================================================================' Cyan
Write-ColorOutput '---------------------------------------------------------------------------' Cyan
Write-ColorOutput "  $script:appName : TVerビデオダウンローダ                                 " Cyan
Write-ColorOutput "                      一括ダウンロード版 version. $script:appVersion       " Cyan
Write-ColorOutput '---------------------------------------------------------------------------' Cyan
Write-ColorOutput '===========================================================================' Cyan
Write-ColorOutput ''

#----------------------------------------------------------------------
#動作環境チェック
checkLatestTVerRec			#TVerRecの最新化チェック
checkLatestYtdl				#youtube-dlの最新化チェック
checkLatestFfmpeg			#ffmpegの最新化チェック
checkRequiredFile			#設定で指定したファイル・フォルダの存在チェック
#checkGeoIP					#日本のIPアドレスでないと接続不可のためIPアドレスをチェック

$local:keywordNames = loadKeywordList			#ダウンロード対象ジャンルリストの読み込み

$local:timer = [System.Diagnostics.Stopwatch]::StartNew()
$local:keywordNum = 0						#キーワードの番号
if ($script:keywordNames -is [array]) {
	$local:keywordTotal = $script:keywordNames.Length	#トータルキーワード数
} else { $local:keywordTotal = 1 }

#======================================================================
#個々のジャンルページチェックここから
foreach ($local:keywordName in $local:keywordNames) {

	#ジャンルページチェックタイトルの表示
	Write-ColorOutput ''
	Write-ColorOutput '==========================================================================='
	Write-ColorOutput "【 $(trimTabSpace ($local:keywordName)) 】 のダウンロードを開始します。"
	Write-ColorOutput '==========================================================================='

	$local:keywordNum = $local:keywordNum + 1		#キーワード数のインクリメント

	if ($local:timer.Elapsed.TotalMilliseconds -ge 1000) {
		Write-Progress -Id 1 `
			-Activity "$($local:keywordNum)/$($local:keywordTotal)" `
			-PercentComplete $($( $local:keywordNum / $local:keywordTotal ) * 100) `
			-Status 'キーワードの動画を取得中'
		$local:timer.Reset(); $local:timer.Start()
	}

	$local:videoLinks = getVideoLinksFromKeyword ($local:keywordName)
	$local:keywordName = $local:keywordName.Replace('https://tver.jp/', '')

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

		Write-ColorOutput '----------------------------------------------------------------------'
		Write-ColorOutput "[ $local:keywordName - $local:videoNum / $local:videoTotal ] をダウンロードします。 ($(getTimeStamp))"
		Write-ColorOutput '----------------------------------------------------------------------'

		#保存先ディレクトリの存在確認
		if (Test-Path $script:downloadBaseDir -PathType Container) { }
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します' Green ; exit 1 }

		#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum

		$local:videoPageURL = 'https://tver.jp' + $local:videoLink
		Write-ColorOutput $local:videoPageURL

		#TVerビデオダウンロードのメイン処理
		downloadTVerVideo $local:keywordName $local:videoPageURL $local:videoLink

		Start-Sleep -Seconds 1
	}
	#----------------------------------------------------------------------

}
#======================================================================

#youtube-dlのプロセスが終わるまで待機
Write-ColorOutput 'ダウンロードの終了を待機しています'
waitTillYtdlProcessIsZero

Write-ColorOutput '---------------------------------------------------------------------------' Cyan
Write-ColorOutput '処理を終了しました。                                                       ' Cyan
Write-ColorOutput '---------------------------------------------------------------------------' Cyan
