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

#ダウンロード先のフルパス(絶対パス指定)
switch ($true) {
	$IsWindows { $script:downloadBaseDir = 'W:' ; break }
	$isLinux { $script:downloadBaseDir = '/mnt/Work' ; break }
	$isMacOs { $script:downloadBaseDir = '/Volumes/Work' ; break }
}

#ダウンロード中の作業ファイル置き場のフルパス(絶対パス指定)
switch ($true) {
	$IsWindows { $script:downloadWorkDir = $env:TMP ; break }	#$env:TMP = C:\Users\<ユーザ名>\AppData\Local\Temp
	$isLinux { $script:downloadWorkDir = '/var/tmp' ; break }
	$isMacOs { $script:downloadWorkDir = '/Volumes/RamDrive/Temp' ; break }
}

#保存先のフルパス(絶対パス指定)
switch ($true) {
	$IsWindows { $script:saveBaseDir = 'V:' ; break }
	$isLinux { $script:saveBaseDir = '/mnt/Video' ; break }
	$isMacOs { $script:saveBaseDir = '/Volumes/Video' ; break }
}

#同時ダウンロードファイル数
$script:parallelDownloadFileNum = 5

#1本の番組あたりの同時ダウンロード数
$script:parallelDownloadNumPerFile = 10

#ダウンロード時に放送局毎のフォルダ配下にダウンロードファイルを保存
#「$false」の際の保存先は以下
#  ダウンロード先\
#    └番組シリーズ名 番組シーズン名\
#      └番組シリーズ名 番組シーズン名 放送日 番組タイトル名).mp4
#「$true」の際の保存先は以下
#  ダウンロード先\
#    └放送局\
#      └番組シリーズ名 番組シーズン名\
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

#youtube-dlのウィンドウの表示方法(Windowsのみ) Normal/Maximized/Minimized/Hidden
$script:windowShowStyle = 'Hidden'

#番組の整合性検証の高速化(「$true」で高速化。ただし、検証の精度は落ちる)
$script:simplifiedValidation = $false

#番組の整合性検証の無効化(「$true」で無効化)
$script:disableValidation = $false

#youtube-dlの自動アップデートを無効化
$script:disableUpdateYoutubedl = $false

#youtube-dlの取得元
$script:preferredYoutubedl = 'yt-dlp'	#'yt-dlp' or 'ytdl-patched'

#ffmpegの自動アップデートを無効化
$script:disableUpdateFfmpeg = $false

#ffmpegのデコードオプション
$script:forceSoftwareDecodeFlag = $false				#ソフトウェアデコードを強制する場合は「$false」を「$true」に変える
$script:ffmpegDecodeOption = ''							#ffmpegのデコードオプションを以下を参考に設定
#以下は$script:ffmpegDecodeOptionの設定例
#$script:ffmpegDecodeOption = '-hwaccel qsv -c:v h264_qsv'											#QSV : for Intel CPUs (Intel内蔵グラフィックを使用)
#$script:ffmpegDecodeOption = '-hwaccel d3d11va -hwaccel_output_format d3d11'						#Direct3D 11 : for Windows (GPUを使用)
#$script:ffmpegDecodeOption = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld'						#Direct3D 9 : for Windows (GPUを使用)
#$script:ffmpegDecodeOption = '-hwaccel cuda -hwaccel_output_format cuda'							#CUDA : for NVIDIA Graphic Cards
#$script:ffmpegDecodeOption = '-hwaccel videotoolbox'												#VideoToolBox : for Macs
#$script:ffmpegDecodeOption = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32'	#for Raspberry Pi 4 64bit
#$script:ffmpegDecodeOption = '-c:v h264_omx'														#for Raspberry Pi 3/4 32bit

#----------------------------------------------------------------------
#	以下は変更を推奨しない設定。変更の際は自己責任で。
#----------------------------------------------------------------------
#アプリケーション名・バージョン番号
$script:appName = 'TVerRec'
$script:appVersion = Get-Content '..\VERSION'

#デバッグレベル
$VerbosePreference = 'SilentlyContinue'						#詳細メッセージなし
$DebugPreference = 'SilentlyContinue'						#デバッグメッセージなし

#ファイルシステムが許容するファイル名の最大長(byte)
$script:fileNameLengthMax = 255

#Httpアクセスのタイムアウト(sec)
$script:timeoutSec = 60

#各種ディレクトリのパス
$script:binDir = $(Join-Path $scriptRoot '..\bin')
$script:dbDir = $(Join-Path $scriptRoot '..\db')
$script:libDir = $(Join-Path $scriptRoot '..\lib')
$script:imgDir = $(Join-Path $scriptRoot '..\img')

#トースト通知用画像のパス
$script:toastAppLogo = Convert-Path (Join-Path $script:imgDir 'TVerRec-Toast.png')

#ダウンロード対象キーワードのパス
$script:keywordFileSamplePath = $(Join-Path $script:confDir 'keyword.sample.conf')
$script:keywordFilePath = $(Join-Path $script:confDir 'keyword.conf')

#ダウンロード対象外番組のパス
$script:ignoreFileSamplePath = $(Join-Path $script:confDir 'ignore.sample.conf')
$script:ignoreFilePath = $(Join-Path $script:confDir 'ignore.conf')

#ダウンロード履歴のパス
$script:listFileSamplePath = $(Join-Path $script:dbDir 'tver.sample.csv')
$script:listFilePath = $(Join-Path $script:dbDir 'tver.csv')
$script:lockFilePath = $(Join-Path $script:dbDir 'tver.lock')

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
