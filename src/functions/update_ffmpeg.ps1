###################################################################################
#
#		Windows用ffmpeg最新化処理スクリプト
#
###################################################################################
Add-Type -AssemblyName System.IO.Compression.FileSystem

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([void])]
	Param(
		[Parameter(Mandatory = $true)][string]$path,
		[Parameter(Mandatory = $true)][string]$destination
	)

	if (Test-Path -Path $path) {
		Write-Verbose ('{0}を{1}に展開します' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('{0}を展開しました' -f $path)
	} else {
		Write-Error ('{0}が見つかりません' -f $path)
	}
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($script:myInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition)
	} else { $scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❗ ディレクトリ設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❗ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }

#設定ファイル読み込み
try {
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
	} elseif ($IsWindows) {
		while (!( Test-Path (Join-Path $script:confDir 'user_setting.ps1')) ) {
			Write-Output ('ユーザ設定ファイルを作成する必要があります')
			& 'gui/gui_setting.ps1'
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

#ffmpeg移動先相対Path
if ($IsWindows) { $ffmpegPath = Join-Path $script:binDir './ffmpeg.exe' }
else { $ffmpegPath = Join-Path $script:binDir 'ffmpeg' }

switch ($true) {
	$IsWindows {
		$os = [String][System.Environment]::OSVersion
		$arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()

		#残っているかもしれない中間ファイルを削除
		Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }

		#ffmpegの最新バージョン取得
		$releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		$latestRelease = ''
		$latestVersion = ''
		try {
			$latestRelease = Invoke-RestMethod -Uri $releases -Method 'GET'
			if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(\w*)(\d+\.*\d*\.*\d*)(.*)(-win64-gpl-)(.*).zip') {
				$latestVersion = $matches[7]
			}
		} catch { Write-Warning ('❗ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ('💡 ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
		} else {
			Write-Output ('')
			Write-Output ('❗ ffmpegが古いため更新します。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)

			if ([System.Environment]::IS64bitOperatingSystem) {
				$cpu = 'x64'
				if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-win64-gpl-)(.*).zip') {
					$donwloadURL = $matches[0]
				}
			} else {
				$cpu = 'x86'
				if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-win32-gpl-)(.*).zip') {
					$donwloadURL = $matches[0]
				}
			}

			#ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $cpu)
			try { Invoke-WebRequest -UseBasicParsing -Uri $donwloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.zip') }
			catch { Write-Error ('❗ ffmpegのダウンロードに失敗しました') ; exit 1 }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try { Expand-Zip -Path (Join-Path $script:binDir 'ffmpeg.zip') -Destination $script:binDir }
			catch { Write-Error ('❗ ffmpegの解凍に失敗しました') ; exit 1 }

			#配置
			Write-Output ('解凍したffmpegを配置します')
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*.exe' -f $script:binDir) -Destination $script:binDir -Force }
			catch { Write-Error ('❗ ffmpegの配置に失敗しました') ; exit 1 }

			#ゴミ掃除
			Write-Output ('中間ディレクトリと中間ファイルを削除します')
			try { Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ディレクトリの削除に失敗しました') ; exit 1 }
			try { Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ファイルの削除に失敗しました') ; exit 1 }

			#バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }

		}

		continue

	}
	$IsLinux {
		$os = ('Linux {0}' -f [System.Environment]::OSVersion.Version)
		$arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#残っているかもしれない中間ファイルを削除
		Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }

		#ffmpegの最新バージョン取得
		$releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		$latestRelease = ''
		$latestVersion = ''
		try {
			$latestRelease = Invoke-RestMethod -Uri $releases -Method 'GET'
			if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(\w*)(\d+\.*\d*\.*\d*)(.*)(-linux64-gpl-)(.*).tar.xz') {
				$latestVersion = $matches[7]
			}
		} catch { Write-Warning ('❗ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ('💡 ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
		} else {
			Write-Output ('')
			Write-Output ('❗ ffmpegが古いため更新します。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)

			switch ($true) {
				(($arch -eq 'aarch64') -or ($arch -icontains 'armv8')) {
					$cpu = 'arm64'
					if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linuxarm64-gpl-)(.*).tar.xz') {
						$donwloadURL = $matches[0]
					}
					continue
				}
				($arch -in @('x86_64', 'ia64')) {
					$cpu = 'amd64'
					if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linux64-gpl-)(.*).tar.xz') {
						$donwloadURL = $matches[0]
					}
					continue
				}
				default {
					Write-Warning ('❗ お使いのCPUに適合するffmpegを特定できませんでした。')
					Write-Warning ('❗ {0}に適合するffmpegをご自身で配置してください。' -f $arch)
					return
					continue
				}
			}

			#ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $cpu)
			try { Invoke-WebRequest -UseBasicParsing -Uri $donwloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.tar.xz') }
			catch { Write-Error ('❗ ffmpegのダウンロードに失敗しました') ; exit 1 }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try { (& tar Jxf (Join-Path $script:binDir 'ffmpeg.tar.xz') -C $script:binDir) }
			catch { Write-Error ('❗ ffmpegの展開に失敗しました') ; exit 1 }

			#配置
			Write-Output ('解凍したffmpegを配置します')
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*' -f $script:binDir) -Destination $script:binDir -Force }
			catch { Write-Error ('❗ ffmpegの配置に失敗しました') ; exit 1 }

			#ゴミ掃除
			Write-Output ('中間ディレクトリと中間ファイルを削除します')
			try { Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ディレクトリの削除に失敗しました') ; exit 1 }
			try { Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue }
			catch { Write-Error ('❗ 中間ファイルの削除に失敗しました') ; exit 1 }

			#実行権限の付与
			(& chmod a+x $ffmpegPath)
			(& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }

		}

		continue

	}
	$IsMacOS {
		$os = ('macOS {0}' -f [System.Environment]::OSVersion.Version)
		$arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#残っているかもしれない中間ファイルを削除
		Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath (Join-Path $script:binDir 'ffprobe.zip') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }

		#ffmpegの最新バージョン取得
		$ffmpegReleases = 'https://evermeet.cx/ffmpeg/info/ffmpeg/release'
		$ffprobeReleases = 'https://evermeet.cx/ffmpeg/info/ffprobe/release'
		$ffmpegReleaseInfo = ''
		$ffprobeReleaseInfo = ''
		$latestVersion = ''
		try {
			$ffmpegReleaseInfo = Invoke-RestMethod -Uri $ffmpegReleases -Method 'GET'
			$latestVersion = $ffmpegReleaseInfo.version
			$ffprobeReleaseInfo = Invoke-RestMethod -Uri $ffprobeReleases -Method 'GET'
		} catch { Write-Warning ('❗ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($latestVersion -eq $currentVersion) {
			Write-Output ('')
			Write-Output ('💡 ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
		} else {
			Write-Output ('')
			Write-Output ('❗ ffmpegが古いため更新します。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)

			#ダウンロード
			Write-Output ('ffmpegの最新版をダウンロードします')
			try {
				Invoke-WebRequest -UseBasicParsing -Uri $ffmpegReleaseInfo.download.zip.url -OutFile (Join-Path $script:binDir 'ffmpeg.zip')
				Invoke-WebRequest -UseBasicParsing -Uri $ffprobeReleaseInfo.download.zip.url -OutFile (Join-Path $script:binDir 'ffprobe.zip')
			} catch { Write-Error ('❗ ffmpegのダウンロードに失敗しました') ; exit 1 }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try {
				Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg') -Force -ErrorAction SilentlyContinue
				Remove-Item -LiteralPath (Join-Path $script:binDir 'ffprobe') -Force -ErrorAction SilentlyContinue
				Expand-Zip -Path (Join-Path $script:binDir 'ffmpeg.zip') -Destination $script:binDir
				Expand-Zip -Path (Join-Path $script:binDir 'ffprobe.zip') -Destination $script:binDir
			} catch { Write-Error ('❗ ffmpegの展開に失敗しました') ; exit 1 }

			#ゴミ掃除
			Write-Output ('中間ファイルを削除します')
			try {
				Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue
				Remove-Item -LiteralPath (Join-Path $script:binDir 'ffprobe.zip') -Force -ErrorAction SilentlyContinue
			} catch { Write-Error ('❗ 中間ファイルの削除に失敗しました') ; exit 1 }

			#実行権限の付与
			(& chmod a+x $ffmpegPath)
			(& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Write-Error ('❗ 更新後のバージョン取得に失敗しました') ; exit 1 }

		}

		continue

	}
	default {
		$os = [String][System.Environment]::OSVersion
		Write-Warning ('❗ お使いのOSに適合するffmpegを特定できませんでした。')
		Write-Warning ('❗ {0}に適合するffmpegをご自身で配置してください。' -f $os)
		return
		continue
	}
}
