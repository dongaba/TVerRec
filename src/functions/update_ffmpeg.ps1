###################################################################################
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
	Set-Location $local:scriptRoot
} catch { Write-Error ('❗ ディレクトリ設定に失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#ffmpeg移動先相対Path
$local:binDir = Convert-Path (Join-Path $local:scriptRoot '../bin')
if ($IsWindows) { $local:ffmpegPath = Join-Path $local:binDir './ffmpeg.exe' }
else { $local:ffmpegPath = Join-Path $local:binDir 'ffmpeg' }

switch ($true) {
	$IsWindows {
		$local:os = [String][System.Environment]::OSVersion
		$local:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()

		#残っているかもしれない中間ファイルを削除
		Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $local:binDir) -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item -Path (Join-Path $local:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $local:ffmpegPath -PathType Leaf) {
				# get version of current ffmpeg.exe
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:currentVersion = $matches[1]
			} else { $local:currentVersion = '' }
		} catch { $local:currentVersion = '' }

		#ffmpegの最新バージョン取得
		$local:releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		$local:latestRelease = ''
		$local:latestVersion = ''
		try {
			$local:latestRelease = Invoke-RestMethod -Uri $local:releases -Method 'GET'
			$null = $local:latestRelease -match 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(n\d+\.\d+-\d+-[0-9a-z]*)(-win64-gpl-)(.*).zip'
			$local:latestVersion = $matches[6]
		} catch { Write-Warning ('❗ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($local:currentVersion -match $local:latestVersion) {
			Write-Output ('💡 ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $local:currentVersion)
			Write-Output ('　Latest version: {0}' -f $local:latestVersion)
			Write-Output ('')
		} else {
			Write-Output ('❗ ffmpegが古いため更新します。')
			Write-Output ('　Local version: {0}' -f $local:currentVersion)
			Write-Output ('　Latest version: {0}' -f $local:latestVersion)
			Write-Output ('')

			if ([System.Environment]::IS64bitOperatingSystem -eq $true) {
				$local:cpu = 'x64'
				$null = $local:latestRelease -match 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-win64-gpl-)(.*).zip'
				$local:donwloadURL = $matches[0]
			} else {
				$local:cpu = 'x86'
				$null = $local:latestRelease -match 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-win32-gpl-)(.*).zip'
				$local:donwloadURL = $matches[0]
			}

			#ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $local:cpu)
			try { Invoke-WebRequest -Uri $local:donwloadURL -OutFile (Join-Path $local:binDir 'ffmpeg.zip') }
			catch { Write-Error ('❗ ffmpegのダウンロードに失敗しました') ; exit 1 }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try { unZip -File (Join-Path $local:binDir 'ffmpeg.zip') -OutPath $local:binDir }
			catch { Write-Error ('❗ ffmpegの解凍に失敗しました') ; exit 1 }

			#配置
			Write-Output ('解凍したffmpegを配置します')
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*.exe' -f $local:binDir) -Destination $local:binDir -Force }
			catch { Write-Error ('❗ ffmpegの配置に失敗しました') ; exit 1 }

			#ゴミ掃除
			Write-Output ('中間ディレクトリと中間ファイルを削除します')
			try { Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $local:binDir) -Force -Recurse -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ディレクトリの削除に失敗しました') ; exit 1 }
			try { Remove-Item -Path (Join-Path $local:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ファイルの削除に失敗しました') ; exit 1 }

			#バージョンチェック
			try {
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:currentVersion = $local:matches[1]
				Write-Output ('💡 ffmpegをversion{0}に更新しました。' -f $local:currentVersion)
				Write-Output ('')
			} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }

		}

		break

	}
	$IsLinux {
		$local:os = ('Linux {0}' -f [System.Environment]::OSVersion.Version)
		$local:arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#残っているかもしれない中間ファイルを削除
		Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $local:binDir) -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item -Path (Join-Path $local:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $local:ffmpegPath -PathType Leaf) {
				# get version of current ffmpeg.exe
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:currentVersion = $matches[1]
			} else { $local:currentVersion = '' }
		} catch { $local:currentVersion = '' }

		#ffmpegの最新バージョン取得
		$local:releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		$local:latestRelease = ''
		$local:latestVersion = ''
		try {
			$local:latestRelease = Invoke-RestMethod -Uri $local:releases -Method 'GET'
			$null = $local:latestRelease -match 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(n\d+\.\d+-\d+-[0-9a-z]*)(-linux64-gpl-)(.*).tar.xz'
			$local:latestVersion = $matches[6]
		} catch { Write-Warning ('❗ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($local:currentVersion -match $local:latestVersion) {
			Write-Output ('💡 ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $local:currentVersion)
			Write-Output ('　Latest version: {0}' -f $local:latestVersion)
			Write-Output ('')
		} else {
			Write-Output ('❗ ffmpegが古いため更新します。')
			Write-Output ('　Local version: {0}' -f $local:currentVersion)
			Write-Output ('　Latest version: {0}' -f $local:latestVersion)
			Write-Output ('')

			if (($local:arch -eq 'aarch64') -Or ($local:arch -Contains 'armv8')) {
				$local:cpu = 'arm64'
				$null = $local:latestRelease -match 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linuxarm64-gpl-)(.*).tar.xz'
				$local:donwloadURL = $matches[0]
			} elseif (($local:arch -eq 'x86_64') -Or ($local:arch -eq 'ia64')) {
				$local:cpu = 'amd64'
				$null = $local:latestRelease -match 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linux64-gpl-)(.*).tar.xz'
				$local:donwloadURL = $matches[0]
			} else {
				Write-Warning ('❗ お使いのCPUに適合するffmpegを特定できませんでした。')
				Write-Warning ('❗ {0}に適合するffmpegをご自身で配置してください。' -f $local:arch)
				return
			}

			#ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $local:cpu)
			try { Invoke-WebRequest -Uri $local:donwloadURL -OutFile (Join-Path $local:binDir 'ffmpeg.tar.xz') }
			catch { Write-Error ('❗ ffmpegのダウンロードに失敗しました') ; exit 1 }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try { (& tar Jxf (Join-Path $local:binDir 'ffmpeg.tar.xz') -C $local:binDir) }
			catch { Write-Error ('❗ ffmpegの展開に失敗しました') ; exit 1 }

			#配置
			Write-Output ('解凍したffmpegを配置します')
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*' -f $local:binDir) -Destination $local:binDir -Force }
			catch { Write-Error ('❗ ffmpegの配置に失敗しました') ; exit 1 }

			#ゴミ掃除
			Write-Output ('中間ディレクトリと中間ファイルを削除します')
			try { Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $local:binDir) -Force -Recurse -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ディレクトリの削除に失敗しました') ; exit 1 }
			try { Remove-Item -Path (Join-Path $local:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ファイルの削除に失敗しました') ; exit 1 }

			#実行権限の付与
		(& chmod a+x $local:ffmpegPath)
		(& chmod a+x ($local:ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:currentVersion = $local:matches[1]
				Write-Output ('💡 ffmpegをversion{0}に更新しました。' -f $local:currentVersion)
				Write-Output ('')
			} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }

		}

		break

	}
	$IsMacOS {
		$local:os = ('macOS {0}' -f [System.Environment]::OSVersion.Version)
		$local:arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#残っているかもしれない中間ファイルを削除
		Remove-Item -Path (Join-Path $local:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue
		Remove-Item -Path (Join-Path $local:binDir 'ffprobe.zip') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $local:ffmpegPath -PathType Leaf) {
				# get version of current ffmpeg.exe
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?).*'
				$local:currentVersion = $matches[1]
			} else { $local:currentVersion = '' }
		} catch { $local:currentVersion = '' }

		#ffmpegの最新バージョン取得
		$local:ffmpegReleases = 'https://evermeet.cx/ffmpeg/info/ffmpeg/release'
		$local:ffprobeReleases = 'https://evermeet.cx/ffmpeg/info/ffprobe/release'
		$local:ffmpegReleaseInfo = ''
		$local:ffprobeReleaseInfo = ''
		$local:latestVersion = ''
		try {
			$local:ffmpegReleaseInfo = Invoke-RestMethod -Uri $local:ffmpegReleases -Method 'GET'
			$local:latestVersion = $local:ffmpegReleaseInfo.version
			$local:ffprobeReleaseInfo = Invoke-RestMethod -Uri $local:ffprobeReleases -Method 'GET'
		} catch { Write-Warning ('❗ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($local:latestVersion -eq $local:currentVersion) {
			Write-Output ('💡 ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $local:currentVersion)
			Write-Output ('　Latest version: {0}' -f $local:latestVersion)
			Write-Output ('')
		} else {
			Write-Output ('❗ ffmpegが古いため更新します。')
			Write-Output ('　Local version: {0}' -f $local:currentVersion)
			Write-Output ('　Latest version: {0}' -f $local:latestVersion)
			Write-Output ('')

			#ダウンロード
			Write-Output ('ffmpegの最新版をダウンロードします')
			try {
				Invoke-WebRequest -Uri $local:ffmpegReleaseInfo.download.zip.url -OutFile (Join-Path $local:binDir 'ffmpeg.zip')
				Invoke-WebRequest -Uri $local:ffprobeReleaseInfo.download.zip.url -OutFile (Join-Path $local:binDir 'ffprobe.zip')
			} catch { Write-Error ('❗ ffmpegのダウンロードに失敗しました') ; exit 1 }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try {
				Remove-Item -Path (Join-Path $local:binDir 'ffmpeg') -Force -ErrorAction SilentlyContinue
				Remove-Item -Path (Join-Path $local:binDir 'ffprobe') -Force -ErrorAction SilentlyContinue
				unZip -File (Join-Path $local:binDir 'ffmpeg.zip') -OutPath $local:binDir
				unZip -File (Join-Path $local:binDir 'ffprobe.zip') -OutPath $local:binDir
			} catch { Write-Error ('❗ ffmpegの展開に失敗しました') ; exit 1 }

			#ゴミ掃除
			Write-Output ('中間ファイルを削除します')
			try {
				Remove-Item -Path (Join-Path $local:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue
				Remove-Item -Path (Join-Path $local:binDir 'ffprobe.zip') -Force -ErrorAction SilentlyContinue
			} catch { Write-Error ('❗ 中間ファイルの削除に失敗しました') ; exit 1 }

			#実行権限の付与
		(& chmod a+x $local:ffmpegPath)
		(& chmod a+x ($local:ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
				$local:currentVersion = $local:matches[1]
				Write-Output ('💡 ffmpegをversion{0}に更新しました。' -f $local:currentVersion)
				Write-Output ('')
			} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }

		}

		break

	}
	default {
		$local:os = [String][System.Environment]::OSVersion
		Write-Warning ('❗ お使いのOSに適合するffmpegを特定できませんでした。')
		Write-Warning ('❗ {0}に適合するffmpegをご自身で配置してください。' -f $local:os)
		return
		break
	}
}
