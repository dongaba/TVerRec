###################################################################################
#
#		Windows用youtube-dl最新化処理スクリプト
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
else { Write-Warning ($script:msg.ToolInvalidSource -f 'youtube-dl') ; return }
$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)

# youtube-dlのバージョン取得
try {
	if (Test-Path $ytdlPath -PathType Leaf) { $currentVersion = (& $ytdlPath --version) }
	else { $currentVersion = '' }
} catch { $currentVersion = '' }

# youtube-dlの最新バージョン取得
try { $latestVersion = (Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec)[0].Tag_Name }
catch { Write-Warning ($script:msg.ToolLatestNotIdentified -f 'youtube-dl') ; return }

# youtube-dlのダウンロード
if ($latestVersion -eq $currentVersion) {
	Write-Output ('')
	Write-Output ($script:msg.ToolUpToDate -f 'youtube-dl')
	Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
	Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
} else {
	Write-Output ('')
	Write-Warning ($script:msg.ToolOutdated -f 'youtube-dl')
	Write-Output ($script:msg.ToolLocalVersion -f $currentVersion)
	Write-Output ($script:msg.ToolRemoteVersion -f $latestVersion)
	if ($script:preferredYoutubedl -eq 'yt-dlp-nightly') { $downloadFileName = 'yt-dlp' }
	else { $downloadFileName = $script:preferredYoutubedl }
	if (!$IsWindows) { $fileBeforeRename = $downloadFileName ; $fileAfterRename = 'yt-dlp' }
	else { $fileBeforeRename = ('{0}.exe' -f $downloadFileName) ; $fileAfterRename = 'yt-dlp.exe' }
	Write-Output ($script:msg.ToolDownload -f 'youtube-dl', [String]([System.Runtime.InteropServices.RuntimeInformation]::OSDescription).split()[0..1])
	try {
		#ダウンロード
		$tag = (Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec)[0].Tag_Name
		$downloadURL = ('https://github.com/{0}/releases/download/{1}/{2}' -f $repo, $tag, $fileBeforeRename)
		$ytdlFileLocation = Join-Path $script:binDir $fileAfterRename
		Invoke-WebRequest -Uri $downloadURL -Out $ytdlFileLocation
	} catch { Write-Warning ($script:msg.ToolDownloadFailed -f 'youtube-dl') ; return }
	if (!$IsWindows) { (& chmod a+x $ytdlFileLocation) }

	# バージョンチェック
	try {
		$currentVersion = (& $ytdlPath --version)
		Write-Output ($script:msg.ToolUpdated -f 'youtube-dl', $currentVersion)
	} catch { Write-Warning $script:msg.ToolVersionCheckFailed ; return }

}

Remove-Variable -Name lookupTable, releases, ytdlPath, currentVersion, latestVersion, file, fileAfterRename, fileBeforeRename, tag, downloadURL, ytdlFileLocation -ErrorAction SilentlyContinue
