###################################################################################
#
#		不要ファイル削除処理スクリプト
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition  }
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ カレントディレクトリの設定に失敗しました') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#======================================================================
#1/3 ダウンロードが中断した際にできたゴミファイルは削除
Write-Output ('----------------------------------------------------------------------')
Write-Output ('処理が中断した際にできたゴミファイルを削除します')
Write-Output ('----------------------------------------------------------------------')
showProgressToast `
	-Text1 '不要ファイル削除中' `
	-Text2 '　処理1/3 - ダウンロード中断時のゴミファイルを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

updateProgressToast `
	-Title $script:downloadWorkDir `
	-Rate ( 1 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#半日以上前のログファイル・ロックファイルを削除
$script:ffmpegErrorLogDir = Convert-Path (Split-Path -Parent -Path $script:ffpmegErrorLogPath)
deleteFiles `
	-Path $script:ffmpegErrorLogDir `
	-Conditions 'ffmpeg_error_*.log' `
	-DaysPassed -0.5
deleteFiles `
	-Path $scriptRoot `
	-Conditions 'brightcovenew_*.lock' `
	-DaysPassed -0.5

#7日以上前の無視リストのバックアップを削除
deleteFiles `
	-Path $script:confDir `
	-Conditions 'ignore.conf.*' `
	-DaysPassed -7

updateProgressToast `
	-Title $script:downloadWorkDir `
	-Rate ( 2 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#作業ディレクトリ
deleteFiles `
	-Path $script:downloadWorkDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*, *.mp4' `
	-DaysPassed 0

updateProgressToast `
	-Title $script:downloadBaseDir `
	-Rate ( 3 / 4 ) `
	-LeftText '' `
	-RightText '' `
	-Tag $script:appName `
	-Group 'Delete'

#ダウンロード先
deleteFiles `
	-Path $script:downloadBaseDir `
	-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*' `
	-DaysPassed 0

#移動先
if ($script:saveBaseDir -ne '') {
	foreach ($local:saveDir in $script:saveBaseDirArray) {
		updateProgressToast `
			-Title $local:saveDir `
			-Rate ( 4 / 4 ) `
			-LeftText '' `
			-RightText '' `
			-Tag $script:appName `
			-Group 'Delete'
		deleteFiles `
			-Path $local:saveDir `
			-Conditions '*.ytdl, *.jpg, *.vtt, *.temp.mp4, *.part, *.mp4.part-Frag*' `
			-DaysPassed 0
	}
}

#======================================================================
#2/3 ダウンロード対象外に入っている番組は削除
Write-Output ('----------------------------------------------------------------------')
Write-Output ('ダウンロード対象外の番組を削除します')
Write-Output ('----------------------------------------------------------------------')
showProgressToast `
	-Text1 '不要ファイル削除中' `
	-Text2 '　処理2/3 - ダウンロード対象外の番組を削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

#ダウンロード対象外番組の読み込み
if (Test-Path $script:ignoreFilePath -PathType Leaf) {
	try {
		while ((fileLock $script:ignoreLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$local:ignoreTitles = @((Get-Content -LiteralPath $script:ignoreFilePath -Encoding UTF8).Where({ $_ -notmatch '^\s*$' }).Where({ $_ -notmatch '^;.*$' }))
	} catch { Write-Error ('❗ ダウンロード対象外の読み込みに失敗しました') ; exit 1 }
	finally { $null = fileUnlock $script:ignoreLockFilePath }
} else { $local:ignoreTitles = $null }

#作業ディレクトリの一覧
$workDirEntities = @(Get-ChildItem -LiteralPath $script:downloadBaseDir -Name)

#ダウンロード対象外番組と作業ディレクトリの一致を抽出
$local:ignoreDirs = @(Compare-Object -IncludeEqual -ExcludeDifferent $local:ignoreTitles $workDirEntities)

#----------------------------------------------------------------------
if ($local:ignoreDirs.Count -ne 0) {
	if ($script:enableMultithread -eq $true) {
		#並列化が有効の場合は並列化
		$local:ignoreDirs.InputObject | ForEach-Object -Parallel {
			$local:ignoreNum = ([Array]::IndexOf($using:local:ignoreDirs, $_)) + 1
			$local:ignoreTotal = $using:local:ignoreDirs.Count
			Write-Output ('{0}/{1} - {2}' -f $local:ignoreNum, $local:ignoreTotal, $_)
			try {
				$local:delPath = Join-Path $using:script:downloadBaseDir $_
				Write-Output ('💡 {0}/{1} - {2}を削除します' -f $local:ignoreNum, $local:ignoreTotal, $local:delPath)
				Remove-Item -LiteralPath $local:delPath -Recurse -Force
			} catch { Write-Warning ('❗ 削除できないファイルがありました') }
		} -ThrottleLimit $script:multithreadNum
	} else {
		#並列化が無効の場合は従来型処理
		#ダウンロード対象外内のエントリ合計数
		$local:ignoreNum = 0
		$local:ignoreTotal = $local:ignoreDirs.Count
		$local:totalStartTime = Get-Date
		foreach ($local:ignoreDir in $local:ignoreDirs.InputObject) {
			$local:ignoreNum += 1
			#処理時間の推計
			$local:secElapsed = (Get-Date) - $local:totalStartTime
			$local:secRemaining = -1
			if ($local:ignoreNum -ne 1) {
				$local:secRemaining = [Int][Math]::Ceiling(($local:secElapsed.TotalSeconds / $local:ignoreNum) * ($local:ignoreTotal - $local:ignoreNum))
				$local:minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($local:secRemaining / 60)))
				$local:progressRate = [Float]($local:ignoreNum / $local:ignoreTotal)
			} else {
				$local:minRemaining = ''
				$local:progressRate = 0
			}
			UpdateProgressToast `
				-Title $local:ignoreDir `
				-Rate $local:progressRate `
				-LeftText ('{0}/{1}' -f $local:ignoreNum, $local:ignoreTotal) `
				-RightText ('残り時間 {0}' -f $local:minRemaining) `
				-Tag $script:appName `
				-Group 'Delete'
			Write-Output ('{0}/{1} - {2}' -f $local:ignoreNum, $local:ignoreTotal, $local:ignoreDir)
			try {
				$local:delPath = Join-Path $script:downloadBaseDir $local:ignoreDir
				Write-Output ('💡 {0}/{1} - {2}を削除します' -f $local:ignoreNum, $local:ignoreTotal, $local:delPath)
				Remove-Item -Path $local:delPath -Recurse -Force
			} catch { Write-Warning ('❗ 削除できないファイルがありました') }
		}
	}
}

#----------------------------------------------------------------------

#======================================================================
#3/3 空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Write-Output ('----------------------------------------------------------------------')
Write-Output ('空ディレクトリを削除します')
Write-Output ('----------------------------------------------------------------------')
showProgressToast `
	-Text1 '不要ファイル削除中' `
	-Text2 '　処理3/3 - 空ディレクトリを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Delete' `
	-Duration 'long' `
	-Silent $false

$local:emptyDirs = @()
try { $local:emptyDirs = @(((Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse).where({ $_.PSIsContainer -eq $true })).Where({ ($_.GetFiles().Count -eq 0) -And ($_.GetDirectories().Count -eq 0) }).FullName)
} catch { Write-Warning ('❗ ディレクトリを見つけられませんでした') }

$local:emptyDirTotal = $local:emptyDirs.Count

#----------------------------------------------------------------------
if ($local:emptyDirTotal -ne 0) {
	if ($script:enableMultithread -eq $true) {
		#並列化が有効の場合は並列化
		$local:emptyDirs | ForEach-Object -Parallel {
			$local:emptyDirNum = ([Array]::IndexOf($using:local:emptyDirs, $_)) + 1
			$local:emptyDirTotal = $using:local:emptyDirs.Count
			Write-Output ('💡 {0}/{1} - {2}を削除します' -f $local:emptyDirNum, $local:emptyDirTotal, $_)
			try { Remove-Item -LiteralPath $_ -Recurse -Force }
			catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました: {0}' -f $_) }
		} -ThrottleLimit $script:multithreadNum
	} else {
		#並列化が無効の場合は従来型処理
		$local:emptyDirNum = 0
		$local:emptyDirTotal = $local:emptyDirs.Count
		$local:totalStartTime = Get-Date
		foreach ($local:subDir in $local:emptyDirs) {
			$local:emptyDirNum += 1
			#処理時間の推計
			$local:secElapsed = (Get-Date) - $local:totalStartTime
			$local:secRemaining = -1
			if ($local:emptyDirNum -ne 1) {
				$local:secRemaining = [Int][Math]::Ceiling(($local:secElapsed.TotalSeconds / $local:emptyDirNum) * ($local:emptyDirTotal - $local:emptyDirNum))
				$local:minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($local:secRemaining / 60)))
				$local:progressRate = [Float]($local:emptyDirNum / $local:emptyDirTotal)
			} else {
				$local:minRemaining = ''
				$local:progressRate = 0
			}
			UpdateProgressToast `
				-Title $local:subDir `
				-Rate $local:progressRate `
				-LeftText ('{0}/{1}' -f $local:emptyDirNum, $local:emptyDirTotal) `
				-RightText ('残り時間 {0}' -f $local:minRemaining) `
				-Tag $script:appName `
				-Group 'Move'
			Write-Output ('💡 {0}/{1} - {2}を削除します' -f $local:emptyDirNum, $local:emptyDirTotal, $local:subDir)
			try { Remove-Item -LiteralPath $local:subDir -Recurse -Force -ErrorAction SilentlyContinue
			} catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました: {0}' -f $local:subDir) }
		}
	}
}
#----------------------------------------------------------------------

updateProgressToast `
	-Title '不要ファイル削除' `
	-Rate 1 `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Delete'

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

Write-Output ('---------------------------------------------------------------------------')
Write-Output ('不要ファイル削除処理を終了しました。                                       ')
Write-Output ('---------------------------------------------------------------------------')
