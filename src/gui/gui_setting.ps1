###################################################################################
#
#		GUI設定スクリプト
#
###################################################################################
using namespace System.Windows.Threading
Set-StrictMode -Version Latest
if (!$IsWindows) { Throw ('❌️ Windows以外では動作しません') ; Start-Sleep 10 }
Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName PresentationFramework | Out-Null

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# region 環境設定

try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }

#----------------------------------------------------------------------
# メッセージファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
$script:langDir = Convert-Path (Join-Path $scriptRoot '../resources/lang')
$script:currentCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
Write-Debug "Current Language: $script:currentCulture"
$script:langFile = Get-Content -Path (Join-Path $script:langDir 'messages.json') | ConvertFrom-Json
$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:currentCulture)) { $script:langFile.$script:currentCulture }
else { $script:langFile.default }

#----------------------------------------------------------------------
# 設定ファイル読み込み
try {
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
} catch { Throw ($script:msg.LoadSystemSettingFailed) }

#----------------------------------------------------------------------
# 外部関数ファイルの読み込み
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
} catch { Throw ($script:msg.LoadCommonFuncFailed) }

$days = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
$hours = 0..23
$userSettingFile = Join-Path $script:confDir 'user_setting.ps1'
$settingAttributes = @(
	'$script:downloadBaseDir',
	'$script:downloadWorkDir',
	'$script:saveBaseDir',
	'$script:parallelDownloadFileNum',
	'$script:parallelDownloadNumPerFile',
	'$script:loopCycle',
	'$script:myPlatformUID',
	'$script:myPlatformToken',
	'$script:myMemberSID',
	'$script:enableMultithread',
	'$script:multithreadNum',
	'$script:disableToastNotification',
	'$script:rateLimit',
	'$script:timeoutSec',
	'$script:guiMaxExecLogLines',
	'$script:histRetentionPeriod',
	'$script:sortVideoByMedia',
	'$script:addSeriesName',
	'$script:addSeasonName',
	'$script:addBroadcastDate',
	'$script:addEpisodeNumber',
	'$script:removeSpecialNote',
	'$script:preferredYoutubedl',
	'$script:disableUpdateYoutubedl',
	'$script:disableUpdateFfmpeg',
	'$script:forceSoftwareDecodeFlag',
	'$script:simplifiedValidation',
	'$script:disableValidation',
	'$script:sitemapParseEpisodeOnly',
	'$script:downloadWhenEpisodeIdChanged',
	'$script:detailedProgress',
	'$script:embedSubtitle',
	'$script:embedMetatag',
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
	'$script:ytdlHttpHeader',
	'$script:ytdlBaseArgs',
	'$script:nonTVerYtdlBaseArgs',
	'$script:scheduleStop'
)

# endregion 環境設定

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# region 関数定義

# GUIイベントの処理
function Sync-WpfEvents {
	[OutputType([System.Void])]
	Param ()
	[DispatcherFrame] $frame = [DispatcherFrame]::new($true)
	[Dispatcher]::CurrentDispatcher.BeginInvoke(
		'Background',
		[DispatcherOperationCallback] {
			Param ([object] $f)
			($f -as [DispatcherFrame]).Continue = $false
			return $null
		},
		$frame) | Out-Null
	[Dispatcher]::PushFrame($frame)
	Remove-Variable -Name frame, f -ErrorAction SilentlyContinue
}

