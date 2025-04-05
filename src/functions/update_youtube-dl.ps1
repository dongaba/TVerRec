###################################################################################
#
#		Windows用youtube-dl最新化処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecで使用するyt-dlpを最新バージョンに更新するスクリプト

	.DESCRIPTION
		yt-dlpの最新バージョンをダウンロードし、インストールします。
		複数のソースから選択してダウンロードできます：
		- yt-dlp（標準版）
		- ytdl-patched（パッチ適用版）
		- yt-dlp-nightly（開発版）

	.NOTES
		前提条件:
		- PowerShell 7.0以上が必要です
		- インターネット接続が必要です
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 設定ファイルでpreferredYoutubedlが正しく設定されている必要があります

		対応ソース:
		1. yt-dlp (yt-dlp/yt-dlp)
		- 安定版
		- 一般利用向け
		2. ytdl-patched (ytdl-patched/ytdl-patched)
		- パッチ適用版
		- 追加機能対応
		3. yt-dlp-nightly (yt-dlp/yt-dlp-nightly-builds)
		- 開発版
		- 最新機能テスト用

		処理の流れ:
		1. 現在の環境確認
		1.1 設定の読み込み
		1.2 現在のバージョン確認
		2. 最新版の確認
		2.1 ソースの選択
		2.2 最新バージョンの取得
		3. 更新処理
		3.1 ダウンロード
		3.2 実行ファイルの配置
		4. 検証
		4.1 実行権限の設定
		4.2 バージョン確認

	.EXAMPLE
		# スクリプトの実行
		.\update_youtube-dl.ps1

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
Write-Debug "Message Table Loaded: $script:uiCulture"

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
if ($script:preferredLanguage) {
	$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:preferredLanguage)) { $script:langFile.$script:preferredLanguage }
	else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理

# youtube-dl移動先相対Path
if ($IsWindows) { $ytdlPath = Join-Path $script:binDir 'yt-dlp.exe' }
else { $ytdlPath = Join-Path $script:binDir 'yt-dlp' }

# githubの設定
$lookupTable = @{
	'yt-dlp'         = 'yt-dlp/yt-dlp'
	'ytdl-patched'   = 'ytdl-patched/ytdl-patched'
	'yt-dlp-nightly' = 'yt-dlp/yt-dlp-nightly-builds'
}
if ($lookupTable.ContainsKey($script:preferredYoutubedl)) { $repo = $lookupTable[$script:preferredYoutubedl] }
else { Write-Warning ($script:msg.ToolInvalidSource -f $script:preferredYoutubedl) ; return }
$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)

# youtube-dlのバージョン取得
try {
	if (Test-Path $ytdlPath -PathType Leaf) { $currentVersion = (& $ytdlPath --version) }
	else { $currentVersion = '' }
} catch { $currentVersion = '' }

# youtube-dlの最新バージョン取得
try { $latestVersion = (Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec)[0].Tag_Name }
catch { Write-Warning ($script:msg.ToolLatestNotIdentified -f $script:preferredYoutubedl) ; return }

# youtube-dlのダウンロード
if ($latestVersion -eq $currentVersion) {
	Write-Output ('')
	Write-Output ($script:msg.ToolUpToDate -f $script:preferredYoutubedl)
	Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
	Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
} else {
	Write-Output ('')
	Write-Warning ($script:msg.ToolOutdated -f $script:preferredYoutubedl)
	Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
	Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
	if ($script:preferredYoutubedl -eq 'yt-dlp-nightly') { $downloadFileName = 'yt-dlp' }
	else { $downloadFileName = $script:preferredYoutubedl }
	if (!$IsWindows) { $fileBeforeRename = $downloadFileName ; $fileAfterRename = 'yt-dlp' }
	else { $fileBeforeRename = ('{0}.exe' -f $downloadFileName) ; $fileAfterRename = 'yt-dlp.exe' }
	Write-Output ($script:msg.ToolDownload -f $script:preferredYoutubedl, [String]([System.Runtime.InteropServices.RuntimeInformation]::OSDescription).split()[0..1])
	try {
		#ダウンロード
		$tag = (Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec)[0].Tag_Name
		$downloadURL = ('https://github.com/{0}/releases/download/{1}/{2}' -f $repo, $tag, $fileBeforeRename)
		$ytdlFileLocation = Join-Path $script:binDir $fileAfterRename
		Invoke-WebRequest -Uri $downloadURL -Out $ytdlFileLocation -TimeoutSec $script:timeoutSec
	} catch { Write-Warning ($script:msg.ToolDownloadFailed -f $script:preferredYoutubedl) ; return }
	if (!$IsWindows) { (& chmod a+x $ytdlFileLocation) }

	# バージョンチェック
	try {
		$currentVersion = (& $ytdlPath --version)
		Write-Output ($script:msg.ToolUpdated -f $script:preferredYoutubedl, $currentVersion)
	} catch { Write-Warning $script:msg.ToolVersionCheckFailed ; return }

}

Remove-Variable -Name lookupTable, releases, ytdlPath, currentVersion, latestVersion, file, fileAfterRename, fileBeforeRename, tag, downloadURL, ytdlFileLocation -ErrorAction SilentlyContinue
