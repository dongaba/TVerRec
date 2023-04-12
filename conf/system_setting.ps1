###################################################################################
#  TVerRec : TVerダウンローダ
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
Set-StrictMode -Off
Set-StrictMode -Version Latest

#----------------------------------------------------------------------
# 基本的な設定
#----------------------------------------------------------------------

#ダウンロード先のフルパス(絶対パス指定)
#　ダウンロード先とは、検証が終わった動画ファイルが配置される場所です。
#　規定の設定ではWドライブが設定されています。(通常のPCではWドライブはありませんので変更が必要です)
#　例えば C:\Users\yamada-taro\Video にダウンロードするのであれば $script:downloadBaseDir = 'C:\Users\yamada-taro\Video' と設定します。
#　MacOSやLinuxでは $script:downloadBaseDir = '/mnt/Work' や $script:downloadBaseDir = '/Volumes/Work' などのように設定します。
$script:downloadBaseDir = 'W:'

#ダウンロード中の作業ディレクトリのフルパス(絶対パス指定)
#　作業ディレクトリは、動画のダウンロード中に処理途中のファイルが配置される場所です。
#　多数のファイルが作成され読み書きが多発するので、SSDやRamDriveなどの高速なディスクを指定すると動作速度が向上します。
#　規定の設定では各ユーザのTempディレクトリ配下が設定されており、Windows環境であれば変更しなくても動作します。
#　例えば C:\Temp にダウンロードするのであれば $script:downloadWorkDir = 'C:\Temp' と設定します。
#　MacOSやLinuxでは $script:downloadWorkDir = '/var/tmp' や $script:downloadWorkDir = '/Volumes/RamDrive/Temp' などのように設定します。
$script:downloadWorkDir = $env:TMP	#$env:TMP = C:\Users\<ユーザ名>\AppData\Local\Temp

#保存先のフルパス(絶対パス指定)
#　保存先とは、動画ファイルを最終的に整理するためのライブラリ等が配置されている場所です。
#　規定の設定ではVドライブが設定されています。(通常のPCではVドライブはありませんので変更が必要です)
#　ダウンロード先のディレクトリで動画を再生するのであれば、適当な空ディレクトリを指定しておいてもOKです。
#　例えば C:\TverLibrary を保存先にするのであれば $script:saveBaseDir = 'C:\TverLibrary' と設定します。
#　MacOSやLinuxでは $script:saveBaseDir = '/var/Video' や $script:saveBaseDir = '/Volumes/RamDrive/Video' などのように設定します。
$script:saveBaseDir = 'V:'

#----------------------------------------------------------------------
# 高度な設定
#----------------------------------------------------------------------

#同時ダウンロードファイル数
$script:parallelDownloadFileNum = 5

#1本の番組あたりの同時ダウンロード数
$script:parallelDownloadNumPerFile = 10

#ダウンロード時に放送局毎のディレクトリ配下にダウンロードファイルを保存
#「$false」の際の保存先は以下
#  ダウンロード先/
#    └番組シリーズ名 番組シーズン名/
#      └番組シリーズ名 番組シーズン名 放送日 番組タイトル名).mp4
#「$true」の際の保存先は以下
#  ダウンロード先/
#    └放送局/
#      └番組シリーズ名 番組シーズン名/
#        └番組シリーズ名 番組シーズン名 放送日 番組タイトル名).mp4
$script:sortVideoByMedia = $false

#ダウンロードファイル名にエピソード番号を付加
#「$false」の場合のファイル名は以下
#  番組シリーズ名 番組シーズン名 放送日 番組タイトル名.mp4
#「$true」の際のファイル名は以下
#  番組シリーズ名 番組シーズン名 放送日 Epエピソード番号 番組タイトル名.mp4
$script:addEpisodeNumber = $false

#番組名に付くことがある不要なコメントを削除
#「$false」の場合はTVerで配信されているとおりに番組名を設定
#「$true」の場合は「《」と「》」で挟まれた部分を削除
#  《ドラマ特区》、《新シリーズ放送記念》、《ドラマParavi》、《〇〇出演 「〇〇」スタート記念》などを除去する目的
$script:removeSpecialNote = $false

#youtube-dlの取得元
$script:preferredYoutubedl = 'yt-dlp'	#'yt-dlp' or 'ytdl-patched'

#youtube-dlの自動アップデートを無効化
$script:disableUpdateYoutubedl = $false

#ffmpegの自動アップデートを無効化
$script:disableUpdateFfmpeg = $false

#ソフトウェアデコードの強制(「$true」でソフトウェアデコードの強制。ただしCPU使用率が上がる)
$script:forceSoftwareDecodeFlag = $false

#番組の整合性検証の高速化(「$true」で高速化。ただし検証の精度は落ちる)
$script:simplifiedValidation = $false