# ディレクトリ選択ダイアログ
function Select-Folder() {
	[OutputType([System.Void])]
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

# user_setting.ps1から各設定項目を読み込む
function Read-UserSetting {
	[OutputType([System.Void])]
	Param ()
	if (Test-Path $userSettingFile) {
		$userSettings = Get-Content -LiteralPath $userSettingFile -Encoding UTF8
		# 動作停止設定以外の抽出
		foreach ($settingAttribute in $settingAttributes) {
			# 変数名から「$script:」を取った名前がBox名
			$settingBox = $settingWindow.FindName($settingAttribute.Replace('$script:', ''))
			# ユーザー設定の値を取得しGUIに反映
			$userSettingValue = ($userSettings -match ('^{0}' -f [regex]::Escape($settingAttribute)))
			if ($userSettingValue) {
				Write-Debug $userSettingValue
				$settingBox.Text = $userSettingValue.split('=', 2)[1].Trim().Trim("'")
				if ($settingBox.Text -eq '$true') { $settingBox.Text = $script:msg.SettingTrue }
				elseif ($settingBox.Text -eq '$false') { $settingBox.Text = $script:msg.SettingFalse }
			} elseif ($settingAttribute -in @('$script:downloadBaseDir', '$script:downloadWorkDir', '$script:saveBaseDir', '$script:myPlatformUID', '$script:myPlatformToken', '$script:myMemberSID')) { $settingBox.Text = $script:msg.SettingUndefined }
			else { $settingBox.Text = $script:msg.SettingDefault }
		}
		# 動作停止設定の抽出
		$scheduleStopPattern = '\$script:stopSchedule\s*=\s*@\{([^}]*)\}'
		$scheduleStopDetail = [regex]::Match($userSettings, $scheduleStopPattern)
		# 抽出した内容を解析してチェックボックスに反映
		if ($scheduleStopDetail.Success) {
			$scheduleStopString = $scheduleStopDetail.Groups[1].Value
			foreach ($day in $days) {
				if ($scheduleStopString -match "'$day'\s*=\s*@\(([^)]*)\)") {
					$schedule = $matches[1].Split(',').Trim() | Where-Object { $_ -ne '' }
					foreach ($hour in $schedule) {
						$checkbox = $settingWindow.FindName(('chkbxStop{0}{1}' -f $day, ([int]$hour).ToString('D2')))
						if ($checkbox) { $checkbox.IsChecked = $true }
					}
				}
			}
		}
	}
	Remove-Variable -Name userSettings, settingBox -ErrorAction SilentlyContinue
	Remove-Variable -Name scheduleStopPattern, scheduleStopDetail, scheduleStopString -ErrorAction SilentlyContinue
	Remove-Variable -Name day, schedule, hour, checkbox -ErrorAction SilentlyContinue
}

# user_setting.ps1に各設定項目を書き込む
function Save-UserSetting {
	[OutputType([System.Void])]
	Param ()
	$newSetting = @()
	$startSegment = '##Start Setting Generated from GUI'
	$endSegment = '##End Setting Generated from GUI'
	# ファイルが無ければ作ればいい
	if (!(Test-Path $userSettingFile)) {
		New-Item -Path $userSettingFile -ItemType File | Out-Null
		$content = Get-Content -LiteralPath $userSettingFile
		$totalLineNum = 0
	} else {
		$content = Get-Content -LiteralPath $userSettingFile -Encoding UTF8
		#自動生成部分の行数を取得
		$totalLineNum = try { $content.Count + 1 } catch { 0 }
		$headLineNum = try { ($content | Select-String $startSegment).LineNumber - 2 } catch { 0 }
		$tailLineNum = try { $totalLineNum - ($content | Select-String $endSegment).LineNumber - 1 } catch { 0 }
	}
	# 自動生成より前の部分
	# 自動生成の開始位置が2行目以降の場合にだけ自動生成寄りの前の部分がある
	if (Test-Path variable:headLineNum) { if ($headLineNum -ge 0 ) { $newSetting += $content[0..$headLineNum] } }
	# 動作停止設定以外の部分
	$newSetting += $startSegment
	if ($settingAttributes) {
		foreach ($settingAttribute in $settingAttributes) {
			$settingBoxName = $settingAttribute.Replace('$script:', '')
			$settingBox = $settingWindow.FindName($settingBoxName)
			switch -wildcard ($settingBox.Text) {
				{ $_ -in '', $script:msg.SettingDefault, $script:msg.SettingUndefined } { continue }
				{ $_ -eq $script:msg.SettingTrue } { $newSetting += ('{0} = $true' -f $settingAttribute) ; continue }
				{ $_ -eq $script:msg.SettingFalse } { $newSetting += ('{0} = $false' -f $settingAttribute) ; continue }
				default {
					if (([Int]::TryParse($settingBox.Text, [ref]$null)) -or ($settingBox.Text -match '[${}]')) { $newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text) }
					else { $newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text) }
				}
			}
		}
	}
	# 動作停止設定の部分
	$stopSetting = @()
	$stopSetting += '$script:stopSchedule = @{'
	foreach ($day in $days) {
		$stopHoursList = @()
		foreach ($hour in $hours) {
			$checkbox = $settingWindow.FindName(('chkbxStop{0}{1}' -f $day, $hour.ToString('D2')))
			if ($checkbox -and $checkbox.IsChecked) { $stopHoursList += $hour }
		}
		# 停止時間を文字列に変換し、曜日ごとのエントリを作成
		$stopHours = "'{0}' = @({1})" -f $day, ($stopHoursList -join ', ')
		$stopSetting += "`t" + $stopHours
	}
	$stopSetting += '}'
	$newSetting += $stopSetting
	# 自動生成より後の部分
	$newSetting += $endSegment
	if ( $totalLineNum -ne 0 ) {
		try { $newSetting += Get-Content $userSettingFile -Tail $tailLineNum }
		catch { Write-Warning ($script:msg.AutoGenNotDetected) }
	}
	# 改行コードLFを強制 + NFCで出力
	$newSetting.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC)  | Out-File -LiteralPath $userSettingFile -Encoding UTF8 -NoNewline
	Remove-Variable -Name newSetting, startSegment, endSegment, content -ErrorAction SilentlyContinue
	Remove-Variable -Name totalLineNum, headLineNum, tailLineNum -ErrorAction SilentlyContinue
	Remove-Variable -Name settingAttribute, settingBoxName, settingBox -ErrorAction SilentlyContinue
	Remove-Variable -Name stopSetting, day, hour, checkbox, stopHours -ErrorAction SilentlyContinue
}

