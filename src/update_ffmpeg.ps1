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
$isWin = $PSVersionTable.Platform -match '^($|(Microsoft)?Win)'
Set-StrictMode -Version Latest

if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
	$scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
	$scriptRoot = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
	if (!$scriptRoot) { $scriptRoot = '.' }
}

#ffmpeg保存先相対Path
$ffmpegRelativeDir = '..\bin'
$ffmpegDir = $(Join-Path $scriptRoot $ffmpegRelativeDir)
if ($isWin) { $ffmpegRelativePath = $(Join-Path $ffmpegDir 'ffmpeg.exe') } else { $ffmpegRelativePath = $(Join-Path $ffmpegDir 'ffmpeg') }

#ffmpegのディレクトリがなければ作成
if (-Not (Test-Path $ffmpegDir -PathType Container)) {
	$null = New-Item -ItemType directory -Path $ffmpegDir
}

#ffmpegのバージョン取得
if (Test-Path $ffmpegRelativePath -PathType Leaf) {
	# get version of current ffmpeg.exe
	$ffmpegFileVersion = (& $ffmpegRelativePath -version)
	$null = $ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?).*'
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
	} else {
		try {

			#ダウンロード
			try {
				$ffmpegZipLink = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
				Write-Host "ffmpegをダウンロードします。 $ffmpegZipLink"
				$ffmpegZipFileLocation = $(Join-Path $ffmpegDir 'ffmpeg-release-essentials.zip')
				Invoke-WebRequest -Uri $ffmpegZipLink -OutFile $ffmpegZipFileLocation
			} catch { Write-Host 'ffmpegのダウンロードに失敗しました' }

			#展開
			try {
				Expand-Archive $ffmpegZipFileLocation -DestinationPath $(Join-Path $scriptRoot $ffmpegRelativeDir) -Force
			} catch { Write-Host 'ffmpegの展開に失敗しました' }

			#配置
			try {
				$extractedDir = $(Join-Path $scriptRoot $ffmpegRelativeDir)
				$extractedDir = $extractedDir + '\ffmpeg-*-essentials_build'
				$extractedFiles = $extractedDir + '\bin\*.exe'
				Move-Item $extractedFiles $(Join-Path $scriptRoot $ffmpegRelativeDir) -Force
			} catch { Write-Host 'ffmpegの配置に失敗しました' }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path $extractedDir `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Write-Host '中間フォルダの削除に失敗しました' }
			try {
				Remove-Item `
					-Path $ffmpegZipFileLocation `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Host '中間ファイルの削除に失敗しました' }

		} catch { Write-Host 'ffmpegの更新に失敗しました' }

		#バージョンチェック
		$ffmpegFileVersion = (& $ffmpegRelativePath -version)
		$null = $ffmpegFileVersion[0].ToChar -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
		$ffmpegCurrentVersion = $matches[1]
		Write-Host "ffmpegをversion $ffmpegCurrentVersion に更新しました。 "
	}
}

