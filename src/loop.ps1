###################################################################################
#
#		ループ処理スクリプト
#
###################################################################################

try { $script:guiMode = [String]$args[0] } catch { $script:guiMode = '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❗ カレントディレクトリの設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❗ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#----------------------------------------------------------------------
while ($true) {

	. ('{0}/download_bulk.ps1' -f $script:scriptRoot) $script:guiMode
	. ('{0}/delete_trash.ps1' -f $script:scriptRoot) $script:guiMode
	. ('{0}/validate_video.ps1' -f $script:scriptRoot) $script:guiMode
	. ('{0}/move_video.ps1' -f $script:scriptRoot) $script:guiMode
	Invoke-GarbageCollection
	Write-Output ('')
	Write-Output ('{0}秒待機します。' -f $script:loopCycle)
	$remainingWaitTime = $script:loopCycle
	do {
		Start-Sleep -Second 100
		$remainingWaitTime -= 100
		$progressRatio = [Int]($remainingWaitTime / $script:loopCycle * 100 / 2 )
		Write-Output ('[{0}{1}{2}] 残り{3}秒' -f $('=' * $(50 - $progressRatio)), '>', $('-' * $progressRatio), $remainingWaitTime)
		Invoke-GarbageCollection
	} while ($remainingWaitTime -ge 100)
}
#----------------------------------------------------------------------
Invoke-GarbageCollection
