###################################################################################
#
#		関数読み込みスクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
try { $launchMode = [String]$args[0] } catch { $launchMode = '' }

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

#----------------------------------------------------------------------
# 外部関数ファイルの読み込み
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/common_functions.ps1')) }
catch { Throw ($script:msg.LoadCommonFuncFailed) }
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/tver_functions.ps1')) }
catch { Throw ($script:msg.LoadTVerFuncFailed) }
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/tverrec_functions.ps1')) }
catch { Throw ($script:msg.LoadTVerRecFuncFailed) }

#----------------------------------------------------------------------
# 開発環境用に設定上書き
try {
	$devFunctionFile = Join-Path $script:devDir 'dev_functions.ps1'
	$devConfFile = Join-Path $script:devDir 'dev_setting.ps1'
	if (Test-Path $devConfFile) { . $devConfFile ; Write-Output ($script:msg.DevConfLoaded) }
	if (Test-Path $devFunctionFile) { . $devFunctionFile ; Write-Output ($script:msg.DevFuncLoaded) }
	Remove-Variable -Name devFunctionFile, devConfFile -ErrorAction SilentlyContinue
} catch { Throw ($script:msg.LoadDevFilesFailed) }

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

# グローバル変数でジョブを管理
$global:jobList = @()

# スクリプト終了時にジョブを停止
Register-EngineEvent PowerShell.Exiting -Action {
	foreach ($jobId in $global:jobList) {
		Stop-Job -Id $jobId -Force -ErrorAction SilentlyContinue
		Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
	}
}

Remove-Variable -Name launchMode -ErrorAction SilentlyContinue
