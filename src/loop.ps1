###################################################################################
#
#		ループ処理スクリプト
#
###################################################################################
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
