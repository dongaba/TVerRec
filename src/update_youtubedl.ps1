###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		Windows用youtube-dl最新化処理スクリプト
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
$repo = 'ytdl-org/youtube-dl'
$file = 'youtube-dl.exe'
$releases = "https://api.github.com/repos/$repo/releases"

#youtube-dl保存先相対Path
$youtubedlRelativeDir = '..\bin'
$youtubedlDir = $(Join-Path $scriptRoot $youtubedlRelativeDir)
$youtubedlFile = $(Join-Path $youtubedlDir 'youtube-dl.exe')

#youtube-dlのディレクトリがなければ作成
if (-Not (Test-Path $youtubedlDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $youtubedlDir
}

#youtube-dlのバージョン取得
if (Test-Path $youtubedlFile -PathType Leaf) {
	# get version of current youtube-dl.exe
	$youtubedlCurrentVersion = (& $youtubedlFile --version)
} else {
	# if youtube-dl.exe not found, will download it
	$youtubedlCurrentVersion = ''
}

#youtube-dlの最新バージョン取得
$latestVersion = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name

Write-Host 'youtube-dl current:' $youtubedlCurrentVersion
Write-Host 'youtube-dl latest:' $latestVersion

#youtube-dlのダウンロード
if ($latestVersion -ne $youtubedlCurrentVersion) {
	#ダウンロード
	$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
	$download = "https://github.com/$repo/releases/download/$tag/$file"
	$youtubedlFileLocation = $(Join-Path $youtubedlDir $file)

	Write-Host "youtube-dlをダウンロードします。 $download"
	Invoke-WebRequest $download -Out $youtubedlFileLocation

	#バージョンチェック
	$youtubedlCurrentVersion = (& $youtubedlFile --version)
	Write-Host "youtube-dlをversion $youtubedlCurrentVersion に更新しました。 "
} else {
	Write-Host 'youtube-dlは最新です。 '
	Write-Host ''
}





