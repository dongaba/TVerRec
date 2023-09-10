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

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	. $(Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		. $(Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
	} elseif ($IsWindows) {
		while (!( Test-Path $(Join-Path $script:confDir 'user_setting.ps1')) ) {
			Write-Output 'ユーザ設定ファイルを作成する必要があります'
			. 'gui/gui_setting.ps1'
		}
		if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
			. $(Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
		}
	} else {
		Write-Error '❗ ユーザ設定が完了してません' ; exit 1
	}
} catch { Write-Error '❗ 設定ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
} catch { Write-Error '❗ 外部関数ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Write-Warning '💡 開発ファイル用共通関数ファイルを読み込みました'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Write-Warning '💡 開発ファイル用設定ファイルを読み込みました'
	}
} catch { Write-Error '❗ 開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#GUI起動を判定
if ( $script:myInvocation.ScriptName.Contains('gui')) {
	#TVerRecの最新化チェック
	checkLatestTVerRec
	if ($? -eq $false) { exit 1 }
} else {
	[Console]::ForegroundColor = 'Red'
	$versionBanner = ' ' * $(56 - $script:appVersion.Length) + "Version. $script:appVersion"
	Write-Output ''
	Write-Output '==========================================================================='
	Write-Output '                                                                           '
	Write-Output '        ████████ ██    ██ ███████ ██████  ██████  ███████  ██████          '
	Write-Output '           ██    ██    ██ ██      ██   ██ ██   ██ ██      ██               '
	Write-Output '           ██    ██    ██ █████   ██████  ██████  █████   ██               '
	Write-Output '           ██     ██  ██  ██      ██   ██ ██   ██ ██      ██               '
	Write-Output '           ██      ████   ███████ ██   ██ ██   ██ ███████  ██████          '
	Write-Output '                                                                           '
	Write-Output "$versionBanner"
	Write-Output '                                                                           '
	Write-Output '==========================================================================='
	Write-Output ''
	[Console]::ResetColor()

	#youtube-dlの最新化チェック
	checkLatestYtdl

	#ffmpegの最新化チェック
	checkLatestFfmpeg

	#TVerRecの最新化チェック
	if ($script:appName -eq 'TVerRec') {
		checkLatestTVerRec
		if ($? -eq $false) { exit 1 }
	}

}
