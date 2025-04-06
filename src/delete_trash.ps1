###################################################################################
#
#		不要ファイル削除処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecの不要ファイルとディレクトリを削除するスクリプト

	.DESCRIPTION
		ダウンロード処理で生成された不要ファイルやディレクトリを削除します。
		以下の処理を順番に実行します：
		1. 中断されたダウンロードで生成された一時ファイルの削除
		2. ダウンロード対象外の番組の削除
		3. 空ディレクトリの削除

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
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		削除対象:
		1. 一時ファイル
		- ログファイル（半日以上前のもの）
		- ダウンロード中断ファイル（*.ytdl, *.part*）
		- サムネイル画像（*.jpg, *.webp）
		- 字幕ファイル（*.srt, *.vtt）
		- その他の一時ファイル
		2. ダウンロード対象外番組
		- ignore.confに記載された番組
		3. 空ディレクトリ
		- 隠しファイルのみのディレクトリを含む

		処理の流れ:
		1. 一時ファイルの削除
		1.1 ログディレクトリのクリーンアップ
		1.2 作業ディレクトリのクリーンアップ
		1.3 ダウンロードディレクトリのクリーンアップ
		1.4 保存先ディレクトリのクリーンアップ（設定時）
		2. 対象外番組の削除
		2.1 ignore.confの読み込み
		2.2 対象ディレクトリの特定
		2.3 並列処理による削除
		3. 空ディレクトリの削除
		3.1 空ディレクトリの特定
		3.2 並列処理による削除

	.EXAMPLE
		# 通常モードで実行
		.\delete_trash.ps1

		# GUIモードで実行
		.\delete_trash.ps1 gui

	.OUTPUTS
		System.Void
		このスクリプトは以下の出力を行います：
		- コンソールへの進捗状況の表示
		- トースト通知による進捗状況の表示
		- エラー発生時のエラーメッセージ
		- 処理完了時のサマリー情報
		- 削除されたファイルとディレクトリの一覧
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

#======================================================================
# 1/3ダウンロードが中断した際にできたゴミファイルは削除
Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.DeleteTrashFiles)

$toastShowParams = @{
	Text1      = $script:msg.DeleteTrashes
	Text2      = $script:msg.DeleteTrashesStep1
	WorkDetail = ''
	Tag        = $script:appName
	Silent     = $false
	Group      = 'Delete'
}
Show-ProgressToast @toastShowParams

if ($script:cleanupDownloadBaseDir -and $script:cleanupSaveBaseDir ) { $totalCleanupSteps = 4 }
elseif ($script:cleanupDownloadBaseDir -or $script:cleanupSaveBaseDir ) { $totalCleanupSteps = 3 }
else { $totalCleanupSteps = 2 }

# 1日以上前のログファイル・ロックファイルを削除
$toastUpdateParams = @{
	Title     = $script:logDir
	Rate      = [Float]( 1 / $totalCleanupSteps )
	LeftText  = ''
	RightText = ''
	Tag       = $script:appName
	Group     = 'Delete'
}
Update-ProgressToast @toastUpdateParams
$getChildItemParams = @{
	Path        = $script:logDir
	Include     = @('ffmpeg_error_*.log', 'ffmpeg_err_*.log', 'ytdl_out_*.log', 'ytdl_err_*.log')
	File        = $true
	Recurse     = $true
	ErrorAction = 'SilentlyContinue'
}
Get-ChildItem @getChildItemParams -ErrorAction SilentlyContinue | Remove-File -DelPeriod 1

# 作業ディレクトリ
$toastUpdateParams.Title = $script:downloadWorkDir
$toastUpdateParams.Rate = [Float]( 2 / $totalCleanupSteps )
Update-ProgressToast @toastUpdateParams
# リネームに失敗したファイルを削除
Write-Output ($script:msg.DeleteFilesFailedToRename)
Remove-UnMovedTempFile
$workDirParams = @{
	Path    = $script:downloadWorkDir
	Include = @('*.ytdl', '*.jpg', '*.webp', '*.srt', '*.vtt', '*.part*', '*.m4a-Frag*',
		'*.live_chat.json', '*.temp.mp4', '*.temp.ts', '*.mp4-Frag*', '*.ts-Frag*')
	File    = $true
	Recurse = $true
}
Get-ChildItem @workDirParams -ErrorAction SilentlyContinue | Remove-File -DelPeriod 0

# ダウンロード先
$toastUpdateParams.Title = $script:downloadBaseDir
$toastUpdateParams.Rate = [Float]( 3 / $totalCleanupSteps )
Update-ProgressToast @toastUpdateParams
# リネームに失敗したファイルを削除
Write-Output ($script:msg.DeleteFilesFailedToRename)
Remove-UnRenamedTempFile
if ($script:cleanupDownloadBaseDir) {
	$downloadDirParams = @{
		Path        = $script:downloadBaseDir
		Include     = @('*.ytdl', '*.jpg', '*.webp', '*.srt', '*.vtt', '*.part*', '*.m4a-Frag*',
			'*.live_chat.json', '*.temp.mp4', '*.temp.ts', '*.mp4-Frag*', '*.ts-Frag*')
		File        = $true
		Recurse     = $true
		ErrorAction = 'SilentlyContinue'
	}
	Get-ChildItem @downloadDirParams -ErrorAction SilentlyContinue | Remove-File -DelPeriod 0
}

