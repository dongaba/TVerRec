###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		システム設定
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
#	「#」or「;」でコメントアウト
#	このファイルに書かれた内容はそのままPowershellスクリプトとして実行。
#----------------------------------------------------------------------

#アプリケーション名・バージョン番号
$script:appName = "$($script:appName)"
$script:appVersion = Get-Content '..\VERSION'

#Windowsの判定
Set-StrictMode -Off
$script:isWin = $PSVersionTable.Platform -match '^($|(Microsoft)?Win)'
Set-StrictMode -Version Latest

#デバッグレベル
$VerbosePreference = 'SilentlyContinue'						#詳細メッセージなし
$DebugPreference = 'SilentlyContinue'						#デバッグメッセージなし

#ファイルシステムが許容するファイル名の最大長(byte)
$script:fileNameLengthMax = 255

#各種ディレクトリのパス
$script:binDir = $(Join-Path $scriptRoot '..\bin')
$script:dbDir = $(Join-Path $scriptRoot '..\db')
$script:libDir = $(Join-Path $scriptRoot '..\lib')
$script:imgDir = $(Join-Path $scriptRoot '..\img')

#トースト通知用画像のパス
$script:toastAppLogo = Convert-Path (Join-Path $script:imgDir 'TVerRec-Toast.png')

#ダウンロード対象ジャンルリストのパス
$script:keywordFilePath = $(Join-Path $script:confDir 'keyword.conf')

#ダウンロード対象外ビデオリストのパス
$script:ignoreFilePath = $(Join-Path $script:confDir 'ignore.conf')

#ダウンロードリストのパス
$script:listFileBlankPath = $(Join-Path $script:dbDir 'tver-blank.csv')
$script:listFilePath = $(Join-Path $script:dbDir 'tver.csv')
$script:lockFilePath = $(Join-Path $script:dbDir 'tver.lock')

#ffpmegで動画検証時のエラーファイルのパス
$script:ffpmegErrorLogPath = $(Join-Path $script:dbDir "ffmpeg_error_$($PID).log")

#youtube-dlのパス
if ($script:isWin) { $script:ytdlPath = $(Join-Path $script:binDir 'youtube-dl.exe') }
else { $script:ytdlPath = $(Join-Path $script:binDir 'youtube-dl') }

#ffmpegのパス
if ($script:isWin) { $script:ffmpegPath = $(Join-Path $script:binDir 'ffmpeg.exe') }
else { $script:ffmpegPath = $(Join-Path $script:binDir 'ffmpeg') }

#ffprobeのパス
if ($script:isWin) { $script:ffprobePath = $(Join-Path $script:binDir 'ffprobe.exe') }
else { $script:ffprobePath = $(Join-Path $script:binDir 'ffprobe') }

#プログレスバーの表示形式
#$PSStyle.Progress.View = 'Classic'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
	$PSStyle.Progress.MaxWidth = 70
	$PSStyle.Progress.Style = "`e[38;5;123m"
}
