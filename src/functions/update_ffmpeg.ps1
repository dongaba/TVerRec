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
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipArchive, $path)
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

switch ($true) {
	$IsWindows {
		$local:os = [String][System.Environment]::OSVersion
		$local:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
		break
	}
	$IsLinux {
		$local:os = "Linux $([String][System.Environment]::OSVersion.Version)"
		$local:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		break
	}
	$IsMacOS {
		$local:os = "macOS $([String][System.Environment]::OSVersion.Version)"
		$local:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		break
	}
	default {
		$local:os = [String][System.Environment]::OSVersion
		break
	}
}

#ダウンロード先の設定
$local:releases = 'https://www.gyan.dev/ffmpeg/builds/release-version'

#ffmpeg移動先相対Path
$local:ffmpegDir = $(Join-Path $local:scriptRoot '../bin')
if ($IsWindows) { $local:ffmpegPath = $(Join-Path $local:ffmpegDir './ffmpeg.exe') }
else { $local:ffmpegPath = $(Join-Path $local:ffmpegDir 'ffmpeg') }

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
$local:latestVersion = ''
try {
	$local:latestVersion = Invoke-RestMethod `
		-Uri $local:releases `
		-Method Get `
	| ConvertTo-Json
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

	switch ($true) {
		$IsWindows {
			#ダウンロード
			Write-Output 'ffmpegの最新版をダウンロードします'
			try {
				$local:donwloadURL = `
					'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
				Invoke-WebRequest `
					-Uri $local:donwloadURL `
					-OutFile $(Join-Path $local:ffmpegDir './ffmpeg.zip')
			} catch { Write-Error '❗ ffmpegのダウンロードに失敗しました' ; exit 1 }

			#展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try {
				unZip `
					-File "$($local:ffmpegDir)/ffmpeg.zip" `
					-OutPath "$($local:ffmpegDir)"
			} catch { Write-Error '❗ ffmpegの解凍に失敗しました' ; exit 1 }

			#配置
			Write-Output '解凍したffmpegを配置します'
			try {
				Move-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-essentials_build/bin/ff*.exe" `
					-Destination "$local:ffmpegDir" -Force
			} catch { Write-Error '❗ ffmpegの配置に失敗しました' ; exit 1 }


			#ゴミ掃除
			Write-Output '中間ディレクトリと中間ファイルを削除します'
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-essentials_build" `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ディレクトリの削除に失敗しました' ; exit 1 }


			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg.zip" `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ファイルの削除に失敗しました' ; exit 1 }


			break
		}
		$IsLinux {
			if (($local:arch -eq 'aarch64') -Or ($local:arch -Contains 'armv8')) {
				$local:cpu = 'arm64'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz'
			} elseif (($local:arch -eq 'armhf') -Or ($local:arch -Contains 'armv7')) {
				$local:cpu = 'armhf'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armhf-static.tar.xz'
			} elseif (($local:arch -eq 'armel') -Or ($local:arch -Contains 'armv6')) {
				$local:cpu = 'armel'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armel-static.tar.xz'
			} elseif (($local:arch -eq 'x86_64') -Or ($local:arch -eq 'ia64')) {
				$local:cpu = 'amd64'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz'
			} elseif (($local:arch -eq 'i686') -Or ($local:arch -eq 'i386')) {
				$local:cpu = 'i686'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-i686-static.tar.xz'
			} else {
				Write-Warning '❗ お使いのCPUに適合するffmpegを特定できませんでした。'
				Write-Warning "❗ お使いのCPU $($local:arch)に適合するffmpegをご自身で配置してください。"
				return
			}

			#ダウンロード
			Write-Output "ffmpegの最新版$($local:cpu)用をダウンロードします"
			try {
				Invoke-WebRequest `
					-Uri $donwloadURL `
					-OutFile "$($local:ffmpegDir)/ffmpeg.xz"
			} catch { Write-Error '❗ ffmpegのダウンロードに失敗しました' ; exit 1 }

			#展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try {
				(& tar xf "$($local:ffmpegDir)/ffmpeg.xz" -C "$local:ffmpegDir")
			} catch { Write-Error '❗ ffmpegの展開に失敗しました' ; exit 1 }

			#配置
			Write-Output '解凍したffmpegを配置します'
			try {
				Move-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-static/ff*" `
					-Destination "$local:ffmpegDir" `
					-Force
			} catch { Write-Error '❗ ffmpegの配置に失敗しました' ; exit 1 }

			#ゴミ掃除
			Write-Output '中間ディレクトリと中間ファイルを削除します'
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-static" `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ディレクトリの削除に失敗しました' ; exit 1 }
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg.xz" `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ファイルの削除に失敗しました' ; exit 1 }

			break
		}
		$IsMacOS {
			#ダウンロード
			Write-Output 'ffmpegの最新版をダウンロードします'
			try {
				Invoke-WebRequest `
					-Uri https://evermeet.cx/ffmpeg/getrelease/zip `
					-OutFile "$($local:ffmpegDir)/ffmpeg.zip"
				Invoke-WebRequest `
					-Uri https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip `
					-OutFile "$($local:ffmpegDir)/ffprobe.zip"
			} catch { Write-Error '❗ ffmpegのダウンロードに失敗しました' ; exit 1 }

			#展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try {
				unZip `
					-File "$($local:ffmpegDir)/ffmpeg.zip" `
					-OutPath "$($local:ffmpegDir)"
				unZip `
					-File "$($local:ffmpegDir)/ffprobe.zip" `
					-OutPath "$($local:ffmpegDir)"
			} catch { Write-Error '❗ ffmpegの展開に失敗しました' ; exit 1 }

			#ゴミ掃除
			Write-Output '中間ファイルを削除します'
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg.zip" `
					-Force `
					-ErrorAction SilentlyContinue
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffprobe.zip" `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Write-Error '❗ 中間ファイルの削除に失敗しました' ; exit 1 }

			break
		}
		default {
			Write-Warning '❗ お使いのOSに適合するffmpegを特定できませんでした。'
			Write-Warning "❗ お使いのOSは$($local:os)に適合するffmpegをご自身で配置してください。"
			return
			break
		}

	}

	if ($IsWindows -eq $false) {
		#実行権限の付与
		(& chmod a+x $local:ffmpegPath)
		(& chmod a+x $($local:ffmpegPath).Replace('ffmpeg', 'ffprobe'))
	}

	#バージョンチェック
	try {
		$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
		$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
		$local:ffmpegCurrentVersion = $local:matches[1]
		Write-Output "💡 ffmpegをversion $local:ffmpegCurrentVersion に更新しました。"
		Write-Output ''
	} catch { Write-Error '❗ 更新後のバージョン取得に失敗しました' ; exit 1 }

}


