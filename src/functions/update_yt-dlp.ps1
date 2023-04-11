###################################################################################
#  TVerRec : TVerダウンローダ
#
#		Windows用ytdl-patched最新化処理スクリプト
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

#githubの設定
$local:repo = 'yt-dlp/yt-dlp'
$local:releases = "https://api.github.com/repos/$($local:repo)/releases"

#yt-dlp保存先相対Path
$local:ytdlRelDir = '../bin'
$local:ytdlDir = $(Join-Path $script:scriptRoot $local:ytdlRelDir)
if ($IsWindows) { $local:ytdlPath = $(Join-Path $local:ytdlDir 'youtube-dl.exe') }
else { $local:ytdlPath = $(Join-Path $local:ytdlDir 'youtube-dl') }

#yt-dlpのディレクトリがなければ作成
if (-Not (Test-Path $local:ytdlDir -PathType Container)) {
	$null = New-Item `
		-ItemType Directory `
		-Path $local:ytdlDir
}

#yt-dlpのバージョン取得
if (Test-Path $local:ytdlPath -PathType Leaf) {
	# get version of current yt-dlp.exe
	$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
} else {
	# if yt-dlp.exe not found, will download it
	$local:ytdlCurrentVersion = ''
}

#yt-dlpの最新バージョン取得
try {
	$local:latestVersion = (Invoke-RestMethod `
			-Uri $local:releases `
			-Method Get `
			-TimeoutSec $script:timeoutSec `
	)[0].Tag_Name
} catch { Out-Msg 'youtube-dl(yt-dlp)の最新バージョンを特定できませんでした' -Fg 'Green' ; return }

#yt-dlpのダウンロード
if ($local:latestVersion -eq $local:ytdlCurrentVersion) {
	Out-Msg 'youtube-dlは最新です。'
	Out-Msg "　youtube-dl current: $local:ytdlCurrentVersion"
	Out-Msg "　youtube-dl latest: $local:latestVersion"
	Out-Msg ''
} else {
	Out-Msg 'youtube-dlが古いため更新します。'
	Out-Msg "　youtube-dl current: $local:ytdlCurrentVersion"
	Out-Msg "　youtube-dl latest: $local:latestVersion"
	Out-Msg ''
	if ($IsWindows -eq $false) {
		#githubの設定
		$local:file = 'yt-dlp'
		$local:fileAfterRename = 'youtube-dl'
	} else {
		#githubの設定
		$local:file = 'yt-dlp.exe'
		$local:fileAfterRename = 'youtube-dl.exe'
	}

	try {
		#ダウンロード
		$local:tag = (Invoke-RestMethod `
				-Uri $local:releases `
				-Method Get `
				-TimeoutSec $script:timeoutSec `
		)[0].Tag_Name
		$local:download = `
			"https://github.com/$($local:repo)/releases/download/$($local:tag)/$($local:file)"
		$local:ytdlFileLocation = $(Join-Path $local:ytdlDir $local:fileAfterRename)
		Invoke-WebRequest `
			-Uri $local:download `
			-Out $local:ytdlFileLocation `
			-TimeoutSec $script:timeoutSec
	} catch { exit 1 }

	#バージョンチェック
	try {
		$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
		if ($? -eq $false) { throw '更新後のバージョン取得に失敗しました' }
		Out-Msg "youtube-dlをversion $local:ytdlCurrentVersion に更新しました。"
		Out-Msg ''
	} catch { exit 1 }

}

