###################################################################################
#  TVerRec : TVerビデオダウンローダ
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

#Windowsの判定
Set-StrictMode -Off
$isWin = $PSVersionTable.Platform -match '^($|(Microsoft )?Win)'
Set-StrictMode -Version Latest

if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') { 
	$scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
} else { 
	$scriptRoot = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
	if (!$scriptRoot) { $scriptRoot = '.' } 
}

#githubの設定
$repo = 'yt-dlp/yt-dlp'
$file = 'yt-dlp.exe'
$releases = "https://api.github.com/repos/$repo/releases"

#yt-dlp保存先相対Path
$ytdlpRelativeDir = '..\bin'
$ytdlpDir = $(Join-Path $scriptRoot $ytdlpRelativeDir)
if ($isWin) { $ytdlpPath = $(Join-Path $ytdlpDir 'yt-dlp.exe') } else { $ytdlpPath = $(Join-Path $ytdlpDir 'yt-dlp') }

#yt-dlpのディレクトリがなければ作成
if (-Not (Test-Path $ytdlpDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $ytdlpDir
}

#yt-dlpのバージョン取得
if (Test-Path $ytdlpPath -PathType Leaf) {
	# get version of current yt-dlp.exe
	$ytdlpCurrentVersion = (& $ytdlpPath --version)
} else {
	# if yt-dlp.exe not found, will download it
	$ytdlpCurrentVersion = ''
}

#yt-dlpの最新バージョン取得
try { $latestVersion = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name } catch {}

Write-Host 'yt-dlp current:' $ytdlpCurrentVersion
Write-Host 'yt-dlp latest:' $latestVersion

#youtube-dlのダウンロード
if ($latestVersion -eq $ytdlpCurrentVersion) {
	Write-Host 'yt-dlpは最新です。 '
	Write-Host ''
} else {
	if ($isWin -eq $false) {
		Write-Host '自動アップデートはWindowsでのみ動作します。 '
	} else {
		try {
			#ダウンロード
			$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
			$download = "https://github.com/$repo/releases/download/$tag/$file"
			$ytdlpFileLocation = $(Join-Path $ytdlpDir $file)
			Write-Host "yt-dlpをダウンロードします。 $download"
			Invoke-WebRequest $download -Out $ytdlpFileLocation
			#バージョンチェック
			$ytdlpCurrentVersion = (& $ytdlpFile --version)
			Write-Host "yt-dlpをversion $ytdlpCurrentVersion に更新しました。 "
		} catch {}
	}
} 


