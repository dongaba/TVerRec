###################################################################################
#
#		Windows用ffmpeg最新化処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecで使用するffmpegを最新バージョンに更新するスクリプト

	.DESCRIPTION
		ffmpegの最新バージョンをダウンロードし、インストールします。
		Windows、Linux、macOSの各プラットフォームに対応しています。
		以下の処理を実行します：
		1. 現在のバージョン確認
		2. 最新バージョンの確認
		3. 必要に応じたダウンロードと更新
		4. インストール後の検証

	.NOTES
		前提条件:
		- PowerShell 7.0以上を推奨です
		- インターネット接続が必要です
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 十分なディスク容量が必要です

		対応プラットフォーム:
		1. Windows
		- x64, Arm64, x86アーキテクチャに対応
		- yt-dlp/FFmpeg-Buildsからダウンロード
		2. Linux
		- x64, Arm64アーキテクチャに対応
		- yt-dlp/FFmpeg-Buildsからダウンロード
		3. macOS
		- Intel(amd64), Apple Silicon(arm64)に対応
		- ffmpeg.martin-riedl.deからダウンロード

		処理の流れ:
		1. 現在の環境確認
		1.1 OSとアーキテクチャの判定
		1.2 現在のバージョン確認
		2. 最新版の確認
		2.1 リポジトリの確認
		2.2 最新バージョンの取得
		3. 更新処理
		3.1 ダウンロード
		3.2 アーカイブの展開
		3.3 実行ファイルの配置
		4. 検証
		4.1 実行権限の設定
		4.2 バージョン確認

	.EXAMPLE
		# スクリプトの実行
		.\update_ffmpeg.ps1

	.OUTPUTS
		System.Void
		処理の進行状況と結果をコンソールに出力します。
		- 現在のバージョン
		- 最新のバージョン
		- 更新の成功/失敗
#>

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

#----------------------------------------------------------------------
# Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$path,
		[Parameter(Mandatory = $true)][String]$destination
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	if (Test-Path -Path $path) {
		Write-Verbose ('Extracting {0} into {1}' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('Extracted {0}' -f $path)
	} else { throw ($script:msg.FileNotFound -f $path) }
	Remove-Variable -Name path, destination -ErrorAction SilentlyContinue
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -eq 'ExternalScript') { $scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $myInvocation.MyCommand.Definition) }
	else { $scriptRoot = Convert-Path .. }
	Set-Location $script:scriptRoot
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }

#----------------------------------------------------------------------
# メッセージファイル読み込み
$script:langDir = Convert-Path (Join-Path $scriptRoot '../resources/lang')
$script:uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
Write-Debug "Current Language: $script:uiCulture"
$script:langFile = Get-Content -Path (Join-Path $script:langDir 'messages.json') | ConvertFrom-Json
$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:uiCulture)) { $script:langFile.$script:uiCulture }
else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }
Write-Debug "Message Table Loaded: $script:uiCulture"

#----------------------------------------------------------------------
# 設定ファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
if ( Test-Path (Join-Path $script:confDir 'system_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'system_setting.ps1')) }
	catch { throw ($script:msg.LoadSystemSettingFailed) }
} else { throw ($script:msg.SystemSettingNotFound) }
if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	catch { throw ($script:msg.LoadUserSettingFailed) }
} elseif ($IsWindows) {
	Write-Output ($script:msg.UserSettingNeedsToBeCreated)
	try { & 'gui/gui_setting.ps1' }
	catch { throw ($script:msg.LoadSettingGUIFailed) }
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
		catch { throw ($script:msg.LoadUserSettingFailed) }
	} else { throw ($script:msg.UserSettingNotCompleted) }
} else { throw ($script:msg.UserSettingNotCompleted) }
if ($script:preferredLanguage) {
	$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:preferredLanguage)) { $script:langFile.$script:preferredLanguage }
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
			$latestRelease = Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec
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
		$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
		$pattern = switch ($arch) {
			'X64' { '-win64-gpl-' ; break }
			'Arm64' { '-winarm64-gpl-' ; break }
			'X86' { '-win32-gpl-' ; break }
			Default { '-win32-gpl-' }
		}
		if ($latestRelease -cmatch "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(${pattern})(.*).zip") {
			$downloadURL = $matches[0]
			# ダウンロード
			Write-Output ($script:msg.ToolDownload -f 'ffmpeg', $arch)
			try { Invoke-WebRequest -Uri $downloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.zip') -TimeoutSec $script:timeoutSec }
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
		break
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
			$latestRelease = Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec
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
		$pattern = @{
			'arm64' = @('aarch64', 'armv8')
			'64'    = @('x86_64', 'ia64')
		}
		# アーキテクチャに対応するCPUタイプを取得
		$arch = (& uname -m).ToLower()
		$cpu = $pattern.GetEnumerator().where({ $_.Value -contains $arch }) | Select-Object -ExpandProperty Key
		# CPUタイプが見つからない場合のエラーメッセージ
		if (-not $cpu) {
			Write-Warning ($script:msg.ToolArchitectureNotIdentified1 -f 'ffmpeg')
			Write-Warning ($script:msg.ToolArchitectureNotIdentified2 -f $arch, 'ffmpeg')
			return
		}
		if ($latestRelease -cmatch "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-(.*)(-linux${cpu}-gpl-)(.*).tar.xz") {
			$downloadURL = $matches[0]
			# ダウンロード
			Write-Output ($script:msg.ToolDownload -f 'ffmpeg', $arch )
			try { Invoke-WebRequest -Uri $downloadURL -OutFile (Join-Path $script:binDir 'ffmpeg.tar.xz') -TimeoutSec $script:timeoutSec }
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
		break
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
			$ffmpegReleaseInfo = (Invoke-WebRequest -Uri $ffmpegReleases -TimeoutSec $script:timeoutSec).links.href[0]
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
			$uriBasePage = Invoke-WebRequest -Uri $uriBase -TimeoutSec $script:timeoutSec
			foreach ($file in $downloadFiles) {
				$downloadLink = $uriBasePage.links.where({
						$_.href -match $arch `
							-and $_.href -match $latestBuild `
							-and $_.outerHTML -match $file `
							-and $_.href -notmatch '.sha256'
					}) | Select-Object -First 1
				Invoke-WebRequest -Uri ('{0}{1}' -f $uriBase, $downloadLink.href) -OutFile (Join-Path $script:binDir $file) -TimeoutSec $script:timeoutSec
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
		break
	}

	default {
		$os = [String][System.Environment]::OSVersion
		Write-Warning ($script:msg.ToolArchitectureNotIdentified1 -f 'ffmpeg')
		Write-Warning ($script:msg.ToolArchitectureNotIdentified2 -f $os, 'ffmpeg')
		return
	}
}

Remove-Variable -Name ffmpegPath, os, arch, ffmpegFileVersion, currentVersion, releases, latestRelease, latestVersion, cpu, downloadURL, ffmpegFileVersion, ffmpegReleases, ffprobeReleases, ffmpegReleaseInfo, ffprobeReleaseInfo -ErrorAction SilentlyContinue