# endregion 関数定義

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理

#----------------------------------------------------------------------
# region WPFのWindow設定

try {
	[String]$mainXaml = Get-Content -LiteralPath (Join-Path $script:xamlDir 'TVerRecSetting.xaml')
	$mainXaml = $mainXaml -ireplace 'mc:Ignorable="d"', '' -ireplace 'x:N', 'N' -ireplace 'x:Class=".*?"', ''
	[xml]$mainCleanXaml = $mainXaml
	$settingWindow = [System.Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]::new($mainCleanXaml)))
} catch { Throw ($script:msg.GuiBroken) }
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
$mainCleanXaml.SelectNodes('//*[@Name]') | ForEach-Object { Set-Variable -Name ($_.Name) -Value $settingWindow.FindName($_.Name) -Scope Script }
# WPFにロゴをロード
$LogoImage.Source = ConvertFrom-Base64 $script:logoBase64
# バージョン表記
$lblVersion.Content = ('Version {0}' -f $script:appVersion)

# GUI部品のラベルを言語別に設定
$lblBasicSetting.Content = $script:msg.GuiLabelBasicSetting
$lblAdvancedSetting.Content = $script:msg.GuiLabelAdvancedSetting
$btnWiki.Content = $script:msg.GuiButtonWiki
$btnCancel.Content = $script:msg.GuiButtonCancel
$btnSave.Content = $script:msg.GuiButtonSave
# 基本的な設定
$expDownloadDir.Header = $script:msg.GuiExpanderDownloadDir
$tbDownloadDirDesc.Text = $script:msg.GuiTextboxDownloadDirDesc
$expWorkDir.Header = $script:msg.GuiExpanderWorkDir
$tbWorkDirDesc.Text = $script:msg.GuiTextboxWorkDirDesc
$expSaveDir.Header = $script:msg.GuiExpanderSaveDir
$tbSaveDirDesc.Text = $script:msg.GuiTextboxSaveDirDesc
# 動作タブ
$tabOperation.Header = $script:msg.GuiTabOperation
$expEnableMultithread.Header = $script:msg.GuiExpanderEnableMultithread
$tbEnableMultithreadDesc.Text = $script:msg.GuiTextboxEnableMultithreadDesc
$expMultithreadNum.Header = $script:msg.GuiExpanderMultithreadNum
$tbMultithreadNumDesc.Text = $script:msg.GuiTextBoxMultithreadNumDesc
$expDisableToast.Header = $script:msg.GuiExpanderDisableToast
$tbDisableToastDesc.Text = $script:msg.GuiTextBoxDisableToastDesc
$expMaxExecLogLines.Header = $script:msg.GuiExpanderMaxExecLogLines
$tbMaxExecLogLinesDesc.Text = $script:msg.GuiTextBoxMaxExecLogLinesDesc
$expHistRetentionPeriod.Header = $script:msg.GuiExpanderHistRetentionPeriod
$tbHistRetentionPeriodDesc.Text = $script:msg.GuiTextBoxHistRetentionPeriodDesc
$expLoopCycle.Header = $script:msg.GuiExpanderLoopCycle
$tbLoopCycleDesc.Text = $script:msg.GuiTextBoxLoopCycleDesc
$expDetailedProgress.Header = $script:msg.GuiExpanderDetailedProgress
$tbDetailedProgressDesc.Text = $script:msg.GuiTextBoxDetailedProgressDesc
$expExtractDescTextToList.Header = $script:msg.GuiExpanderExtractDescTextToList
$tbExtractDescTextToListDesc.Text = $script:msg.GuiTextBoxExtractDescTextToListDesc
$expListGenHistoryCheck.Header = $script:msg.GuiExpanderListGenHistoryCheck
$tbListGenHistoryCheckDesc.Text = $script:msg.GuiTextBoxListGenHistoryCheckDesc
$expCleanupDownloadBaseDir.Header = $script:msg.GuiExpanderCleanupDownloadBaseDir
$tbCleanupDownloadBaseDirDesc.Text = $script:msg.GuiTextBoxCleanupDownloadBaseDirDesc
$expCleanupSaveBaseDir.Header = $script:msg.GuiExpanderCleanupSaveBaseDir
$tbCleanupSaveBaseDir.Text = $script:msg.GuiTextBoxCleanupSaveBaseDirDesc
$expUpdateChannel.Header = $script:msg.GuiExpanderUpdateChannel
$tbUpdateChannel.Text = $script:msg.GuiTextBoxUpdateChannelDesc
# マイページタブ
$tabMypage.Header = $script:msg.GuiTabMypage
$expMyPlatformUID.Header = $script:msg.GuiExpanderMyPlatformUID
$tbMyPlatformUIDDesc.Text = $script:msg.GuiTextBoxMyPlatformUIDDesc
$expMyPlatformToken.Header = $script:msg.GuiExpanderMyPlatformToken
$tbMyPlatformTokenDesc.Text = $script:msg.GuiTextBoxMyPlatformTokenDesc
$expMyMemberSID.Header = $script:msg.GuiExpanderMyMemberSID
$tbMyMemberSIDDesc.Text = $script:msg.GuiTextBoxMyMemberSIDDesc
# ダウンロードタブ
$tabDownload.Header = $script:msg.GuiTabDownload
$expParallelDownloadFileNum.Header = $script:msg.GuiExpanderParallelDownloadFileNum
$tbParallelDownloadFileNumDesc.Text = $script:msg.GuiTextBoxParallelDownloadFileNumDesc
$expParallelDownloadNumPerFile.Header = $script:msg.GuiExpanderParallelDownloadNumPerFile
$tbParallelDownloadNumPerFileDesc.Text = $script:msg.GuiTextBoxParallelDownloadNumPerFileDesc
$expRateLimit.Header = $script:msg.GuiExpanderRateLimit
$tbRateLimitDesc.Text = $script:msg.GuiTextBoxRateLimitDesc
$expTimeoutSec.Header = $script:msg.GuiExpanderTimeoutSec
$tbTimeoutSecDesc.Text = $script:msg.GuiTextBoxTimeoutSecDesc
$expEmbedSubtitle.Header = $script:msg.GuiExpanderEmbedSubtitle
$tbEmbedSubtitleDesc.Text = $script:msg.GuiTextBoxEmbedSubtitleDesc
$expEmbedMetatag.Header = $script:msg.GuiExpanderEmbedMetatag
$tbEmbedMetatagDesc.Text = $script:msg.GuiTextBoxEmbedMetatagDesc
$expSortVideoByMedia.Header = $script:msg.GuiExpanderSortVideoByMedia
$tbSortVideoByMediaDesc.Text = $script:msg.GuiTextBoxSortVideoByMediaDesc
$expForceSingleDownload.Header = $script:msg.GuiExpanderForceSingleDownload
$tbForceSingleDownloadDesc.Text = $script:msg.GuiTextBoxForceSingleDownloadDesc
$expSitemapParseEpisodeOnly.Header = $script:msg.GuiExpanderSitemapParseEpisodeOnly
$tbSitemapParseEpisodeOnlyDesc.Text = $script:msg.GuiTextBoxSitemapParseEpisodeOnlyDesc
$expDownloadWhenEpisodeIdChanged.Header = $script:msg.GuiExpanderDownloadWhenEpisodeIdChanged
$tbDownloadWhenEpisodeIdChangedDesc.Text = $script:msg.GuiTextBoxDownloadWhenEpisodeIdChangedDesc
$expVideoContainerFormat.Header = $script:msg.GuiExpanderVideoContainerFormat
$tbVideoContainerFormatDesc.Text = $script:msg.GuiTextBoxVideoContainerFormatDesc
# 動画ファイル名タブ
$tabVideoFile.Header = $script:msg.GuiTabVideoFile
$expAddSeriesName.Header = $script:msg.GuiExpanderAddSeriesName
$tbAddSeriesNameDesc.Text = $script:msg.GuiTextBoxAddSeriesNameDesc
$expAddSeasonName.Header = $script:msg.GuiExpanderAddSeasonName
$tbAddSeasonNameDesc.Text = $script:msg.GuiTextBoxAddSeasonNameDesc
$expAddBroadcastDate.Header = $script:msg.GuiExpanderAddBroadcastDate
$tbAddBroadcastDateDesc.Text = $script:msg.GuiTextBoxAddBroadcastDateDesc
$expAddEpisodeNumber.Header = $script:msg.GuiExpanderAddEpisodeNumber
$tbAddEpisodeNumberDesc.Text = $script:msg.GuiTextBoxAddEpisodeNumberDesc
$expRemoveSpecialNote.Header = $script:msg.GuiExpanderRemoveSpecialNote
$tbRemoveSpecialNoteDesc.Text = $script:msg.GuiTextBoxRemoveSpecialNoteDesc
$expYtdlNonTVerFileName.Header = $script:msg.GuiExpanderYtdlNonTVerFileName
$tbYtdlNonTVerFileNameDesc.Text = $script:msg.GuiTextBoxYtdlNonTVerFileNameDesc
# Ytdl/ffmpegタブ
$tabYtdlFfmpeg.Header = $script:msg.GuiTabYtdlFfmpeg
$btnFfmpegDecodeOptionClear.Content = $script:msg.GuiButtonFfmpegDecodeOptionClear
$btnFfmpegDecodeOptionQsv.Content = $script:msg.GuiButtonFfmpegDecodeOptionQSV
$btnFfmpegDecodeOptionD3d11.Content = $script:msg.GuiButtonFfmpegDecodeOptionD3D11
$btnFfmpegDecodeOptionD3d9.Content = $script:msg.GuiButtonFfmpegDecodeOptionD3D9
$btnFfmpegDecodeOptionCuda.Content = $script:msg.GuiButtonFfmpegDecodeOptionCuda
$btnFfmpegDecodeOptionVTB.Content = $script:msg.GuiButtonFfmpegDecodeOptionVTB
$btnFfmpegDecodeOptionPi4.Content = $script:msg.GuiButtonFfmpegDecodeOptionPi4
$btnFfmpegDecodeOptionPi3.Content = $script:msg.GuiButtonFfmpegDecodeOptionPi3
$btnYtdlOptionClear.Content = $script:msg.GuiButtonYtdlOptionClear
$btnYtdlOption1080.Content = $script:msg.GuiButtonYtdlOption1080
$btnYtdlOption720.Content = $script:msg.GuiButtonYtdlOption720
$btnYtdlOption480.Content = $script:msg.GuiButtonYtdlOption480
$btnYtdlOption360.Content = $script:msg.GuiButtonYtdlOption360
$expWindowShowStyle.Header = $script:msg.GuiExpanderWindowShowStyle
$tbWindowShowStyleDesc.Text = $script:msg.GuiTextBoxWindowShowStyleDesc
$expPreferredYoutubedl.Header = $script:msg.GuiExpanderPreferredYoutubedl
$tbPreferredYoutubedlDesc.Text = $script:msg.GuiTextBoxPreferredYoutubedlDesc
$expFfmpegDecodeOption.Header = $script:msg.GuiExpanderFfmpegDecodeOption
$tbFfmpegDecodeOptionDesc.Text = $script:msg.GuiTextBoxFfmpegDecodeOptionDesc
$expForceSoftwareDecodeFlag.Header = $script:msg.GuiExpanderForceSoftwareDecodeFlag
$tbForceSoftwareDecodeFlagDesc.Text = $script:msg.GuiTextBoxForceSoftwareDecodeFlagDesc
$expSimplifiedValidation.Header = $script:msg.GuiExpanderSimplifiedValidation
$tbSimplifiedValidationDesc.Text = $script:msg.GuiTextBoxSimplifiedValidationDesc
$expDisableValidation.Header = $script:msg.GuiExpanderDisableValidation
$tbDisableValidationDesc.Text = $script:msg.GuiTextBoxDisableValidationDesc
$expDisableUpdateYoutubedl.Header = $script:msg.GuiExpanderDisableUpdateYoutubedl
$tbDisableUpdateYoutubedlDesc.Text = $script:msg.GuiTextBoxDisableUpdateYoutubedlDesc
$expDisableUpdateFfmpeg.Header = $script:msg.GuiExpanderDisableUpdateFfmpeg
$tbDisableUpdateFfmpegDesc.Text = $script:msg.GuiTextBoxDisableUpdateFfmpegDesc
$expYtdlOption.Header = $script:msg.GuiExpanderYtdlOption
$tbYtdlOptionDesc.Text = $script:msg.GuiTextBoxYtdlOptionDesc
$expYtdlHttpHeader.Header = $script:msg.GuiExpanderYtdlHttpHeader
$tbYtdlHttpHeaderDesc.Text = $script:msg.GuiTextBoxYtdlHttpHeaderDesc
$expYtdlBaseArgs.Header = $script:msg.GuiExpanderYtdlBaseArgs
$tbYtdlBaseArgsDesc.Text = $script:msg.GuiTextBoxYtdlBaseArgsDesc
$expNonTVerYtdlBaseArgs.Header = $script:msg.GuiExpanderNonTVerYtdlBaseArgs
$tbNonTVerYtdlBaseArgsDesc.Text = $script:msg.GuiTextBoxNonTVerYtdlBaseArgsDesc

