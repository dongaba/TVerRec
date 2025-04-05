###################################################################################
#
#		関数読み込みスクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecの初期化処理を行うスクリプトです。

	.DESCRIPTION
		TVerRecアプリケーションの起動時に必要な初期化処理を実行します。
		主に以下の5つのカテゴリの初期化を行います：

		1. 基本設定の初期化
		- ロゴデータの設定
		- 言語設定の読み込み
		- メッセージリソースの初期化

		2. 設定ファイルの読み込み
		- システム設定ファイルの読み込み
		- ユーザー設定ファイルの読み込み
		- 開発環境用設定の読み込み

		3. 関数ファイルの読み込み
		- 共通関数の読み込み
		- TVer固有関数の読み込み
		- TVerRec固有関数の読み込み

		4. パスの初期化
		- 各種設定ファイルのパス設定
		- ログファイルのパス設定
		- 実行ファイルのパス設定

		5. 環境設定の初期化
		- HTTPヘッダーの設定
		- GeoIP情報の設定
		- ロックファイル用変数の初期化

	.NOTES
		主要な機能：
		- アプリケーションの初期設定
		- 設定ファイルの管理
		- 関数ライブラリの読み込み
		- パス設定の初期化
		- 実行環境の設定

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
try { $launchMode = [String]$args[0] } catch { $launchMode = '' }

# ロゴデータ
$script:logoLines = @(
	'⣴⠟⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦',
	'⣿⠀⠀⣿⣿⣿⣿⡿⠟⠛⠛⠛⠛⠳⢦⣄⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿',
	'⣿⠀⠀⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⢳⣄⠀⠀⠀⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿',
	'⣿⠀⠀⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣆⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣦⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿',
	'⣿⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⡟⠁⣀⣀⠈⢻⣿⠀⠋⢀⣀⡀⠙⣿⠀⠀⣿⣿⣿⠟⠀⢀⣿⡟⠁⣀⣀⠈⢻⣿⡟⠁⣀⣀⠈⢻⣿⣿⣿⣿',
	'⣿⠀⠀⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⠏⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⠀⠾⠿⠿⠷⠀⣿⠀⣾⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⣠⣿⣿⠀⠾⠿⠿⠷⠀⣿⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿',
	'⣿⠀⠀⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠋⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣦⡀⠈⠻⠟⠁⢀⣴⣿⠀⢶⣶⣶⣶⣶⣿⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣧⠀⠘⣿⣿⠀⢶⣶⣶⣶⣶⣿⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿',
	'⣿⠀⠀⣿⣿⣿⣿⣷⣦⣤⣤⣤⣤⣴⣾⠋⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣦⡀⢀⣴⣿⣿⣿⣧⡀⠉⠉⢀⣼⣿⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣧⠀⠘⣿⣧⡀⠉⠉⢀⣼⣿⣧⡀⠉⠉⢀⣼⣿⣿⣿⣿',
	'⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠙⢷⣄⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿',
	'⠻⣦⣤⣿⣿⣿⣿⣿⣿⣿⣿⣤⣤⣤⣤⣽⣷⣤⣤⣤⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟'
)

$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
$script:devDir = Join-Path $script:scriptRoot '../dev'

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

#----------------------------------------------------------------------
# 外部関数ファイルの読み込み
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/common_functions.ps1')) }
catch { throw ($script:msg.LoadCommonFuncFailed) }
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/tver_functions.ps1')) }
catch { throw ($script:msg.LoadTVerFuncFailed) }
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/tverrec_functions.ps1')) }
catch { throw ($script:msg.LoadTVerRecFuncFailed) }

#----------------------------------------------------------------------
# 開発環境用に設定上書き
try {
	$devFunctionFile = Join-Path $script:devDir 'dev_functions.ps1'
	$devConfFile = Join-Path $script:devDir 'dev_setting.ps1'
	if (Test-Path $devConfFile) { . $devConfFile ; Write-Output ($script:msg.DevConfLoaded) }
	if (Test-Path $devFunctionFile) { . $devFunctionFile ; Write-Output ($script:msg.DevFuncLoaded) }
	Remove-Variable -Name devFunctionFile, devConfFile -ErrorAction SilentlyContinue
} catch { throw ($script:msg.LoadDevFilesFailed) }

#----------------------------------------------------------------------
# 連続実行時は以降の処理は不要なのでexit
# 不要な理由はloop.ps1は「.」ではなく「&」で各処理を呼び出ししているので各種変数が不要なため
if ($launchMode -eq 'loop') { Remove-Variable -Name launchMode -ErrorAction SilentlyContinue ; exit 0 }

