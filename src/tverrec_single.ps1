###################################################################################
#  TVerRec : TVerビデオダウンローダ
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
	#設定ファイル読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:sysFile = $(Join-Path $script:confDir 'system_setting_5.ps1')
		. $script:sysFile
		if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
			$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting_5.ps1'))
			. $script:confFile
		}
	} else {
		$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
		. $script:sysFile
		if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
			$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
			. $script:confFile
		}
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions.ps1'))
	}

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons_5.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting_5.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '開発ファイル用共通関数ファイルを読み込みました' -FgColor 'Yellow'
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '開発ファイル用設定ファイルを読み込みました' -FgColor 'Yellow'
		}
	} else {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '開発ファイル用共通関数ファイルを読み込みました' -FgColor 'Yellow'
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '開発ファイル用設定ファイルを読み込みました' -FgColor 'Yellow'
		}
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-ColorOutput ''
Write-ColorOutput '===========================================================================' -FgColor 'Cyan'
Write-ColorOutput '                                                                           ' -FgColor 'Cyan'
Write-ColorOutput '        ████████ ██    ██ ███████ ██████  ██████  ███████  ██████          ' -FgColor 'Cyan'
Write-ColorOutput '           ██    ██    ██ ██      ██   ██ ██   ██ ██      ██               ' -FgColor 'Cyan'
Write-ColorOutput '           ██    ██    ██ █████   ██████  ██████  █████   ██               ' -FgColor 'Cyan'
Write-ColorOutput '           ██     ██  ██  ██      ██   ██ ██   ██ ██      ██               ' -FgColor 'Cyan'
Write-ColorOutput '           ██      ████   ███████ ██   ██ ██   ██ ███████  ██████          ' -FgColor 'Cyan'
Write-ColorOutput '                                                                           ' -FgColor 'Cyan'
Write-ColorOutput "        $script:appName : TVerビデオダウンローダ                           " -FgColor 'Cyan'
Write-ColorOutput "                             個別ダウンロード版 version. $script:appVersion" -FgColor 'Cyan'
Write-ColorOutput '                                                                           ' -FgColor 'Cyan'
Write-ColorOutput '===========================================================================' -FgColor 'Cyan'
Write-ColorOutput ''

#----------------------------------------------------------------------
#動作環境チェック
checkLatestTVerRec			#TVerRecの最新化チェック
checkLatestYtdl				#youtube-dlの最新化チェック
checkLatestFfmpeg			#ffmpegの最新化チェック
checkRequiredFile			#設定で指定したファイル・フォルダの存在チェック

#処理
$local:keywordName = 'URL指定'
$script:ignoreTitles = getIgnoreList		#ダウンロード対象外番組リストの読み込み
getToken

#無限ループ
while ($true) {
	#いろいろ初期化
	$local:videoPageURL = ''

	#保存先ディレクトリの存在確認(稼働中に共有フォルダが切断された場合に対応)
	if (Test-Path $script:downloadBaseDir -PathType Container) { }
	else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します' ; exit 1 }

	#youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	waitTillYtdlProcessGetFewer $script:parallelDownloadFileNum

	$local:videoPageURL = Read-Host 'ビデオURLを入力してください。何も入力しないで Enter を押すと終了します。'
	if ($videoPageURL -ne '') {
		$local:videoLink = $local:videoPageURL.Replace('https://tver.jp', '').Trim()
		$local:videoPageURL = 'https://tver.jp' + $local:videoLink
		Write-ColorOutput $local:videoPageURL

		#TVerビデオダウンロードのメイン処理
		downloadTVerVideo `
			-Keyword $local:keywordName `
			-URL $local:videoPageURL `
			-Link $local:videoLink
	} else {
		Write-ColorOutput '---------------------------------------------------------------------------' -FgColor 'Cyan'
		Write-ColorOutput '処理を終了しました。                                                       ' -FgColor 'Cyan'
		Write-ColorOutput '---------------------------------------------------------------------------' -FgColor 'Cyan'
		exit
	}
}
