###################################################################################
#
#		GUIメインスクリプト
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

if ($IsWindows -eq $false) { Write-Error ('❗ Windows以外では動作しません') ; Start-Sleep 10 ; exit 1 }
Add-Type -AssemblyName PresentationFramework

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 環境設定

Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ ディレクトリ設定に失敗しました') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#endregion 環境設定

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 関数定義
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#GUIイベントの処理
function DoWpfEvents {
	[DispatcherFrame] $script:frame = [DispatcherFrame]::new($true)
	$null = [Dispatcher]::CurrentDispatcher.BeginInvoke(
		'Background',
		[DispatcherOperationCallback] {
			param([object] $script:f)
			($script:f -as [DispatcherFrame]).Continue = $false
			return $null
		},
		$script:frame)
	[Dispatcher]::PushFrame($script:frame)
}

#テキストボックスへのログ出力と再描画
function AddOutput {
	Param ([String]$script:Message)
	$script:mainWindow.Dispatcher.Invoke([action] { $script:outText.AddText("{0}`n" -f $script:Message) }, 'Render')
	$script:outText.ScrollToEnd()
}

#endregion 関数定義


#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
#region WPFのWindow設定

try {
	[String]$local:mainXaml = Get-Content -Path '../resources/TVerRecMain.xaml'
	$local:mainXaml = $local:mainXaml -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace 'x:Class=".*?"', ''
	[xml]$local:mainCleanXaml = $local:mainXaml
	$script:mainWindow = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $local:mainCleanXaml))
} catch { Write-Error ('❗ ウィンドウデザイン読み込めませんでした。TVerRecが破損しています。') ; exit 1 }

#PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]public static extern IntPtr GetConsoleWindow() ;
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow) ;
'
$local:console = [Console.Window]::GetConsoleWindow()
$null = [Console.Window]::ShowWindow($local:console, 0)

#タスクバーのアイコンにオーバーレイ表示
$local:icon = New-Object System.Windows.Media.Imaging.BitmapImage
$local:icon.BeginInit()
$local:icon.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($script:iconBase64)
$local:icon.EndInit()
$local:icon.Freeze()
$script:mainWindow.TaskbarItemInfo.Overlay = $local:icon
$script:mainWindow.TaskbarItemInfo.Description = $script:mainWindow.Title

#ウィンドウを読み込み時の処理
$script:mainWindow.add_Loaded({
		$script:mainWindow.Icon = $script:iconPath
	})

#ウィンドウを閉じる際の処理
$script:mainWindow.Add_Closing({
		#Windowが閉じられたら乗っているゴミジョブを削除して終了
		Get-Job | Receive-Job -Wait -AutoRemoveJob -Force
	})

#Name属性を持つ要素のオブジェクト作成
$local:mainCleanXaml.SelectNodes('//*[@Name]') | ForEach-Object { Set-Variable -Name ($_.Name) -Value $script:mainWindow.FindName($_.Name) -Scope Local }

#WPFにロゴをロード
$local:logo = New-Object System.Windows.Media.Imaging.BitmapImage
$local:logo.BeginInit()
$local:logo.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($script:logoBase64)
$local:logo.EndInit()
$local:logo.Freeze()
$script:LogoImage.Source = $local:logo

#バージョン表記
$script:lblVersion.Content = ('Version {0}' -f $script:appVersion)

#ログ出力するためのテキストボックス
$script:outText = $script:mainWindow.FindName('tbOutText')

#endregion WPFのWindow設定

#----------------------------------------------------------------------
#region バックグラウンドジョブ化する処理を持つボタン

$script:btns = $script:mainWindow.FindName('btnSingle'), #0
$script:mainWindow.FindName('btnBulk'), #1
$script:mainWindow.FindName('btnListGen'), #2
$script:mainWindow.FindName('btnList'), #3
$script:mainWindow.FindName('btnDelete'), #4
$script:mainWindow.FindName('btnValidate'), #5
$script:mainWindow.FindName('btnMove'), #6
$script:mainWindow.FindName('btnLoop')

#バックグラウンドジョブ化するボタンの処理内容
$script:scriptBlocks = @{
	$script:btns[0] = { . './download_single.ps1' 'GUI' }
	$script:btns[1] = { . './download_bulk.ps1' }
	$script:btns[2] = { . './generate_list.ps1' }
	$script:btns[3] = { . './download_list.ps1' }
	$script:btns[4] = { . './delete_trash.ps1' }
	$script:btns[5] = { . './validate_video.ps1' }
	$script:btns[6] = { . './move_video.ps1' }
	$script:btns[7] = { . './loop.ps1' }
}

#バックグラウンドジョブ化する処理の名前
$script:threadNames = @{
	$script:btns[0] = { 個別ダウンロード処理を実行中 }
	$script:btns[1] = { 一括ダウンロード処理を実行中 }
	$script:btns[2] = { リスト作成処理を実行中 }
	$script:btns[3] = { リストダウンロード処理を実行中 }
	$script:btns[4] = { 不要ファイル削除処理を実行中 }
	$script:btns[5] = { 番組整合性検証処理を実行中 }
	$script:btns[6] = { 番組移動処理を実行中 }
	$script:btns[7] = { ループ処理を実行中 }
}

