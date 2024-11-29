###################################################################################
#
#		番組移動処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません') }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if (!$?) { Throw ('❌️ TVerRecの初期化処理に失敗しました') }
} catch { Throw ('❌️ 関数の読み込みに失敗しました') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Invoke-RequiredFileCheck

#======================================================================
#1/3 移動先ディレクトリを起点として、配下のディレクトリを取得
Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('移動先ディレクトリの一覧を作成しています')

$toastShowParams = @{
	Text1      = '番組の移動中'
	Text2      = '　処理1/3 - ディレクトリ一覧を作成'
	WorkDetail = ''
	Tag        = $script:appName
	Silent     = $false
	Group      = 'Move'
}
Show-ProgressToast @toastShowParams

# Windowsのディレクトリ一覧を取得する関数
function Get-DirectoriesOnWindows {
	param ([string[]]$paths)
	$results = @()
	foreach ($path in $paths) {
		$dirCmd = "dir `"$path`" /s /b /a:d"
		$results += (& cmd /c $dirCmd) | ForEach-Object { $_ }
	}
	return $results
}

# Linux/Macのディレクトリ一覧を取得する関数
function Get-DirectoriesNotOnWindows {
	param ([string[]]$paths)
	$results = @()
	foreach ($path in $paths) {
		$dirCmd = "find `"$path`" -type d"
		$results += (& sh -c $dirCmd)
	}
	return $results
}

# プラットフォームに応じたディレクトリ一覧を取得する関数
function Get-DirectoriesWithPlatformCheck {
	param ([string[]]$paths)
	#PowerShellではジャンクションの展開ができないので、cmd.exeを使ってジャンクションを解決する
	switch ($true) {
		$IsWindows { $results = Get-DirectoriesOnWindows -paths $paths ; continue }
		default { $results = Get-DirectoriesNotOnWindows -paths $paths }
	}
	return $results
}

# 移動先ディレクトリ配下のディレクトリ一覧
$moveToPathsHash = @{}
if ($script:saveBaseDir) {
	$script:saveBaseDirArray = $script:saveBaseDir.Split(';').Trim()
	$saveBaseDirs = Get-DirectoriesWithPlatformCheck -paths $script:saveBaseDirArray
	foreach ($saveBaseDir in $saveBaseDirs) {
		$saveBaseDirLeaf = Split-Path -Leaf $saveBaseDir
		$moveToPathsHash[$saveBaseDirLeaf] = $saveBaseDir
	}
}

#作業ディレクトリ配下のディレクトリ一覧
$moveFromPathsHash = @{}
if ($script:saveBaseDir -and (Get-ChildItem -LiteralPath $script:downloadBaseDir -Include @('*.mp4', '*.ts') -Recurse)) {
	Get-ChildItem -LiteralPath $script:downloadBaseDir -Include @('*.mp4', '*.ts') -Recurse -File | Select-Object Directory -Unique | ForEach-Object { $moveFromPathsHash[$_.Directory.Name] = $_.Directory.FullName }
}

#移動先ディレクトリと作業ディレクトリの一致を抽出
if ($moveToPathsHash.Count -gt 0) {
	$moveDirs = @(Compare-Object -ReferenceObject @($moveToPathsHash.Keys) -DifferenceObject @($moveFromPathsHash.Keys) -IncludeEqual -ExcludeDifferent | ForEach-Object { $_.InputObject })
} else { $moveDirs = $null }

#======================================================================
#2/3 移動先ディレクトリと同名のディレクトリ配下の番組を移動
Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('ダウンロードファイルを移動しています')

$toastShowParams.Text2 = '　処理2/3 - ダウンロードファイルを移動'
Show-ProgressToast @toastShowParams

#----------------------------------------------------------------------
$totalStartTime = Get-Date
if ($moveDirs) {
	$dirNum = 0
	$dirTotal = $moveDirs.Count
	foreach ($dir in $moveDirs) {
		#処理時間の推計
		$secElapsed = (Get-Date) - $totalStartTime
		$secRemaining = -1
		if ($dirNum -ne 0) {
			$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $dirNum) * ($dirTotal - $dirNum))
			$minRemaining = ('残り時間 {0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
			$progressRate = [Float]($dirNum / $dirTotal)
		} else {
			$minRemaining = ''
			$progressRate = 0
		}
		$dirNum++

		$toastUpdateParams = @{
			Title     = $dir
			Rate      = $progressRate
			LeftText  = ('{0}/{1}' -f $dirNum, $dirTotal)
			RightText = $minRemaining
			Tag       = $script:appName
			Group     = 'Delete'
		}
		Update-ProgressToast @toastUpdateParams

		#.Normalize([Text.NormalizationForm]::FormC)
		$moveFromPath = $moveFromPathsHash[$dir] ?? $moveFromPathsHash[$dir.Normalize([Text.NormalizationForm]::FormC)]
		$moveToPath = $moveToPathsHash[$dir] ?? $moveToPathsHash[$dir.Normalize([Text.NormalizationForm]::FormC)]

		#同名ディレクトリが存在する場合は配下のファイルを移動
		if ((Test-Path -LiteralPath $moveFromPath) -and (Test-Path -LiteralPath $moveToPath)) {
			Write-Output ('　{0}\* -> {1}' -f $moveFromPath, $moveToPath)
			try { Get-ChildItem -LiteralPath $moveFromPath -File | Move-Item -Destination $moveToPath -Force | Out-Null }
			catch { Write-Warning ('⚠️ 移動できないファイルがありました - {0}' -f $moveFromPath) }
		} else { Write-Warning ('⚠️ 移動元、または移動先にアクセスできなくなりました - {0}' -f $moveFromPath) }
	}
}
#----------------------------------------------------------------------

