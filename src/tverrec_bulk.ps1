###################################################################################
#  TVerRec : TVerダウンローダ
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
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '../conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '../dev')
} catch {
	Write-Error 'ディレクトリ設定に失敗しました' ; exit 1
}

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
	. $script:sysFile
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:confFile
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
} catch { Write-Error '外部関数ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Out-Msg '開発ファイル用共通関数ファイルを読み込みました' -Fg 'Yellow'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Out-Msg '開発ファイル用設定ファイルを読み込みました' -Fg 'Yellow'
	}
} catch { Write-Error '開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Out-Msg ''
Out-Msg '===========================================================================' -Fg 'Cyan'
Out-Msg '                                                                           ' -Fg 'Cyan'
Out-Msg '        ████████ ██    ██ ███████ ██████  ██████  ███████  ██████          ' -Fg 'Cyan'
Out-Msg '           ██    ██    ██ ██      ██   ██ ██   ██ ██      ██               ' -Fg 'Cyan'
Out-Msg '           ██    ██    ██ █████   ██████  ██████  █████   ██               ' -Fg 'Cyan'
Out-Msg '           ██     ██  ██  ██      ██   ██ ██   ██ ██      ██               ' -Fg 'Cyan'
Out-Msg '           ██      ████   ███████ ██   ██ ██   ██ ███████  ██████          ' -Fg 'Cyan'
Out-Msg '                                                                           ' -Fg 'Cyan'
Out-Msg "        $script:appName : TVerダウンローダ                                 " -Fg 'Cyan'
Out-Msg "                             一括ダウンロード version. $script:appVersion  " -Fg 'Cyan'
Out-Msg '                                                                           ' -Fg 'Cyan'
Out-Msg '===========================================================================' -Fg 'Cyan'
Out-Msg ''

#----------------------------------------------------------------------
#動作環境チェック
checkLatestTVerRec			#TVerRecの最新化チェック
checkLatestYtdl				#youtube-dlの最新化チェック
checkLatestFfmpeg			#ffmpegの最新化チェック
checkRequiredFile			#設定で指定したファイル・フォルダの存在チェック

#処理
$local:keywordNames = loadKeywordList		#ダウンロード対象キーワードの読み込み
$script:ignoreTitles = getIgnoreList		#ダウンロード対象外番組の読み込み
getToken

$local:keywordNum = 0						#キーワードの番号
if ($script:keywordNames -is [Array]) { $local:keywordTotal = $script:keywordNames.Length }		#トータルキーワード数
else { $local:keywordTotal = 1 }

#進捗表示
showProgress2Row `
	-ProgressText1 '一括ダウンロード中' `
	-ProgressText2 'キーワードから番組を抽出しダウンロード' `
	-WorkDetail1 '読み込み中...' `
	-WorkDetail2 '読み込み中...' `
	-Duration 'long' `
	-Silent $false `
	-Group 'Bulk'

#======================================================================
#個々のジャンルページチェックここから
$local:totalStartTime = Get-Date
foreach ($local:keywordName in $local:keywordNames) {
	#いろいろ初期化
	$local:videoLink = '　'
	$local:videoLinks = @()
	$local:searchResultCount = 0

	#ジャンルページチェックタイトルの表示
	Out-Msg ''
	Out-Msg '----------------------------------------------------------------------'
	Out-Msg "$(trimTabSpace ($local:keywordName))"
	Out-Msg '----------------------------------------------------------------------'

	#処理
	$local:resultLinks = getVideoLinksFromKeyword ($local:keywordName)
	$local:keywordName = $local:keywordName.Replace('https://tver.jp/', '')

	#ダウンロード履歴ファイルのデータを読み込み
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$script:historyFileData = `
			Import-Csv `
			-Path $script:historyFilePath `
			-Encoding UTF8
	} catch {
		Out-Msg '　ダウンロード履歴を読み込めなかったのでスキップしました' -Fg 'Green'
		continue
	} finally { $null = fileUnlock $script:historyLockFilePath }

	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	foreach ($local:resultLink in $local:resultLinks) {
		$local:historyMatch = $script:historyFileData | Where-Object { $_.videoPage -eq $local:resultLink }
		if ($null -eq $local:historyMatch) { $local:videoLinks += $local:resultLink }
		else { $local:searchResultCount = $local:searchResultCount + 1
			continue
		}
	}

	$local:videoNum = 0								#ジャンル内の処理中の番組の番号
	$local:videoTotal = $local:videoLinks.Length	#ダウンロード対象のトータル番組数
	Out-Msg "　ダウンロード対象$($local:videoTotal)本 処理済$($local:searchResultCount)本" -Fg 'Gray'

	#処理時間の推計
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining1 = -1
	if ($local:keywordNum -ne 0) {
		$local:secRemaining1 = ($local:secElapsed.TotalSeconds / $local:keywordNum) * ($local:keywordTotal - $local:keywordNum)
	}
	$local:progressRatio1 = $($local:keywordNum / $local:keywordTotal)
	$local:progressRatio2 = 0

	$local:keywordNum = $local:keywordNum + 1		#キーワード数のインクリメント

	#進捗更新
	updateProgress2Row `
		-ProgressActivity1 $local:keywordNum/$local:keywordTotal `
		-CurrentProcessing1 $(trimTabSpace ($local:keywordName)) `
		-Rate1 $local:progressRatio1 `
		-SecRemaining1 $local:secRemaining1 `
		-ProgressActivity2 '' `
		-CurrentProcessing2 $local:videoLink `
		-Rate2 $local:progressRatio2 `
		-SecRemaining2 '' `
		-Group 'Bulk'

	#----------------------------------------------------------------------
	#個々の番組ダウンロードここから
	foreach ($local:videoLink in $local:videoLinks) {
		#いろいろ初期化
		$local:videoNum = $local:videoNum + 1		#ジャンル内の番組番号のインクリメント

		#保存先ディレクトリの存在確認(稼働中に共有フォルダが切断された場合に対応)
		if (Test-Path $script:downloadBaseDir -PathType Container) { }
		else { Write-Error '番組ダウンロード先フォルダにアクセスできません。終了します' ; exit 1 }

		#進捗率の計算
		$local:progressRatio2 = $($local:videoNum / $local:videoTotal)

		#進捗更新
		updateProgress2Row `
			-ProgressActivity1 $local:keywordNum/$local:keywordTotal `
			-CurrentProcessing1 $(trimTabSpace ($local:keywordName)) `
			-Rate1 $local:progressRatio1 `
			-SecRemaining1 $local:secRemaining1 `
			-ProgressActivity2 $local:videoNum/$local:videoTotal `
			-CurrentProcessing2 $local:videoLink `
			-Rate2 $local:progressRatio2 `
			-SecRemaining2 '' `
			-Group 'Bulk'

		#処理
		Out-Msg '--------------------------------------------------'
		Out-Msg "$($local:videoNum)/$($local:videoTotal) - $local:videoLink" -NoNL $true

		#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum

		#TVer番組ダウンロードのメイン処理
		downloadTVerVideo `
			-Keyword $local:keywordName `
			-URL $local:videoLink `
			-Link $local:videoLink.Replace('https://tver.jp', '')

	}
	#----------------------------------------------------------------------

}
#======================================================================

#進捗表示
updateProgressToast2 `
	-Title1 'キーワードから番組の抽出' `
	-Rate1 '1' `
	-LeftText1 '' `
	-RightText1 '完了' `
	-Title2 '番組のダウンロード' `
	-Rate2 '1' `
	-LeftText2 '' `
	-RightText2 '完了' `
	-Tag $script:appName `
	-Group 'Bulk'

#youtube-dlのプロセスが終わるまで待機
Out-Msg 'ダウンロードの終了を待機しています'
waitTillYtdlProcessIsZero

Out-Msg '---------------------------------------------------------------------------' -Fg 'Cyan'
Out-Msg '処理を終了しました。                                                       ' -Fg 'Cyan'
Out-Msg '---------------------------------------------------------------------------' -Fg 'Cyan'
