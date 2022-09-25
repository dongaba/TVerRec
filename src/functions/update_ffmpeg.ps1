###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		Windows用ffmpeg最新化処理スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the MIT License;
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in
#	all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#	THE SOFTWARE.
#
###################################################################################

#ダウンロード先の設定
$local:releases = 'https://www.gyan.dev/ffmpeg/builds/release-version'

#ffmpeg保存先相対Path
$local:ffmpegRelativeDir = '..\bin'
$local:ffmpegDir = $(Join-Path $script:scriptRoot $local:ffmpegRelativeDir)
if ($script:isWin) { $local:ffmpegPath = $(Join-Path $local:ffmpegDir 'ffmpeg.exe') }
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
catch { Write-ColorOutput 'ffmpegの最新バージョンを特定できませんでした' -FgColor 'Green' ; return }
$local:latestVersion = $([String]$local:latestRawVersion.rawcontent).remove(0, $([String]$local:latestRawVersion.rawcontent).LastIndexOf("`n") + 1)

Write-ColorOutput "ffmpeg current: $local:ffmpegCurrentVersion"
Write-ColorOutput "ffmpeg latest: $local:latestVersion"

#ffmpegのダウンロード
if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
	Write-ColorOutput 'ffmpegは最新です。 '
	Write-ColorOutput ''
} else {
	if ($script:isWin -eq $false) {
		Write-ColorOutput '自動アップデートはWindowsでのみ動作します。' -FgColor 'Green'
	} else {
		try {

			#ダウンロード
			try {
				$local:ffmpegZipLink = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
				Write-ColorOutput "ffmpegをダウンロードします。 $local:ffmpegZipLink"
				$local:ffmpegZipFileLocation = $(Join-Path $local:ffmpegDir 'ffmpeg-release-essentials.zip')
				Invoke-WebRequest -Uri $local:ffmpegZipLink -OutFile $local:ffmpegZipFileLocation
			} catch { Write-ColorOutput 'ffmpegのダウンロードに失敗しました' -FgColor 'Green' }

			#展開
			try {
				$local:extractedDir = $(Join-Path $script:scriptRoot $local:ffmpegRelativeDir)
				Expand-Archive $local:ffmpegZipFileLocation -DestinationPath $local:extractedDir
			} catch { Write-ColorOutput 'ffmpegの展開に失敗しました' -FgColor 'Green' }

			#配置
			try {
				$local:extractedDir = $local:extractedDir + '\ffmpeg-*-essentials_build'
				$local:extractedFiles = $local:extractedDir + '\bin\*.exe'
				Move-Item $local:extractedFiles $(Join-Path $script:scriptRoot $local:ffmpegRelativeDir) -Force
			} catch { Write-ColorOutput 'ffmpegの配置に失敗しました' -FgColor 'Green' }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path $local:extractedDir `
					-Force -Recurse -ErrorAction SilentlyContinue
			} catch { Write-ColorOutput '中間フォルダの削除に失敗しました' -FgColor 'Green' }
			try {
				Remove-Item `
					-LiteralPath $local:ffmpegZipFileLocation `
					-Force -ErrorAction SilentlyContinue
			} catch { Write-ColorOutput '中間ファイルの削除に失敗しました' -FgColor 'Green' }

		} catch { Write-ColorOutput 'ffmpegの更新に失敗しました' -FgColor 'Green' }

		#バージョンチェック
		try {
			$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
			if ($? -eq $false) { throw '更新後のバージョン取得に失敗しました' }
			$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
			$local:ffmpegCurrentVersion = $local:matches[1]
			Write-ColorOutput "ffmpegをversion $local:ffmpegCurrentVersion に更新しました。 "
		} catch { exit 1 }
	}
}

