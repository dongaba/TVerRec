###################################################################################
#  TVerRec : TVerダウンローダ
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
$local:ffmpegRelDir = '../bin'
$local:ffmpegDir = $(Join-Path $script:scriptRoot $local:ffmpegRelDir)
if ($IsWindows) { $local:ffmpegPath = $(Join-Path $local:ffmpegDir 'ffmpeg.exe') }
else { $local:ffmpegPath = $(Join-Path $local:ffmpegDir 'ffmpeg') }

#ffmpegのディレクトリがなければ作成
if (-Not (Test-Path $local:ffmpegDir -PathType Container)) {
	$null = New-Item `
		-ItemType Directory `
		-Path $local:ffmpegDir
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
try {
	$local:latestVersion = Invoke-RestMethod `
		-Uri $local:releases `
		-Method Get `
	| ConvertTo-Json
} catch {
	Out-Msg 'ffmpegの最新バージョンを特定できませんでした' -Fg 'Green'
	return
}

#ffmpegのダウンロード
if ($local:latestVersion -eq $local:ffmpegCurrentVersion) {
	Out-Msg 'ffmpegは最新です。'
	Out-Msg "　ffmpeg current: $local:ffmpegCurrentVersion"
	Out-Msg "　ffmpeg latest: $local:latestVersion"
	Out-Msg ''
} else {
	Out-Msg 'ffmpegが古いため更新します。'
	Out-Msg "　ffmpeg current: $local:ffmpegCurrentVersion"
	Out-Msg "　ffmpeg latest: $local:latestVersion"
	Out-Msg ''

	switch ($true) {
		$IsWindows {
			#ダウンロード
			try {
				$local:donwloadURL = `
					'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
				Invoke-WebRequest `
					-Uri $local:donwloadURL `
					-OutFile "$($local:ffmpegDir)/ffmpeg.zip" `
					-TimeoutSec $script:timeoutSec
			} catch { Out-Msg 'ffmpegのダウンロードに失敗しました' -Fg 'Green' }

			#展開
			try {
				unZip `
					-File "$($local:ffmpegDir)/ffmpeg.zip" `
					-OutPath "$($local:ffmpegDir)"
			} catch { Out-Msg 'ffmpegの展開に失敗しました' -Fg 'Green' }

			#配置
			try {
				Move-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-essentials_build/bin/ff*.exe" `
					-Destination "$local:ffmpegDir" -Force
			} catch { Out-Msg 'ffmpegの配置に失敗しました' -Fg 'Green' }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-essentials_build" `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Out-Msg '中間フォルダの削除に失敗しました' -Fg 'Green' }
			try { Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg.zip" `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Out-Msg '中間ファイルの削除に失敗しました' -Fg 'Green' }

			break
		}
		$IsLinux {
			if (($script:arch -eq 'aarch64') -Or ($script:arch -Contains 'armv8')) {
				$local:cpu = 'arm64'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz'
			} elseif (($script:arch -eq 'armhf') -Or ($script:arch -Contains 'armv7')) {
				$local:cpu = 'armhf'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armhf-static.tar.xz'
			} elseif (($script:arch -eq 'armel') -Or ($script:arch -Contains 'armv6')) {
				$local:cpu = 'armel'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armel-static.tar.xz'
			} elseif (($script:arch -eq 'x86_64') -Or ($script:arch -eq 'ia64')) {
				$local:cpu = 'amd64'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz'
			} elseif (($script:arch -eq 'i686') -Or ($script:arch -eq 'i386')) {
				$local:cpu = 'i686'
				$donwloadURL = `
					'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-i686-static.tar.xz'
			} else {
				Out-Msg 'お使いのCPUに適合するffmpegを特定できませんでした。' -Fg 'Green'
				Out-Msg "お使いのCPUは$($script:arch)に適合するffmpegをご自身で配置してください。" -Fg 'Green'
				exit 1
			}
			Out-Msg "$($local:cpu)用のffmpegをダウンロードします。"

			#ダウンロード
			try {
				Invoke-WebRequest `
					-Uri $donwloadURL `
					-OutFile "$($local:ffmpegDir)/ffmpeg.xz" `
					-TimeoutSec $script:timeoutSec
			} catch { Out-Msg 'ffmpegのダウンロードに失敗しました' -Fg 'Green' }

			#展開
			try {
				(& tar xf "$($local:ffmpegDir)/ffmpeg.xz" -C "$local:ffmpegDir")
			} catch { Out-Msg 'ffmpegの展開に失敗しました' -Fg 'Green' }

			#配置
			try {
				Move-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-static/ff*" `
					-Destination "$local:ffmpegDir" `
					-Force
			} catch { Out-Msg 'ffmpegの配置に失敗しました' -Fg 'Green' }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg-*-static" `
					-Force `
					-Recurse `
					-ErrorAction SilentlyContinue
			} catch { Out-Msg '中間フォルダの削除に失敗しました' -Fg 'Green' }
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg.xz" `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Out-Msg '中間ファイルの削除に失敗しました' -Fg 'Green' }

			break
		}
		$IsMacOS {
			#ダウンロード
			try {
				Invoke-WebRequest `
					-Uri https://evermeet.cx/ffmpeg/getrelease/zip `
					-OutFile "$($local:ffmpegDir)/ffmpeg.zip" `
					-TimeoutSec $script:timeoutSec
				Invoke-WebRequest `
					-Uri https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip `
					-OutFile "$($local:ffmpegDir)/ffprobe.zip" `
					-TimeoutSec $script:timeoutSec
			} catch { Out-Msg 'ffmpegのダウンロードに失敗しました' -Fg 'Green' }

			#展開
			try {
				unZip `
					-File "$($local:ffmpegDir)/ffmpeg.zip" `
					-OutPath "$($local:ffmpegDir)/ffmpeg"
				unZip `
					-File "$($local:ffmpegDir)/ffprobe.zip" `
					-OutPath "$($local:ffmpegDir)/ffprobe"
			} catch { Out-Msg 'ffmpegの展開に失敗しました' -Fg 'Green' }

			#ゴミ掃除
			try {
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffmpeg.zip" `
					-Force `
					-ErrorAction SilentlyContinue
				Remove-Item `
					-Path "$($local:ffmpegDir)/ffprobe.zip" `
					-Force `
					-ErrorAction SilentlyContinue
			} catch { Out-Msg '中間ファイルの削除に失敗しました' -Fg 'Green' }

			break
		}
		default {
			Out-Msg 'お使いのOSに適合するffmpegを特定できませんでした。' -Fg 'Green'
			Out-Msg "お使いのOSは$($script:os)に適合するffmpegをご自身で配置してください。" -Fg 'Green'
			exit 1
			break
		}

	}

	#バージョンチェック
	try {
		$local:ffmpegFileVersion = (& $local:ffmpegPath -version)
		if ($? -eq $false) { throw '更新後のバージョン取得に失敗しました' }
		$null = $local:ffmpegFileVersion[0] -match 'ffmpeg version (\d+\.\d+(\.\d+)?)-.*'
		$local:ffmpegCurrentVersion = $local:matches[1]
		Out-Msg "ffmpegをversion $local:ffmpegCurrentVersion に更新しました。"
		Out-Msg ''
	} catch { exit 1 }

}


