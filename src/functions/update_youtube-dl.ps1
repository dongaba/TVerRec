###################################################################################
#
#		Windows用youtube-dl最新化処理スクリプト
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
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('File')]
		[String]$zipArchive,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('OutPath')]
		[String]$path
	)
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $path, $true)
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($script:myInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$local:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition
		$local:scriptRoot = Split-Path -Parent -Path $local:scriptRoot
	} else { $local:scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ ディレクトリ設定に失敗しました') ; exit 1 }

#設定ファイル読み込み
try {
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
	} elseif ($IsWindows) {
		while (!( Test-Path (Join-Path $script:confDir 'user_setting.ps1')) ) {
			Write-Output ('ユーザ設定ファイルを作成する必要があります')
			. 'gui/gui_setting.ps1'
		}
		if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
			. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
		}
	} else {
		Write-Error ('❗ ユーザ設定が完了してません') ; exit 1
	}
} catch { Write-Error ('❗ 設定ファイルの読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#githubの設定
switch ($script:preferredYoutubedl) {
	'yt-dlp' { $local:repo = 'yt-dlp/yt-dlp' ; break }
	'ytdl-patched' { $local:repo = 'ytdl-patched/ytdl-patched' ; break }
	default { Write-Error ('❗ youtube-dlの取得元の指定が無効です') ; exit 1 ; break }
}
$local:releases = ('https://api.github.com/repos/{0}/releases' -f $local:repo)

#youtube-dl移動先相対Path
$local:binDir = Convert-Path (Join-Path $local:scriptRoot '../bin')
if ($IsWindows) { $local:ytdlPath = Join-Path $local:binDir 'youtube-dl.exe' }
else { $local:ytdlPath = Join-Path $local:binDir 'youtube-dl' }

#youtube-dlのバージョン取得
try {
	if (Test-Path $local:ytdlPath -PathType Leaf) { $local:currentVersion = (& $local:ytdlPath --version) }
	else { $local:currentVersion = '' }
} catch { $local:currentVersion = '' }

#youtube-dlの最新バージョン取得
try {
	$local:latestVersion = (Invoke-RestMethod -Uri $local:releases -Method 'GET')[0].Tag_Name
} catch { Write-Warning ('❗ youtube-dlの最新バージョンを特定できませんでした') ; return }

#youtube-dlのダウンロード
if ($local:latestVersion -eq $local:currentVersion) {
	Write-Output ('💡 youtube-dlは最新です。')
	Write-Output ('　Local version: {0}' -f $local:currentVersion)
	Write-Output ('　Latest version: {0}' -f $local:latestVersion)
	Write-Output ('')
} else {
	Write-Output ('❗ youtube-dlが古いため更新します。')
	Write-Output ('　Local version: {0}' -f $local:currentVersion)
	Write-Output ('　Latest version: {0}' -f $local:latestVersion)
	Write-Output ('')
	if ($IsWindows -eq $false) {
		#githubの設定
		$local:file = $script:preferredYoutubedl
		$local:fileAfterRename = 'youtube-dl'
	} else {
		#githubの設定
		$local:file = ('{0}.exe' -f $script:preferredYoutubedl)
		$local:fileAfterRename = 'youtube-dl.exe'
	}

	Write-Output ('youtube-dlの最新版をダウンロードします')
	try {
		#ダウンロード
		$local:tag = (Invoke-RestMethod -Uri $local:releases -Method 'GET')[0].Tag_Name
		$local:downloadURL = ('https://github.com/{0}/releases/download/{1}/{2}' -f $local:repo, $local:tag, $local:file)
		$local:ytdlFileLocation = Join-Path $local:binDir $local:fileAfterRename
		Invoke-WebRequest -Uri $local:downloadURL -Out $local:ytdlFileLocation
	} catch { Write-Error ('❗ youtube-dlのダウンロードに失敗しました') ; exit 1 }

	if ($IsWindows -eq $false) { (& chmod a+x $local:ytdlFileLocation) }

	#バージョンチェック
	try {
		$local:currentVersion = (& $local:ytdlPath --version)
		if ($? -eq $false) { throw '更新後のバージョン取得に失敗しました' }
		Write-Output ('💡 youtube-dlをversion{0}に更新しました。' -f $local:currentVersion)
		Write-Output ('')
	} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }


}

