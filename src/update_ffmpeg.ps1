###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		Windows用ffmpeg最新化処理スクリプト
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

#ffmpeg保存先相対Path
$local:ffmpegRelativeDir = '..\bin'
$local:ffmpegDir = $(Join-Path $local:scriptRoot $local:ffmpegRelativeDir)
if ($local:isWin) { $local:ffmpegPath = $(Join-Path $local:ffmpegDir 'ffmpeg.exe') }
else { $local:ffmpegPath = $(Join-Path $local:ffmpegDir 'ffmpeg') }

#ffmpegのディレクトリがなければ作成
if (-Not (Test-Path $local:ffmpegDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $local:ffmpegDir
}

#ffmpegのバージョン取得
if (Test-Path $local:ffmpegPath -PathType Leaf) {
	# get version of current ffmpeg.exe
	$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
	$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?).*'
	$local:ffmpegCurrentVersion = $matches[1]
} else {
	# if ffmpeg.exe not found, will download it
	$local:ffmpegCurrentVersion = ''
}

#ffmpegの最新バージョン取得
try { $local:latestVersion = Invoke-RestMethod -Uri https://www.gyan.dev/ffmpeg/builds/release-version }catch {}

Write-Host 'ffmpeg current:' $local:ffmpegCurrentVersion
Write-Host 'ffmpeg latest:' $local:latestVersion

#ffmpegのダウンロード
if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
	Write-Host 'ffmpegは最新です。 '
	Write-Host ''
} else {
	if ($local:isWin -eq $false) {
		Write-Host '自動アップデートはWindowsでのみ動作します。' -ForegroundColor Green
	} else {
		try {

			#ダウンロード
			try {
				$local:ffmpegZipLink = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
				Write-Host "ffmpegをダウンロードします。 $local:ffmpegZipLink"
				$local:ffmpegZipFileLocation = $(Join-Path $local:ffmpegDir 'ffmpeg-release-essentials.zip')
				Invoke-WebRequest -Uri $local:ffmpegZipLink -OutFile $local:ffmpegZipFileLocation
			} catch { Write-Host 'ffmpegのダウンロードに失敗しました' -ForegroundColor Green }

			#展開
			try {
				$local:extractedDir = $(Join-Path $local:scriptRoot $local:ffmpegRelativeDir)
				Expand-Archive $local:ffmpegZipFileLocation -DestinationPath $local:extractedDir
			} catch { Write-Host 'ffmpegの展開に失敗しました' -ForegroundColor Green }

			#配置
			try {
				$local:extractedDir = $local:extractedDir + '\ffmpeg-*-essentials_build'
				$local:extractedFiles = $local:extractedDir + '\bin\*.exe'
				Move-Item $local:extractedFiles $(Join-Path $local:scriptRoot $local:ffmpegRelativeDir) -Force
			} catch { Write-Host 'ffmpegの配置に失敗しました' -ForegroundColor Green }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path $local:extractedDir `
					-Force -Recurse -ErrorAction SilentlyContinue
			} catch { Write-Host '中間フォルダの削除に失敗しました' -ForegroundColor Green }
			try {
				Remove-Item `
					-LiteralPath $local:ffmpegZipFileLocation `
					-Force -ErrorAction SilentlyContinue
			} catch { Write-Host '中間ファイルの削除に失敗しました' -ForegroundColor Green }

		} catch { Write-Host 'ffmpegの更新に失敗しました' -ForegroundColor Green }

		#バージョンチェック
		$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
		$null = $local:ffmpegFileVersion[0].ToChar -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
		$local:ffmpegCurrentVersion = $local:matches[1]
		Write-Host "ffmpegをversion $local:ffmpegCurrentVersion に更新しました。 "
	}
}

