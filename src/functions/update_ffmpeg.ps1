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
		[Parameter(Mandatory = $true)][String]$path,
		[Parameter(Mandatory = $true)][String]$destination
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	if (Test-Path -Path $path) {
		Write-Verbose ('Extracting {0} into {1}' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('Extracted {0}' -f $path)
	} else { Throw ($script:msg.FileNotFound -f $path) }
	Remove-Variable -Name path, destination -ErrorAction SilentlyContinue
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -eq 'ExternalScript') { $scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $myInvocation.MyCommand.Definition) }
	else { $scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }

#----------------------------------------------------------------------
# メッセージファイル読み込み
$script:langDir = Convert-Path (Join-Path $scriptRoot '../resources/lang')
$script:uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
Write-Debug "Current Language: $script:uiCulture"
$script:langFile = Get-Content -Path (Join-Path $script:langDir 'messages.json') | ConvertFrom-Json
$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:uiCulture)) { $script:langFile.$script:uiCulture }
else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }

#----------------------------------------------------------------------
# 設定ファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
if ( Test-Path (Join-Path $script:confDir 'system_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'system_setting.ps1')) }
	catch { Throw ($script:msg.LoadSystemSettingFailed) }
} else { Throw ($script:msg.SystemSettingNotFound) }
if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	catch { Throw ($script:msg.LoadUserSettingFailed) }
} elseif ($IsWindows) {
	Write-Output ($script:msg.UserSettingNeedsToBeCreated)
	try { & 'gui/gui_setting.ps1' }
	catch { Throw ($script:msg.LoadSettingGUIFailed) }
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
		catch { Throw ($script:msg.LoadUserSettingFailed) }
	} else { Throw ($script:msg.UserSettingNotCompleted) }
} else { Throw ($script:msg.UserSettingNotCompleted) }
if (Test-Path variable:lang) {
	$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:lang)) { $script:langFile.$script:lang }
	else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }
}

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
		} catch { Write-Warning ($script:msg.ToolLatestNotIdentified -f 'ffmpeg') ; return }
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ($script:msg.ToolUpToDate -f 'ffmpeg')
			Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
			Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
			return
		} else {
			Write-Output ('')
			Write-Warning ($script:msg.ToolOutdated -f 'ffmpeg')
			Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
			Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
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
			Write-Output ($script:msg.ToolDownload -f 'ffmpeg', $cpu)
			try { Invoke-WebRequest -Uri $downloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.zip') }
			catch { Write-Warning ($script:msg.ToolDownloadFailed -f 'ffmpeg') ; return }
			# 展開
			Write-Output ($script:msg.ToolExtract -f 'ffmpeg')
			try { Expand-Zip -Path (Join-Path $script:binDir 'ffmpeg.zip') -Destination $script:binDir }
			catch { Write-Warning ($script:msg.ToolExtractFailed -f 'ffmpeg') ; return }
			# 配置
			Write-Output ($script:msg.ToolDeploy -f 'ffmpeg')
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*.exe' -f $script:binDir) -Destination $script:binDir -Force | Out-Null }
			catch { Write-Warning ($script:msg.ToolDeployFailed -f 'ffmpeg') ; return }
			# ゴミ掃除
			Write-Output $script:msg.ToolRemoveWorkingFiles
			Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
			Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.zip') -Force -ErrorAction SilentlyContinue | Out-Null
			# バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ($script:msg.ToolUpdated -f 'ffmpeg', $currentVersion)
			} catch { Write-Warning $script:msg.ToolVersionCheckFailed ; return }
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
		} catch { Write-Warning ($script:msg.ToolLatestNotIdentified -f 'ffmpeg') ; return }
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ($script:msg.ToolUpToDate -f 'ffmpeg')
			Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
			Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
			return
		} else {
			Write-Output ('')
			Write-Warning ($script:msg.ToolOutdated -f 'ffmpeg')
			Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
			Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
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
			Write-Warning ($script:msg.ToolArchitectureNotIdentified1 -f 'ffmpeg')
			Write-Warning ($script:msg.ToolArchitectureNotIdentified2 -f $arch, 'ffmpeg')
			return
		}
		if ($latestRelease -cmatch "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linux${cpu}-gpl-)(.*).tar.xz") {
			$downloadURL = $matches[0]
			# ダウンロード
			Write-Output ($script:msg.ToolDownload -f 'ffmpeg', $cpu)
			try { Invoke-WebRequest -Uri $downloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.tar.xz') }
			catch { Write-Warning ($script:msg.ToolDownloadFailed -f 'ffmpeg') ; return }
			# 展開
			Write-Output ($script:msg.ToolExtract -f 'ffmpeg')
			try { & tar Jxf (Join-Path $script:binDir 'ffmpeg.tar.xz') -C $script:binDir }
			catch { Write-Warning ($script:msg.ToolExtractFailed -f 'ffmpeg') ; return }
			# 配置
			Write-Output ($script:msg.ToolDeploy -f 'ffmpeg')
			try { Move-Item -Path ('{0}/ffmpeg-*-gpl-*/bin/ff*' -f $script:binDir) -Destination $script:binDir -Force | Out-Null }
			catch { Write-Warning ($script:msg.ToolDeployFailed -f 'ffmpeg') ; return }
			# ゴミ掃除
			Write-Output $script:msg.ToolRemoveWorkingFiles
			Remove-Item -Path ('{0}/ffmpeg-*-gpl-*' -f $script:binDir) -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
			Remove-Item -LiteralPath (Join-Path $script:binDir 'ffmpeg.tar.xz') -Force -ErrorAction SilentlyContinue | Out-Null
			# 実行権限の付与
			& chmod a+x $ffmpegPath
			& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe')
			# バージョンチェック
			try {
				$ffmpegFileVersion = (& $ffmpegPath -version)
				if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\w*)(\d+\.*\d*\.*\d*)') { $currentVersion = $matches[2] }
				Write-Output ($script:msg.ToolUpdated -f 'ffmpeg', $currentVersion)
			} catch { Write-Warning $script:msg.ToolVersionCheckFailed ; return }
		}
		continue
	}

	$IsMacOS {
		# 残っているかもしれない中間ファイルを削除
		$downloadFiles = @('ffmpeg.zip', 'ffprobe.zip', 'ffplay.zip')
		foreach ($file in $downloadFiles) { Remove-Item -LiteralPath (Join-Path $script:binDir $file) -Force -ErrorAction SilentlyContinue | Out-Null }
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
		} catch { Write-Warning ($script:msg.ToolLatestNotIdentified -f 'ffmpeg') ; return }
		if ($currentVersion -eq $latestVersion) {
			Write-Output ('')
			Write-Output ($script:msg.ToolUpToDate -f 'ffmpeg')
			Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
			Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
			return
		} else {
			Write-Output ('')
			Write-Warning ($script:msg.ToolOutdated -f 'ffmpeg')
			Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
			Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
		}
		# ダウンロード
		Write-Output ($script:msg.ToolDownload -f 'ffmpeg', 'Mac')
		try {
			$uriBase = 'https://ffmpeg.martin-riedl.de/'
			$uriBasePage = Invoke-WebRequest -Uri $uriBase
			foreach ($file in $downloadFiles) {
				$downloadLink = $uriBasePage.links | Where-Object { ($_.href -match $arch) -and ($_.href -match $latestBuild) -and ($_.outerHTML -match $file) -and ($_.href -notmatch '.sha256') }
				Invoke-WebRequest -Uri ('{0}{1}' -f $uriBase, $downloadLink.href) -OutFile (Join-Path $script:binDir $file)
			}
		} catch { Write-Warning ($script:msg.ToolDownloadFailed -f 'ffmpeg') ; return }
		# 展開
		Write-Output ($script:msg.ToolExtract -f 'ffmpeg')
		try {
			foreach ($file in $downloadFiles) {
				Remove-Item -LiteralPath (Join-Path $script:binDir $file.Replace('.zip', '')) -Force -ErrorAction SilentlyContinue | Out-Null
				Expand-Zip -Path (Join-Path $script:binDir $file) -Destination $script:binDir
			}
		} catch { Write-Warning ($script:msg.ToolExtractFailed -f 'ffmpeg') ; return }
		# ゴミ掃除
		Write-Output $script:msg.ToolRemoveWorkingFiles
		foreach ($file in $downloadFiles) { Remove-Item -LiteralPath (Join-Path $script:binDir $file) -Force -ErrorAction SilentlyContinue | Out-Null }
		# 実行権限の付与
			(& chmod a+x $ffmpegPath)
			(& chmod a+x ($ffmpegPath).Replace('ffmpeg', 'ffprobe'))
		# バージョンチェック
		try {
			$ffmpegFileVersion = (& $ffmpegPath -version)
			if ($ffmpegFileVersion[0] -cmatch 'ffmpeg version (\d+\.*\d*\.*\d*)') { $currentVersion = $matches[1] }
			Write-Output ($script:msg.ToolUpdated -f 'ffmpeg', $currentVersion)
		} catch { Write-Warning $script:msg.ToolVersionCheckFailed ; return }
		continue
	}

	default {
		$os = [String][System.Environment]::OSVersion
		Write-Warning ($script:msg.ToolArchitectureNotIdentified1 -f 'ffmpeg')
		Write-Warning ($script:msg.ToolArchitectureNotIdentified2 -f $os, 'ffmpeg')
		return
	}
}

Remove-Variable -Name ffmpegPath, os, arch, ffmpegFileVersion, currentVersion, releases, latestRelease, latestVersion, cpu, downloadURL, ffmpegFileVersion, ffmpegReleases, ffprobeReleases, ffmpegReleaseInfo, ffprobeReleaseInfo -ErrorAction SilentlyContinue