#バックグラウンドジョブ化するボタンのアクション
foreach ($script:btn in $script:btns) {
	$script:btn.Add_Click({
			#ジョブの稼働中はボタンを無効化
			foreach ($script:btn in $script:btns) { $script:btn.IsEnabled = $false }
			$script:btnExit.IsEnabled = $false
			$script:lblStatus.Content = ([String]$script:threadNames[$this]).Trim()

			#処理停止ボタンの有効化
			$script:btnKillAll.IsEnabled = $true

			#バックグラウンドジョブの起動
			$null = Start-ThreadJob -Name $this.Name $script:scriptBlocks[$this]
			#$null = Start-Job -Name $this.Name $script:scriptBlocks[$this]	#こっちにするとWrite-Debugがコンソールに出る
		})
}

#endregion バックグラウンドジョブ化する処理を持つボタン

#----------------------------------------------------------------------
#region ジョブ化しないボタンのアクション

$script:btnWorkOpen.add_Click({ Invoke-Item $script:downloadWorkDir })
$script:btnDownloadOpen.add_Click({ Invoke-Item $script:downloadBaseDir })
$script:btnSaveOpen.add_Click({
		if ($script:saveBaseDir -ne '') {
			$script:saveBaseDirArray = @()
			$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim()
			foreach ($saveDir in $script:saveBaseDirArray) { Invoke-Item $saveDir.Trim() }
		} else { [System.Windows.MessageBox]::Show('保存ディレクトリが設定されていません') }
	})
$script:btnKeywordOpen.add_Click({ Invoke-Item $script:keywordFilePath })
$script:btnIgnoreOpen.add_Click({ Invoke-Item $script:ignoreFilePath })
$script:btnListOpen.add_Click({ Invoke-Item $script:listFilePath })
$script:btnClearLog.add_Click({
		$script:outText.Clear()
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		[System.GC]::Collect()
	})
$script:btnKillAll.add_Click({
		Get-Job | Remove-Job -Force
		foreach ($btn in $script:btns) { $btn.IsEnabled = $true }
		$script:btnExit.IsEnabled = $true
		$script:btnKillAll.IsEnabled = $false
		$script:lblStatus.Content = '処理を強制停止しました'
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		[System.GC]::Collect()
	})
$script:btnWiki.add_Click({ Start-Process ‘https://github.com/dongaba/TVerRec/wiki’ })
$script:btnSetting.add_Click({
		. 'gui/gui_setting.ps1'
		if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
			. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
		}
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		[System.GC]::Collect()
	})
$script:btnExit.add_Click({ $script:mainWindow.close() })

#endregion ジョブ化しないボタンのアクション

#----------------------------------------------------------------------
#region ウィンドウ表示

#処理停止ボタンの初期値は無効
$btnKillAll.IsEnabled = $false

try {
	$null = $script:mainWindow.Show()
	$null = $script:mainWindow.Activate()
	$null = [Console.Window]::ShowWindow($local:console, 0)
} catch { Write-Error ('❗ ウィンドウを描画できませんでした。TVerRecが破損しています。') ; exit 1 }

#endregion ウィンドウ表示

#----------------------------------------------------------------------
#region ウィンドウ表示後のループ処理
while ($script:mainWindow.IsVisible) {
	#GUIイベント処理
	DoWpfEvents

	if ($null -eq (Get-Job)) {
		#ジョブがない場合はメモリ解放
		[System.GC]::WaitForPendingFinalizers()
		[System.GC]::Collect()
	} else {
		#ジョブがある場合の処理
		foreach ($local:job in Get-Job) {
			# Get the originating button via the job name.
			$script:btn = $script:mainWindow.FindName($local:job.Name)

			#ジョブが終了したかどうか判定
			$local:completed = $local:job.State -in 'Completed', 'Failed', 'Stopped'

			#ジョブからの出力をテキストボックスに出力
			if ($script:data = Receive-Job $local:job *>&1) { AddOutput ($script:data -join "`n") }

			#終了したジョブのボタンの再有効化
			if ($local:completed) {
				Remove-Job $local:job
				foreach ($script:btn in $script:btns) { $script:btn.IsEnabled = $true }
				$script:btnExit.IsEnabled = $true
				$script:btnKillAll.IsEnabled = $false
				$script:lblStatus.Content = '処理を終了しました'
				[System.GC]::Collect()
				[System.GC]::WaitForPendingFinalizers()
				[System.GC]::Collect()
			}
		}
	}

	#GUIイベント処理
	DoWpfEvents

	Start-Sleep -Milliseconds 100
}

#endregion ウィンドウ表示後のループ処理

#----------------------------------------------------------------------
#region 終了処理

#Windowが閉じられたら乗っているゴミジョブを削除して終了
Get-Job | Receive-Job -Wait -AutoRemoveJob -Force

#endregion 終了処理

