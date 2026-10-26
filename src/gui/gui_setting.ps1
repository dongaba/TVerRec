###################################################################################
#
#		GUI設定スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecの設定画面を提供するGUIスクリプト

	.DESCRIPTION
		TVerRecの各種設定を変更するためのグラフィカルユーザーインターフェース（GUI）を提供します。
		以下の設定カテゴリを管理します：
		- 基本的な設定（ダウンロードディレクトリ、作業ディレクトリなど）
		- 動作設定（マルチスレッド、通知設定など）
		- マイページ設定（プラットフォームID、トークンなど）
		- ダウンロード設定（並列ダウンロード数、タイムアウトなど）
		- 動画ファイル名設定（シリーズ名、放送日などの追加）
		- Ytdl/ffmpeg設定（デコードオプション、更新設定など）
		- Geo IP設定（プロキシ設定など）
		- スケジュール設定（停止時間の設定）
		- 言語設定

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上を推奨です
		- WPFアセンブリが必要です

		主な機能:
		1. 設定の読み込みと表示
		2. 設定の変更と保存
		3. ディレクトリ選択ダイアログ
		4. スケジュール設定の管理

	.EXAMPLE
		# 設定画面を起動
		.\gui_setting.ps1

	.OUTPUTS
		System.Void
		設定を変更し、user_setting.ps1ファイルに保存します。
#>

using namespace System.Windows.Threading
Set-StrictMode -Version Latest
if (!$IsWindows) { throw ('❌️ Windows以外では動作しません') ; Start-Sleep 10 }
Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName PresentationFramework | Out-Null

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 環境設定

try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }

#----------------------------------------------------------------------
# メッセージファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
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
} else { New-Item (Join-Path $script:confDir 'user_setting.ps1') -Force | Out-Null }
if ($script:preferredLanguage) {
	$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:preferredLanguage)) { $script:langFile.$script:preferredLanguage }
	else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }
}

#----------------------------------------------------------------------
# 外部関数ファイルの読み込み
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
} catch { throw ($script:msg.LoadCommonFuncFailed) }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/gui/user_setting_functions.ps1'))
} catch { throw ($script:msg.LoadUserSettingFuncFailed) }

$days = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
$hours = 0..23
$userSettingFile = Join-Path $script:confDir 'user_setting.ps1'
$settingAttributes = @(
	'$script:downloadBaseDir',
	'$script:downloadWorkDir',
	'$script:saveBaseDir',
	'$script:parallelDownloadFileNum',
	'$script:parallelDownloadNumPerFile',
	'$script:ytdlTimeoutSec',
	'$script:minDownloadWorkDirCapacity',
	'$script:minDownloadBaseDirCapacity',
	'$script:loopCycle',
	'$script:myPlatformUID',
	'$script:myPlatformToken',
	'$script:myMemberSID',
	'$script:enableMultithread',
	'$script:multithreadNum',
	'$script:disableToastNotification',
	'$script:guiRefreshIntervalMs',
	'$script:rateLimit',
	'$script:timeoutSec',
	'$script:guiMaxExecLogLines',
	'$script:histRetentionPeriod',
	'$script:sortVideoBySeries',
	'$script:sortVideoByMedia',
	'$script:addSeriesName',
	'$script:addSeasonName',
	'$script:addBroadcastDate',
	'$script:addEpisodeNumber',
	'$script:removeSpecialNote',
	'$script:preferredYoutubedl',
	'$script:disableUpdateYoutubedl',
	'$script:disableUpdateFfmpeg',
	'$script:disableCheckPowerShellUpdate',
	'$script:forceSoftwareDecodeFlag',
	'$script:simplifiedValidation',
	'$script:disableValidation',
	'$script:sitemapParseEpisodeOnly',
	'$script:downloadWhenEpisodeIdChanged',
	'$script:detailedProgress',
	'$script:embedSubtitle',
	'$script:embedMetatag',
	'$script:embedThumbnail',
	'$script:redownloadWhenSubtitleAdded',
	'$script:windowShowStyle',
	'$script:ffmpegDecodeOption',
	'$script:ytdlOption',
	'$script:ytdlNonTVerFileName',
	'$script:forceSingleDownload',
	'$script:extractDescTextToList',
	'$script:listGenHistoryCheck',
	'$script:updateChannel',
	'$script:videoContainerFormat',
	'$script:cleanupDownloadBaseDir',
	'$script:cleanupSaveBaseDir',
	'$script:emptyDownloadBaseDir',
	'$script:deleteUnrenamedFile',
	'$script:moveConflictAction',
	'$script:ytdlHttpHeader',
	'$script:ytdlBaseArgs',
	'$script:nonTVerYtdlBaseArgs',
	'$script:proxyUrl',
	'$script:ytdlRandomIp',
	'$script:scheduleStop',
	'$script:preferredLanguage'
)

#endregion 環境設定

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 関数定義

