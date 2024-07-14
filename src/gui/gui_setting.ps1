###################################################################################
#
#		GUI設定スクリプト
#
###################################################################################
using namespace System.Windows.Threading
Set-StrictMode -Version Latest
if (!$IsWindows) { Throw ('❌️ Windows以外では動作しません') ; Start-Sleep 10 }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 環境設定

try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ ディレクトリ設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
} catch { Throw ('❌️ システム設定ファイルの読み込みに失敗しました') }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/tverrec_functions.ps1'))
} catch { Throw ('❌️ 外部関数ファイルの読み込みに失敗しました') }

#endregion 環境設定

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 関数定義

#GUIイベントの処理
function Sync-WpfEvents {
	[DispatcherFrame] $frame = [DispatcherFrame]::new($true)
	$null = [Dispatcher]::CurrentDispatcher.BeginInvoke(
		'Background',
		[DispatcherOperationCallback] {
			Param([object] $f)
			($f -as [DispatcherFrame]).Continue = $false
			return $null
		},
		$frame)
	[Dispatcher]::PushFrame($frame)
	Remove-Variable -Name frame, f -ErrorAction SilentlyContinue
}

#ディレクトリ選択ダイアログ
function Select-Folder($description, $textBox) {
	$fd = [System.Windows.Forms.FolderBrowserDialog]::new()
	$fd.Description = $description
	$fd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
	$fd.SelectedPath = $textBox.Text
	if ($fd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) { $textBox.Text = $fd.SelectedPath }
	Remove-Variable -Name description, textBox, fd -ErrorAction SilentlyContinue
}

#system_setting.ps1から各設定項目を読み込む
function Read-SystemSetting {
	Param ([Parameter(Mandatory = $true)][String]$key)
	$defaultSetting = try { (Select-String -Pattern ('^{0}' -f $key.Replace('$', '\$')) -LiteralPath $systemSettingFile | ForEach-Object { $_.Line }).split('=', 2)[1].Trim() }
	catch { '' }
	return $defaultSetting.Trim("'")
	Remove-Variable -Name key, defaultSetting -ErrorAction SilentlyContinue
}

#user_setting.ps1から各設定項目を読み込む
function Read-UserSetting {
	Param ([Parameter(Mandatory = $true)][String]$key)
	$currentSetting = ''
	if (Test-Path (Join-Path $script:confDir 'user_setting.ps1')) {
		try { $currentSetting = (Select-String -Pattern ('^{0}' -f [regex]::Escape($key)) -LiteralPath $userSettingFile | ForEach-Object { $_.Line }).split('=', 2)[1].Trim() }
		catch { return }
	}
	return $currentSetting.Trim("'")
	Remove-Variable -Name key, currentSetting -ErrorAction SilentlyContinue
}

#user_setting.ps1に各設定項目を書き込む
function Save-UserSetting {
	$newSetting = @()
	$startSegment = '##Start Setting Generated from GUI'
	$endSegment = '##End Setting Generated from GUI'
	#ファイルが無ければ作ればいい
	if (!(Test-Path $userSettingFile)) {
		$null = New-Item -Path $userSettingFile -ItemType File
		$content = Get-Content -LiteralPath $userSettingFile
		$totalLineNum = 0
	} else {
		$content = Get-Content -LiteralPath $userSettingFile
		#自動生成部分の行数を取得
		$totalLineNum = try { $content.Count + 1 } catch { 0 }
		$headLineNum = try { ($content | Select-String $startSegment).LineNumber - 2 } catch { 0 }
		$tailLineNum = try { $totalLineNum - ($content | Select-String $endSegment).LineNumber - 1 } catch { 0 }
	}
	#自動生成より前の部分
	#自動生成の開始位置が2行目以降の場合にだけ自動生成寄りの前の部分がある
	if (Test-Path variable:headLineNum) { if ($headLineNum -ge 0 ) { $newSetting += $content[0..$headLineNum] } }
	#自動生成の部分
	$newSetting += $startSegment
	if ($settingAttributes) {
		foreach ($settingAttribute in $settingAttributes) {
			$settingBoxName = $settingAttribute.Replace('$script:', '')
			$settingBox = $settingWindow.FindName($settingBoxName)
			switch -wildcard ($settingBox.Text) {
				{ $_ -in '', 'デフォルト値', '未設定' } { continue }
				{ $_ -eq 'する' } { $newSetting += ('{0} = $true' -f $settingAttribute); continue }
				{ $_ -eq 'しない' } { $newSetting += ('{0} = $false' -f $settingAttribute); continue }
				default {
					if ([Int]::TryParse($settingBox.Text, [ref]$null) -or $settingBox.Text -match '[${}]') { $newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text) }
					else { $newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text) }
				}
			}
		}
	}
	$newSetting += $endSegment
	#自動生成より後の部分
	if ( $totalLineNum -ne 0 ) {
		try { $newSetting += Get-Content $userSettingFile -Tail $tailLineNum }
		catch { Write-Warning ('⚠️ 自動生成の終了部分を特定できませんでした') }
	}
	#改行コードLFを強制 + NFCで出力
	$newSetting.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC)  | Out-File -LiteralPath $userSettingFile -Encoding UTF8 -NoNewline
	Remove-Variable -Name newSetting, startSegment, endSegment, content -ErrorAction SilentlyContinue
	Remove-Variable -Name totalLineNum, headLineNum, tailLineNum -ErrorAction SilentlyContinue
	Remove-Variable -Name settingAttribute, settingBoxName, settingBox -ErrorAction SilentlyContinue
}

