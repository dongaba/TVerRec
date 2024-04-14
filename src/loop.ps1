###################################################################################
#
#		ループ処理スクリプト
#
###################################################################################

$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❌️ カレントディレクトリの設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❌️ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1')) 'loop'
	if (!$?) { Write-Error ('❌️ TVerRecの初期化処理に失敗しました') ; exit 1 }
} catch { Write-Error ('❌️ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#----------------------------------------------------------------------
while ($true) {

	& ('{0}/download_bulk.ps1' -f $script:scriptRoot) $script:guiMode
	& ('{0}/delete_trash.ps1' -f $script:scriptRoot) $script:guiMode
	& ('{0}/validate_video.ps1' -f $script:scriptRoot) $script:guiMode
	& ('{0}/move_video.ps1' -f $script:scriptRoot) $script:guiMode

	Invoke-GarbageCollection

	Write-Output ('')
	Write-Output ('{0}秒待機します。' -f $script:loopCycle)

	$remainingWaitTime = $script:loopCycle
	do {
		Start-Sleep -Second 100
		$remainingWaitTime -= 100
		$progressRatio = [Int]($remainingWaitTime / $script:loopCycle * 100 / 2 )
		Write-Output ('{0}{1} 残り{2}秒' -f $('█' * $(50 - $progressRatio)), $('▁' * $progressRatio), $remainingWaitTime)
		Invoke-GarbageCollection
	} while ($remainingWaitTime -ge 100)

	Remove-Variable -Name remainingWaitTime, progressRatio -ErrorAction SilentlyContinue

}
#----------------------------------------------------------------------

Invoke-GarbageCollection
