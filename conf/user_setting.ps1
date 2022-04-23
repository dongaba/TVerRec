###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		ユーザ設定
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
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

#youtube-dlのウィンドウの表示方法(Windowsのみ) Normal/Maximized/Minimized/Hidden
$script:windowShowStyle = 'Hidden'

#動画検証の高速化(「$true」で高速化。ただし、検証の精度は落ちる)
$script:simplifiedValidation = $false

#動画検証の無効化(「$true」で無効化)
$script:disableValidation = $false

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
