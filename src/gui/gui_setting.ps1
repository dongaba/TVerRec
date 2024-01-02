###################################################################################
#
#		GUI設定スクリプト
#
###################################################################################
using namespace System.Windows.Threading

if (!$IsWindows) { Write-Error ('❗ Windows以外では動作しません') ; Start-Sleep 10 ; exit 1 }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 環境設定

Set-StrictMode -Version Latest
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
} catch { Write-Error ('❗ ディレクトリ設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❗ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
} catch { Write-Error ('❗ システム設定ファイルの読み込みに失敗しました') ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/tverrec_functions.ps1'))
} catch { Write-Error ('❗ 外部関数ファイルの読み込みに失敗しました') ; exit 1 }

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
}

#ディレクトリ選択ダイアログ
function Select-Folder($description, $textBox) {
	$fd.Description = $description
	$fd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
	$fd.SelectedPath = $textBox.Text

	if ($fd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
		$textBox.Text = $fd.SelectedPath
	}
}

#system_setting.ps1から各設定項目を読み込む
function Read-SystemSetting {
	Param (
		[Parameter(Mandatory = $true)][String]$key
	)
	try { $defaultSetting = (Select-String -Pattern ('^{0}' -f $key.Replace('$', '\$')) -LiteralPath $systemSettingFile | ForEach-Object { $_.Line }).split('=')[1].Trim() }
	catch { $defaultSetting = '' }

	return $defaultSetting.Trim("'")
}

#user_setting.ps1から各設定項目を読み込む
function Read-UserSetting {
	Param (
		[Parameter(Mandatory = $true)][String]$key
	)
	try { $currentSetting = (Select-String -Pattern ('^{0}' -f $key.Replace('$', '\$')) -LiteralPath $userSettingFile | ForEach-Object { $_.Line }).split('=', 2)[1].Trim() }
	catch { $currentSetting = '' }

	return $currentSetting.Trim("'")
}

#user_setting.ps1に各設定項目を書き込む
function Save-UserSetting {

	$newSetting = @()
	$startSegment = '##Start Setting Generated from GUI'
	$endSegment = '##End Setting Generated from GUI'

	#自動生成部分の行数を取得
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		$content = Get-Content -LiteralPath $userSettingFile
		try { $totalLineNum = $content.Count + 1 } catch { $totalLineNum = 0 }
		try { $headLineNum = ($content | Select-String $startSegment | ForEach-Object { $_.LineNumber }) - 2 } catch { $headLineNum = 0 }
		try { $tailLineNum = $totalLineNum - ($content | Select-String $endSegment  | ForEach-Object { $_.LineNumber }) - 1 } catch { $tailLineNum = 0 }
	} else { $totalLineNum = 0 ; $headLineNum = 0 ; $tailLineNum = 0 }

	#自動生成より前の部分
	$newSetting += $content[0..$headLineNum]

	#自動生成の部分
	$newSetting += $startSegment
	if ($null -ne $settingAttributes) {
		foreach ($settingAttribute in $settingAttributes) {
			$settingBoxName = $settingAttribute.Replace('$script:', '')
			$settingBox = $settingWindow.FindName($settingBoxName)

			switch ($true) {
				#出力しない
				($settingBox.Text -in @('', 'デフォルト値', '未設定')) { continue }
				#True/False
				($settingBox.Text -eq 'する') { $newSetting += ('{0} = {1}' -f $settingAttribute, '$true') ; continue }
				($settingBox.Text -eq 'しない') { $newSetting += ('{0} = {1}' -f $settingAttribute, '$false') ; continue }
				#数値
				( [Int]::TryParse($settingBox.Text, [ref]$null) ) { $newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text) ; continue }
				#Powershellの変数や関数等を含む場合はシングルクォーテーション不要
				($local:settingBox.Text.Contains('$') `
					-or $local:settingBox.Text.Contains('{') `
					-or $local:settingBox.Text.Contains('(') `
					-or $local:settingBox.Text.Contains('}') `
					-or $local:settingBox.Text.Contains(')') ) {
					$newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text) ; continue
				}
				#デフォルトはシングルクォーテーション必要
				default { $newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text) ; continue }
			}
		}
	}
	$newSetting += $endSegment

	#自動生成より後の部分
	if ( $totalLineNum -ne 0 ) {
		try { $newSetting += Get-Content $userSettingFile -Tail $tailLineNum }
		catch { Write-Warning ('❗ 自動生成の終了部分を特定できませんでした') }
	}

	#改行コードLFを強制 + NFCで出力
	$newSetting.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC)  | Out-File -LiteralPath $userSettingFile -Encoding UTF8 -NoNewline
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
	$settingWindow = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $mainCleanXaml))
} catch { Write-Error ('❗ ウィンドウデザイン読み込めませんでした。TVerRecが破損しています。') ; exit 1 }

#PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]public static extern IntPtr GetConsoleWindow() ;
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow) ;
'
$console = [Console.Window]::GetConsoleWindow()
$null = [Console.Window]::ShowWindow($console, 0)

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
$btnSave.Add_Click({
		Save-UserSetting
		$settingWindow.close()
	})
$btndownloadBaseDir.Add_Click({
		Select-Folder 'ダウンロード先ディレクトリを選択してください' $script:downloadBaseDir
	})

$btndownloadWorkDir.Add_Click({
		Select-Folder '作業ディレクトリを選択してください' $script:downloadWorkDir
	})

$btnsaveBaseDir.Add_Click({
		Select-Folder '移動先ディレクトリを選択してください' $script:saveBaseDir
	})

#endregion ボタンのアクション
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region 設定ファイルの読み込み

$settingAttributes = @()
$settingAttributes += '$script:downloadBaseDir'
$settingAttributes += '$script:downloadWorkDir'
$settingAttributes += '$script:saveBaseDir'
$settingAttributes += '$script:parallelDownloadFileNum'
$settingAttributes += '$script:parallelDownloadNumPerFile'
$settingAttributes += '$script:loopCycle'
$settingAttributes += '$script:enableMultithread'
$settingAttributes += '$script:multithreadNum'
$settingAttributes += '$script:disableToastNotification'
$settingAttributes += '$script:rateLimit'
$settingAttributes += '$script:timeoutSec'
$settingAttributes += '$script:histRetentionPeriod'
$settingAttributes += '$script:sortVideoByMedia'
$settingAttributes += '$script:addSeriesName'
$settingAttributes += '$script:addSeasonName'
$settingAttributes += '$script:addBrodcastDate'
$settingAttributes += '$script:addEpisodeNumber'
$settingAttributes += '$script:removeSpecialNote'
$settingAttributes += '$script:preferredYoutubedl'
$settingAttributes += '$script:disableUpdateYoutubedl'
$settingAttributes += '$script:disableUpdateFfmpeg'
$settingAttributes += '$script:forceSoftwareDecodeFlag'
$settingAttributes += '$script:simplifiedValidation'
$settingAttributes += '$script:disableValidation'
$settingAttributes += '$script:sitemapParseEpisodeOnly'
$settingAttributes += '$script:embedSubtitle'
$settingAttributes += '$script:embedMetatag'
$settingAttributes += '$script:windowShowStyle'
$settingAttributes += '$script:ffmpegDecodeOption'
$settingAttributes += '$script:ytdlOption'
$settingAttributes += '$script:ytdlNonTVerFileName'
$settingAttributes += '$script:forceSingleDownload'
$settingAttributes += '$script:extractDescTextToList'

$defaultSetting = @{}
$currentSetting = @{}

foreach ($settingAttribute in $settingAttributes) {
	$defaultSetting[$settingAttribute] = Read-SystemSetting $settingAttribute
	$currentSetting[$settingAttribute] = Read-UserSetting $settingAttribute
	$settingBoxName = $settingAttribute.Replace('$script:', '')
	$settingBox = $settingWindow.FindName($settingBoxName)
	if ( (Read-UserSetting $settingAttribute) -ne '') {
		$settingBox.Text = Read-UserSetting $settingAttribute
		if ($settingBox.Text -eq '$true') { $settingBox.Text = 'する' }
		if ($settingBox.Text -eq '$false') { $settingBox.Text = 'しない' }
	}
}

#endregion 設定ファイルの読み込み
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#ウィンドウ表示

try {
	$null = $settingWindow.Show()
	$null = $settingWindow.Activate()
	$null = [Console.Window]::ShowWindow($console, 0)
} catch { Write-Error ('❗ ウィンドウを描画できませんでした。TVerRecが破損しています。') ; exit 1 }

#メインウィンドウ取得
$process = [Diagnostics.Process]::GetCurrentProcess()
$form = New-Object Windows.Forms.NativeWindow
$form.AssignHandle($process.MainWindowHandle)
$fd = New-Object System.Windows.Forms.FolderBrowserDialog

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#ウィンドウ表示後のループ処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
#region ウィンドウ表示後のループ処理
while ($settingWindow.IsVisible) {
	#GUIイベント処理
	Sync-WpfEvents

	Start-Sleep -Milliseconds 10
}

#endregion ウィンドウ表示後のループ処理
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#終了処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

