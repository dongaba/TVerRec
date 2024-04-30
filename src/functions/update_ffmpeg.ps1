###################################################################################
#
#		Windows用ffmpeg最新化処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
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
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-Path -Path $path) {
		Write-Verbose ('{0}を{1}に展開します' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('{0}を展開しました' -f $path)
	} else { Throw ('❌️ {0}が見つかりません' -f $path) }
	Remove-Variable -Name path, destination -ErrorAction SilentlyContinue
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -eq 'ExternalScript') { $scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $myInvocation.MyCommand.Definition) }
	else { $scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ ディレクトリ設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }

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
		if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	} else { Throw ('❌️ ユーザ設定が完了してません') }
} catch { Throw ('❌️ 設定ファイルの読み込みに失敗しました') }

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
		$null = Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue
		$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue

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
			if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(\w*)(\d+\.*\d*\.*\d*)(.*)(-win64-gpl-)(.*).zip') { $latestVersion = $matches[7] }
		} catch { Write-Warning ('⚠️ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ('✅️ ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
		} else {
			Write-Output ('')
			Write-Warning ('⚠️ ffmpegが古いため更新します。')
			Write-Warning ('　Local version: {0}' -f $currentVersion)
			Write-Warning ('　Latest version: {0}' -f $latestVersion)

			if ([System.Environment]::IS64bitOperatingSystem) {
				$cpu = 'x64'
				if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-win64-gpl-)(.*).zip') { $donwloadURL = $matches[0] }
			} else {
				$cpu = 'x86'
				if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-win32-gpl-)(.*).zip') { $donwloadURL = $matches[0] }
			}

			#ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $cpu)
			try { Invoke-WebRequest -Uri $donwloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.zip') }
			catch { Throw ('❌️ ffmpegのダウンロードに失敗しました') }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try { Expand-Zip -Path (Join-Path $script:binDir 'ffmpeg.zip') -Destination $script:binDir }
			catch { Throw ('❌️ ffmpegの解凍に失敗しました') }

			#配置
			Write-Output ('解凍したffmpegを配置します')
			try { $null = Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*.exe' -f $script:binDir) -Destination $script:binDir -Force }
			catch { Throw ('❌️ ffmpegの配置に失敗しました') }

			#ゴミ掃除
			Write-Output ('中間ディレクトリと中間ファイルを削除します')
			try { $null = Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue }
			catch { Throw ('❌️ 中間ディレクトリの削除に失敗しました') }
			try { $null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue }
			catch { Throw ('❌️ 中間ファイルの削除に失敗しました') }

			#バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Throw ('❌️ 更新後のバージョン取得に失敗しました') }

		}

		continue

	}
	$IsLinux {
		$os = ('Linux {0}' -f [System.Environment]::OSVersion.Version)
		$arch = (& uname -m | tr '[:upper:]' '[:lower:]')

		#残っているかもしれない中間ファイルを削除
		$null = Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue
		$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue

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
			if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(\w*)(\d+\.*\d*\.*\d*)(.*)(-linux64-gpl-)(.*).tar.xz') { $latestVersion = $matches[7] }
		} catch { Write-Warning ('⚠️ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ('✅️ ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
		} else {
			Write-Output ('')
			Write-Warning ('⚠️ ffmpegが古いため更新します。')
			Write-Warning ('　Local version: {0}' -f $currentVersion)
			Write-Warning ('　Latest version: {0}' -f $latestVersion)

			switch ($true) {
				(($arch -eq 'aarch64') -or ($arch -icontains 'armv8')) {
					$cpu = 'arm64'
					if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linuxarm64-gpl-)(.*).tar.xz') { $donwloadURL = $matches[0] }
					continue
				}
				($arch -in @('x86_64', 'ia64')) {
					$cpu = 'amd64'
					if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linux64-gpl-)(.*).tar.xz') { $donwloadURL = $matches[0] }
					continue
				}
				default {
					Write-Warning ('⚠️ お使いのCPUに適合するffmpegを特定できませんでした。')
					Write-Warning ('⚠️ {0}に適合するffmpegをご自身で配置してください。' -f $arch)
					return
				}
			}

			#ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $cpu)
			try { Invoke-WebRequest -Uri $donwloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.tar.xz') }
			catch { Throw ('❌️ ffmpegのダウンロードに失敗しました') }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try { (& tar Jxf (Join-Path $script:binDir 'ffmpeg.tar.xz') -C $script:binDir) }
			catch { Throw ('❌️ ffmpegの展開に失敗しました') }

			#配置
			Write-Output ('解凍したffmpegを配置します')
			try { $null = Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*' -f $script:binDir) -Destination $script:binDir -Force }
			catch { Throw ('❌️ ffmpegの配置に失敗しました') }

			#ゴミ掃除
			Write-Output ('中間ディレクトリと中間ファイルを削除します')
			try { $null = Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue }
			catch { Throw ('❌️ 中間ディレクトリの削除に失敗しました') }
			try { $null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue }
			catch { Throw ('❌️ 中間ファイルの削除に失敗しました') }

			#実行権限の付与
			(& chmod a+x $ffmpegPath)
			(& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Throw ('❌️ 更新後のバージョン取得に失敗しました') }

		}

		continue

	}
	$IsMacOS {
		$os = ('macOS {0}' -f [System.Environment]::OSVersion.Version)
		$arch = (& uname -m | tr '[:upper:]' '[:lower:]').replace('x86_64', 'amd64')

		#残っているかもしれない中間ファイルを削除
		$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue
		$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffprobe.zip') -Force -ErrorAction SilentlyContinue

		#ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\d+\.*\d*\.*\d*)') { $currentVersion = $matches[1] }
				else { $currentVersion = '' }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }

		#ffmpegの最新バージョン取得
		$ffmpegReleases = ('https://ffmpeg.martin-riedl.de/info/history/macos/{0}/release' -f $arch)
		$ffmpegReleaseInfo = ''
		$latestVersion = ''
		$latestBuild = ''
		try {
			$ffmpegReleaseInfo = (Invoke-WebRequest -Uri $ffmpegReleases).links.href[0]
			if ($ffmpegReleaseInfo -cmatch ('{0}/(\d+)_(.+)' -f $arch)) { $latestBuild = $matches[1] ; $latestVersion = $matches[2] }
		} catch { Write-Warning ('⚠️ ffmpegの最新バージョンを特定できませんでした') ; return }

		#ffmpegのダウンロード
		if ($latestVersion -eq $currentVersion) {
			Write-Output ('')
			Write-Output ('✅️ ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
		} else {
			Write-Output ('')
			Write-Warning ('⚠️ ffmpegが古いため更新します。')
			Write-Warning ('　Local version: {0}' -f $currentVersion)
			Write-Warning ('　Latest version: {0}' -f $latestVersion)

			#ダウンロード
			Write-Output ('ffmpegの最新版をダウンロードします')
			try {
				$uriBase = 'https://ffmpeg.martin-riedl.de/'
				$uriBasePage = Invoke-WebRequest -Uri $uriBase
				Invoke-WebRequest -Uri ('{0}{1}' -f $uriBase, ($uriBasePage.links | Where-Object { $_.href -match $arch } | Where-Object { $_.href -match $latestBuild } | Where-Object { $_.outerHTML -match 'ffmpeg.zip"' }).href) -OutFile (Join-Path $script:binDir 'ffmpeg.zip')
				Invoke-WebRequest -Uri ('{0}{1}' -f $uriBase, ($uriBasePage.links | Where-Object { $_.href -match $arch } | Where-Object { $_.href -match $latestBuild } | Where-Object { $_.outerHTML -match 'ffprobe.zip"' }).href) -OutFile (Join-Path $script:binDir 'ffprobe.zip')
			} catch { Throw ('❌️ ffmpegのダウンロードに失敗しました') }

			#展開
			Write-Output ('ダウンロードしたffmpegを解凍します')
			try {
				$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg') -Force -ErrorAction SilentlyContinue
				$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffprobe') -Force -ErrorAction SilentlyContinue
				Expand-Zip -Path (Join-Path $script:binDir 'ffmpeg.zip') -Destination $script:binDir
				Expand-Zip -Path (Join-Path $script:binDir 'ffprobe.zip') -Destination $script:binDir
			} catch { Throw ('❌️ ffmpegの展開に失敗しました') }

			#ゴミ掃除
			Write-Output ('中間ファイルを削除します')
			try {
				$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue
				$null = Remove-Item -LiteralPath (Join-Path $script:binDir 'ffprobe.zip') -Force -ErrorAction SilentlyContinue
			} catch { Throw ('❌️ 中間ファイルの削除に失敗しました') }

			#実行権限の付与
			(& chmod a+x $ffmpegPath)
			(& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe'))

			#バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\d+\.*\d*\.*\d*)') { $currentVersion = $matches[1] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Throw ('❌️ 更新後のバージョン取得に失敗しました') }

		}

		continue

	}
	default {
		$os = [String][System.Environment]::OSVersion
		Write-Warning ('⚠️ お使いのOSに適合するffmpegを特定できませんでした。')
		Write-Warning ('⚠️ {0}に適合するffmpegをご自身で配置してください。' -f $os)
		return
		continue
	}
}

Remove-Variable -Name ffmpegPath, os, arch, ffmpegFileVersion, currentVersion, releases, latestRelease, latestVersion, cpu, donwloadURL, ffmpegFileVersion, ffmpegReleases, ffprobeReleases, ffmpegReleaseInfo, ffprobeReleaseInfo -ErrorAction SilentlyContinue