#----------------------------------------------------------------------
# アップデータのアップデート(アップデート後の実行時にアップデータを更新)
if (Test-Path (Join-Path $script:scriptRoot '../log/updater_update.txt')) {
	try {
		Invoke-WebRequest `
			-Uri 'https://raw.githubusercontent.com/dongaba/TVerRec/master/unix/update_tverrec.sh' `
			-OutFile (Join-Path $script:scriptRoot '../unix/update_tverrec.sh') `
			-TimeoutSec $script:timeoutSec
		Invoke-WebRequest `
			-Uri 'https://raw.githubusercontent.com/dongaba/TVerRec/master/win/update_tverrec.cmd' `
			-OutFile (Join-Path $script:scriptRoot '../win/update_tverrec.cmd') `
			-TimeoutSec $script:timeoutSec
		Remove-Item (Join-Path $script:scriptRoot '../log/updater_update.txt') -Force | Out-Null
	} catch { Write-Warning ($script:msg.UpdateUpdaterFailed) }
}

# TVerRecの最新化チェック
Invoke-TVerRecUpdateCheck
if (!$?) { Write-Warning ($script:msg.TVerRecVersionCheckFailed) }

#----------------------------------------------------------------------
# ダウンロード対象キーワードのパス
$script:keywordFileSamplePath = Join-Path $script:sampleDir 'keyword.sample.conf'
$script:keywordFilePath = Join-Path $script:confDir 'keyword.conf'

# ダウンロード対象外番組のパス
$script:ignoreFileSamplePath = Join-Path $script:sampleDir 'ignore.sample.conf'
$script:ignoreFilePath = Join-Path $script:confDir 'ignore.conf'
$script:ignoreLockFilePath = Join-Path $script:lockDir 'ignore.lock'

# ダウンロード履歴のパス
$script:histFilePath = Join-Path $script:dbDir 'history.csv'
$script:histFileSamplePath = Join-Path $script:sampleDir 'history.sample.csv'
$script:histLockFilePath = Join-Path $script:lockDir 'history.lock'

# ダウンロードリストのパス
$script:listFilePath = Join-Path $script:listDir 'list.csv'
$script:listFileSamplePath = Join-Path $script:sampleDir 'list.sample.csv'
$script:listLockFilePath = Join-Path $script:lockDir 'list.lock'

# ffmpegで番組検証時のエラーファイルのパス
$script:ffmpegErrorLogPath = Join-Path $script:logDir ('ffmpeg_err_{0}.log' -f $PID)

# youtube-dlでダウンロードするときのログファイルのパス
$script:ytdlStdOutLogPath = Join-Path $script:logDir ('ytdl_out_{0}.log' -f $PID)
$script:ytdlStdErrLogPath = Join-Path $script:logDir ('ytdl_err_{0}.log' -f $PID)

# youtube-dlのパス
if ($IsWindows) { $script:ytdlPath = Join-Path $script:binDir 'yt-dlp.exe' }
else { $script:ytdlPath = Join-Path $script:binDir 'yt-dlp' }

# ffmpegのパス
if ($IsWindows) { $script:ffmpegPath = Join-Path $script:binDir 'ffmpeg.exe' }
else { $script:ffmpegPath = Join-Path $script:binDir 'ffmpeg' }

# ffprobeのパス
if ($IsWindows) { $script:ffprobePath = Join-Path $script:binDir 'ffprobe.exe' }
else { $script:ffprobePath = Join-Path $script:binDir 'ffprobe' }

# 進捗表示
if ($script:detailedProgress) { $InformationPreference = 'Continue' }
else { $InformationPreference = 'SilentlyContinue' }

# Geo IPのパス
$script:jpIPList = Join-Path $script:geoIPDir 'jp.csv'

# GUI起動を判定
if ( $myInvocation.ScriptName.Contains('gui')) {
} else {
	# Logo表示
	if (!$script:guiMode) { Show-Logo }
	# youtube-dl/ffmpegの最新化チェック
	try { if (!$script:disableUpdateYoutubedl) { Invoke-ToolUpdateCheck -scriptName 'update_youtube-dl.ps1' -targetName $script:preferredYoutubedl } }
	catch { Write-Warning ($script:msg.YoutubeDLVersionCheckFailed) }
	try { if (!$script:disableUpdateFfmpeg) { Invoke-ToolUpdateCheck -scriptName 'update_ffmpeg.ps1' -targetName 'ffmpeg' } }
	catch { Write-Warning ($script:msg.FfmpegVersionCheckFailed) }
}

# 共通HTTPヘッダ
$script:jpIP = Get-JpIP
Write-Output ('')
Write-Output ($script:msg.JpIPFound -f $script:jpIP)
$script:commonHttpHeader = @{
	'x-tver-platform-type' = 'web'
	'Origin'               = 'https://tver.jp'
	'Referer'              = 'https://tver.jp/'
	'Forwarded'            = $script:jpIP
	'Forwarded-For'        = $script:jpIP
	'X-Forwarded'          = $script:jpIP
	'X-Forwarded-For'      = $script:jpIP
}

# ロックファイル用
$script:fileInfo = @{}
$script:fileStream = @{}

Remove-Variable -Name launchMode -ErrorAction SilentlyContinue