#endregion 関数定義

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

$systemSettingFile = Join-Path $script:confDir 'system_setting.ps1'
$userSettingFile = Join-Path $script:confDir 'user_setting.ps1'

#----------------------------------------------------------------------
#region WPFのWindow設定

try {
	[String]$mainXaml = Get-Content -LiteralPath (Join-Path $script:xamlDir 'TVerRecSetting.xaml')
	$mainXaml = $mainXaml -ireplace 'mc:Ignorable="d"', '' -ireplace 'x:N', 'N' -ireplace 'x:Class=".*?"', ''
	[xml]$mainCleanXaml = $mainXaml
	$settingWindow = [System.Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]::new($mainCleanXaml)))
} catch { Throw ('❌️ ウィンドウデザイン読み込めませんでした。TVerRecが破損しています。') }
#PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]public static extern IntPtr GetConsoleWindow() ;
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow) ;
'
$null = [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)
#タスクバーのアイコンにオーバーレイ表示
$settingWindow.TaskbarItemInfo.Overlay = ConvertFrom-Base64 $script:iconBase64
$settingWindow.TaskbarItemInfo.Description = $settingWindow.Title
#ウィンドウを読み込み時の処理
$settingWindow.Add_Loaded({ $settingWindow.Icon = $script:iconPath })
#ウィンドウを閉じる際の処理
$settingWindow.Add_Closing({})
#Name属性を持つ要素のオブジェクト作成
$mainCleanXaml.SelectNodes('//*[@Name]') | ForEach-Object { Set-Variable -Name ($_.Name) -Value $settingWindow.FindName($_.Name) -Scope Script }
#WPFにロゴをロード
$LogoImage.Source = ConvertFrom-Base64 $script:logoBase64
#バージョン表記
$lblVersion.Content = ('Version {0}' -f $script:appVersion)

