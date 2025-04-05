###################################################################################
#
#		ループ処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのメインループ処理を実行するスクリプト

	.DESCRIPTION
		TVerRecの主要な処理を定期的に実行するループスクリプトです。
		以下の処理を順番に実行します：
		1. 一括ダウンロード処理
		2. ゴミ箱の削除処理
		3. 動画の検証処理
		4. 動画の移動処理
		各処理の間には指定された待機時間が設定されています。

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上を推奨です
		- TVerRecの設定ファイルが正しく設定されている必要があります

		処理の流れ:
		1. 環境設定の読み込み
		2. メインループの開始
		3. 各処理の実行
		4. 待機時間のカウントダウン表示
		5. 次のループへ

	.EXAMPLE
		# 通常モードで実行
		.\loop.ps1

		# GUIモードで実行
		.\loop.ps1 gui

	.OUTPUTS
		System.Void
		各処理の実行結果をコンソールに出力します。
#>

Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1')) 'loop'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
#----------------------------------------------------------------------
while ($true) {
	& ('{0}/download_bulk.ps1' -f $script:scriptRoot) $script:guiMode
	& ('{0}/delete_trash.ps1' -f $script:scriptRoot) $script:guiMode
	& ('{0}/validate_video.ps1' -f $script:scriptRoot) $script:guiMode
	& ('{0}/move_video.ps1' -f $script:scriptRoot) $script:guiMode
	Invoke-GarbageCollection
	Write-Output ('')
	Write-Output ($script:msg.SecWaiting -f $script:loopCycle)
	$remainingWaitTime = $script:loopCycle
	while ($remainingWaitTime -ge 100) {
		Start-Sleep -Second 100
		$remainingWaitTime -= 100
		$progressRatio = [Int]($remainingWaitTime / $script:loopCycle * 100 / 2 )
		Write-Output ($script:msg.SecWaitRemaining -f $('█' * $(50 - $progressRatio)), $('▁' * $progressRatio), $remainingWaitTime)
		Invoke-GarbageCollection
	}
}
#----------------------------------------------------------------------

Remove-Variable -Name args, remainingWaitTime, progressRatio -ErrorAction SilentlyContinue

Invoke-GarbageCollection