# スケジュールタブ
$tabSchedule.Header = $script:msg.GuiTabSchedule
$expScheduleStop.Header = $script:msg.GuiExpanderScheduleStop
$tbScheduleStopDesc.Text = $script:msg.GuiTextBoxScheduleStopDesc
$tbScheduleSpecifyDesc.Text = $script:msg.GuiTextBoxScheduleSpecifyDesc
$tbScheduleStopTime.Text = $script:msg.GuiTextBoxScheduleStopTime
$tbScheduleStopWeek.Text = $script:msg.GuiTextBoxScheduleStopWeek
$tbScheduleStopMon.Text = $script:msg.GuiTextBoxScheduleStopMon
$tbScheduleStopTue.Text = $script:msg.GuiTextBoxScheduleStopTue
$tbScheduleStopWed.Text = $script:msg.GuiTextBoxScheduleStopWed
$tbScheduleStopThu.Text = $script:msg.GuiTextBoxScheduleStopThu
$tbScheduleStopFri.Text = $script:msg.GuiTextBoxScheduleStopFri
$tbScheduleStopSat.Text = $script:msg.GuiTextBoxScheduleStopSat
$tbScheduleStopSun.Text = $script:msg.GuiTextBoxScheduleStopSun
$tbScheduleStopDay.Text = $script:msg.GuiTextBoxScheduleStopDay

