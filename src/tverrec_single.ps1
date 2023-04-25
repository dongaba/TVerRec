###################################################################################
#  TVerRec : TVerダウンローダ
#
#		個別ダウンロード処理スクリプト
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
Out-Msg "                             個別ダウンロード version. $script:appVersion  " -Fg 'Cyan'
Out-Msg '                                                                           ' -Fg 'Cyan'
Out-Msg '===========================================================================' -Fg 'Cyan'
Out-Msg ''

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

#処理
$local:keywordName = '個別指定'
#ダウンロード対象外番組の読み込み
$script:ignoreRegExTitles = getRegExIgnoreList

getToken

#無限ループ
while ($true) {
	#いろいろ初期化
	$local:videoPageURL = ''

	#保存先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (Test-Path $script:downloadBaseDir -PathType Container) { }
	else { Write-Error '番組ダウンロード先ディレクトリにアクセスできません。終了します' ; exit 1 }

	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum

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

	$local:videoPageURL = Read-Host '番組URLを入力してください。何も入力しないで Enter を押すと終了します。'
	if ($videoPageURL -ne '') {
		$local:videoLink = $local:videoPageURL.Replace('https://tver.jp', '').Trim()
		$local:videoPageURL = 'https://tver.jp' + $local:videoLink
		Out-Msg $local:videoPageURL

		#TVer番組ダウンロードのメイン処理
		downloadTVerVideo `
			-Keyword $local:keywordName `
			-URL $local:videoPageURL `
			-Link $local:videoLink
	} else {
		Out-Msg '---------------------------------------------------------------------------' -Fg 'Cyan'
		Out-Msg '処理を終了しました。                                                       ' -Fg 'Cyan'
		Out-Msg '---------------------------------------------------------------------------' -Fg 'Cyan'
	}
}
