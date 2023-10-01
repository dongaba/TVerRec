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
} catch { Write-Error '❗ カレントディレクトリの設定に失敗しました' ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error '❗ 関数の読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	. (Convert-Path (Join-Path $script:confDir 'system_setting.ps1'))
	if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
		. (Convert-Path (Join-Path $script:confDir 'user_setting.ps1'))
	}
} catch { Write-Error '❗ 設定ファイルの読み込みに失敗しました' ; exit 1 }

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#======================================================================
#ディレクトリの存在確認
if (!(Test-Path $script:downloadWorkDir -PathType Container))
{ Write-Error '❗ ダウンロード作業ディレクトリが存在しません。終了します。' ; exit 1 }
if (!(Test-Path $script:downloadBaseDir -PathType Container))
{ Write-Error '❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します。' ; exit 1 }
foreach ($local:saveDir in $script:saveBaseDirArray) {
	if (!(Test-Path $local:saveDir.Trim() -PathType Container))
	{ Write-Error '❗ 番組移動先ディレクトリが存在しません。終了します。' ; exit 1 }
}

#======================================================================
#1/3 移動先ディレクトリを起点として、配下のディレクトリを取得
Write-Output '----------------------------------------------------------------------'
Write-Output '移動先ディレクトリの一覧を作成しています'
Write-Output '----------------------------------------------------------------------'

#進捗表示
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理1/3 - ディレクトリ一覧を作成' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false


#======================================================================
#2/3 移動先ディレクトリと同名のディレクトリ配下の番組を移動
Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロードファイルを移動しています'
Write-Output '----------------------------------------------------------------------'


#進捗表示
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理2/3 - ダウンロードファイルを移動' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#処理
$local:moveToPaths = @()
foreach ($local:saveDir in $script:saveBaseDirArray) {
	$local:moveToPaths += Get-ChildItem -Path $local:saveDir.Trim() -Recurse `
	| Where-Object { $_.PSIsContainer } `
	| Sort-Object
}
$local:moveToPaths = @($local:moveToPaths)

#移動先パス番号
$local:moveToPathNum = 0
#移動先パス合計数
$local:moveToPathTotal = $local:moveToPaths.Count

#----------------------------------------------------------------------
$local:totalStartTime = Get-Date

if ($local:moveToPathTotal -ne 0) {
	foreach ($local:moveToPath in $local:moveToPaths.FullName) {

		#処理時間の推計
		$local:secElapsed = (Get-Date) - $local:totalStartTime
		$local:secRemaining = -1
		if ($local:moveToPathNum -ne 0) {
			$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:moveToPathNum) * ($local:moveToPathTotal - $local:moveToPathNum)
			$local:minRemaining = ([String]([math]::Ceiling($local:secRemaining / 60)) + '分')
			$local:progressRatio = ($local:moveToPathNum / $local:moveToPathTotal)
		} else {
			$local:minRemaining = '計算中...'
			$local:progressRatio = 0
		}
		$local:moveToPathNum = $local:moveToPathNum + 1

		#進捗表示
		UpdateProgressToast `
			-Title $local:moveToPath `
			-Rate $local:progressRatio `
			-LeftText ([String]$local:moveToPathNum + '/' + [String]$local:moveToPathTotal) `
			-RightText ('残り時間 ' + $local:minRemaining) `
			-Tag $script:appName `
			-Group 'Move'

		#処理
		Write-Output ([String]$local:moveToPathNum + '/' + [String]$local:moveToPathTotal + ' - ' + $local:moveToPath)
		$local:targetFolderName = Split-Path -Leaf $local:moveToPath
		if ($script:sortVideoByMedia) {
			$local:mediaName = Split-Path -Leaf (Split-Path -Parent $local:moveToPath)
			$local:targetFolderName = Join-Path $local:mediaName $local:targetFolderName
		}
		#同名フォルダが存在する場合は配下のファイルを移動
		$local:moveFromPath = Join-Path $script:downloadBaseDir $local:targetFolderName
		if (Test-Path $local:moveFromPath) {
			$local:moveFromPath = $local:moveFromPath + '\*.mp4'
			Write-Output ('💡 ' + $local:moveFromPath + 'を移動します')
			try { Move-Item $local:moveFromPath -Destination $local:moveToPath -Force }
			catch { Write-Warning '❗ 移動できないファイルがありました' }
		}
	}
}
#----------------------------------------------------------------------