# ComboBOxのラベルを言語別に設定
$trueFalseOptions = @($script:msg.SettingDefault, $script:msg.SettingTrue, $script:msg.SettingFalse)
foreach ($option in $trueFalseOptions) { $enableMultithread.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $disableToastNotification.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $detailedProgress.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $extractDescTextToList.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $listGenHistoryCheck.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $cleanupDownloadBaseDir.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $cleanupSaveBaseDir.Items.Add($option) }
$updateChannel.Items.Add($script:msg.SettingDefault)
$updateChannel.Items.Add('release')
$updateChannel.Items.Add('prerelease')
$updateChannel.Items.Add('master')
$updateChannel.Items.Add('beta')
$updateChannel.Items.Add('dev')
foreach ($option in $trueFalseOptions) { $embedSubtitle.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $embedMetatag.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $sortVideoByMedia.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $forceSingleDownload.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $sitemapParseEpisodeOnly.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $downloadWhenEpisodeIdChanged.Items.Add($option) }
$videoContainerFormat.Items.Add($script:msg.SettingDefault)
$videoContainerFormat.Items.Add('mp4')
$videoContainerFormat.Items.Add('ts')
foreach ($option in $trueFalseOptions) { $addSeriesName.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $addSeasonName.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $addBroadcastDate.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $addEpisodeNumber.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $removeSpecialNote.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $forceSoftwareDecodeFlag.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $simplifiedValidation.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $disableValidation.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $disableUpdateYoutubedl.Items.Add($option) }
foreach ($option in $trueFalseOptions) { $disableUpdateFfmpeg.Items.Add($option) }
$windowShowStyle.Items.Add($script:msg.SettingDefault)
$windowShowStyle.Items.Add('Minimized')
$windowShowStyle.Items.Add('Hidden')
$windowShowStyle.Items.Add('Normal')
$windowShowStyle.Items.Add('Maximized')
$preferredYoutubedl.Items.Add($script:msg.SettingDefault)
$preferredYoutubedl.Items.Add('yt-dlp')
$preferredYoutubedl.Items.Add('ytdl-patched')
foreach ($option in $trueFalseOptions) { $scheduleStop.Items.Add($option) }


