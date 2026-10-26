###################################################################################
#
#		番組移動処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecでダウンロードした番組を指定のディレクトリに移動するスクリプト

	.DESCRIPTION
		ダウンロードした番組を指定の保存先ディレクトリに移動し、空のディレクトリを削除します。
		以下の処理を順番に実行します：
		1. 移動先ディレクトリの一覧取得
		2. ダウンロードディレクトリの一覧取得
		3. 番組ファイルの移動
		4. 空ディレクトリの削除

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。
		- 指定なし: 通常モードで実行
		- 'gui': GUIモードで実行
		- その他の値: 通常モードで実行

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 保存先ディレクトリが設定されている必要があります
		- 十分なディスク容量が必要です
		- インターネット接続が必要です

		処理の流れ:
		1. 移動先ディレクトリの処理
		1.1 保存先ディレクトリ配下のディレクトリ一覧を取得
		1.2 ジャンクションやシンボリックリンクを解決
		2. ダウンロードディレクトリの処理
		2.1 動画ファイルを含むディレクトリを特定
		2.2 移動先ディレクトリと名前が一致するものを抽出
		3. ファイル移動の処理
		3.1 同名ディレクトリ間でファイルを移動
		3.2 エラー発生時は警告を表示
		4. クリーンアップ処理
		4.1 空ディレクトリを特定
		4.2 並列処理による空ディレクトリの削除

	.EXAMPLE
		# 通常モードで実行
		.\move_video.ps1

		# GUIモードで実行
		.\move_video.ps1 gui

	.OUTPUTS
		System.Void
		このスクリプトは以下の出力を行います：
		- コンソールへの進捗状況の表示
		- トースト通知による進捗状況の表示
		- エラー発生時のエラーメッセージ
		- 処理完了時のサマリー情報
		- 移動したファイルの一覧
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
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Invoke-RequiredFileCheck
Suspend-Process

#======================================================================
# 1/3移動先ディレクトリを起点として、配下のディレクトリを取得
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.ListUpDestinationDirs)

$toastShowParams = @{
	Text1      = $script:msg.MoveVideos
	Text2      = $script:msg.MoveVideosStep1
	WorkDetail = ''
	Tag        = $script:appName
	Silent     = $false
	Group      = 'Move'
}
Show-ProgressToast @toastShowParams

#----------------------------------------------------------------------
# プラットフォームに応じたディレクトリ一覧を取得
#----------------------------------------------------------------------
function Get-DirectoriesWithPlatformCheck {
	<#
		.SYNOPSIS
			指定したパス配下のディレクトリを、サブディレクトリを含めてすべて取得します。

		.DESCRIPTION
			Windowsでは、PowerShellがジャンクションを展開できないため、cmd.exeのdirコマンドでジャンクションを解決して取得します。
			Linux/Macでは、findコマンドで取得します。

		.PARAMETER paths
			検索するディレクトリのパスを配列で指定します。

		.OUTPUTS
			[Collections.Generic.List[String]]
			取得したディレクトリのフルパスの一覧。

		.EXAMPLE
			$dirs = Get-DirectoriesWithPlatformCheck -Paths @($script:downloadBaseDir)
	#>
	Param ([String[]]$paths)
	$results = New-Object System.Collections.Generic.List[String]
	if ($IsWindows) {
		# PowerShellではジャンクションの展開ができないので、cmd.exeを使ってジャンクションを解決する
		foreach ($path in $paths) {
			$dirCmd = "dir `"$path`" /s /b /a:d"
			$resultTemp = [String[]](& cmd /c $dirCmd)
			if ($resultTemp) { $results.AddRange($resultTemp ) }
		}
	} else {
		# 念の為、Linux/Macでもfindを使う
		foreach ($path in $paths) {
			$findCmd = "find `"$path`" -type d"
			$resultTemp = [String[]](& sh -c $findCmd)
			if ($resultTemp) { $results.AddRange($resultTemp ) }
		}
	}
	return $results
}

# 移動先ディレクトリ配下のディレクトリ一覧
# * 同名のフォルダが複数ある場合もすべて保持する(キー: フォルダ名、値: パスの配列)
$moveToPathsHash = @{}
if ($script:saveBaseDir) {
	$script:saveBaseDirArray = $script:saveBaseDir.Split(';').Trim()
	$saveBaseDirs = Get-DirectoriesWithPlatformCheck -paths $script:saveBaseDirArray
	$moveToPathsHash = Group-DirectoryPathByLeaf -Path @($saveBaseDirs)
}