#======================================================================
#3/3 空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Write-Output '----------------------------------------------------------------------'
Write-Output '空ディレクトリを削除します'
Write-Output '----------------------------------------------------------------------'
#進捗表示
showProgressToast `
	-Text1 '番組の移動中' `
	-Text2 '　処理3/3 - 空ディレクトリを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Move' `
	-Duration 'long' `
	-Silent $false

#処理
$local:allSubDirs = @()
try {
	$local:allSubDirs = @((Get-ChildItem -LiteralPath $script:downloadBaseDir -Recurse).Where({ $_.PSIsContainer }).FullName | Sort-Object -Descending)
} catch { Write-Warning '❗ ディレクトリを見つけられませんでした' }

#サブディレクトリの合計数
$local:subDirTotal = $local:allSubDirs.Count

#----------------------------------------------------------------------
if ($local:subDirTotal -ne 0) {
	if ($script:enableMultithread -eq $true) {
		#並列化が有効の場合は並列化
		$local:allSubDirs | ForEach-Object -Parallel {
			$local:i = ([Array]::IndexOf($using:local:allSubDirs, $_)) + 1
			$local:total = $using:local:allSubDirs.Count
			#処理
			Write-Output ([String]$local:i + '/' + [String]$local:total + ' - ' + $_)
			if (@((Get-ChildItem -LiteralPath $_ -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
				Write-Output ('💡 ' + [String]$local:i + '/' + [String]$local:total + ' - ' + $_ + 'を削除します')
				try { Remove-Item -LiteralPath $_ -Recurse -Force }
				catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました:' + $_) }
			}
		} -ThrottleLimit $script:multithreadNum

	} else {
		#並列化が無効の場合は従来型処理
		#サブディレクトリの番号
		$local:subDirNum = 0
		#サブディレクトリの合計数
		$local:subDirTotal = $local:allSubDirs.Count
		$local:totalStartTime = Get-Date
		foreach ($local:subDir in $local:allSubDirs) {
			#処理時間の推計
			$local:secElapsed = (Get-Date) - $local:totalStartTime
			$local:secRemaining = -1
			if ($local:subDirNum -ne 0) {
				$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:subDirNum) * ($local:subDirTotal - $local:subDirNum)
				$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
				$local:progressRatio = $($local:subDirNum / $local:subDirTotal)
			} else {
				$local:minRemaining = '計算中...'
				$local:progressRatio = 0
			}
			$local:subDirNum = $local:subDirNum + 1

			#進捗表示
			UpdateProgressToast `
				-Title $local:subDir `
				-Rate $local:progressRatio `
				-LeftText ([String]$local:subDirNum + '/' + [String]$local:subDirTotal) `
				-RightText ('残り時間 ' + $local:minRemaining) `
				-Tag $script:appName `
				-Group 'Move'

			#処理
			Write-Output ([String]$local:subDirNum + '/' + [String]$local:subDirTotal + ' - ' + $local:subDir)
			if (@((Get-ChildItem -LiteralPath $local:subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
				Write-Output ('💡 ' + [String]$local:subDirNum + '/' + [String]$local:subDirTotal + $local:subDir + 'を削除します')
				try { Remove-Item -LiteralPath $local:subDir -Recurse -Force -ErrorAction SilentlyContinue
				} catch { Write-Warning ('❗ - 空ディレクトリの削除に失敗しました:' + $local:subDir) }
			}
		}


	}
}
#----------------------------------------------------------------------

#進捗表示
updateProgressToast `
	-Title '番組の移動' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Move'

Write-Output '---------------------------------------------------------------------------'
Write-Output '番組移動処理を終了しました。                                               '
Write-Output '---------------------------------------------------------------------------'
