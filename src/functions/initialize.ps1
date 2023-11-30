###################################################################################
#
#		関数読み込みスクリプト
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
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#設定ファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
$script:devDir = Join-Path $script:scriptRoot '../dev'

try { . (Convert-Path (Join-Path $script:confDir 'system_setting.ps1')) }
catch { Write-Error ('❗ システム設定ファイルの読み込みに失敗しました') ; exit 1 }

if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	catch { Write-Error ('❗ ユーザ設定ファイルの読み込みに失敗しました') ; exit 1 }
} elseif ($IsWindows) {
	Write-Output ('ユーザ設定ファイルを作成する必要があります')
	try { . 'gui/gui_setting.ps1' }
	catch { Write-Error ('❗ 設定画面の起動に失敗しました') ; exit 1 }
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
		catch { Write-Error ('❗ ユーザ設定ファイルの読み込みに失敗しました') ; exit 1 }
	}
} else { Write-Error ('❗ ユーザ設定が完了してません') ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/tverrec_functions.ps1'))
} catch { Write-Error ('❗ 外部関数ファイルの読み込みに失敗しました') ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$script:devFunctionFile = Join-Path $script:devDir 'dev_funcitons.ps1'
	$script:devConfFile = Join-Path $script:devDir 'dev_setting.ps1'
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Write-Warning ('💡 開発ファイル用共通関数ファイルを読み込みました')
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Write-Warning ('💡 開発ファイル用設定ファイルを読み込みました')
	}
} catch { Write-Error ('❗ 開発用設定ファイルの読み込みに失敗しました') ; exit 1 }

#----------------------------------------------------------------------
#ダウンロード対象キーワードのパス
$script:keywordFileSamplePath = Join-Path $script:sampleDir 'keyword.sample.conf'
$script:keywordFilePath = Join-Path $script:confDir 'keyword.conf'

#ダウンロード対象外番組のパス
$script:ignoreFileSamplePath = Join-Path $script:sampleDir 'ignore.sample.conf'
$script:ignoreFilePath = Join-Path $script:confDir 'ignore.conf'
$script:ignoreLockFilePath = Join-Path $script:lockDir 'ignore.lock'

#ダウンロード履歴のパス
$script:histFilePath = Join-Path $script:dbDir 'history.csv'
$script:histFileSamplePath = Join-Path $script:sampleDir 'history.sample.csv'
$script:histLockFilePath = Join-Path $script:lockDir 'history.lock'

#ダウンロードリストのパス
$script:listFilePath = Join-Path $script:listDir 'list.csv'
$script:listFileSamplePath = Join-Path $script:sampleDir 'list.sample.csv'
$script:listLockFilePath = Join-Path $script:lockDir 'list.lock'

#ffpmegで番組検証時のエラーファイルのパス
$script:ffpmegErrorLogPath = Join-Path $script:dbDir ('ffmpeg_error_{0}.log' -f $PID)

#youtube-dlのパス
if ($IsWindows) { $script:ytdlPath = Join-Path $script:binDir 'youtube-dl.exe' }
else { $script:ytdlPath = Join-Path $script:binDir 'youtube-dl' }

#ffmpegのパス
if ($IsWindows) { $script:ffmpegPath = Join-Path $script:binDir 'ffmpeg.exe' }
else { $script:ffmpegPath = Join-Path $script:binDir 'ffmpeg' }

#ffprobeのパス
if ($IsWindows) { $script:ffprobePath = Join-Path $script:binDir 'ffprobe.exe' }
else { $script:ffprobePath = Join-Path $script:binDir 'ffprobe' }

#GUI起動を判定
if ( $script:myInvocation.ScriptName.Contains('gui')) {
	#TVerRecの最新化チェック
	Invoke-TVerRecUpdateCheck
	if (!$?) { exit 1 }
} else {
	if (!$script:guiMode) {
		[Console]::ForegroundColor = 'Red'
		Write-Output ('')
		Write-Output ('===========================================================================')
		Write-Output ('                                                                           ')
		Write-Output ('        ████████ ██    ██ ███████ ██████  ██████  ███████  ██████          ')
		Write-Output ('           ██    ██    ██ ██      ██   ██ ██   ██ ██      ██               ')
		Write-Output ('           ██    ██    ██ █████   ██████  ██████  █████   ██               ')
		Write-Output ('           ██     ██  ██  ██      ██   ██ ██   ██ ██      ██               ')
		Write-Output ('           ██      ████   ███████ ██   ██ ██   ██ ███████  ██████          ')
		Write-Output ('                                                                           ')
		Write-Output ("{0,$(56 - $script:appVersion.Length)}Version. {1}" -f ' ', $script:appVersion)
		Write-Output ('                                                                           ')
		Write-Output ('===========================================================================')
		Write-Output ('')
		[Console]::ResetColor()
	}

	#youtube-dl/ffmpegの最新化チェック
	if (!$script:disableUpdateYoutubedl) { Invoke-ToolUpdateCheck -scriptName 'update_youtube-dl.ps1' -targetName 'youtube-dl' }
	if (!$script:disableUpdateFfmpeg) { Invoke-ToolUpdateCheck -scriptName 'update_ffmpeg.ps1' -targetName 'ffmpeg' }

	#TVerRecの最新化チェック
	if ($script:appName -eq 'TVerRec') {
		Invoke-TVerRecUpdateCheck
		if (!$?) { exit 1 }
	}

}