# ダウンロードディレクトリ配下のディレクトリ一覧
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.ListUpSourceDirs)
$moveFromPathsHash = @{}
if ($script:saveBaseDir) {
	$moveFromFiles = @(Get-ChildItem -LiteralPath $script:downloadBaseDir -Include @('*.mp4', '*.ts') -Recurse -File -Force -ErrorAction SilentlyContinue)
	$moveFromPathsHash = Group-DirectoryPathByLeaf -Path @($moveFromFiles.ForEach({ $_.Directory.FullName }))
}

# 移動先ディレクトリとダウンロードディレクトリの一致を抽出
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.MatchingTargetAndSource)
if ($moveToPathsHash.Count -gt 0) {
	$moveDirs = New-Object System.Collections.Generic.List[Object]
	foreach ($item in Compare-Object -ReferenceObject @($moveToPathsHash.Keys) -DifferenceObject @($moveFromPathsHash.Keys) -IncludeEqual -ExcludeDifferent) {
		$moveDirs.Add($item.InputObject)
	}
} else { $moveDirs = $null }

#======================================================================
# 2/3移動先ディレクトリと同名のディレクトリ配下の番組を移動
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.MovingVideos)

$toastShowParams.Text2 = $script:msg.MoveVideosStep2
Show-ProgressToast @toastShowParams

#----------------------------------------------------------------------
$totalStartTime = Get-Date
if ($moveDirs) {
	$dirNum = 0
	$dirTotal = $moveDirs.Count
	foreach ($dir in $moveDirs) {
		# 処理時間の推計
		$secElapsed = (Get-Date) - $totalStartTime
		$secRemaining = -1
		if ($dirNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $dirNum) * ($dirTotal - $dirNum))
			$minRemaining = ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($secRemaining / 60)))
			$progressRate = [Float]($dirNum / $dirTotal)
		} else { $minRemaining = '' ; $progressRate = 0 }
		$dirNum++

		$toastUpdateParams = @{
			Title     = $dir
			Rate      = $progressRate
			LeftText  = ('{0}/{1}' -f $dirNum, $dirTotal)
			RightText = $minRemaining
			Tag       = $script:appName
			Group     = 'Move'
		}
		Update-ProgressToast @toastUpdateParams

		# .Normalize([Text.NormalizationForm]::FormC)
		$moveFromPaths = @($moveFromPathsHash[$dir] ?? $moveFromPathsHash[$dir.Normalize([Text.NormalizationForm]::FormC)])
		$moveToPaths = @($moveToPathsHash[$dir] ?? $moveToPathsHash[$dir.Normalize([Text.NormalizationForm]::FormC)])

		# 移動先に同名のフォルダが複数ある場合は、どれに移動すべきか判断できないため移動しない
		if ($moveToPaths.Count -gt 1) {
			Write-Warning ($script:msg.MoveDestAmbiguous -f $dir, ($moveToPaths -join ' , '))
			continue
		}
		$moveToPath = $moveToPaths[0]

		# 同名ディレクトリが存在する場合は配下のファイルを移動(移動元に同名のフォルダが複数ある場合はすべて対象)
		foreach ($moveFromPath in $moveFromPaths) {
			if ((Test-Path -LiteralPath $moveFromPath) -and (Test-Path -LiteralPath $moveToPath)) {
				Write-Output ('　{0}\* -> {1}' -f $moveFromPath, $moveToPath)
				foreach ($moveFile in @(Get-ChildItem -LiteralPath $moveFromPath -File)) {
					try {
						$moveResult = Move-VideoFileToDestination -Path $moveFile.FullName -DestinationDir $moveToPath -ConflictAction $script:moveConflictAction
						if ($moveResult.Result -eq 'Skipped') { Write-Warning ($script:msg.MoveFileSkipped -f $moveFile.Name) }
						elseif ($moveResult.Result -eq 'SubtitleKept') { Write-Warning ($script:msg.MoveFileSubtitleKept -f $moveFile.Name) }
						elseif ($moveResult.Result -eq 'Renamed') { Write-Output ($script:msg.MoveFileRenamed -f $moveFile.Name, (Split-Path -Leaf $moveResult.Destination)) }
					} catch { Write-Warning ($script:msg.MoveFileFailed -f $moveFile.FullName) }
				}
			} else { Write-Warning ($script:msg.MoveFileNotAccessible -f $moveFromPath) }
		}
	}
}
#----------------------------------------------------------------------

