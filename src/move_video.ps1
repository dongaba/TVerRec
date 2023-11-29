###################################################################################
#
#		番組移動処理スクリプト
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
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if (!$?) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#設定で指定したファイル・ディレクトリの存在チェック
Invoke-RequiredFileCheck

#======================================================================
#1/3 移動先ディレクトリを起点として、配下のディレクトリを取得
Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('移動先ディレクトリの一覧を作成しています')
Show-ProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理1/3 - ディレクトリ一覧を作成' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#移動先ディレクトリ配下のディレクトリ一覧
$moveToPathsHash = @{}
if ($script:saveBaseDir) {
	$script:saveBaseDirArray = @($script:saveBaseDir.split(';').Trim())
	$moveToPathsArray = @((Get-ChildItem -LiteralPath $script:saveBaseDirArray -Recurse).Where({ $_.PSIsContainer }) | Select-Object Name, FullName)
} else { $moveToPathsArray = @() }
for ($i = 0 ; $i -lt $moveToPathsArray.Count ; $i++) {
	$moveToPathsHash[$moveToPathsArray[$i].Name] = $moveToPathsArray[$i].FullName
}

#作業ディレクトリ配下のディレクトリ一覧
$moveFromPathsHash = @{}
if ($script:saveBaseDir) {
	$moveFromPathsArray = @((Get-ChildItem -LiteralPath $script:downloadBaseDir -Filter *.mp4 -Recurse).Directory | Sort-Object -Unique | Select-Object Name, FullName)
} else { $moveFromPathsArray = @() }
for ($i = 0 ; $i -lt $moveFromPathsArray.Count ; $i++) {
	$moveFromPathsHash[$moveFromPathsArray[$i].Name] = $moveFromPathsArray[$i].FullName
}

#移動先ディレクトリと作業ディレクトリの一致を抽出
if ($moveToPathsArray.Count -ne 0) {
	$moveDirs = @(Compare-Object -IncludeEqual -ExcludeDifferent $moveToPathsArray.Name $moveFromPathsArray.Name)
} else { $moveDirs = $null }

#======================================================================
#2/3 移動先ディレクトリと同名のディレクトリ配下の番組を移動
Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('ダウンロードファイルを移動しています')

Show-ProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理2/3 - ダウンロードファイルを移動' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#----------------------------------------------------------------------
$totalStartTime = Get-Date
if (($null -ne $moveDirs) -and ($moveDirs.Count -ne 0)) {
	$moveDirNum = 0
	$moveDirsTotal = $moveDirs.Count
	foreach ($moveDir in $moveDirs) {
		#処理時間の推計
		$secElapsed = (Get-Date) - $totalStartTime
		$secRemaining = -1
		if ($moveDirNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $moveDirNum) * ($moveDirsTotal - $moveDirNum))
			$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
			$progressRate = [Float]($moveDirNum / $moveDirsTotal)
		} else {
			$minRemaining = ''
			$progressRate = 0
		}
		$moveDirNum += 1
		Update-ProgressToast `
			-Title $moveDir.InputObject `
			-Rate $progressRate `
			-LeftText ('{0}/{1}' -f $moveDirNum, $moveDirsTotal) `
			-RightText ('残り時間 {0}' -f $minRemaining) `
			-Tag $script:appName `
			-Group 'Move'
		$targetFolderName = $moveDir.InputObject
		#同名ディレクトリが存在する場合は配下のファイルを移動
		$moveFromPath = $moveFromPathsHash[$targetFolderName]
		$moveToPath = $moveToPathsHash[$targetFolderName]
		if (Test-Path $moveFromPath) {
			Write-Output ('　{0}\*.mp4' -f $moveFromPath)
			try { Move-Item ('{0}\*.mp4' -f $moveFromPath) -Destination $moveToPath -Force }
			catch { Write-Warning ('❗ 移動できないファイルがありました') }
		}
	}
}
#----------------------------------------------------------------------

#======================================================================
#3/3 空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('空ディレクトリを削除します')
Show-ProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理3/3 - 空ディレクトリを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

$emptyDirs = @()
$emptyDirs = @((Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).Where({ ($_.GetFiles().Count -eq 0) -and ($_.GetDirectories().Count -eq 0) })
if ($emptyDirs.Count -ne 0) { $emptyDirs = @($emptyDirs.Fullname) }

$emptyDirTotal = $emptyDirs.Count

#----------------------------------------------------------------------
if ($emptyDirTotal -ne 0) {
	if ($script:enableMultithread) {
		Write-Debug ('Multithread Processing Enabled')
		#並列化が有効の場合は並列化
		$emptyDirs | ForEach-Object -Parallel {
			$emptyDirNum = ([Array]::IndexOf($using:emptyDirs, $_)) + 1
			$emptyDirTotal = $using:emptyDirs.Count
			Write-Output ('　{0}/{1} - {2}' -f $emptyDirNum, $emptyDirTotal, $_)
			try { Remove-Item -LiteralPath $_ -Recurse -Force }
			catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました: {0}' -f $_) }
		} -ThrottleLimit $script:multithreadNum
	} else {
		#並列化が無効の場合は従来型処理
		$emptyDirNum = 0
		$emptyDirTotal = $emptyDirs.Count
		$totalStartTime = Get-Date
		foreach ($subDir in $emptyDirs) {
			$emptyDirNum += 1
			#処理時間の推計
			$secElapsed = (Get-Date) - $totalStartTime
			$secRemaining = -1
			if ($emptyDirNum -ne 1) {
				$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $emptyDirNum) * ($emptyDirTotal - $emptyDirNum))
				$minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
				$progressRate = [Float]($emptyDirNum / $emptyDirTotal)
			} else {
				$minRemaining = ''
				$progressRate = 0
			}
			Update-ProgressToast `
				-Title $subDir `
				-Rate $progressRate `
				-LeftText ('{0}/{1}' -f $emptyDirNum, $emptyDirTotal) `
				-RightText ('残り時間 {0}' -f $minRemaining) `
				-Tag $script:appName `
				-Group 'Move'
			Write-Output ('　{0}/{1} - {2}' -f $emptyDirNum, $emptyDirTotal, $subDir)
			try { Remove-Item -LiteralPath $subDir -Recurse -Force -ErrorAction SilentlyContinue
			} catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました: {0}' -f $subDir) }
		}
	}
}
#----------------------------------------------------------------------

try { $script:guiMode = [String]$args[0] } catch { $script:guiMode = '' }

Update-ProgressToast `
	-Title '番組の移動' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Move'

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('番組移動処理を終了しました。                                               ')
Write-Output ('---------------------------------------------------------------------------')
