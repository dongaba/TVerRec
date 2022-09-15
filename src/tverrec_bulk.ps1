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
		$script:scriptName = Split-Path -Leaf -Path $MyInvocation.MyCommand.Definition
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
			Write-ColorOutput '　開発ファイル用共通関数ファイルを読み込みました' white DarkGreen
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '　開発ファイル用設定ファイルを読み込みました' white DarkGreen
		}
	} else {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '　開発ファイル用共通関数ファイルを読み込みました' white DarkGreen
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '　開発ファイル用設定ファイルを読み込みました' white DarkGreen
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
#checkGeoIP					#GEO IPのチェック

#処理
$local:keywordNames = loadKeywordList			#ダウンロード対象ジャンルリストの読み込み

$local:keywordNum = 0						#キーワードの番号
if ($script:keywordNames -is [array]) {
	$local:keywordTotal = $script:keywordNames.Length	#トータルキーワード数
} else { $local:keywordTotal = 1 }

#進捗表示
ShowProgess2Row `
	'一括ダウンロード中' `
	'キーワードから動画を抽出しダウンロード' `
	'読み込み中...' `
	'読み込み中...' `
	'long' `
	$false `
	'Bulk'


#======================================================================
#個々のジャンルページチェックここから
$local:totalStartTime = Get-Date
foreach ($local:keywordName in $local:keywordNames) {
	#いろいろ初期化
	$local:videoLink = '　'

	#ジャンルページチェックタイトルの表示
	Write-ColorOutput ''
	Write-ColorOutput '==========================================================================='
	Write-ColorOutput "【 $(trimTabSpace ($local:keywordName)) 】 のダウンロードを開始します。"
	Write-ColorOutput '==========================================================================='

	#処理
	$local:videoLinks = getVideoLinksFromKeyword ($local:keywordName)
	$local:keywordName = $local:keywordName.Replace('https://tver.jp/', '')

	$local:videoNum = 0						#ジャンル内の処理中のビデオの番号
	if ($local:videoLinks -is [array]) {
		$local:videoTotal = $local:videoLinks.Length	#ジャンル内のトータルビデオ数
	} else { $local:videoTotal = 1 }

	#処理時間の推計
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining1 = -1
	if ($local:keywordNum -ne 0) {
		$local:secRemaining1 = ($local:secElapsed.TotalSeconds / $local:keywordNum) * ($local:keywordTotal - $local:keywordNum)
		$local:progressRatio1 = $($local:keywordNum / $local:keywordTotal)
	} else {
		$local:progressRatio1 = 0
	}
	$local:progressRatio2 = 0

	$local:keywordNum = $local:keywordNum + 1		#キーワード数のインクリメント

	#進捗更新
	UpdateProgess2Row `
		"$($local:keywordNum)/$($local:keywordTotal)" `
		"$($local:keywordName)" `
		"$($local:progressRatio1)" `
		$local:secRemaining1 `
		'' `
		"$($local:videoLink)" `
		"$($local:progressRatio2)" `
		'' `
		'Bulk'


	#----------------------------------------------------------------------
	#個々のビデオダウンロードここから
	foreach ($local:videoLink in $local:videoLinks) {
		#いろいろ初期化
		$local:videoPageURL = ''
		$local:videoNum = $local:videoNum + 1		#ジャンル内のビデオ番号のインクリメント

		#進捗率の計算
		if ($local:keywordNum -ne 0) {
			$local:progressRatio2 = $($local:videoNum / $local:videoTotal)
		} else {
			$local:progressRatio2 = 0
		}

		#進捗更新
		UpdateProgess2Row `
			"$($local:keywordNum)/$($local:keywordTotal)" `
			"$($local:keywordName)" `
			"$($local:progressRatio1)" `
			$local:secRemaining1 `
			"$($local:videoNum)/$($local:videoTotal)" `
			"$($local:videoLink)" `
			"$($local:progressRatio2)" `
			'' `
			'Bulk'


		#処理
		Write-ColorOutput '----------------------------------------------------------------------'
		Write-ColorOutput "[ $local:keywordName - $local:videoNum / $local:videoTotal ] をダウンロードします。 ($(getTimeStamp))"
		Write-ColorOutput '----------------------------------------------------------------------'

		#保存先ディレクトリの存在確認(稼働中に共有フォルダが切断された場合に対応)
		if (Test-Path $script:downloadBaseDir -PathType Container) { }
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します' Green ; exit 1 }

		#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum

		$local:videoPageURL = 'https://tver.jp' + $local:videoLink
		Write-ColorOutput $local:videoPageURL

		#TVerビデオダウンロードのメイン処理
		downloadTVerVideo $local:keywordName $local:videoPageURL $local:videoLink

		Start-Sleep -Seconds 0.5
	}
	#----------------------------------------------------------------------

}
#======================================================================

#進捗表示
UpdateProgessToast2 `
	'キーワードから動画の抽出' '1' `
	'' '完了' `
	'動画のダウンロード' '1' `
	'' '完了' `
	"$($script:appName)" 'Bulk'

#youtube-dlのプロセスが終わるまで待機
Write-ColorOutput 'ダウンロードの終了を待機しています'
waitTillYtdlProcessIsZero

Write-ColorOutput '---------------------------------------------------------------------------' Cyan
Write-ColorOutput '処理を終了しました。                                                       ' Cyan
Write-ColorOutput '---------------------------------------------------------------------------' Cyan