#======================================================================
# 3/3空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.DeleteEmptyDirs)

$toastShowParams.Text2 = $script:msg.MoveVideosStep3
Show-ProgressToast @toastShowParams

if ($script:emptyDownloadBaseDir) {
	try {
		$emptyDirs = New-Object System.Collections.Generic.List[String]
		foreach ($dir in (Get-ChildItem -Path $script:downloadBaseDir -Directory -Recurse -ErrorAction SilentlyContinue)) {
			$files = $dir.GetFileSystemInfos()
			$visibleFiles = @($files | Where-Object { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) })
			if ($visibleFiles.Count -eq 0) { $emptyDirs.Add($dir.FullName) }
		}
	} catch { $emptyDirs = @() }
	$emptyDirTotal = $emptyDirs.Count

	#----------------------------------------------------------------------
	if ($emptyDirTotal -ne 0) {
		if ($script:enableMultithread) {
			Write-Debug ('Multithread Processing Enabled')
			# 並列化が有効の場合は並列化
			$emptyDirs | ForEach-Object -Parallel {
				$emptyDirNum = ([Array]::IndexOf($using:emptyDirs, $_)) + 1
				$emptyDirTotal = $using:emptyDirs.Count
				Write-Output ('　{0}/{1} - {2}' -f $emptyDirNum, $emptyDirTotal, $_)
				try { Remove-Item -LiteralPath $_ -Recurse -Force -ErrorAction Stop | Out-Null }
				catch { Write-Warning ($script:msg.DeleteEmptyDirsFailed -f $_) }
			} -ThrottleLimit $script:multithreadNum
		} else {
			# 並列化が無効の場合は従来型処理
			$emptyDirNum = 0
			$emptyDirTotal = $emptyDirs.Count
			$totalStartTime = Get-Date
			foreach ($dir in $emptyDirs) {
				$emptyDirNum++
				# 処理時間の推計
				$secElapsed = (Get-Date) - $totalStartTime
				$secRemaining = -1
				if ($emptyDirNum -ne 1) {
					$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $emptyDirNum) * ($emptyDirTotal - $emptyDirNum))
					$minRemaining = ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($secRemaining / 60)))
					$progressRate = [Float]($emptyDirNum / $emptyDirTotal)
				} else { $minRemaining = '' ; $progressRate = 0 }

				$toastUpdateParams.Title = $dir
				$toastUpdateParams.Rate = $progressRate
				$toastUpdateParams.LeftText = ('{0}/{1}' -f $emptyDirNum, $emptyDirTotal)
				$toastUpdateParams.RightText = $minRemaining
				Update-ProgressToast @toastUpdateParams

				Write-Output ('　{0}/{1} - {2}' -f $emptyDirNum, $emptyDirTotal, $dir)
				try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop | Out-Null
				} catch { Write-Warning ($script:msg.DeleteEmptyDirsFailed -f $dir) }
			}
		}
	}
	#----------------------------------------------------------------------
}

$toastUpdateParams = @{
	Title     = $script:msg.MoveVideo
	Rate      = 1
	LeftText  = ''
	RightText = $script:msg.Completed
	Tag       = $script:appName
	Group     = 'Move'
}
Update-ProgressToast @toastUpdateParams

Remove-Variable -Name args, toastShowParams, moveToPathsHash, moveFromPathsHash, moveDirs, moveDir, totalStartTime, dirNum, dirTotal, dir, secElapsed, secRemaining, minRemaining, progressRate, toastUpdateParams, targetFolderName, moveFromPath, moveToPath, moveFromPaths, moveToPaths, moveFromFiles, saveBaseDirs, moveFile, moveResult, emptyDirs, emptyDirTotal, emptyDirNum -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.MoveVideoCompleted)
Write-Output ($script:msg.LongBoldBorder)
