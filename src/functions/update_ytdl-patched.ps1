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
Add-Type -AssemblyName System.IO.Compression.FileSystem

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function unZip {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param(
		[Parameter(Mandatory = $true)]
		[Alias('File')]
		[String]$zipArchive,
		[Parameter(Mandatory = $true)]
		[Alias('OutPath')]
		[String]$path
	)
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $path)
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$local:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
		$local:scriptRoot = Split-Path -Parent -Path $local:scriptRoot
	} else {
		$local:scriptRoot = Convert-Path ..
	}
	Set-Location $local:scriptRoot
} catch {
	Write-Error 'ディレクトリ設定に失敗しました' ; exit 1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#githubの設定
$local:repo = 'ytdl-patched/ytdl-patched'
$local:releases = "https://api.github.com/repos/$($local:repo)/releases"

#ytdl-patched保存先相対Path
$local:ytdlDir = $(Join-Path $local:scriptRoot '../bin')
if ($IsWindows) { $local:ytdlPath = $(Join-Path $local:ytdlDir 'youtube-dl.exe') }
else { $local:ytdlPath = $(Join-Path $local:ytdlDir 'youtube-dl') }

#ytdl-patchedのバージョン取得
if (Test-Path $local:ytdlPath -PathType Leaf) {
	# get version of current ytdl-patched.exe
	$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
} else {
	# if yt-dlp.exe not found, will download it
	$local:ytdlCurrentVersion = ''
}

#ytdl-patchedの最新バージョン取得
try {
	$local:latestVersion = (Invoke-RestMethod `
			-Uri $local:releases `
			-Method Get
	)[0].Tag_Name
} catch {
	Write-Output 'youtube-dl(ytdl-patched)の最新バージョンを特定できませんでした'
	return
}

#ytdl-patchedのダウンロード
if ($local:latestVersion -eq $local:ytdlCurrentVersion) {
	Write-Output 'youtube-dlは最新です。'
	Write-Output "　youtube-dl current: $local:ytdlCurrentVersion"
	Write-Output "　youtube-dl latest: $local:latestVersion"
	Write-Output ''
} else {
	Write-Output 'youtube-dlが古いため更新します。'
	Write-Output "　youtube-dl current: $local:ytdlCurrentVersion"
	Write-Output "　youtube-dl latest: $local:latestVersion"
	Write-Output ''
	if ($IsWindows -eq $false) {
		#githubの設定
		$local:file = 'ytdl-patched'
		$local:fileAfterRename = 'youtube-dl'
	} else {
		#githubの設定
		$local:file = 'ytdl-patched-red.exe'
		$local:fileAfterRename = 'youtube-dl.exe'
	}

	Write-Output 'youtube-dl(ytdl-patched)の最新版をダウンロードします'
	try {
		#ダウンロード
		$local:tag = (Invoke-RestMethod `
				-Uri $local:releases `
				-Method Get
		)[0].Tag_Name
		$local:download = `
			"https://github.com/$($local:repo)/releases/download/$($local:tag)/$($local:file)"
		$local:ytdlFileLocation = $(Join-Path $local:ytdlDir $local:fileAfterRename)
		Invoke-WebRequest `
			-Uri $local:download `
			-Out $local:ytdlFileLocation
	} catch {
		Write-Error 'ffmpegのダウンロードに失敗しました' ; exit 1
	}

	if ($IsWindows -eq $false) {
		#実行権限の付与
		(& chmod a+x $local:ytdlFileLocation)
	}

	#バージョンチェック
	try {
		$local:ytdlCurrentVersion = (& $local:ytdlPath --version)
		if ($? -eq $false) { throw '更新後のバージョン取得に失敗しました' }
		Write-Output "youtube-dlをversion $local:ytdlCurrentVersion に更新しました。"
		Write-Output ''
	} catch {
		Write-Error '更新後のバージョン取得に失敗しました' ; exit 1
	}


}