# endregion WPFのWindow設定
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# region ボタンのアクション
$btnWiki.Add_Click({ Start-Process ‘https://github.com/dongaba/TVerRec/wiki’ })
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

function Set-YtdlOption ($height) {
	$ytdlOption.Text = if ($height -eq 'Clear') { '' }
	else { '-f "bestvideo[height<=' + $height + ']+bestaudio/best[height<=' + $height + ']"' }
}
$btnYtdlOptionClear.Add_Click({ Set-YtdlOption 'Clear' })
$btnYtdlOption1080.Add_Click({ Set-YtdlOption 1080 })
$btnYtdlOption720.Add_Click({ Set-YtdlOption 720 })
$btnYtdlOption480.Add_Click({ Set-YtdlOption 480 })
$btnYtdlOption360.Add_Click({ Set-YtdlOption 360 })

function Sync-MultiCheckboxes {
	param (
		[string]$day,
		[string]$hour,
		[object]$allCheckbox
	)
	if ($day) {
		foreach ($hour in $hours) {
			$checkboxName = 'chkbxStop{0}{1:D2}' -f $day, [int]$hour
			(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			if ($allCheckbox.IsChecked -eq $false) {
				$checkboxName = 'chkbxStop{0:D2}{1}' -f [int]$hour, 'All'
				(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			}
		}
	} elseif ($hour) {
		foreach ($day in $days) {
			$checkboxName = 'chkbxStop{0}{1:D2}' -f $day, [int]$hour
			(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			if ($allCheckbox.IsChecked -eq $false) {
				$checkboxName = 'chkbxStop{0}{1}' -f $day, 'All'
				(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			}
		}
	}
}

# 各曜日に対してクリックイベントを登録
$chkbxStopMonAll.Add_Click({ Sync-MultiCheckboxes -day 'Mon' -allCheckbox $chkbxStopMonAll })
$chkbxStopTueAll.Add_Click({ Sync-MultiCheckboxes -day 'Tue' -allCheckbox $chkbxStopTueAll })
$chkbxStopWedAll.Add_Click({ Sync-MultiCheckboxes -day 'Wed' -allCheckbox $chkbxStopWedAll })
$chkbxStopThuAll.Add_Click({ Sync-MultiCheckboxes -day 'Thu' -allCheckbox $chkbxStopThuAll })
$chkbxStopFriAll.Add_Click({ Sync-MultiCheckboxes -day 'Fri' -allCheckbox $chkbxStopFriAll })
$chkbxStopSatAll.Add_Click({ Sync-MultiCheckboxes -day 'Sat' -allCheckbox $chkbxStopSatAll })
$chkbxStopSunAll.Add_Click({ Sync-MultiCheckboxes -day 'Sun' -allCheckbox $chkbxStopSunAll })

# 各時間に対してクリックイベントを登録
$chkbxStop00All.Add_Click({ Sync-MultiCheckboxes -hour '00' -allCheckbox $chkbxStop00All })
$chkbxStop01All.Add_Click({ Sync-MultiCheckboxes -hour '01' -allCheckbox $chkbxStop01All })
$chkbxStop02All.Add_Click({ Sync-MultiCheckboxes -hour '02' -allCheckbox $chkbxStop02All })
$chkbxStop03All.Add_Click({ Sync-MultiCheckboxes -hour '03' -allCheckbox $chkbxStop03All })
$chkbxStop04All.Add_Click({ Sync-MultiCheckboxes -hour '04' -allCheckbox $chkbxStop04All })
$chkbxStop05All.Add_Click({ Sync-MultiCheckboxes -hour '05' -allCheckbox $chkbxStop05All })
$chkbxStop06All.Add_Click({ Sync-MultiCheckboxes -hour '06' -allCheckbox $chkbxStop06All })
$chkbxStop07All.Add_Click({ Sync-MultiCheckboxes -hour '07' -allCheckbox $chkbxStop07All })
$chkbxStop08All.Add_Click({ Sync-MultiCheckboxes -hour '08' -allCheckbox $chkbxStop08All })
$chkbxStop09All.Add_Click({ Sync-MultiCheckboxes -hour '09' -allCheckbox $chkbxStop09All })
$chkbxStop10All.Add_Click({ Sync-MultiCheckboxes -hour '10' -allCheckbox $chkbxStop10All })
$chkbxStop11All.Add_Click({ Sync-MultiCheckboxes -hour '11' -allCheckbox $chkbxStop11All })
$chkbxStop12All.Add_Click({ Sync-MultiCheckboxes -hour '12' -allCheckbox $chkbxStop12All })
$chkbxStop13All.Add_Click({ Sync-MultiCheckboxes -hour '13' -allCheckbox $chkbxStop13All })
$chkbxStop14All.Add_Click({ Sync-MultiCheckboxes -hour '14' -allCheckbox $chkbxStop14All })
$chkbxStop15All.Add_Click({ Sync-MultiCheckboxes -hour '15' -allCheckbox $chkbxStop15All })
$chkbxStop16All.Add_Click({ Sync-MultiCheckboxes -hour '16' -allCheckbox $chkbxStop16All })
$chkbxStop17All.Add_Click({ Sync-MultiCheckboxes -hour '17' -allCheckbox $chkbxStop17All })
$chkbxStop18All.Add_Click({ Sync-MultiCheckboxes -hour '18' -allCheckbox $chkbxStop18All })
$chkbxStop19All.Add_Click({ Sync-MultiCheckboxes -hour '19' -allCheckbox $chkbxStop19All })
$chkbxStop20All.Add_Click({ Sync-MultiCheckboxes -hour '20' -allCheckbox $chkbxStop20All })
$chkbxStop21All.Add_Click({ Sync-MultiCheckboxes -hour '21' -allCheckbox $chkbxStop21All })
$chkbxStop22All.Add_Click({ Sync-MultiCheckboxes -hour '22' -allCheckbox $chkbxStop22All })
$chkbxStop23All.Add_Click({ Sync-MultiCheckboxes -hour '23' -allCheckbox $chkbxStop23All })

# endregion ボタンのアクション
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# region 設定ファイルの読み込み
Read-UserSetting
# endregion 設定ファイルの読み込み
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# ウィンドウ表示

try {
	$settingWindow.Show() | Out-Null
	$settingWindow.Activate() | Out-Null
	[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch { Throw ($script:msg.WindowRenderError) }

# メインウィンドウ取得
$currentProcess = [Diagnostics.Process]::GetCurrentProcess()
$form = [Windows.Forms.NativeWindow]::new()
$form.AssignHandle($currentProcess.MainWindowHandle)

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ウィンドウ表示後のループ処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
# region ウィンドウ表示後のループ処理
while ($settingWindow.IsVisible) {
	# GUIイベント処理
	Sync-WpfEvents
	Start-Sleep -Milliseconds 10
}

# endregion ウィンドウ表示後のループ処理
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 終了処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Remove-Variable -Name mainXaml, mainCleanXaml, settingWindow -ErrorAction SilentlyContinue
Remove-Variable -Name LogoImage, lblVersion -ErrorAction SilentlyContinue
Remove-Variable -Name btnWiki, btnCancel, btnSave -ErrorAction SilentlyContinue
Remove-Variable -Name btndownloadBaseDir, btnDownloadWorkDir, btnSaveBaseDir -ErrorAction SilentlyContinue
Remove-Variable -Name userSettingFile, settingAttributes -ErrorAction SilentlyContinue
Remove-Variable -Name currentProcess, form -ErrorAction SilentlyContinue
