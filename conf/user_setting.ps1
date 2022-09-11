###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		ユーザ設定
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

#ダウンロード先のフルパス(絶対パス指定)
if ($script:isWin) { $script:downloadBaseDir = 'W:' }
elseif ($isLinux) { $script:downloadBaseDir = '/mnt/Work' }
elseif ($isMacOs) { $script:downloadBaseDir = '/Volumes/Work' }

#ダウンロード中の作業ファイル置き場のフルパス(絶対パス指定)
if ($script:isWin) { $script:downloadWorkDir = $env:TMP }	#$env:TMP = C:\Users\<ユーザ名>\AppData\Local\Temp
elseif ($isLinux) { $script:downloadWorkDir = '/var/tmp' }
elseif ($isMacOs) { $script:downloadWorkDir = '/Volumes/RamDrive/Temp' }

#保存先のフルパス(絶対パス指定)
if ($script:isWin) { $script:saveBaseDir = 'V:' }
elseif ($isLinux) { $script:downloadBaseDir = '/mnt/Video' }
elseif ($isMacOs) { $script:saveBaseDir = '/Volumes/Video' }

#同時ダウンロードファイル数
$script:parallelDownloadFileNum = 5

#1本のビデオあたりの同時ダウンロード数
$script:parallelDownloadNumPerFile = 10

#ダウンロード時に放送局毎のフォルダ配下に動画ファイルを保存
#「$false」の際の保存先は以下
#  ダウンロード先\
#    └動画シリーズ名 動画シーズン名\
#      └動画シリーズ名 動画シーズン名 放送日 動画タイトル名).mp4
#「$true」の際の保存先は以下
#  ダウンロード先\
#    └放送局\
#      └動画シリーズ名 動画シーズン名\
#        └動画シリーズ名 動画シーズン名 放送日 動画タイトル名).mp4
$script:sortVideoByMedia = $false

#youtube-dlのウィンドウの表示方法(Windowsのみ) Normal/Maximized/Minimized/Hidden
$script:windowShowStyle = 'Hidden'

#動画検証の高速化(「$true」で高速化。ただし、検証の精度は落ちる)
$script:simplifiedValidation = $false

#動画検証の無効化(「$true」で無効化)
$script:disableValidation = $false

#youtube-dlの自動アップデートを無効化
$script:disableUpdateYoutubedl = $false

#youtube-dlの取得元
$script:preferredYoutubedl = 'ytdl-patched'	#'yt-dlp' or 'ytdl-patched'

#ffmpegの自動アップデートを無効化
$script:disableUpdateFfmpeg = $false

#ffmpegのデコードオプション
$script:forceSoftwareDecodeFlag = $false						#ソフトウェアデコードを強制する場合は「$false」を「$true」に変える
$script:ffmpegDecodeOption = ''							#ffmpegのデコードオプションを以下を参考に設定
#以下は$script:ffmpegDecodeOptionの設定例
#$script:ffmpegDecodeOption = '-hwaccel qsv -c:v h264_qsv'											#QSV : for Intel CPUs
#$script:ffmpegDecodeOption = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32'	#for Raspberry Pi 4 64bit
#$script:ffmpegDecodeOption = '-c:v h264_omx'														#for Raspberry Pi 3/4 32bit
#$script:ffmpegDecodeOption = '-hwaccel d3d11va -hwaccel_output_format d3d11'						#Direct3D 11 : for Windows
#$script:ffmpegDecodeOption = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld'					#Direct3D 9 : for Windows
#$script:ffmpegDecodeOption = '-hwaccel cuda -hwaccel_output_format cuda'							#CUDA : for NVIDIA Graphic Cards
#$script:ffmpegDecodeOption = '-hwaccel videotoolbox'												#VideoToolBox : for Macs
