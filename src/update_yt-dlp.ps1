###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		Windows用yt-dlp最新化処理スクリプト
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

$scriptRoot = if ($PSScriptRoot -eq '') { '.' } else { $PSScriptRoot }

#githubの設定
$repo = 'yt-dlp/yt-dlp'
$file = 'yt-dlp.exe'
$releases = "https://api.github.com/repos/$repo/releases"

#yt-dlp保存先相対Path
$ytdlpRelativeDir = '..\bin'
$ytdlpDir = $(Join-Path $scriptRoot $ytdlpRelativeDir)
$ytdlpFile = $(Join-Path $ytdlpDir 'yt-dlp.exe')

#yt-dlpのディレクトリがなければ作成
if (-Not (Test-Path $ytdlpDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $ytdlpDir
}

#yt-dlpのバージョン取得
if (Test-Path $ytdlpFile -PathType Leaf) {
	# get version of current yt-dlp.exe
	$ytdlpCurrentVersion = (& $ytdlpFile --version)
} else {
	# if yt-dlp.exe not found, will download it
	$ytdlpCurrentVersion = ''
}

#yt-dlpの最新バージョン取得
$latestVersion = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name

Write-Host 'yt-dlp current:' $ytdlpCurrentVersion
Write-Host 'yt-dlp latest:' $latestVersion

#youtube-dlのダウンロード
if ($latestVersion -ne $ytdlpCurrentVersion) {
	#ダウンロード
	$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
	$download = "https://github.com/$repo/releases/download/$tag/$file"
	$ytdlpFileLocation = $(Join-Path $ytdlpDir $file)

	Write-Host "yt-dlpをダウンロードします。 $download"
	Invoke-WebRequest $download -Out $ytdlpFileLocation

	#バージョンチェック
	$ytdlpCurrentVersion = (& $ytdlpFile --version)
	Write-Host "yt-dlpをversion $ytdlpCurrentVersion に更新しました。 "
} else {
	Write-Host 'yt-dlpは最新です。 '
	Write-Host ''
}





