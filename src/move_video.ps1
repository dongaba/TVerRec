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
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#======================================================================
#1/3 移動先ディレクトリを起点として、配下のディレクトリを取得
Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('移動先ディレクトリの一覧を作成しています')
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理1/3 - ディレクトリ一覧を作成' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

$local:moveToPathsHash = @{}
$local:moveToPathsArray = @()
if ($script:saveBaseDir -ne '') {
	$script:saveBaseDirArray = @($script:saveBaseDir.split(';').Trim())
	foreach ($saveDir in $script:saveBaseDirArray) {
		$local:moveToPathsArray += @((Get-ChildItem -LiteralPath $local:saveDir.Trim() -Recurse).Where({ $_.PSIsContainer }) | Select-Object Name, FullName)
	}
}
for ($i = 0 ; $i -lt $local:moveToPathsArray.Count ; $i++) {
	$local:moveToPathsHash[$local:moveToPathsArray[$i].Name] = $local:moveToPathsArray[$i].FullName
}

#作業ディレクトリ配下のディレクトリ一覧
$local:moveFromPaths = @(Get-ChildItem -LiteralPath $script:downloadBaseDir -Name)

#移動先ディレクトリと作業ディレクトリの一致を抽出
if ($local:moveToPathsArray.Count -ne 0) {
	$local:moveToPaths = @(Compare-Object -IncludeEqual -ExcludeDifferent $local:moveToPathsArray.Name $local:moveFromPaths)
} else { $local:moveToPaths = $null }

#======================================================================
#2/3 移動先ディレクトリと同名のディレクトリ配下の番組を移動
Write-Output ('')
Write-Output ('----------------------------------------------------------------------')
Write-Output ('ダウンロードファイルを移動しています')

showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理2/3 - ダウンロードファイルを移動' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date
if (($null -ne $local:moveToPaths) -And ($local:moveToPaths.Count -ne 0)) {
	$local:moveToPathNum = 0
	$local:moveToPathTotal = $local:moveToPaths.Count
	foreach ($local:moveToPath in $local:moveToPaths) {
		#処理時間の推計
		$local:secElapsed = (Get-Date) - $local:totalStartTime
		$local:secRemaining = -1
		if ($local:moveToPathNum -ne 0) {
			$local:secRemaining = [Int][Math]::Ceiling(($local:secElapsed.TotalSeconds / $local:moveToPathNum) * ($local:moveToPathTotal - $local:moveToPathNum))
			$local:minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($local:secRemaining / 60)))
			$local:progressRate = [Float]($local:moveToPathNum / $local:moveToPathTotal)
		} else {
			$local:minRemaining = ''
			$local:progressRate = 0
		}
		$local:moveToPathNum += 1
		UpdateProgressToast `
			-Title $local:moveToPath.InputObject `
			-Rate $local:progressRate `
			-LeftText ('{0}/{1}' -f $local:moveToPathNum, $local:moveToPathTotal) `
			-RightText ('残り時間 {0}' -f $local:minRemaining) `
			-Tag $script:appName `
			-Group 'Move'
		$local:targetFolderName = $local:moveToPath.InputObject
		if ($script:sortVideoByMedia) {
			$local:mediaName = Split-Path -Leaf -Path (Split-Path -Parent -Path $local:moveToPathsHash[$local:moveToPath.InputObject])
			$local:targetFolderName = Join-Path $local:mediaName $local:targetFolderName
		}
		#同名ディレクトリが存在する場合は配下のファイルを移動
		$local:moveFromPath = Join-Path $script:downloadBaseDir $local:targetFolderName
		if (Test-Path $local:moveFromPath) {
			Write-Output ('　{0}\*.mp4' -f $local:moveFromPath)
			try { Move-Item ('{0}\*.mp4' -f $local:moveFromPath) -Destination $local:moveToPathsHash[$local:moveToPath.InputObject] -Force }
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
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理3/3 - 空ディレクトリを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

$local:emptyDirs = @()
$local:emptyDirs = @((Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse).where({ $_.PSIsContainer -eq $true })).Where({ ($_.GetFiles().Count -eq 0) -And ($_.GetDirectories().Count -eq 0) })
if ($local:emptyDirs.Count -ne 0) { $local:emptyDirs = @($local:emptyDirs.Fullname) }
else { { Write-Warning ('❗ 空ディレクトリを見つけられませんでした') } }

$local:emptyDirTotal = $local:emptyDirs.Count

#----------------------------------------------------------------------
if ($local:emptyDirTotal -ne 0) {
	if ($script:enableMultithread -eq $true) {
		#並列化が有効の場合は並列化
		$local:emptyDirs | ForEach-Object -Parallel {
			$local:emptyDirNum = ([Array]::IndexOf($using:local:emptyDirs, $_)) + 1
			$local:emptyDirTotal = $using:local:emptyDirs.Count
			Write-Output ('　{0}/{1} - {2}' -f $local:emptyDirNum, $local:emptyDirTotal, $_)
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
			Write-Output ('　{0}/{1} - {2}' -f $local:emptyDirNum, $local:emptyDirTotal, $local:subDir)
			try { Remove-Item -LiteralPath $local:subDir -Recurse -Force -ErrorAction SilentlyContinue
			} catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました: {0}' -f $local:subDir) }
		}
	}
}
#----------------------------------------------------------------------

try { $script:uiMode = [String]$args[0] } catch { $script:uiMode = '' }

updateProgressToast `
	-Title '番組の移動' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Move'

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('番組移動処理を終了しました。                                               ')
Write-Output ('---------------------------------------------------------------------------')
