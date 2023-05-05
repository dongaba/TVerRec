###################################################################################
#  TVerRec : TVerダウンローダ
#
#		リストダウンロード処理スクリプト
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
	} else { $script:scriptRoot = Convert-Path . }
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '../conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '../dev')
} catch { Write-Error 'ディレクトリ設定に失敗しました' ; exit 1 }

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
		Write-Warning '開発ファイル用共通関数ファイルを読み込みました'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Write-Warning '開発ファイル用設定ファイルを読み込みました'
	}
} catch { Write-Error '開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
[Console]::ForegroundColor = 'Cyan'
Write-Output ''
Write-Output '==========================================================================='
Write-Output '                                                                           '
Write-Output '        ████████ ██    ██ ███████ ██████  ██████  ███████  ██████          '
Write-Output '           ██    ██    ██ ██      ██   ██ ██   ██ ██      ██               '
Write-Output '           ██    ██    ██ █████   ██████  ██████  █████   ██               '
Write-Output '           ██     ██  ██  ██      ██   ██ ██   ██ ██      ██               '
Write-Output '           ██      ████   ███████ ██   ██ ██   ██ ███████  ██████          '
Write-Output '                                                                           '
Write-Output "        $script:appName : TVerダウンローダ                                 "
Write-Output "                             リストダウンロード version. $script:appVersion  "
Write-Output '                                                                           '
Write-Output '==========================================================================='
Write-Output ''
[Console]::ResetColor()

#----------------------------------------------------------------------
#TVerRecの最新化チェック
checkLatestTVerRec
#youtube-dlの最新化チェック
checkLatestYtdl
#ffmpegの最新化チェック
checkLatestFfmpeg

#設定ファイル再読み込み
try {
	$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
	. $script:sysFile
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:confFile
	}
} catch { Write-Error '設定ファイルの再読み込みに失敗しました' ; exit 1 }

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#いろいろ初期化
$local:videoLink = '　'
$local:videoLinks = @()

#リスト内の処理中の番組の番号
$local:videoNum = 0

#処理
$local:keywordName = 'リスト指定'
#ダウンロード対象外番組の読み込み
$script:ignoreRegExTitles = getRegExIgnoreList

getToken

Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロードリストを読み込みます'
$local:listLinks = loadDownloadList
Write-Output "　リスト件数$($local:listLinks.Length)件"
Write-Output ''

Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロード履歴を読み込みます'
#ダウンロード履歴ファイルのデータを読み込み
try {
	#ロックファイルをロック
	while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
	{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
	#ファイル操作
	$script:historyFileData = `
		Import-Csv `
		-Path $script:historyFilePath `
		-Encoding UTF8
} catch { Write-Warning 'ダウンロード履歴を読み込めなかったのでスキップしました'; continue
} finally { $null = fileUnlock $script:historyLockFilePath }
Write-Output ''

Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロード履歴に含まれる番組を除外します'
#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
foreach ($local:listLink in $local:listLinks.episodeID) {
	$local:historyMatch = $script:historyFileData `
	| Where-Object { $_.videoPage -eq $($local:listLink) }
	if ($null -eq $local:historyMatch) { $local:videoLinks += $local:listLink }
}
#ダウンロード対象のトータル番組数
$local:videoTotal = $local:videoLinks.Length
Write-Output "　ダウンロード対象$($local:videoTotal)件"
Write-Output ''


#処理時間の推計
$local:totalStartTime = Get-Date
$local:secRemaining = -1

#進捗表示
showProgressToast `
	-Text1 'リストからの番組のダウンロード' `
	-Text2 'リストファイルから番組をダウンロード' `
	-WorkDetail '読み込み中...' `
	-Duration 'long' `
	-Silent $false `
	-Tag $script:appName `
	-Group 'List'

#----------------------------------------------------------------------
#個々の番組ダウンロードここから
foreach ($local:videoLink in $local:videoLinks) {
	#ジャンル内の番組番号のインクリメント
	$local:videoNum = $local:videoNum + 1

	#移動先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (Test-Path $script:downloadBaseDir -PathType Container) {}
	else { Write-Error '番組ダウンロード先ディレクトリにアクセスできません。終了します' ; exit 1 }

	#進捗率の計算
	$local:progressRatio = $($local:videoNum / $local:videoTotal)
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:videoNum) * ($local:videoTotal - $local:videoNum)
	$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"

	#進捗更新
	updateProgressToast `
		-Title 'リストからの番組のダウンロード' `
		-Rate $local:progressRatio `
		-LeftText $local:videoNum/$local:videoTotal `
		-RightText $local:minRemaining `
		-Tag $script:appName `
		-Group 'List'

	#処理
	Write-Output '--------------------------------------------------'
	Write-Output "$($local:videoNum)/$($local:videoTotal) - https://tver.jp/episodes/$($local:videoLink)"

	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum

	#TVer番組ダウンロードのメイン処理
	downloadTVerVideo `
		-Keyword $local:keywordName `
		-URL $('https://tver.jp/episodes/' + $local:videoLink) `
		-Link $('/episodes/' + $local:videoLink)

}
#----------------------------------------------------------------------

#進捗表示
updateProgressToast `
	-Title 'リストからの番組のダウンロード' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'List'

#youtube-dlのプロセスが終わるまで待機
Write-Output 'ダウンロードの終了を待機しています'
Write-Output ''
waitTillYtdlProcessIsZero

Write-Output '---------------------------------------------------------------------------'
Write-Output '処理を終了しました。                                                       '
Write-Output '---------------------------------------------------------------------------'
Write-Output '必要に応じてリストファイルを編集してダウンロード不要な番組を削除してください'
Write-Output "　リストファイルパス: $($script:listFilePath)"
