###################################################################################
#
#		GUI設定スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the MIT License;
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in
#	all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#	THE SOFTWARE.
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
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ ディレクトリ設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❗ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
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
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#GUIイベントの処理
function Sync-WpfEvents {
	[DispatcherFrame] $script:frame = [DispatcherFrame]::new($true)
	$null = [Dispatcher]::CurrentDispatcher.BeginInvoke(
		'Background',
		[DispatcherOperationCallback] {
			Param([object] $script:f)
			($script:f -as [DispatcherFrame]).Continue = $false
			return $null
		},
		$script:frame)
	[Dispatcher]::PushFrame($script:frame)
}

#フォルダ選択ダイアログ
function Select-Folder($description, $textBox) {
	$script:fd.Description = $description
	$script:fd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
	$script:fd.SelectedPath = $textBox.Text

	if ($script:fd.ShowDialog($script:form) -eq [System.Windows.Forms.DialogResult]::OK) {
		$textBox.Text = $script:fd.SelectedPath
	}
}

#system_setting.ps1から各設定項目を読み込む
function Read-SystemSetting {
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$key
	)
	try { $defaultSetting = (Select-String -Pattern ('^{0}' -f $key.Replace('$', '\$')) -LiteralPath $script:systemSettingFile | ForEach-Object { $_.Line }).split('=')[1].Trim() }
	catch { $defaultSetting = '' }

	return $defaultSetting.Trim("'")
}

#user_setting.ps1から各設定項目を読み込む
function Read-UserSetting {
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$key
	)
	try { $currentSetting = (Select-String -Pattern ('^{0}' -f $key.Replace('$', '\$')) -LiteralPath $script:userSettingFile | ForEach-Object { $_.Line }).split('=', 2)[1].Trim() }
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
		try {
			$totalLineNum = (Get-Content -LiteralPath $script:userSettingFile).Count
		} catch { $totalLineNum = 0 }
		try {
			$headLineNum = (Select-String $startSegment $script:userSettingFile | ForEach-Object { $_.LineNumber }) - 1
		} catch { $headLineNum = 0 }
		try {
			$tailLineNum = $totalLineNum - (Select-String $endSegment $script:userSettingFile | ForEach-Object { $_.LineNumber })
		} catch { $tailLineNum = 0 }
	} else { $totalLineNum = 0 ; $headLineNum = 0 ; $tailLineNum = 0 }

	#自動生成より前の部分
	if ( $totalLineNum -ne 0 ) {
		try { $newSetting += Get-Content $userSettingFile -Head $headLineNum }
		catch { Write-Warning ('❗ 自動生成の開始部分を特定できませんでした') }
	}

	#自動生成の部分
	$newSetting += $startSegment
	if ($null -ne $script:settingAttributes) {
		foreach ($settingAttribute in $script:settingAttributes) {
			$settingBoxName = $settingAttribute.Replace('$script:', '')
			$settingBox = $script:settingWindow.FindName($settingBoxName)

			switch ($true) {
				(($settingBox.Text -eq '') `
					-or ($settingBox.Text -eq 'デフォルト値') `
					-or ($settingBox.Text -eq '未設定')) {
					#設定していないときは出力しない
					break
				}
				($settingBox.Text -eq 'する') {
					#するを$trueに置換
					$newSetting += ('{0} = {1}' -f $settingAttribute, '$true') ; break
				}
				($settingBox.Text -eq 'しない') {
					#しないを$falseに置換
					$newSetting += ('{0} = {1}' -f $settingAttribute, '$false') ; break
				}
				( [Int]::TryParse($settingBox.Text, [ref]$null) ) {
					#数字はシングルクォーテーション不要
					$newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text) ; break
				}
				($settingBox.Text -cmatch '^[a-zA-Z]:') {
					#ドライブ文字列で開始する場合はシングルクォーテーション必要
					$newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text)
					break
				}
				($settingBox.Text -cmatch '^\\\\') {
					#UNCパスの場合はシングルクォーテーション必要
					$newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text)
					break
				}
				($settingBox.Text.Contains('$') `
					-or $settingBox.Text.Contains('{') `
					-or $settingBox.Text.Contains('(') `
					-or $settingBox.Text.Contains('}') `
					-or $settingBox.Text.Contains(')') ) {
					#Powershellの変数や関数等を含む場合はシングルクォーテーション不要
					$newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text)
					break
				}
				default {
					#それ以外はシングルクォーテーション必要
					$newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text)
					break
				}
			}
		}
	}
	$newSetting += $endSegment

	#自動生成より後の部分
	if ( $totalLineNum -ne 0 ) {
		try { $newSetting += Get-Content $script:userSettingFile -Tail $tailLineNum }
		catch { Write-Warning ('❗ 自動生成の終了部分を特定できませんでした') }
	}

	#改行コードをLFで出力
	$newSetting | ForEach-Object { ("{0}`n" -f $_) } | Out-File -LiteralPath $script:userSettingFile -Encoding UTF8 -NoNewline

}

#endregion 関数定義
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$script:systemSettingFile = Join-Path $script:confDir 'system_setting.ps1'
$script:userSettingFile = Join-Path $script:confDir 'user_setting.ps1'

#----------------------------------------------------------------------
#region WPFのWindow設定

try {
	[String]$mainXaml = Get-Content -LiteralPath (Join-Path $script:wpfDir 'TVerRecSetting.xaml')
	$mainXaml = $mainXaml -ireplace 'mc:Ignorable="d"', '' -ireplace 'x:N', 'N' -ireplace 'x:Class=".*?"', ''
	[xml]$mainCleanXaml = $mainXaml
	$script:settingWindow = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $mainCleanXaml))
} catch { Write-Error ('❗ ウィンドウデザイン読み込めませんでした。TVerRecが破損しています。') ; exit 1 }

#PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]public static extern IntPtr GetConsoleWindow() ;
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow) ;
'
$console = [Console.Window]::GetConsoleWindow()
$null = [Console.Window]::ShowWindow($console, 0)

#タスクバーのアイコンにオーバーレイ表示
$script:settingWindow.TaskbarItemInfo.Overlay = ConvertFrom-Base64 $script:iconBase64
$script:settingWindow.TaskbarItemInfo.Description = $script:settingWindow.Title

#ウィンドウを読み込み時の処理
$script:settingWindow.Add_Loaded({ $script:settingWindow.Icon = $script:iconPath })

#ウィンドウを閉じる際の処理
$script:settingWindow.Add_Closing({})

#Name属性を持つ要素のオブジェクト作成
$mainCleanXaml.SelectNodes('//*[@Name]') | ForEach-Object { Set-Variable -Name ($_.Name) -Value $script:settingWindow.FindName($_.Name) -Scope Script }

#WPFにロゴをロード
$script:LogoImage.Source = ConvertFrom-Base64 $script:logoBase64

#バージョン表記
$script:lblVersion.Content = ('Version {0}' -f $script:appVersion)

#endregion WPFのWindow設定
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region ボタンのアクション
$script:btnWiki.Add_Click({ Start-Process ‘https://github.com/dongaba/TVerRec/wiki’ })
$script:btnCancel.Add_Click({ $script:settingWindow.close() })
$script:btnSave.Add_Click({
		Save-UserSetting
		$script:settingWindow.close()
	})
$script:btndownloadBaseDir.Add_Click({
		Select-Folder 'ダウンロード先ディレクトリを選択してください' $script:downloadBaseDir
	})

$script:btndownloadWorkDir.Add_Click({
		Select-Folder '作業ディレクトリを選択してください' $script:downloadWorkDir
	})

$script:btnsaveBaseDir.Add_Click({
		Select-Folder '移動先ディレクトリを選択してください' $script:saveBaseDir
	})

#endregion ボタンのアクション
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#region 設定ファイルの読み込み

$script:settingAttributes = @()
$script:settingAttributes += '$script:downloadBaseDir'
$script:settingAttributes += '$script:downloadWorkDir'
$script:settingAttributes += '$script:saveBaseDir'
$script:settingAttributes += '$script:parallelDownloadFileNum'
$script:settingAttributes += '$script:parallelDownloadNumPerFile'
$script:settingAttributes += '$script:loopCycle'
$script:settingAttributes += '$script:enableMultithread'
$script:settingAttributes += '$script:multithreadNum'
$script:settingAttributes += '$script:disableToastNotification'
$script:settingAttributes += '$script:rateLimit'
$script:settingAttributes += '$script:timeoutSec'
$script:settingAttributes += '$script:histRetentionPeriod'
$script:settingAttributes += '$script:sortVideoByMedia'
$script:settingAttributes += '$script:addSeriesName'
$script:settingAttributes += '$script:addSeasonName'
$script:settingAttributes += '$script:addBrodcastDate'
$script:settingAttributes += '$script:addEpisodeNumber'
$script:settingAttributes += '$script:removeSpecialNote'
$script:settingAttributes += '$script:preferredYoutubedl'
$script:settingAttributes += '$script:disableUpdateYoutubedl'
$script:settingAttributes += '$script:disableUpdateFfmpeg'
$script:settingAttributes += '$script:forceSoftwareDecodeFlag'
$script:settingAttributes += '$script:simplifiedValidation'
$script:settingAttributes += '$script:disableValidation'
$script:settingAttributes += '$script:sitemapParseEpisodeOnly'
$script:settingAttributes += '$script:embedSubtitle'
$script:settingAttributes += '$script:embedMetatag'
$script:settingAttributes += '$script:windowShowStyle'
$script:settingAttributes += '$script:ffmpegDecodeOption'
$script:settingAttributes += '$script:ytdlOption'
$script:settingAttributes += '$script:forceSingleDownload'

$defaultSetting = @{}
$currentSetting = @{}

foreach ($settingAttribute in $script:settingAttributes) {
	$defaultSetting[$settingAttribute] = Read-SystemSetting $settingAttribute
	$currentSetting[$settingAttribute] = Read-UserSetting $settingAttribute
	$settingBoxName = $settingAttribute.Replace('$script:', '')
	$settingBox = $script:settingWindow.FindName($settingBoxName)
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
	$null = $script:settingWindow.Show()
	$null = $script:settingWindow.Activate()
	$null = [Console.Window]::ShowWindow($console, 0)
} catch { Write-Error ('❗ ウィンドウを描画できませんでした。TVerRecが破損しています。') ; exit 1 }

# メインウィンドウ取得
$script:process = [Diagnostics.Process]::GetCurrentProcess()
$script:form = New-Object Windows.Forms.NativeWindow
$script:form.AssignHandle($script:process.MainWindowHandle)
$script:fd = New-Object System.Windows.Forms.FolderBrowserDialog

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#ウィンドウ表示後のループ処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
#region ウィンドウ表示後のループ処理
while ($script:settingWindow.IsVisible) {
	#GUIイベント処理
	Sync-WpfEvents

	Start-Sleep -Milliseconds 10
}

#endregion ウィンドウ表示後のループ処理
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#終了処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

