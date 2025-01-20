###################################################################################
#
#		関数読み込みスクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

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
$script:devDir = Join-Path $script:scriptRoot '../dev'

if ( Test-Path (Join-Path $script:confDir 'system_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'system_setting.ps1')) }
	catch { Throw ($script:msg.LoadSystemSettingFailed) }
} else { Throw ($script:msg.SystemSettingNotFound) }

if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	catch { Throw ($script:msg.LoadUserSettingFailed) }
} else { Throw ($script:msg.UserSettingNotCompleted) }
if (Test-Path variable:lang) {
	$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:lang)) { $script:langFile.$script:lang }
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
	if (Test-Path $devConfFile) { . $devConfFile ; Write-Debug ($script:msg.DevConfLoaded) }
	if (Test-Path $devFunctionFile) { . $devFunctionFile ; Write-Debug ($script:msg.DevFuncLoaded) }
	Remove-Variable -Name devFunctionFile, devConfFile -ErrorAction SilentlyContinue
} catch { Throw ($script:msg.LoadDevFilesFailed) }

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
$script:ffmpegErrorLogPath = Join-Path $script:logDir ('ffmpeg_error_{0}.log' -f $PID)

# youtube-dlのパス
if ($IsWindows) { $script:ytdlPath = Join-Path $script:binDir 'youtube-dl.exe' }
else { $script:ytdlPath = Join-Path $script:binDir 'youtube-dl' }

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

# 共通HTTPヘッダ
$script:jpIP = Get-JpIP
$script:requestHeader = @{
	'x-tver-platform-type' = 'web'
	'Origin'               = 'https://tver.jp'
	'Referer'              = 'https://tver.jp'
	'X-Forwarded-For'      = $script:jpIP
}

# ロックファイル用
$script:fileInfo = @{}
$script:fileStream = @{}
