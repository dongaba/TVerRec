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
} catch { Write-Error '❗ ディレクトリ設定に失敗しました' ; exit 1 }

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

		#ffmpegのバージョン取得
		try {
			if (Test-Path $local:ffmpegPath -PathType Leaf) {
				# get version of current ffmpeg.exe
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:ffmpegCurrentVersion = $matches[1]
			} else { $local:ffmpegCurrentVersion = '' }
		} catch { $local:ffmpegCurrentVersion = '' }

		#ffmpegの最新バージョン取得
		$local:releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		$local:latestVersion = ''
		try {
			$local:latestVersion = Invoke-RestMethod `
				-Uri $local:releases `
				-Method Get
			$null = $local:latestVersion -match 'yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-\d+-\d+(.*)ffmpeg-(.*)-win64-gpl.zip'
			$local:latestVersion = $matches[5] + '-' + $matches[1] + $matches[2] + $matches[3]
		} catch { Write-Warning '❗ ffmpegの最新バージョンを特定できませんでした'; return }

		#ffmpegのダウンロード
		if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
			Write-Output 'ffmpegは最新です。'
			Write-Output "　Local version: $local:ffmpegCurrentVersion"
			Write-Output "　Latest version: $local:latestVersion"
			Write-Output ''
		} else {
			Write-Warning '💡 ffmpegが古いため更新します。'
			Write-Warning "　Local version: $local:ffmpegCurrentVersion"
			Write-Warning "　Latest version: $local:latestVersion"
			Write-Output ''

			if ([System.Environment]::IS64bitOperatingSystem -eq $true) {
				$local:cpu = 'x64'
				$donwloadURL = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip'
			} else {
				$local:cpu = 'x86'
				$donwloadURL = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win32-gpl.zip'
			}

			#ダウンロード
			Write-Output "ffmpegの最新版 $local:cpu 用をダウンロードします"
			try {
				Invoke-WebRequest `
					-Uri $donwloadURL `
					-OutFile (Join-Path $local:binDir 'ffmpeg.zip')
			} catch { Write-Error '❗ ffmpegのダウンロードに失敗しました' ; exit 1 }

			#展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try {
				unZip `
					-File (Join-Path $local:binDir 'ffmpeg.zip') `
					-OutPath $local:binDir
			} catch { Write-Error '❗ ffmpegの解凍に失敗しました' ; exit 1 }

			#配置
			Write-Output '解凍したffmpegを配置します'
			try {
				Move-Item `
					-Path "$local:binDir/ffmpeg-master-latest-*-gpl/bin/ff*.exe" `
					-Destination $local:binDir `
					-Force
			} catch { Write-Error '❗ ffmpegの配置に失敗しました' ; exit 1 }

			#ゴミ掃除
			Write-Output '中間ディレクトリと中間ファイルを削除します'
			try {
				Remove-Item `
					-Path "$local:binDir/ffmpeg-master-latest-*-gpl" `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ディレクトリの削除に失敗しました' ; exit 1 }
			try {
				Remove-Item `
					-Path (Join-Path $local:binDir 'ffmpeg.zip') `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ファイルの削除に失敗しました' ; exit 1 }

			#バージョンチェック
			try {
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:ffmpegCurrentVersion = $local:matches[1]
				Write-Output "💡 ffmpegをversion $local:ffmpegCurrentVersion に更新しました。"
				Write-Output ''
			} catch { Write-Error '❗ 更新後のバージョン取得に失敗しました' ; exit 1 }

		}

		break

	}
	$IsLinux {
		$local:os = 'Linux ' + [String][System.Environment]::OSVersion.Version
		$local:arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#ffmpegのバージョン取得
		try {
			if (Test-Path $local:ffmpegPath -PathType Leaf) {
				# get version of current ffmpeg.exe
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:ffmpegCurrentVersion = $matches[1]
			} else { $local:ffmpegCurrentVersion = '' }
		} catch { $local:ffmpegCurrentVersion = '' }

		#ffmpegの最新バージョン取得
		$local:releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		$local:latestVersion = ''
		try {
			$local:latestVersion = Invoke-RestMethod `
				-Uri $local:releases `
				-Method Get `
			| grep 'linux64-gpl.tar.xz'
			$null = $local:latestVersion -match 'yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-\d+-\d+(.*)ffmpeg-(.*)-linux64-gpl.tar.xz'
			$local:latestVersion = $matches[5] + '-' + $matches[1] + $matches[2] + $matches[3]
		} catch { Write-Warning '❗ ffmpegの最新バージョンを特定できませんでした'; return }

		#ffmpegのダウンロード
		if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
			Write-Output 'ffmpegは最新です。'
			Write-Output "　Local version: $local:ffmpegCurrentVersion"
			Write-Output "　Latest version: $local:latestVersion"
			Write-Output ''
		} else {
			Write-Warning '💡 ffmpegが古いため更新します。'
			Write-Warning "　Local version: $local:ffmpegCurrentVersion"
			Write-Warning "　Latest version: $local:latestVersion"
			Write-Output ''

			if (($local:arch -eq 'aarch64') -Or ($local:arch -Contains 'armv8')) {
				$local:cpu = 'arm64'
				$donwloadURL = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz'
			} elseif (($local:arch -eq 'x86_64') -Or ($local:arch -eq 'ia64')) {
				$local:cpu = 'amd64'
				$donwloadURL = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz'
			} else {
				Write-Warning '❗ お使いのCPUに適合するffmpegを特定できませんでした。'
				Write-Warning "❗ お使いのCPU $local:arch に適合するffmpegをご自身で配置してください。"
				return
			}

			#ダウンロード
			Write-Output "ffmpegの最新版 $local:cpu 用をダウンロードします"
			try {
				Invoke-WebRequest `
					-Uri $donwloadURL `
					-OutFile (Join-Path $local:binDir 'ffmpeg.tar.xz')
			} catch { Write-Error '❗ ffmpegのダウンロードに失敗しました' ; exit 1 }

			#展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try {
				(& tar Jxf (Join-Path $local:binDir 'ffmpeg.tar.xz') -C "$local:binDir")
			} catch { Write-Error '❗ ffmpegの展開に失敗しました' ; exit 1 }

			#配置
			Write-Output '解凍したffmpegを配置します'
			try {
				Move-Item `
					-Path "$local:binDir/ffmpeg-master-latest-*-gpl/bin/ff*" `
					-Destination $local:binDir `
					-Force
			} catch { Write-Error '❗ ffmpegの配置に失敗しました' ; exit 1 }

			#ゴミ掃除
			Write-Output '中間ディレクトリと中間ファイルを削除します'
			try {
				Remove-Item `
					-Path "$local:binDir/ffmpeg-master-latest-*-gpl" `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ディレクトリの削除に失敗しました' ; exit 1 }
			try {
				Remove-Item `
					-Path (Join-Path $local:binDir 'ffmpeg.tar.xz') `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ファイルの削除に失敗しました' ; exit 1 }

			#実行権限の付与
		(& chmod a+x $local:ffmpegPath)
		(& chmod a+x ($local:ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (.*) Copyright'
				$local:ffmpegCurrentVersion = $local:matches[1]
				Write-Output "💡 ffmpegをversion $local:ffmpegCurrentVersion に更新しました。"
				Write-Output ''
			} catch { Write-Error '❗ 更新後のバージョン取得に失敗しました' ; exit 1 }

		}

		break

	}
	$IsMacOS {
		$local:os = 'macOS ' + [String][System.Environment]::OSVersion.Version
		$local:arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#ffmpegのバージョン取得
		try {
			if (Test-Path $local:ffmpegPath -PathType Leaf) {
				# get version of current ffmpeg.exe
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?).*'
				$local:ffmpegCurrentVersion = $matches[1]
			} else { $local:ffmpegCurrentVersion = '' }
		} catch { $local:ffmpegCurrentVersion = '' }

		#ffmpegの最新バージョン取得
		$local:ffmpegReleases = 'https://evermeet.cx/ffmpeg/info/ffmpeg/release'
		$local:ffprobeReleases = 'https://evermeet.cx/ffmpeg/info/ffprobe/release'
		$local:ffmpegReleaseInfo = ''
		$local:ffprobeReleaseInfo = ''
		$local:latestVersion = ''
		try {
			$local:ffmpegReleaseInfo = Invoke-RestMethod `
				-Uri $local:ffmpegReleases `
				-Method Get
			$local:latestVersion = $local:ffmpegReleaseInfo.version
			$local:ffprobeReleaseInfo = Invoke-RestMethod `
				-Uri $local:ffprobeReleases `
				-Method Get
		} catch { Write-Warning '❗ ffmpegの最新バージョンを特定できませんでした'; return }

		#ffmpegのダウンロード
		if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
			Write-Output 'ffmpegは最新です。'
			Write-Output "　Local version: $local:ffmpegCurrentVersion"
			Write-Output "　Latest version: $local:latestVersion"
			Write-Output ''
		} else {
			Write-Warning '💡 ffmpegが古いため更新します。'
			Write-Warning "　Local version: $local:ffmpegCurrentVersion"
			Write-Warning "　Latest version: $local:latestVersion"
			Write-Output ''

			#ダウンロード
			Write-Output 'ffmpegの最新版をダウンロードします'
			try {
				Invoke-WebRequest `
					-Uri $local:ffmpegReleaseInfo.download.zip.url `
					-OutFile (Join-Path $local:binDir 'ffmpeg.zip')
				Invoke-WebRequest `
					-Uri $local:ffprobeReleaseInfo.download.zip.url `
					-OutFile (Join-Path $local:binDir 'ffprobe.zip')
			} catch { Write-Error '❗ ffmpegのダウンロードに失敗しました' ; exit 1 }

			#展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try {
				Remove-Item `
					-Path (Join-Path $local:binDir 'ffmpeg') `
					-Force `
					-ErrorAction SilentlyContinue
				Remove-Item `
					-Path (Join-Path $local:binDir 'ffprobe') `
					-Force `
					-ErrorAction SilentlyContinue
				unZip `
					-File (Join-Path $local:binDir 'ffmpeg.zip') `
					-OutPath $local:binDir
				unZip `
					-File (Join-Path $local:binDir 'ffprobe.zip') `
					-OutPath $local:binDir
			} catch { Write-Error '❗ ffmpegの展開に失敗しました' ; exit 1 }

			#ゴミ掃除
			Write-Output '中間ファイルを削除します'
			try {
				Remove-Item `
					-Path (Join-Path $local:binDir 'ffmpeg.zip') `
					-Force `
					-ErrorAction SilentlyContinue
				Remove-Item `
					-Path (Join-Path $local:binDir 'ffprobe.zip') `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ファイルの削除に失敗しました' ; exit 1 }

			#実行権限の付与
		(& chmod a+x $local:ffmpegPath)
		(& chmod a+x ($local:ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
				$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
				$local:ffmpegCurrentVersion = $local:matches[1]
				Write-Output "💡 ffmpegをversion $local:ffmpegCurrentVersion に更新しました。"
				Write-Output ''
			} catch { Write-Error '❗ 更新後のバージョン取得に失敗しました' ; exit 1 }

		}

		break

	}
	default {
		$local:os = [String][System.Environment]::OSVersion
		Write-Warning '❗ お使いのOSに適合するffmpegを特定できませんでした。'
		Write-Warning ('❗ ' + $local:os + 'に適合するffmpegをご自身で配置してください。')
		return
		break
	}
}
