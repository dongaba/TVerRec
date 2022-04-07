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
$local:isWin = $PSVersionTable.Platform -match '^($|(Microsoft)?Win)'
Set-StrictMode -Version Latest

if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
	$local:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
	$local:scriptRoot = '.'
}

#githubの設定
$local:repo = 'ytdl-patched/ytdl-patched'
$local:releases = "https://api.github.com/repos/$local:repo/releases"

#ytdl-patched保存先相対Path
$local:ytdlRelativeDir = '..\bin'
$local:ytdlDir = $(Join-Path $local:scriptRoot $local:ytdlRelativeDir)
if ($local:isWin) { $local:ytdlPath = $(Join-Path $local:ytdlDir 'youtube-dl.exe') }
else { $local:ytdlPath = $(Join-Path $local:ytdlDir 'youtube-dl') }

#ytdl-patchedのディレクトリがなければ作成
if (-Not (Test-Path $local:ytdlDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $local:ytdlDir
}

#ytdl-patchedのバージョン取得
if (Test-Path $local:ytdlPath -PathType Leaf) {
	# get version of current yt-dlp.exe
	$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
} else {
	# if yt-dlp.exe not found, will download it
	$local:ytdlCurrentVersion = ''
}

#ytdl-patchedの最新バージョン取得
try { $local:latestVersion = (Invoke-WebRequest $local:releases | ConvertFrom-Json)[0].Name } catch {}

Write-Host 'youtube-dl current:' $local:ytdlCurrentVersion
Write-Host 'youtube-dl latest:' $local:latestVersion

#ytdl-patchedのダウンロード
if ($local:latestVersion -eq $local:ytdlCurrentVersion) {
	Write-Host 'youtube-dlは最新です。 '
	Write-Host ''
} else {
	if ($local:isWin -eq $false) {
		try {
			#githubの設定
			$local:file = 'youtube-dl'
			#ダウンロード
			$local:tag = (Invoke-WebRequest $local:releases | ConvertFrom-Json)[0].Tag_name
			$local:download = "https://github.com/$local:repo/releases/download/$local:tag/$local:file"
			$local:ytdlFileLocation = $(Join-Path $local:ytdlDir $local:file)
			Write-Host "youtube-dlをダウンロードします。 $local:download"
			Invoke-WebRequest $local:download -Out $local:ytdlFileLocation
			#バージョンチェック
			$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
			Write-Host "youtube-dlをversion $local:ytdlCurrentVersion に更新しました。 "
		} catch { Write-Host 'youtube-dlの更新に失敗しました' -ForegroundColor Green }
	} else {
		try {
			#githubの設定
			$local:file = 'youtube-dl-red.exe'
			$local:fileAfterRename = 'youtube-dl.exe'

			#ダウンロード
			$local:tag = (Invoke-WebRequest $local:releases | ConvertFrom-Json)[0].Tag_name
			$local:download = "https://github.com/$local:repo/releases/download/$local:tag/$local:file"
			$local:ytdlFileLocation = $(Join-Path $local:ytdlDir $local:fileAfterRename)
			Write-Host "youtube-dlをダウンロードします。 $local:download"
			Invoke-WebRequest $local:download -Out $local:ytdlFileLocation
			#バージョンチェック
			$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
			Write-Host "youtube-dlをversion $local:ytdlCurrentVersion に更新しました。 "
		} catch { Write-Host 'youtube-dlの更新に失敗しました' -ForegroundColor Green }
	}
}


