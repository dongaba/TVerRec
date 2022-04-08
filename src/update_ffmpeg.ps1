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

try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$script:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$script:scriptRoot = Convert-Path .
	}
	Set-Location $script:scriptRoot

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\common_functions_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\common_functions.ps1'))
	}
} catch { Write-ColorOutput '設定ファイルの読み込みに失敗しました' Green ; exit 1 }

#Windowsの判定
Set-StrictMode -Off
$local:isWin = $PSVersionTable.Platform -match '^($|(Microsoft)?Win)'
Set-StrictMode -Version Latest

$local:releases = 'https://www.gyan.dev/ffmpeg/builds/release-version'
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
$local:latestVersion = ''
try { $local:latestRawVersion = Invoke-WebRequest -Uri $local:releases }
catch { Write-ColorOutput 'ffmpegの最新バージョンを特定できませんでした' Green ; return }
$local:latestVersion = $([string]$local:latestRawVersion.rawcontent).remove(0, $([string]$local:latestRawVersion.rawcontent).LastIndexOf("`n") + 1)

Write-ColorOutput "ffmpeg current: $local:ffmpegCurrentVersion"
Write-ColorOutput "ffmpeg latest: $local:latestVersion"

#ffmpegのダウンロード
if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
	Write-ColorOutput 'ffmpegは最新です。 '
	Write-ColorOutput ''
} else {
	if ($local:isWin -eq $false) {
		Write-ColorOutput '自動アップデートはWindowsでのみ動作します。' Green
	} else {
		try {

			#ダウンロード
			try {
				$local:ffmpegZipLink = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
				Write-ColorOutput "ffmpegをダウンロードします。 $local:ffmpegZipLink"
				$local:ffmpegZipFileLocation = $(Join-Path $local:ffmpegDir 'ffmpeg-release-essentials.zip')
				Invoke-WebRequest -Uri $local:ffmpegZipLink -OutFile $local:ffmpegZipFileLocation
			} catch { Write-ColorOutput 'ffmpegのダウンロードに失敗しました' Green }

			#展開
			try {
				$local:extractedDir = $(Join-Path $local:scriptRoot $local:ffmpegRelativeDir)
				Expand-Archive $local:ffmpegZipFileLocation -DestinationPath $local:extractedDir
			} catch { Write-ColorOutput 'ffmpegの展開に失敗しました' Green }

			#配置
			try {
				$local:extractedDir = $local:extractedDir + '\ffmpeg-*-essentials_build'
				$local:extractedFiles = $local:extractedDir + '\bin\*.exe'
				Move-Item $local:extractedFiles $(Join-Path $local:scriptRoot $local:ffmpegRelativeDir) -Force
			} catch { Write-ColorOutput 'ffmpegの配置に失敗しました' Green }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path $local:extractedDir `
					-Force -Recurse -ErrorAction SilentlyContinue
			} catch { Write-ColorOutput '中間フォルダの削除に失敗しました' Green }
			try {
				Remove-Item `
					-LiteralPath $local:ffmpegZipFileLocation `
					-Force -ErrorAction SilentlyContinue
			} catch { Write-ColorOutput '中間ファイルの削除に失敗しました' Green }

		} catch { Write-ColorOutput 'ffmpegの更新に失敗しました' Green }

		#バージョンチェック
		$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
		$null = $local:ffmpegFileVersion[0].ToChar -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
		$local:ffmpegCurrentVersion = $local:matches[1]
		Write-ColorOutput "ffmpegをversion $local:ffmpegCurrentVersion に更新しました。 "
	}
}