#----------------------------------------------------------------------
# GUIイベントの処理
#----------------------------------------------------------------------
function Sync-WpfEvent {
	<#
		.SYNOPSIS
			WPFのイベントを同期的に処理します。

		.DESCRIPTION
			WPFのイベントディスパッチャーを使用して、GUIイベントを同期的に処理します。
			これにより、UIの応答性を維持しながらイベントを処理することができます。

		.OUTPUTS
			System.Void

		.NOTES
			この関数は内部で使用され、直接呼び出すことは想定されていません。
	#>
	[OutputType([Void])]
	Param ()
	[DispatcherFrame] $frame = [DispatcherFrame]::new($true)
	[Dispatcher]::CurrentDispatcher.BeginInvoke(
		'Background',
		[DispatcherOperationCallback] {
			Param ([Object] $f)
			($f -as [DispatcherFrame]).Continue = $false
			return $null
		},
		$frame) | Out-Null
	[Dispatcher]::PushFrame($frame)
	Remove-Variable -Name frame, f -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ディレクトリ選択ダイアログ
#----------------------------------------------------------------------
function Select-Folder {
	<#
		.SYNOPSIS
			フォルダ選択ダイアログを表示します。

		.DESCRIPTION
			ユーザーにフォルダを選択させるダイアログを表示し、選択されたパスをテキストボックスに設定します。

		.PARAMETER description
			ダイアログの説明文

		.PARAMETER textBox
			選択されたパスを表示するテキストボックス

		.OUTPUTS
			System.Void

		.EXAMPLE
			Select-Folder -description "ダウンロードディレクトリを選択" -textBox $downloadDirTextBox
	#>
	[OutputType([Void])]
	Param (
		[parameter(Mandatory = $true)]$description,
		[parameter(Mandatory = $true)]$textBox
	)
	$fd = [System.Windows.Forms.FolderBrowserDialog]::new()
	$fd.Description = $description
	$fd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
	$fd.SelectedPath = $textBox.Text
	if ($fd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) { $textBox.Text = $fd.SelectedPath }
	Remove-Variable -Name description, textBox, fd -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# user_setting.ps1から各設定項目を読み込む
#----------------------------------------------------------------------
function Read-UserSetting {
	<#
		.SYNOPSIS
			ユーザー設定を読み込みます。

		.DESCRIPTION
			user_setting.ps1ファイルから設定を読み込み、GUIの各コントロールに反映します。
			未定義の設定項目はデフォルト値で初期化されます。

		.OUTPUTS
			System.Void

		.NOTES
			処理の流れ:
			1. 設定ファイルの読み込み
			2. 各設定項目の値を取得
			3. GUIコントロールに値を設定
			4. スケジュール設定の読み込みと反映
	#>
	[OutputType([Void])]
	Param ()
	$userSettings = @(Get-Content -LiteralPath $userSettingFile -Encoding UTF8)
	# 動作停止設定以外の抽出
	foreach ($settingAttribute in $settingAttributes) {
		# 変数名から「$script:」を取った名前がBox名
		$settingBox = $settingWindow.FindName($settingAttribute.Replace('$script:', ''))
		if ($null -eq $settingBox) { Write-Debug "$settingAttribute is null" ; continue }
		# ユーザー設定の値を取得しGUIに反映
		$settingBox.Text = ConvertTo-SettingDisplayText -Attribute $settingAttribute -Content $userSettings
	}
	# 動作停止設定の抽出と、チェックボックスへの反映
	$stopSchedule = Get-StopScheduleFromSetting -Content $userSettings -Days $days
	foreach ($day in $days) {
		if (!$stopSchedule.ContainsKey($day)) { continue }
		foreach ($hour in $stopSchedule[$day]) {
			$checkbox = $settingWindow.FindName(('chkbxStop{0}{1}' -f $day, $hour.ToString('D2')))
			if ($checkbox) { $checkbox.IsChecked = $true }
		}
	}
	Remove-Variable -Name userSettings, settingAttribute, settingBox, stopSchedule, day, hour, checkbox -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# user_setting.ps1に各設定項目を書き込む
#----------------------------------------------------------------------
function Save-UserSetting {
	<#
		.SYNOPSIS
			ユーザー設定を保存します。

		.DESCRIPTION
			GUIで変更された設定をuser_setting.ps1ファイルに保存します。
			既存の設定ファイルがある場合は、自動生成部分のみを更新します。

		.OUTPUTS
			System.Void

		.NOTES
			処理の流れ:
			1. 既存の設定ファイルの読み込み
			2. 自動生成部分の特定
			3. 新しい設定の生成
			4. 設定ファイルの更新
	#>
	[OutputType([Void])]
	Param ()
	# ファイルが無ければ作る
	if (!(Test-Path -LiteralPath $userSettingFile)) { New-Item -Path $userSettingFile -ItemType File | Out-Null }
	$existingContent = @(Get-Content -LiteralPath $userSettingFile -Encoding UTF8)
	# 動作停止設定以外の部分
	$generatedLines = @()
	foreach ($settingAttribute in $settingAttributes) {
		$settingBox = $settingWindow.FindName($settingAttribute.Replace('$script:', ''))
		if ($null -eq $settingBox) { continue }
		$line = ConvertTo-UserSettingLine -Attribute $settingAttribute -Text $settingBox.Text
		if ($line) { $generatedLines += $line }
	}
	# 動作停止設定の部分
	$stopHours = @{}
	foreach ($day in $days) {
		$stopHoursList = @()
		foreach ($hour in $hours) {
			$checkbox = $settingWindow.FindName(('chkbxStop{0}{1}' -f $day, $hour.ToString('D2')))
			if ($checkbox -and $checkbox.IsChecked) { $stopHoursList += $hour }
		}
		$stopHours[$day] = $stopHoursList
	}
	$generatedLines += ConvertTo-StopScheduleLine -StopHours $stopHours -Days $days
	# 自動生成の部分だけを差し替える
	$newSetting = Merge-UserSettingContent -ExistingContent $existingContent -GeneratedLines $generatedLines
	# 改行コードLFを強制 + NFCで出力
	$newSetting.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC) | Out-File -LiteralPath $userSettingFile -Encoding UTF8 -NoNewline
	Remove-Variable -Name existingContent, generatedLines, settingAttribute, settingBox, line -ErrorAction SilentlyContinue
	Remove-Variable -Name stopHours, stopHoursList, day, hour, checkbox, newSetting -ErrorAction SilentlyContinue
}

#endregion 関数定義

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理

#----------------------------------------------------------------------
#region WPFのWindow設定

try {
	[Xml]$mainXaml = [String](Get-Content -LiteralPath (Join-Path $script:xamlDir 'TVerRecSetting.xaml'))
	$settingWindow = [System.Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]::new($mainXaml)))
} catch { throw ($script:msg.GuiBroken) }
# PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition @'
	[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@ | Out-Null
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
# タスクバーのアイコンにオーバーレイ表示
$settingWindow.TaskbarItemInfo.Overlay = ConvertFrom-Base64 $script:iconBase64
$settingWindow.TaskbarItemInfo.Description = $settingWindow.Title
# ウィンドウを読み込み時の処理
$settingWindow.Add_Loaded({ $settingWindow.Icon = $script:iconPath })
# ウィンドウを閉じる際の処理
$settingWindow.Add_Closing({})
# Name属性を持つ要素のオブジェクト作成
foreach ($node in $mainXaml.SelectNodes('//*[@Name]')) { Set-Variable -Name $node.Name -Value $settingWindow.FindName($node.Name) -Scope Script }
# WPFにロゴをロード
$LogoImage.Source = ConvertFrom-Base64 $script:logoBase64
# バージョン表記
$lblVersion.Content = ('Version {0}' -f $script:appVersion)

# GUI部品のラベルを言語別に設定
$lblBasicSetting.Content = $script:msg.lblBasicSetting
$lblAdvancedSetting.Content = $script:msg.lblAdvancedSetting
$btnWiki.Content = $script:msg.btnWiki
$btnCancel.Content = $script:msg.btnCancel
$btnSave.Content = $script:msg.btnSave
# 基本的な設定
$downloadDirHeader.Header = $script:msg.downloadDirHeader
$downloadDirText.Text = $script:msg.downloadDirText
$workDirHeader.Header = $script:msg.workDirHeader
$workDirText.Text = $script:msg.workDirText
$saveDirHeader.Header = $script:msg.saveDirHeader
$saveDirText.Text = $script:msg.saveDirText
# 動作タブ
$tabOperation.Header = $script:msg.tabOperation
$enableMultithreadHeader.Header = $script:msg.enableMultithreadHeader
$enableMultithreadText.Text = $script:msg.enableMultithreadText
$multithreadNumHeader.Header = $script:msg.multithreadNumHeader
$multithreadNumText.Text = $script:msg.multithreadNumText
$disableToastHeader.Header = $script:msg.disableToastHeader
$disableToastText.Text = $script:msg.disableToastText
$guiRefreshIntervalMsHeader.Header = $script:msg.guiRefreshIntervalMsHeader
$guiRefreshIntervalMsText.Text = $script:msg.guiRefreshIntervalMsText
$maxExecLogLinesHeader.Header = $script:msg.maxExecLogLinesHeader
$maxExecLogLinesText.Text = $script:msg.maxExecLogLinesText
$histRetentionPeriodHeader.Header = $script:msg.histRetentionPeriodHeader
$histRetentionPeriodText.Text = $script:msg.histRetentionPeriodText
$loopCycleHeader.Header = $script:msg.loopCycleHeader
$loopCycleText.Text = $script:msg.loopCycleText
$detailedProgressHeader.Header = $script:msg.detailedProgressHeader
$detailedProgressText.Text = $script:msg.detailedProgressText
$extractDescTextToListHeader.Header = $script:msg.extractDescTextToListHeader
$extractDescTextToListText.Text = $script:msg.extractDescTextToListText
$listGenHistoryCheckHeader.Header = $script:msg.listGenHistoryCheckHeader
$listGenHistoryCheckText.Text = $script:msg.listGenHistoryCheckText
$cleanupDownloadBaseDirHeader.Header = $script:msg.cleanupDownloadBaseDirHeader
$cleanupDownloadBaseDirText.Text = $script:msg.cleanupDownloadBaseDirText
$cleanupSaveBaseDirHeader.Header = $script:msg.cleanupSaveBaseDirHeader
$cleanupSaveBaseDirText.Text = $script:msg.cleanupSaveBaseDirText
$emptyDownloadBaseDirHeader.Header = $script:msg.emptyDownloadBaseDirHeader
$emptyDownloadBaseDirText.Text = $script:msg.emptyDownloadBaseDirText
$deleteUnrenamedFileHeader.Header = $script:msg.deleteUnrenamedFileHeader
$deleteUnrenamedFileText.Text = $script:msg.deleteUnrenamedFileText
$moveConflictActionHeader.Header = $script:msg.moveConflictActionHeader
$moveConflictActionText.Text = $script:msg.moveConflictActionText
$updateChannelHeader.Header = $script:msg.updateChannelHeader
$updateChannelText.Text = $script:msg.updateChannelText
# マイページタブ
$tabMypage.Header = $script:msg.tabMypage
$myPlatformUIDHeader.Header = $script:msg.myPlatformUIDHeader
$myPlatformUIDText.Text = $script:msg.myPlatformUIDText
$myPlatformTokenHeader.Header = $script:msg.myPlatformTokenHeader
$myPlatformTokenText.Text = $script:msg.myPlatformTokenText
$myMemberSIDHeader.Header = $script:msg.myMemberSIDHeader
$myMemberSIDText.Text = $script:msg.myMemberSIDText
# ダウンロードタブ
$tabDownload.Header = $script:msg.tabDownload
$parallelDownloadFileNumHeader.Header = $script:msg.parallelDownloadFileNumHeader
$parallelDownloadFileNumText.Text = $script:msg.parallelDownloadFileNumText
$parallelDownloadNumPerFileHeader.Header = $script:msg.parallelDownloadNumPerFileHeader
$parallelDownloadNumPerFileText.Text = $script:msg.parallelDownloadNumPerFileText
$ytdlTimeoutSecHeader.Header = $script:msg.ytdlTimeoutSecHeader
$YtdlTimeoutSecText.Text = $script:msg.YtdlTimeoutSecText
$minDownloadWorkDirCapacityHeader.Header = $script:msg.minDownloadWorkDirCapacityHeader
$minDownloadWorkDirCapacityText.Text = $script:msg.minDownloadWorkDirCapacityText
$minDownloadBaseDirCapacityHeader.Header = $script:msg.minDownloadBaseDirCapacityHeader
$minDownloadBaseDirCapacityText.Text = $script:msg.minDownloadBaseDirCapacityText
$rateLimitHeader.Header = $script:msg.rateLimitHeader
$rateLimitText.Text = $script:msg.rateLimitText
$timeoutSecHeader.Header = $script:msg.timeoutSecHeader
$timeoutSecText.Text = $script:msg.timeoutSecText
$embedSubtitleHeader.Header = $script:msg.embedSubtitleHeader
$embedSubtitleText.Text = $script:msg.embedSubtitleText
$embedMetatagHeader.Header = $script:msg.embedMetatagHeader
$embedMetatagText.Text = $script:msg.embedMetatagText
$embedThumbnailHeader.Header = $script:msg.embedThumbnailHeader
$embedThumbnailText.Text = $script:msg.embedThumbnailText
$redownloadWhenSubtitleAddedHeader.Header = $script:msg.redownloadWhenSubtitleAddedHeader
$redownloadWhenSubtitleAddedText.Text = $script:msg.redownloadWhenSubtitleAddedText
$sortVideoBySeriesHeader.Header = $script:msg.sortVideoBySeriesHeader
$sortVideoBySeriesText.Text = $script:msg.sortVideoBySeriesText
$sortVideoByMediaHeader.Header = $script:msg.sortVideoByMediaHeader
$sortVideoByMediaText.Text = $script:msg.sortVideoByMediaText
$forceSingleDownloadHeader.Header = $script:msg.forceSingleDownloadHeader
$forceSingleDownloadText.Text = $script:msg.forceSingleDownloadText
$sitemapParseEpisodeOnlyHeader.Header = $script:msg.sitemapParseEpisodeOnlyHeader
$sitemapParseEpisodeOnlyText.Text = $script:msg.sitemapParseEpisodeOnlyText
$downloadWhenEpisodeIdChangedHeader.Header = $script:msg.downloadWhenEpisodeIdChangedHeader
$downloadWhenEpisodeIdChangedText.Text = $script:msg.downloadWhenEpisodeIdChangedText
$VideoContainerFormatHeader.Header = $script:msg.VideoContainerFormatHeader
$videoContainerFormatText.Text = $script:msg.videoContainerFormatText
# 動画ファイル名タブ
$tabVideoFile.Header = $script:msg.tabVideoFile
$addSeriesNameHeader.Header = $script:msg.addSeriesNameHeader
$addSeriesNameText.Text = $script:msg.addSeriesNameText
$addSeasonNameHeader.Header = $script:msg.addSeasonNameHeader
$addSeasonNameText.Text = $script:msg.addSeasonNameText
$addBroadcastDateHeader.Header = $script:msg.addBroadcastDateHeader
$addBroadcastDateText.Text = $script:msg.addBroadcastDateText
$addEpisodeNumberHeader.Header = $script:msg.addEpisodeNumberHeader
$addEpisodeNumberText.Text = $script:msg.addEpisodeNumberText
$removeSpecialNoteHeader.Header = $script:msg.removeSpecialNoteHeader
$removeSpecialNoteText.Text = $script:msg.removeSpecialNoteText
$ytdlNonTVerFileNameHeader.Header = $script:msg.ytdlNonTVerFileNameHeader
$ytdlNonTVerFileNameText.Text = $script:msg.ytdlNonTVerFileNameText
# Ytdl/ffmpegタブ
$tabYtdlFfmpeg.Header = $script:msg.tabYtdlFfmpeg
$btnFfmpegDecodeOptionClear.Content = $script:msg.btnFfmpegDecodeOptionClear
$btnFfmpegDecodeOptionQsv.Content = $script:msg.btnFfmpegDecodeOptionQsv
$btnFfmpegDecodeOptionD3d11.Content = $script:msg.btnFfmpegDecodeOptionD3d11
$btnFfmpegDecodeOptionD3d9.Content = $script:msg.btnFfmpegDecodeOptionD3d9
$btnFfmpegDecodeOptionCuda.Content = $script:msg.btnFfmpegDecodeOptionCuda
$btnFfmpegDecodeOptionVTB.Content = $script:msg.btnFfmpegDecodeOptionVTB
$btnFfmpegDecodeOptionPi4.Content = $script:msg.btnFfmpegDecodeOptionPi4
$btnFfmpegDecodeOptionPi3.Content = $script:msg.btnFfmpegDecodeOptionPi3
$btnYtdlOptionClear.Content = $script:msg.btnYtdlOptionClear
$btnYtdlOption1080.Content = $script:msg.btnYtdlOption1080
$btnYtdlOption720.Content = $script:msg.btnYtdlOption720
$btnYtdlOption480.Content = $script:msg.btnYtdlOption480
$btnYtdlOption360.Content = $script:msg.btnYtdlOption360
$windowShowStyleHeader.Header = $script:msg.windowShowStyleHeader
$windowShowStyleText.Text = $script:msg.windowShowStyleText
$preferredYoutubedlHeader.Header = $script:msg.preferredYoutubedlHeader
$preferredYoutubedlText.Text = $script:msg.preferredYoutubedlText
$ffmpegDecodeOptionHeader.Header = $script:msg.ffmpegDecodeOptionHeader
$ffmpegDecodeOptionText.Text = $script:msg.ffmpegDecodeOptionText
$forceSoftwareDecodeFlagHeader.Header = $script:msg.forceSoftwareDecodeFlagHeader
$forceSoftwareDecodeFlagText.Text = $script:msg.forceSoftwareDecodeFlagText
$simplifiedValidationHeader.Header = $script:msg.simplifiedValidationHeader
$simplifiedValidationText.Text = $script:msg.simplifiedValidationText
$disableValidationHeader.Header = $script:msg.disableValidationHeader
$disableValidationText.Text = $script:msg.disableValidationText
$disableUpdateYoutubedlHeader.Header = $script:msg.disableUpdateYoutubedlHeader
$disableUpdateYoutubedlText.Text = $script:msg.disableUpdateYoutubedlText
$disableUpdateFfmpegHeader.Header = $script:msg.disableUpdateFfmpegHeader
$disableUpdateFfmpegText.Text = $script:msg.disableUpdateFfmpegText
$disableCheckPowerShellUpdateHeader.Header = $script:msg.disableCheckPowerShellUpdateHeader
$disableCheckPowerShellUpdateText.Text = $script:msg.disableCheckPowerShellUpdateText
$ytdlOptionHeader.Header = $script:msg.ytdlOptionHeader
$ytdlOptionText.Text = $script:msg.ytdlOptionText
$ytdlHttpHeaderHeader.Header = $script:msg.ytdlHttpHeaderHeader
$ytdlHttpHeaderText.Text = $script:msg.ytdlHttpHeaderText
$ytdlBaseArgsHeader.Header = $script:msg.ytdlBaseArgsHeader
$ytdlBaseArgsText.Text = $script:msg.ytdlBaseArgsText
$nonTVerYtdlBaseArgsHeader.Header = $script:msg.nonTVerYtdlBaseArgsHeader
$nonTVerYtdlBaseArgsText.Text = $script:msg.nonTVerYtdlBaseArgsText
# Geo IPタブ
$tabGeoIP.Header = $script:msg.tabGeoIP
$proxyUrlHeader.Header = $script:msg.proxyUrlHeader
$proxyUrlText.Text = $script:msg.proxyUrlText
$ytdlRandomIpHeader.Header = $script:msg.ytdlRandomIpHeader
$ytdlRandomIpText.Text = $script:msg.ytdlRandomIpText
# スケジュールタブ
$tabSchedule.Header = $script:msg.tabSchedule
$scheduleStopHeader.Header = $script:msg.scheduleStopHeader
$scheduleStopText.Text = $script:msg.scheduleStopText
$scheduleSpecify.Text = $script:msg.scheduleSpecify
$scheduleStopTime.Text = $script:msg.scheduleStopTextTime
$scheduleStopWeek.Text = $script:msg.scheduleStopTextWeek
$scheduleStopMon.Text = $script:msg.scheduleStopTextMon
$scheduleStopTue.Text = $script:msg.scheduleStopTextTue
$scheduleStopWed.Text = $script:msg.scheduleStopTextWed
$scheduleStopThu.Text = $script:msg.scheduleStopTextThu
$scheduleStopFri.Text = $script:msg.scheduleStopTextFri
$scheduleStopSat.Text = $script:msg.scheduleStopTextSat
$scheduleStopSun.Text = $script:msg.scheduleStopTextSun
$scheduleStopDay.Text = $script:msg.scheduleStopTextDay
# 言語タブ
$tabLanguage.Header = $script:msg.tabLanguage
$preferredLanguageHeader.Header = $script:msg.preferredLanguageHeader
$preferredLanguageText.Text = $script:msg.preferredLanguageText


# ComboBOxのラベルを言語別に設定
# True/Falseオプションを追加するコントロール
$trueFalseOptions = @($script:msg.SettingDefault, $script:msg.SettingTrue, $script:msg.SettingFalse)
$trueFalseControls = @(
	$enableMultithread,
	$disableToastNotification,
	$detailedProgress,
	$extractDescTextToList,
	$listGenHistoryCheck,
	$cleanupDownloadBaseDir,
	$cleanupSaveBaseDir,
	$emptyDownloadBaseDir,
	$deleteUnrenamedFile,
	$embedSubtitle,
	$embedMetatag,
	$embedThumbnail,
	$redownloadWhenSubtitleAdded,
	$sortVideoBySeries,
	$sortVideoByMedia,
	$forceSingleDownload,
	$sitemapParseEpisodeOnly,
	$downloadWhenEpisodeIdChanged,
	$addSeriesName,
	$addSeasonName,
	$addBroadcastDate,
	$addEpisodeNumber,
	$removeSpecialNote,
	$forceSoftwareDecodeFlag,
	$simplifiedValidation,
	$disableValidation,
	$disableUpdateYoutubedl,
	$disableUpdateFfmpeg,
	$disableCheckPowerShellUpdate,
	$ytdlRandomIp,
	$scheduleStop
)
foreach ($control in $trueFalseControls) {
	foreach ($option in $trueFalseOptions) { $control.Items.Add($option) | Out-Null }
}
# カスタムオプションを追加するコントロール
$updateChannel.Items.Add($script:msg.SettingDefault) | Out-Null
$updateChannel.Items.Add('release') | Out-Null
$updateChannel.Items.Add('prerelease') | Out-Null
$updateChannel.Items.Add('master') | Out-Null
$updateChannel.Items.Add('beta') | Out-Null
$updateChannel.Items.Add('dev') | Out-Null
$videoContainerFormat.Items.Add($script:msg.SettingDefault) | Out-Null
$videoContainerFormat.Items.Add('mp4') | Out-Null
$videoContainerFormat.Items.Add('ts') | Out-Null
$moveConflictAction.Items.Add($script:msg.SettingDefault) | Out-Null
$moveConflictAction.Items.Add('Overwrite') | Out-Null
$moveConflictAction.Items.Add('Skip') | Out-Null
$moveConflictAction.Items.Add('Rename') | Out-Null
$windowShowStyle.Items.Add($script:msg.SettingDefault) | Out-Null
$windowShowStyle.Items.Add('Minimized') | Out-Null
$windowShowStyle.Items.Add('Hidden') | Out-Null
$windowShowStyle.Items.Add('Normal') | Out-Null
$windowShowStyle.Items.Add('Maximized') | Out-Null
$preferredYoutubedl.Items.Add($script:msg.SettingDefault) | Out-Null
$preferredYoutubedl.Items.Add('yt-dlp') | Out-Null
$preferredYoutubedl.Items.Add('yt-dlp-nightly') | Out-Null
$preferredYoutubedl.Items.Add('ytdl-patched') | Out-Null
$preferredLanguage.Items.Add($script:msg.SettingDefault) | Out-Null
$preferredLanguage.Items.Add('日本語') | Out-Null	# ja-JP
$preferredLanguage.Items.Add('English') | Out-Null	# en-US


#endregion WPFのWindow設定
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region ボタンのアクション
$btnWiki.Add_Click({ Start-Process 'https://github.com/dongaba/TVerRec/wiki' })
$btnCancel.Add_Click({ $settingWindow.close() })
$btnSave.Add_Click({ Save-UserSetting ; $settingWindow.close() })
$btnDownloadBaseDir.Add_Click({ Select-Folder $script:msg.SelectDownloadDir $script:downloadBaseDir })
$btnDownloadWorkDir.Add_Click({ Select-Folder $script:msg.SelectWorkDir $script:downloadWorkDir })
$btnSaveBaseDir.Add_Click({ Select-Folder $script:msg.SelectSaveDir $script:saveBaseDir })

$btnFfmpegDecodeOptionClear.Add_Click({ $ffmpegDecodeOption.Text = '' })
$btnFfmpegDecodeOptionQsv.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel qsv -c:v h264_qsv' })
$btnFfmpegDecodeOptionD3d11.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel d3d11va -hwaccel_output_format d3d11' })
$btnFfmpegDecodeOptionD3d9.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld' })
$btnFfmpegDecodeOptionCuda.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel cuda -hwaccel_output_format cuda' })
$btnFfmpegDecodeOptionVTB.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel videotoolbox' })
$btnFfmpegDecodeOptionPi4.Add_Click({ $ffmpegDecodeOption.Text = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32' })
$btnFfmpegDecodeOptionPi3.Add_Click({ $ffmpegDecodeOption.Text = '-c:v h264_omx' })

#----------------------------------------------------------------------
# youtube-dlの画質オプションを入力欄に設定
#----------------------------------------------------------------------
function Set-YtdlOption {
	<#
		.SYNOPSIS
			youtube-dlのオプション入力欄に、画質を指定するオプションを設定します。

		.DESCRIPTION
			高さ(画質)を指定すると、その高さ以下で最良の映像と音声を選ぶ`-f "bv[height<=高さ]+ba/b[height<=高さ]"`を設定します。
			`Clear`を指定すると、入力欄を空にします。

		.PARAMETER height
			画質の高さ(1080、720、480、360など)、または、入力欄を空にする場合は`Clear`を指定します。

		.OUTPUTS
			[Void]

		.EXAMPLE
			Set-YtdlOption 720

		.NOTES
			GUIの入力欄($ytdlOption)を更新するだけで、システムの状態は変更しません。
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '画面の入力欄の文字列を設定するだけで、システムの状態は変更しない')]
	Param ($height)
	$ytdlOption.Text = if ($height -eq 'Clear') { '' }
	else { '-f "bv[height<=' + $height + ']+ba/b[height<=' + $height + ']"' }
}
$btnYtdlOptionClear.Add_Click({ Set-YtdlOption 'Clear' })
$btnYtdlOption1080.Add_Click({ Set-YtdlOption 1080 })
$btnYtdlOption720.Add_Click({ Set-YtdlOption 720 })
$btnYtdlOption480.Add_Click({ Set-YtdlOption 480 })
$btnYtdlOption360.Add_Click({ Set-YtdlOption 360 })

#----------------------------------------------------------------------
# 曜日・時間のチェックボックスの一括連動
#----------------------------------------------------------------------
function Sync-MultiCheckbox {
	<#
		.SYNOPSIS
			ダウンロード停止時間帯のチェックボックスを、曜日または時間の「全て」のチェックボックスに連動させます。

		.DESCRIPTION
			dayを指定した場合は、その曜日の全時間帯のチェックボックスを、allCheckboxの状態に揃えます。
			hourを指定した場合は、その時間の全曜日のチェックボックスを、allCheckboxの状態に揃えます。
			allCheckboxのチェックを外した場合は、交差する側の「全て」のチェックボックス(曜日を指定した場合は各時間の、時間を指定した場合は各曜日の「全て」)のチェックも外します。

		.PARAMETER day
			曜日(Mon/Tue/Wed/Thu/Fri/Sat/Sun)を指定します。hourとは同時に指定しません。

		.PARAMETER hour
			時間(00〜23)を指定します。dayとは同時に指定しません。

		.PARAMETER allCheckbox
			曜日または時間の「全て」のチェックボックスを指定します。

		.OUTPUTS
			[Void]

		.EXAMPLE
			Sync-MultiCheckbox -day 'Mon' -allCheckbox $chkbxStopMonAll
	#>
	param (
		[String]$day,
		[String]$hour,
		[Object]$allCheckbox
	)
	if ($day) {
		foreach ($hour in $hours) {
			$checkboxName = 'chkbxStop{0}{1:D2}' -f $day, [Int]$hour
			(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			if ($allCheckbox.IsChecked -eq $false) {
				$checkboxName = 'chkbxStop{0:D2}{1}' -f [Int]$hour, 'All'
				(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			}
		}
	} elseif ($hour) {
		foreach ($day in $days) {
			$checkboxName = 'chkbxStop{0}{1:D2}' -f $day, [Int]$hour
			(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			if ($allCheckbox.IsChecked -eq $false) {
				$checkboxName = 'chkbxStop{0}{1}' -f $day, 'All'
				(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			}
		}
	}
}

# 各曜日に対してクリックイベントを登録
$chkbxStopMonAll.Add_Click({ Sync-MultiCheckbox -day 'Mon' -allCheckbox $chkbxStopMonAll })
$chkbxStopTueAll.Add_Click({ Sync-MultiCheckbox -day 'Tue' -allCheckbox $chkbxStopTueAll })
$chkbxStopWedAll.Add_Click({ Sync-MultiCheckbox -day 'Wed' -allCheckbox $chkbxStopWedAll })
$chkbxStopThuAll.Add_Click({ Sync-MultiCheckbox -day 'Thu' -allCheckbox $chkbxStopThuAll })
$chkbxStopFriAll.Add_Click({ Sync-MultiCheckbox -day 'Fri' -allCheckbox $chkbxStopFriAll })
$chkbxStopSatAll.Add_Click({ Sync-MultiCheckbox -day 'Sat' -allCheckbox $chkbxStopSatAll })
$chkbxStopSunAll.Add_Click({ Sync-MultiCheckbox -day 'Sun' -allCheckbox $chkbxStopSunAll })

# 各時間に対してクリックイベントを登録
$chkbxStop00All.Add_Click({ Sync-MultiCheckbox -hour '00' -allCheckbox $chkbxStop00All })
$chkbxStop01All.Add_Click({ Sync-MultiCheckbox -hour '01' -allCheckbox $chkbxStop01All })
$chkbxStop02All.Add_Click({ Sync-MultiCheckbox -hour '02' -allCheckbox $chkbxStop02All })
$chkbxStop03All.Add_Click({ Sync-MultiCheckbox -hour '03' -allCheckbox $chkbxStop03All })
$chkbxStop04All.Add_Click({ Sync-MultiCheckbox -hour '04' -allCheckbox $chkbxStop04All })
$chkbxStop05All.Add_Click({ Sync-MultiCheckbox -hour '05' -allCheckbox $chkbxStop05All })
$chkbxStop06All.Add_Click({ Sync-MultiCheckbox -hour '06' -allCheckbox $chkbxStop06All })
$chkbxStop07All.Add_Click({ Sync-MultiCheckbox -hour '07' -allCheckbox $chkbxStop07All })
$chkbxStop08All.Add_Click({ Sync-MultiCheckbox -hour '08' -allCheckbox $chkbxStop08All })
$chkbxStop09All.Add_Click({ Sync-MultiCheckbox -hour '09' -allCheckbox $chkbxStop09All })
$chkbxStop10All.Add_Click({ Sync-MultiCheckbox -hour '10' -allCheckbox $chkbxStop10All })
$chkbxStop11All.Add_Click({ Sync-MultiCheckbox -hour '11' -allCheckbox $chkbxStop11All })
$chkbxStop12All.Add_Click({ Sync-MultiCheckbox -hour '12' -allCheckbox $chkbxStop12All })
$chkbxStop13All.Add_Click({ Sync-MultiCheckbox -hour '13' -allCheckbox $chkbxStop13All })
$chkbxStop14All.Add_Click({ Sync-MultiCheckbox -hour '14' -allCheckbox $chkbxStop14All })
$chkbxStop15All.Add_Click({ Sync-MultiCheckbox -hour '15' -allCheckbox $chkbxStop15All })
$chkbxStop16All.Add_Click({ Sync-MultiCheckbox -hour '16' -allCheckbox $chkbxStop16All })
$chkbxStop17All.Add_Click({ Sync-MultiCheckbox -hour '17' -allCheckbox $chkbxStop17All })
$chkbxStop18All.Add_Click({ Sync-MultiCheckbox -hour '18' -allCheckbox $chkbxStop18All })
$chkbxStop19All.Add_Click({ Sync-MultiCheckbox -hour '19' -allCheckbox $chkbxStop19All })
$chkbxStop20All.Add_Click({ Sync-MultiCheckbox -hour '20' -allCheckbox $chkbxStop20All })
$chkbxStop21All.Add_Click({ Sync-MultiCheckbox -hour '21' -allCheckbox $chkbxStop21All })
$chkbxStop22All.Add_Click({ Sync-MultiCheckbox -hour '22' -allCheckbox $chkbxStop22All })
$chkbxStop23All.Add_Click({ Sync-MultiCheckbox -hour '23' -allCheckbox $chkbxStop23All })

#endregion ボタンのアクション
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region 設定ファイルの読み込み
Read-UserSetting
#endregion 設定ファイルの読み込み
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# ウィンドウ表示

try {
	$settingWindow.Show() | Out-Null
	$settingWindow.Activate() | Out-Null
	[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch { throw ($script:msg.WindowRenderError) }

# メインウィンドウ取得
$currentProcess = [Diagnostics.Process]::GetCurrentProcess()
$form = [Windows.Forms.NativeWindow]::new()
$form.AssignHandle($currentProcess.MainWindowHandle)

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ウィンドウ表示後のループ処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
#region ウィンドウ表示後のループ処理
while ($settingWindow.IsVisible) {
	# GUIイベント処理
	Sync-WpfEvent
	Start-Sleep -Milliseconds 10
}

#endregion ウィンドウ表示後のループ処理
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 終了処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Remove-Variable -Name mainXaml, settingWindow -ErrorAction SilentlyContinue
Remove-Variable -Name LogoImage, lblVersion -ErrorAction SilentlyContinue
Remove-Variable -Name btnWiki, btnCancel, btnSave -ErrorAction SilentlyContinue
Remove-Variable -Name btndownloadBaseDir, btnDownloadWorkDir, btnSaveBaseDir -ErrorAction SilentlyContinue
Remove-Variable -Name userSettingFile, settingAttributes -ErrorAction SilentlyContinue
Remove-Variable -Name currentProcess, form -ErrorAction SilentlyContinue