# 移動先
$toastUpdateParams.Title = $script:saveBaseDir
$toastUpdateParams.Rate = 1
Update-ProgressToast @toastUpdateParams
if ($script:cleanupSaveBaseDir -and $script:saveBaseDir) {
	$script:saveDirArray = $script:saveBaseDirArray.ToArray()
	$saveDirArray | ForEach-Object {
		$saveDir = $_
		$saveDirParams = @{
			Path    = $saveDir
			Include = @('*.ytdl', '*.jpg', '*.webp', '*.srt', '*.vtt', '*.part*', '*.m4a-Frag*',
				'*.live_chat.json', '*.temp.mp4', '*.temp.ts', '*.mp4-Frag*', '*.ts-Frag*')
			File    = $true
			Recurse = $true
		}
		Get-ChildItem @saveDirParams | Remove-File -DelPeriod 0
	}
}

#======================================================================
# 2/3ダウンロード対象外に入っている番組は削除
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.DeleteExcludeFiles)

$toastShowParams.Text2 = $script:msg.DeleteTrashesStep2
Show-ProgressToast @toastShowParams

# 個別ダウンロードが強制モードの場合にはスキップ
if ($script:forceSingleDownload) {
	Write-Warning ($script:msg.DisclaimerForForceDownloadFlag)
} else {
	# ダウンロード先にディレクトリがない場合はスキップ
	$workDirEntities = @(Get-ChildItem -LiteralPath $script:downloadBaseDir)
	if ($workDirEntities.Count -eq 0) { return }

	# ダウンロード対象外番組が登録されていない場合はスキップ
	$ignoreTitles = @(Read-IgnoreList)
	$ignoreDirs = New-Object System.Collections.Generic.List[Object]
	if ($ignoreTitles.Count -eq 0) { return }

	# 削除対象の特定
	foreach ($ignoreTitleRaw in $ignoreTitles) {
		$ignoreTitle = $ignoreTitleRaw.Normalize([Text.NormalizationForm]::FormC)
		$filteredDirs = $workDirEntities.Where({ $_.Name.Normalize([Text.NormalizationForm]::FormC) -like "*${ignoreTitle}*" })
		foreach ($filteredDir in $filteredDirs) {
			$ignoreDirs.Add($filteredDir)
			Update-IgnoreList $ignoreTitle
		}
	}

	#----------------------------------------------------------------------
	if ($ignoreDirs.Count -ne 0) {
		if ($script:enableMultithread) {
			Write-Debug ('Multithread Processing Enabled')
			# 並列化が有効の場合は並列化
			$ignoreDirs | ForEach-Object -Parallel {
				$ignoreNum = ([Array]::IndexOf($using:ignoreDirs, $_)) + 1
				$ignoreTotal = $using:ignoreDirs.Count
				Write-Output ('　{0}/{1} - {2}' -f $ignoreNum, $ignoreTotal, $_.Name)
				try { Remove-Item -LiteralPath $_ -Recurse -Force | Out-Null }
				catch { Write-Warning ($script:msg.FileCannotBeDeleted) }
			} -ThrottleLimit $script:multithreadNum
		} else {
			# 並列化が無効の場合は従来型処理
			$ignoreNum = 0
			$ignoreTotal = $ignoreDirs.Count
			$totalStartTime = Get-Date
			foreach ($ignoreDir in $ignoreDirs) {
				$ignoreNum++
				# 処理時間の推計
				$secElapsed = (Get-Date) - $totalStartTime
				$secRemaining = -1
				if ($ignoreNum -ne 1) {
					$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $ignoreNum) * ($ignoreTotal - $ignoreNum))
					$minRemaining = ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($secRemaining / 60)))
					$progressRate = [Float]($ignoreNum / $ignoreTotal)
				} else { $minRemaining = '' ; $progressRate = 0 }

				$toastUpdateParams.Title = $ignoreDir.Name
				$toastUpdateParams.Rate = $progressRate
				$toastUpdateParams.LeftText = ('{0}/{1}' -f $ignoreNum, $ignoreTotal)
				$toastUpdateParams.RightText = $minRemaining
				Update-ProgressToast @toastUpdateParams

				Write-Output ('　{0}/{1} - {2}' -f $ignoreNum, $ignoreTotal, $ignoreDir.Name)
				try { Remove-Item -LiteralPath $ignoreDir -Recurse -Force | Out-Null }
				catch { Write-Warning ($script:msg.FileCannotBeDeleted) }
			}
		}
	}
}

#----------------------------------------------------------------------

#======================================================================
# 3/3空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Write-Output ('')
Write-Output ($script:msg.MediumBoldBorder)
Write-Output ($script:msg.DeleteEmptyDirs)

$toastShowParams.Text2 = $script:msg.DeleteTrashesStep3
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
				try { Remove-Item -LiteralPath $_ -Recurse -Force | Out-Null }
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
				try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }
				catch { Write-Warning ($script:msg.DeleteEmptyDirsFailed -f $dir) }
			}
		}
	}
	#----------------------------------------------------------------------
}

$toastUpdateParams.Title = $script:msg.DeleteTrash
$toastUpdateParams.Rate = 1
$toastUpdateParams.LeftText = ''
$toastUpdateParams.RightText = $script:msg.Completed
Update-ProgressToast @toastUpdateParams

Remove-Variable -Name args, toastShowParams, toastUpdateParams, saveDir, workDirEntities, ignoreTitles, ignoreDirs, ignoreTitle, filteredDirs, filteredDir, ignoreNum, ignoreTotal, totalStartTime, ignoreDir, secElapsed, secRemaining, minRemaining, progressRate, emptyDirs, emptyDirTotal, emptyDirNum, dir -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.DeleteTrashCompleted)
Write-Output ($script:msg.LongBoldBorder)