#endregion WPFのWindow設定
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region ボタンのアクション
$btnWiki.Add_Click({ Start-Process ‘https://github.com/dongaba/TVerRec/wiki’ })
$btnCancel.Add_Click({ $settingWindow.close() })
$btnSave.Add_Click({ Save-UserSetting; $settingWindow.close() })
$btndownloadBaseDir.Add_Click({ Select-Folder 'ダウンロード先ディレクトリを選択してください' $script:downloadBaseDir })
$btndownloadWorkDir.Add_Click({ Select-Folder '作業ディレクトリを選択してください' $script:downloadWorkDir })
$btnsaveBaseDir.Add_Click({ Select-Folder '移動先ディレクトリを選択してください' $script:saveBaseDir })

$ffmpegDecodeOption_Clear.Add_Click({ $ffmpegDecodeOption.Text = '' })
$ffmpegDecodeOption_Qsv.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel qsv -c:v h264_qsv' })
$ffmpegDecodeOption_D3d11.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel d3d11va -hwaccel_output_format d3d11' })
$ffmpegDecodeOption_D3d9.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld' })
$ffmpegDecodeOption_Cuda.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel cuda -hwaccel_output_format cuda' })
$ffmpegDecodeOption_Vtb.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel videotoolbox' })
$ffmpegDecodeOption_Pi4.Add_Click({ $ffmpegDecodeOption.Text = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32' })
$ffmpegDecodeOption_Pi3.Add_Click({ $ffmpegDecodeOption.Text = '-c:v h264_omx' })

function Set-YtdlOption ($height) {
	$ytdlOption.Text = if ($height -eq 'Clear') { '' }
	else { '-f "bestvideo[height<=' + $height + ']+bestaudio/best[height<=' + $height + ']"' }
}
$btnYtdlOption_Clear.Add_Click({ Set-YtdlOption 'Clear' })
$btnYtdlOption_1080.Add_Click({ Set-YtdlOption 1080 })
$btnYtdlOption_720.Add_Click({ Set-YtdlOption 720 })
$btnYtdlOption_480.Add_Click({ Set-YtdlOption 480 })
$btnYtdlOption_360.Add_Click({ Set-YtdlOption 360 })

#endregion ボタンのアクション
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region 設定ファイルの読み込み

$settingAttributes = @(
	'$script:downloadBaseDir',
	'$script:downloadWorkDir',
	'$script:saveBaseDir',
	'$script:parallelDownloadFileNum',
	'$script:parallelDownloadNumPerFile',
	'$script:loopCycle',
	'$script:myPlatformUID',
	'$script:myPlatformToken',
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
	'$script:addBrodcastDate',
	'$script:addEpisodeNumber',
	'$script:removeSpecialNote',
	'$script:preferredYoutubedl',
	'$script:disableUpdateYoutubedl',
	'$script:disableUpdateFfmpeg',
	'$script:forceSoftwareDecodeFlag',
	'$script:simplifiedValidation',
	'$script:disableValidation',
	'$script:sitemapParseEpisodeOnly',
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
	'$script:nonTVerYtdlBaseArgs'
)
$defaultSetting = @{}
$currentSetting = @{}
foreach ($settingAttribute in $settingAttributes) {
	$defaultSetting[$settingAttribute] = Read-SystemSetting $settingAttribute
	$currentSetting[$settingAttribute] = Read-UserSetting $settingAttribute
	#変数名から「$script:」を取った名前がBox名
	$settingBoxName = $settingAttribute.Replace('$script:', '')
	#まずはシステム設定の値をGUIに反映
	$settingBox = $settingWindow.FindName($settingBoxName)
	#次にユーザー設定の値をGUIに反映
	if ( (Read-UserSetting $settingAttribute) ) {
		$settingBox.Text = Read-UserSetting $settingAttribute
		if ($settingBox.Text -eq '$true') { $settingBox.Text = 'する' }
		if ($settingBox.Text -eq '$false') { $settingBox.Text = 'しない' }
	}elseif($settingAttribute -in @('downloadBaseDir', 'downloadWorkDir', 'saveBaseDir')) { $settingBox.Text = '未設定' }
	else { $settingBox.Text = 'デフォルト値' }
}

#endregion 設定ファイルの読み込み
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#ウィンドウ表示

try {
	$null = $settingWindow.Show()
	$null = $settingWindow.Activate()
	$null = [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)
} catch { Throw ('❌️ ウィンドウを描画できませんでした。TVerRecが破損しています。') }

#メインウィンドウ取得
$currentProcess = [Diagnostics.Process]::GetCurrentProcess()
$form = [Windows.Forms.NativeWindow]::new()
$form.AssignHandle($currentProcess.MainWindowHandle)

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#ウィンドウ表示後のループ処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
#region ウィンドウ表示後のループ処理
while ($settingWindow.IsVisible) {
	#GUIイベント処理
	Sync-WpfEvents
	Start-Sleep -Milliseconds 100
}

#endregion ウィンドウ表示後のループ処理
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#終了処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Remove-Variable -Name systemSettingFile, userSettingFile -ErrorAction SilentlyContinue
Remove-Variable -Name mainXaml, mainCleanXaml, settingWindow -ErrorAction SilentlyContinue
Remove-Variable -Name LogoImage, lblVersion -ErrorAction SilentlyContinue
Remove-Variable -Name btnWiki, btnCancel, btnSave -ErrorAction SilentlyContinue
Remove-Variable -Name btndownloadBaseDir, btndownloadWorkDir, btnsaveBaseDir -ErrorAction SilentlyContinue
Remove-Variable -Name settingAttributes, defaultSetting, currentSetting -ErrorAction SilentlyContinue
Remove-Variable -Name settingAttribute, settingBoxName, settingBox -ErrorAction SilentlyContinue
Remove-Variable -Name currentProcess, form -ErrorAction SilentlyContinue