#======================================================================
#3/3 空ディレクトリと隠しファイルしか入っていないディレクトリを一気に削除
Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('空ディレクトリを削除します')
$toastShowParams.Text2 = '　処理3/3 - 空ディレクトリを削除'
Show-ProgressToast @toastShowParams

$emptyDirs = @(Get-ChildItem -Path $script:downloadBaseDir -Directory -Recurse | Where-Object { @($_.GetFileSystemInfos().Where({ -not $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) })).Count -eq 0 })
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
			try { Remove-Item -LiteralPath $_ -Recurse -Force | Out-Null }
			catch { Write-Warning ('⚠️ - 空ディレクトリの削除に失敗しました: {0}' -f $_) }
		} -ThrottleLimit $script:multithreadNum
	} else {
		#並列化が無効の場合は従来型処理
		$emptyDirNum = 0
		$emptyDirTotal = $emptyDirs.Count
		$totalStartTime = Get-Date
		foreach ($dir in $emptyDirs) {
			$emptyDirNum++
			#処理時間の推計
			$secElapsed = (Get-Date) - $totalStartTime
			$secRemaining = -1
			if ($emptyDirNum -ne 1) {
				$secRemaining = [Int][Math]::Ceiling(($secElapsed.TotalSeconds / $emptyDirNum) * ($emptyDirTotal - $emptyDirNum))
				$minRemaining = ('残り時間 {0}分' -f ([Int][Math]::Ceiling($secRemaining / 60)))
				$progressRate = [Float]($emptyDirNum / $emptyDirTotal)
			} else {
				$minRemaining = ''
				$progressRate = 0
			}

			$toastUpdateParams.Title = $dir
			$toastUpdateParams.Rate = $progressRate
			$toastUpdateParams.LeftText = ('{0}/{1}' -f $emptyDirNum, $emptyDirTotal)
			$toastUpdateParams.RightText = $minRemaining
			Update-ProgressToast @toastUpdateParams

			Write-Output ('　{0}/{1} - {2}' -f $emptyDirNum, $emptyDirTotal, $dir)
			try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
			} catch { Write-Warning ('⚠️ - 空ディレクトリの削除に失敗しました: {0}' -f $dir) }
		}
	}
}
#----------------------------------------------------------------------

$script:guiMode = if ($args) { [String]$args[0] } else { '' }

$toastUpdateParams = @{
	Title     = '番組の移動'
	Rate      = 1
	LeftText  = ''
	RightText = '完了'
	Tag       = $script:appName
	Group     = 'Delete'
}
Update-ProgressToast @toastUpdateParams

Remove-Variable -Name args, toastShowParams, moveToPathsHash, moveFromPathsHash, moveDirs, moveDir, totalStartTime, dirNum, dirTotal, dir, secElapsed, secRemaining, minRemaining, progressRate, toastUpdateParams, targetFolderName, moveFromPath, moveToPath, emptyDirs, emptyDirTotal, emptyDirNum -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
Write-Output ('番組移動処理を終了しました。')
Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
