###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		Windows用ytdl-patched最新化処理スクリプト
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

#Windowsの判定
Set-StrictMode -Off
$global:isWin = $PSVersionTable.Platform -match '^($|(Microsoft)?Win)'
Set-StrictMode -Version Latest

if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
	$local:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
	$local:scriptRoot = '.'
}

#githubの設定
$local:repo = 'ytdl-patched/ytdl-patched'
$local:file = 'youtube-dl-red.exe'
$local:releases = "https://api.github.com/repos/$local:repo/releases"

#ytdl-patched保存先相対Path
$local:ytdlpRelativeDir = '..\bin'
$local:ytdlpDir = $(Join-Path $local:scriptRoot $local:ytdlpRelativeDir)
if ($global:isWin) { $global:ytdlpPath = $(Join-Path $local:ytdlpDir 'youtube-dl-red.exe') }
else { $global:ytdlpPath = $(Join-Path $local:ytdlpDir 'yt-dlp') }

#ytdl-patchedのディレクトリがなければ作成
if (-Not (Test-Path $local:ytdlpDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $local:ytdlpDir
}

#ytdl-patchedのバージョン取得
if (Test-Path $global:ytdlpPath -PathType Leaf) {
	# get version of current yt-dlp.exe
	$local:ytdlpCurrentVersion = (& $global:ytdlpPath --version)
} else {
	# if yt-dlp.exe not found, will download it
	$local:ytdlpCurrentVersion = ''
}

#ytdl-patchedの最新バージョン取得
try { $local:latestVersion = (Invoke-WebRequest $local:releases | ConvertFrom-Json)[0].name } catch {}

Write-Host 'youtube-dl-red current:' $local:ytdlpCurrentVersion
Write-Host 'youtube-dl-red latest:' $local:latestVersion

#ytdl-patchedのダウンロード
if ($local:latestVersion -eq $local:ytdlpCurrentVersion) {
	Write-Host 'youtube-dl-redは最新です。 '
	Write-Host ''
} else {
	if ($global:isWin -eq $false) {
		Write-Host '自動アップデートはWindowsでのみ動作します。' -ForegroundColor Green
	} else {
		try {
			#ダウンロード
			$local:tag = (Invoke-WebRequest $local:releases | ConvertFrom-Json)[0].tag_name
			$local:download = "https://github.com/$local:repo/releases/download/$local:tag/$local:file"
			$local:ytdlpFileLocation = $(Join-Path $local:ytdlpDir $local:file)
			Write-Host "youtube-dl-redをダウンロードします。 $local:download"
			Invoke-WebRequest $local:download -Out $local:ytdlpFileLocation
			#バージョンチェック
			$local:ytdlpCurrentVersion = (& $local:ytdlpFile --version)
			Write-Host "youtube-dl-redをversion $local:ytdlpCurrentVersion に更新しました。 "
		} catch { Write-Host 'youtube-dl-redの更新に失敗しました' -ForegroundColor Green }
	}
}


