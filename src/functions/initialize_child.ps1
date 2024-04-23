###################################################################################
#
#		関数読み込みスクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#設定ファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
$script:devDir = Join-Path $script:scriptRoot '../dev'

if ( Test-Path (Join-Path $script:confDir 'system_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'system_setting.ps1')) }
	catch { Write-Error ('❌️ システム設定ファイルの読み込みに失敗しました') ; exit 1 }
} else { Write-Error ('❌️ システム設定ファイルが見つかりません') ; exit 1 }

if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	catch { Write-Error ('❌️ ユーザ設定ファイルの読み込みに失敗しました') ; exit 1 }
} else { Write-Error ('❌️ ユーザ設定が完了してません') ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/common_functions.ps1')) }
catch { Write-Error ('❌️ 外部関数ファイル(common_functions.ps1)の読み込みに失敗しました') ; exit 1 }
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/tver_functions.ps1')) }
catch { Write-Error ('❌️ 外部関数ファイル(tver_functions.ps1)の読み込みに失敗しました') ; exit 1 }
try { . (Convert-Path (Join-Path $script:scriptRoot 'functions/tverrec_functions.ps1')) }
catch { Write-Error ('❌️ 外部関数ファイル(tverrec_functions.ps1)の読み込みに失敗しました') ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$devFunctionFile = Join-Path $script:devDir 'dev_funcitons.ps1'
	$devConfFile = Join-Path $script:devDir 'dev_setting.ps1'
	if (Test-Path $devConfFile) { . $devConfFile }
	if (Test-Path $devFunctionFile) { . $devFunctionFile }
	Remove-Variable -Name devFunctionFile, devConfFile -ErrorAction SilentlyContinue
} catch { Write-Error ('❌️ 開発用設定ファイルの読み込みに失敗しました') ; exit 1 }

#----------------------------------------------------------------------
#ダウンロード対象キーワードのパス
$script:keywordFileSamplePath = Join-Path $script:sampleDir 'keyword.sample.conf'
$script:keywordFilePath = Join-Path $script:confDir 'keyword.conf'

#ダウンロード対象外番組のパス
$script:ignoreFileSamplePath = Join-Path $script:sampleDir 'ignore.sample.conf'
$script:ignoreFilePath = Join-Path $script:confDir 'ignore.conf'
$script:ignoreLockFilePath = Join-Path $script:lockDir 'ignore.lock'

#ダウンロード履歴のパス
$script:histFilePath = Join-Path $script:dbDir 'history.csv'
$script:histFileSamplePath = Join-Path $script:sampleDir 'history.sample.csv'
$script:histLockFilePath = Join-Path $script:lockDir 'history.lock'

#サイトマップ処理時の中間ファイルのパス
$script:sitemaptFilePath = Join-Path $script:dbDir 'sitemap.txt'

#ダウンロードリストのパス
$script:listFilePath = Join-Path $script:listDir 'list.csv'
$script:listFileSamplePath = Join-Path $script:sampleDir 'list.sample.csv'
$script:listLockFilePath = Join-Path $script:lockDir 'list.lock'

#ffpmegで番組検証時のエラーファイルのパス
$script:ffpmegErrorLogPath = Join-Path $script:logDir ('ffmpeg_error_{0}.log' -f $PID)

#youtube-dlのパス
if ($IsWindows) { $script:ytdlPath = Join-Path $script:binDir 'youtube-dl.exe' }
else { $script:ytdlPath = Join-Path $script:binDir 'youtube-dl' }

#ffmpegのパス
if ($IsWindows) { $script:ffmpegPath = Join-Path $script:binDir 'ffmpeg.exe' }
else { $script:ffmpegPath = Join-Path $script:binDir 'ffmpeg' }

#ffprobeのパス
if ($IsWindows) { $script:ffprobePath = Join-Path $script:binDir 'ffprobe.exe' }
else { $script:ffprobePath = Join-Path $script:binDir 'ffprobe' }

#ロックファイル用
$script:fileInfo = @{}
$script:fileStream = @{}
