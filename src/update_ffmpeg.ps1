###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		Windows用ffmpeg最新化処理スクリプト
#
#	Copyright (c) 2021 dongaba
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

#Windowsの判定
Set-StrictMode -Off
$isWin = $PSVersionTable.Platform -match '^($|(Microsoft )?Win)'
Set-StrictMode -Version Latest


$scriptRoot = if ($PSScriptRoot -eq '') { '.' } else { $PSScriptRoot }

#ffmpeg保存先相対Path
$ffmpegRelativeDir = '..\bin'
$ffmpegDir = $(Join-Path $scriptRoot $ffmpegRelativeDir)
$ffmpegPath = $(Join-Path $ffmpegDir 'ffmpeg.exe')

#ffmpegのディレクトリがなければ作成
if (-Not (Test-Path $ffmpegDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $ffmpegDir
}

#ffmpegのバージョン取得
if (Test-Path $ffmpegPath -PathType Leaf) {
	# get version of current ffmpeg.exe
	$ffmpegFileVersion = (& $ffmpegPath -version)
	$null = $ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
	$ffmpegCurrentVersion = $matches[1]
} else {
	# if ffmpeg.exe not found, will download it
	$ffmpegCurrentVersion = ''
}

#ffmpegの最新バージョン取得
try { $latestVersion = Invoke-RestMethod -Uri https://www.gyan.dev/ffmpeg/builds/release-version }catch {}

Write-Host 'ffmpeg current:' $ffmpegCurrentVersion
Write-Host 'ffmpeg latest:' $latestVersion

#ffmpegのダウンロード
if ($latestVersion -eq $ffmpegCurrentVersion) {
	Write-Host 'ffmpegは最新です。 '
	Write-Host ''
} else {
	if ($isWin -eq $false) {
		Write-Host '自動アップデートはWindowsでのみ動作します。 ' 
	}
	try { 
		#ダウンロード
		$ffmpegZipLink = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
		Write-Host "ffmpegをダウンロードします。 $ffmpegZipLink"
		$ffmpegZipFileLocation = $(Join-Path $ffmpegDir 'ffmpeg-release-essentials.zip')
		Invoke-WebRequest -Uri $ffmpegZipLink -OutFile $ffmpegZipFileLocation
		#展開
		Expand-Archive $ffmpegZipFileLocation -DestinationPath $(Join-Path $scriptRoot $ffmpegRelativeDir) -Force
		#配置
		$extractedDir = $(Join-Path $scriptRoot $ffmpegRelativeDir)
		$extractedDir = $extractedDir + '\ffmpeg-*-essentials_build'
		$extractedFiles = $extractedDir + '\bin\*.exe'
		Move-Item $extractedFiles $(Join-Path $scriptRoot $ffmpegRelativeDir) -Force
		#ゴミ掃除
		Remove-Item -Path $extractedDir -Force -Recurse
		Remove-Item -Path $ffmpegZipFileLocation -Force
		#バージョンチェック
		$ffmpegFileVersion = (& $ffmpegPath -version)
		$null = $ffmpegFileVersion[0].ToChar -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
		$ffmpegCurrentVersion = $matches[1]
		Write-Host "ffmpegをversion $ffmpegCurrentVersion に更新しました。 "
	} catch {}
}