#番組の整合性検証の無効化(「$true」で無効化)
$script:disableValidation = $false

#youtube-dlとffmpegのウィンドウの表示方法(Windowsのみ) Normal/Maximized/Minimized/Hidden
$script:windowShowStyle = 'Hidden'


#----------------------------------------------------------------------
#	以下は変更を推奨しない設定。変更の際は自己責任で。
#----------------------------------------------------------------------
#ffmpegのデコードオプション
$script:ffmpegDecodeOption = ''							#ffmpegのデコードオプションを以下を参考に設定
#以下は$script:ffmpegDecodeOptionの設定例
#$script:ffmpegDecodeOption = '-hwaccel qsv -c:v h264_qsv'											#QSV : for Intel CPUs (Intel内蔵グラフィックを使用)
#$script:ffmpegDecodeOption = '-hwaccel d3d11va -hwaccel_output_format d3d11'						#Direct3D 11 : for Windows (GPUを使用)
#$script:ffmpegDecodeOption = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld'						#Direct3D 9 : for Windows (GPUを使用)
#$script:ffmpegDecodeOption = '-hwaccel cuda -hwaccel_output_format cuda'							#CUDA : for NVIDIA Graphic Cards
#$script:ffmpegDecodeOption = '-hwaccel videotoolbox'												#VideoToolBox : for Macs
#$script:ffmpegDecodeOption = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32'	#for Raspberry Pi 4 64bit
#$script:ffmpegDecodeOption = '-c:v h264_omx'														#for Raspberry Pi 3/4 32bit

#アプリケーション名・バージョン番号
$script:appName = 'TVerRec'
$script:appVersion = Get-Content '../VERSION'

#デバッグレベル
$VerbosePreference = 'SilentlyContinue'						#詳細メッセージなし
$DebugPreference = 'SilentlyContinue'						#デバッグメッセージなし

#ファイルシステムが許容するファイル名の最大長(byte)
$script:fileNameLengthMax = 255

#Httpアクセスのタイムアウト(sec)
$script:timeoutSec = 60

#各種ディレクトリのパス
$script:binDir = $(Join-Path $scriptRoot '../bin')
$script:dbDir = $(Join-Path $scriptRoot '../db')
$script:libDir = $(Join-Path $scriptRoot '../lib')
$script:imgDir = $(Join-Path $scriptRoot '../img')
$script:listDir = $(Join-Path $scriptRoot '../list')
$script:containerDir = $(Join-Path $scriptRoot '../container-data')

#トースト通知用画像のパス
$script:toastAppLogo = Convert-Path (Join-Path $script:imgDir 'TVerRec-Toast.png')

#ダウンロード対象キーワードのパス
$script:keywordFileSamplePath = $(Join-Path $script:confDir 'keyword.sample.conf')
$script:keywordFilePath = $(Join-Path $script:confDir 'keyword.conf')

#ダウンロード対象外番組のパス
$script:ignoreFileSamplePath = $(Join-Path $script:confDir 'ignore.sample.conf')
$script:ignoreFilePath = $(Join-Path $script:confDir 'ignore.conf')

#ダウンロード履歴のパス
$script:historyFilePath = $(Join-Path $script:dbDir 'history.csv')
$script:historyFileSamplePath = $(Join-Path $script:dbDir 'history.sample.csv')
$script:historyLockFilePath = $(Join-Path $script:dbDir 'history.lock')
$script:listFilePath = $(Join-Path $script:listDir 'list.csv')
$script:listFileSamplePath = $(Join-Path $script:listDir 'list.sample.csv')
$script:listLockFilePath = $(Join-Path $script:dbDir 'list.lock')

#ffpmegで番組検証時のエラーファイルのパス
$script:ffpmegErrorLogPath = $(Join-Path $script:dbDir "ffmpeg_error_$($PID).log")

#youtube-dlのパス
if ($IsWindows) { $script:ytdlPath = $(Join-Path $script:binDir 'youtube-dl.exe') }
else {
	$script:ytdlPath = $(Join-Path $script:binDir 'youtube-dl')
	if (!(Test-Path $script:ytdlPath)) { $script:ytdlPath = (& which youtube-dl) }
}

#ffmpegのパス
if ($IsWindows) { $script:ffmpegPath = $(Join-Path $script:binDir 'ffmpeg.exe') }
else {
	$script:ffmpegPath = $(Join-Path $script:binDir 'ffmpeg')
	if (!(Test-Path $script:ffmpegPath)) { $script:ffmpegPath = (& which ffmpeg) }
}

#ffprobeのパス
if ($IsWindows) { $script:ffprobePath = $(Join-Path $script:binDir 'ffprobe.exe') }
else {
	$script:ffprobePath = $(Join-Path $script:binDir 'ffprobe')
	if (!(Test-Path $script:ffprobePath)) { $script:ffprobePath = (& which ffprobe) }
}
