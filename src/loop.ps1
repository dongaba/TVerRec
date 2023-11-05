###################################################################################
#
#		ループ処理スクリプト
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

try { $script:uiMode = [String]$args[0] } catch { $script:uiMode = '' }

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
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ カレントディレクトリの設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❗ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
#----------------------------------------------------------------------
while ($true) {

	. ('{0}/download_bulk.ps1' -f $script:scriptRoot) $script:uiMode
	. ('{0}/delete_trash.ps1' -f $script:scriptRoot) $script:uiMode
	. ('{0}/validate_video.ps1' -f $script:scriptRoot) $script:uiMode
	. ('{0}/move_video.ps1' -f $script:scriptRoot) $script:uiMode
	invokeGarbageCollection
	Write-Output ('')
	Write-Output ('{0}秒待機します。' -f $script:loopCycle)
	$local:remainingWaitTime = $script:loopCycle
	do {
		$local:progressRatio = [Int]($local:remainingWaitTime / $script:loopCycle * 100 / 2 )
		Write-Output ('[{0}{1}] 残り{2}秒' -f $('#' * $(50 - $local:progressRatio)), $('.' * $local:progressRatio), $local:remainingWaitTime)
		$local:remainingWaitTime -= 100
		Start-Sleep -Second 100
	} while ($local:remainingWaitTime -ge 0)
	invokeGarbageCollection
}
#----------------------------------------------------------------------
invokeGarbageCollection
