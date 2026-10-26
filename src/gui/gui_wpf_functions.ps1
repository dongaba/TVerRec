###################################################################################
#
#		GUI(WPF)共通関数スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		gui_main.ps1とgui_setting.ps1で共通のWPF関数を定義します。

	.NOTES
		このファイルはWindowsでのみ使用できます(WPFの型を使用します)。
		gui_main.ps1とgui_setting.ps1から読み込まれます。

	.LINK
		https://github.com/dongaba/TVerRec
#>

using namespace System.Windows.Threading
Set-StrictMode -Version Latest

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
