###################################################################################
#
#		Windows用ffmpeg最新化処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

#----------------------------------------------------------------------
# Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
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
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -eq 'ExternalScript') { $scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $myInvocation.MyCommand.Definition) }
	else { $scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ ディレクトリ設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }

# 設定ファイル読み込み
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
# メイン処理

# ffmpeg移動先相対Path
if ($IsWindows) { $ffmpegPath = Join-Path $script:binDir './ffmpeg.exe' }
else { $ffmpegPath = Join-Path $script:binDir 'ffmpeg' }

switch ($true) {
	$IsWindows {
		# 残っているかもしれない中間ファイルを削除
		Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue | Out-Null
		# ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }
		# ffmpegの最新バージョン取得
		$releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		try {
			$latestRelease = Invoke-RestMethod -Uri $releases -Method 'GET'
			if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(\w*)(\d+\.*\d*\.*\d*)(.*)(-win64-gpl-)(.*).zip') { $latestVersion = $matches[7] }
		} catch { Write-Warning ('⚠️ ffmpegの最新バージョンを特定できませんでした') ; return }
		# ffmpegのダウンロード
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ('✅️ ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
			return
		} else {
			Write-Output ('')
			Write-Warning ('⚠️ ffmpegが古いため更新します。')
			Write-Warning ('　Local version: {0}' -f $currentVersion)
			Write-Warning ('　Latest version: {0}' -f $latestVersion)
		}
		# アーキテクチャごとのURLパターン
		$cpu = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
		$pattern = switch ($cpu) {
			'X64' { '-win64-gpl-' ; continue }
			'Arm64' { '-winarm64-gpl-' ; continue }
			'X86' { '-win32-gpl-' ; continue }
			Default { '-win32-gpl-' }
		}
		if ($latestRelease -cmatch "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(${pattern})(.*).zip") {
			$downloadURL = $matches[0]
			# ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $cpu)
			try { Invoke-WebRequest -Uri $downloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.zip') }
			catch { Write-Warning '❌️ ffmpegのダウンロードに失敗しました' ; return }
			# 展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try { Expand-Zip -Path (Join-Path $script:binDir 'ffmpeg.zip') -Destination $script:binDir }
			catch { Write-Warning '❌️ ffmpegの解凍に失敗しました' ; return }
			# 配置
			Write-Output '解凍したffmpegを配置します'
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*.exe' -f $script:binDir) -Destination $script:binDir -Force | Out-Null }
			catch { Write-Warning '❌️ ffmpegの配置に失敗しました' ; return }
			# ゴミ掃除
			Write-Output '中間ディレクトリと中間ファイルを削除します'
			Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
			Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue | Out-Null
			# バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Write-Warning '❌️ 更新後のバージョン取得に失敗しました' ; return }
		}
		continue
	}

	$IsLinux {
		# 残っているかもしれない中間ファイルを削除
		Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue | Out-Null
		# ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }
		# ffmpegの最新バージョン取得
		$releases = 'https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest'
		try {
			$latestRelease = Invoke-RestMethod -Uri $releases -Method 'GET'
			if ($latestRelease -cmatch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(\d+)-(\d+)-(\d+)-(\d+)-(\d+)/ffmpeg-(\w*)(\d+\.*\d*\.*\d*)(.*)(-linux64-gpl-)(.*).tar.xz') { $latestVersion = $matches[7] }
		} catch { Write-Warning ('⚠️ ffmpegの最新バージョンを特定できませんでした') ; return }
		# ffmpegのダウンロード
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ('✅️ ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
			return
		} else {
			Write-Output ('')
			Write-Warning ('⚠️ ffmpegが古いため更新します。')
			Write-Warning ('　Local version: {0}' -f $currentVersion)
			Write-Warning ('　Latest version: {0}' -f $latestVersion)
		}
		# アーキテクチャごとのURLパターン
		$cpuPatterns = @{
			'arm64' = @('aarch64', 'armv8')
			'64'    = @('x86_64', 'ia64')
		}
		# アーキテクチャに対応するCPUタイプを取得
		$arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$cpu = $cpuPatterns.GetEnumerator() | Where-Object { $arch -in $_.Value } | Select-Object -ExpandProperty Key
		# CPUタイプが見つからない場合のエラーメッセージ
		if (-not $cpu) {
			Write-Warning ('⚠️ お使いのCPUに適合するffmpegを特定できませんでした。')
			Write-Warning ('⚠️ {0}に適合するffmpegをご自身で配置してください。' -f $arch)
			return
		}
		if ($latestRelease -cmatch "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linux${cpu}-gpl-)(.*).tar.xz") {
			$downloadURL = $matches[0]
			# ダウンロード
			Write-Output ('ffmpegの最新版{0}用をダウンロードします' -f $arch)
			try { Invoke-WebRequest -Uri $downloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.tar.xz') }
			catch { Write-Warning '❌️ ffmpegのダウンロードに失敗しました' ; return }
			# 展開
			Write-Output 'ダウンロードしたffmpegを解凍します'
			try { & tar Jxf (Join-Path $script:binDir 'ffmpeg.tar.xz') -C $script:binDir }
			catch { Write-Warning '❌️ ffmpegの展開に失敗しました' ; return }
			# 配置
			Write-Output '解凍したffmpegを配置します'
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*' -f $script:binDir) -Destination $script:binDir -Force | Out-Null }
			catch { Write-Warning '❌️ ffmpegの配置に失敗しました' ; return }
			# ゴミ掃除
			Write-Output '中間ディレクトリと中間ファイルを削除します'
			Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
			Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue | Out-Null
			# 実行権限の付与
			& chmod a+x $ffmpegPath
			& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe')
			# バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
			} catch { Write-Warning '❌️ 更新後のバージョン取得に失敗しました' ; return }
		}
		continue
	}

	$IsMacOS {
		# 残っているかもしれない中間ファイルを削除
		$filesToRemove = @('ffmpeg.zip', 'ffprobe.zip')
		foreach ($file in $filesToRemove) { Remove-Item -LiteralPath (Join-Path $script:binDir $file) -Force -ErrorAction SilentlyContinue | Out-Null }
		# ffmpegのバージョン取得
		try {
			if (Test-Path $ffmpegPath -PathType Leaf) {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\d+\.*\d*\.*\d*)') { $currentVersion = $matches[1] }
				else { $currentVersion = '' }
			} else { $currentVersion = '' }
		} catch { $currentVersion = '' }
		# ffmpegの最新バージョン取得
		$arch = (& uname -m | tr '[:upper:]' '[:lower:]').Replace('x86_64', 'amd64')
		$ffmpegReleases = ('https://ffmpeg.martin-riedl.de/info/history/macos/{0}/release' -f $arch)
		$ffmpegReleaseInfo = ''
		$latestVersion = ''
		$latestBuild = ''
		try {
			$ffmpegReleaseInfo = (Invoke-WebRequest -Uri $ffmpegReleases).links.href[0]
			if ($ffmpegReleaseInfo -cmatch ('{0}/(\d+)_(.+)' -f $arch)) { $latestBuild = $matches[1] ; $latestVersion = $matches[2] }
		} catch { Write-Warning ('⚠️ ffmpegの最新バージョンを特定できませんでした') ; return }
		# ffmpegのダウンロード
		if ($latestVersion -eq $currentVersion) {
			Write-Output ('')
			Write-Output ('✅️ ffmpegは最新です。')
			Write-Output ('　Local version: {0}' -f $currentVersion)
			Write-Output ('　Latest version: {0}' -f $latestVersion)
			return
		} else {
			Write-Output ('')
			Write-Warning ('⚠️ ffmpegが古いため更新します。')
			Write-Warning ('　Local version: {0}' -f $currentVersion)
			Write-Warning ('　Latest version: {0}' -f $latestVersion)
		}
		# ダウンロード
		Write-Output ('ffmpegの最新版をダウンロードします')
		try {
			$uriBase = 'https://ffmpeg.martin-riedl.de/'
			$uriBasePage = Invoke-WebRequest -Uri $uriBase
			foreach ($file in $filesToRemove) {
				$downloadLink = $uriBasePage.links | Where-Object { $_.href -match $arch -and $_.href -match $latestBuild -and $_.outerHTML -match $file -and $_.href -notmatch '.sha256' }
				Invoke-WebRequest -Uri ('{0}{1}' -f $uriBase, $downloadLink.href) -OutFile (Join-Path $script:binDir $file)
			}
		} catch { Throw ('❌️ ffmpegのダウンロードに失敗しました') }
		# 展開
		Write-Output ('ダウンロードしたffmpegを解凍します')
		try {
			foreach ($file in $filesToRemove) {
				Remove-Item -LiteralPath (Join-Path $script:binDir $file.Replace('.zip', '')) -Force -ErrorAction SilentlyContinue | Out-Null
				Expand-Zip -Path (Join-Path $script:binDir $file) -Destination $script:binDir
			}
		} catch { Throw ('❌️ ffmpegの展開に失敗しました') }
		# ゴミ掃除
		Write-Output ('中間ファイルを削除します')
		try { foreach ($file in $filesToRemove) { Remove-Item -LiteralPath (Join-Path $script:binDir $file) -Force -ErrorAction SilentlyContinue | Out-Null } }
		catch { Throw ('❌️ 中間ファイルの削除に失敗しました') }
		# 実行権限の付与
			(& chmod a+x $ffmpegPath)
			(& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe'))
		# バージョンチェック
		try {
			$ffmpegFileVersion = (& $ffmpegPath -version)
			if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\d+\.*\d*\.*\d*)') { $currentVersion = $matches[1] }
			Write-Output ('💡 ffmpegをversion {0}に更新しました。' -f $currentVersion)
		} catch { Throw ('❌️ 更新後のバージョン取得に失敗しました') }
		continue
	}

	default {
		$os = [String][System.Environment]::OSVersion
		Write-Warning ('⚠️ お使いのOSに適合するffmpegを特定できませんでした。')
		Write-Warning ('⚠️ {0}に適合するffmpegをご自身で配置してください。' -f $os)
		return
	}
}

Remove-Variable -Name ffmpegPath, os, arch, ffmpegFileVersion, currentVersion, releases, latestRelease, latestVersion, cpu, downloadURL, ffmpegFileVersion, ffmpegReleases, ffprobeReleases, ffmpegReleaseInfo, ffprobeReleaseInfo -ErrorAction SilentlyContinue
