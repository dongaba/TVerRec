###################################################################################
#
#		TVerRec固有関数スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
Add-Type -AssemblyName 'System.Globalization' | Out-Null

#----------------------------------------------------------------------
# TVerRec Logo表示
#----------------------------------------------------------------------
function Show-Logo {
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# [Console]::ForegroundColor = 'Red'
	Write-Output ('⣴⠟⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦')
	Write-Output ('⣿⠀⠀⣿⣿⣿⣿⡿⠟⠛⠛⠛⠛⠳⢦⣄⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⢳⣄⠀⠀⠀⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣆⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣦⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⡟⠁⣀⣀⠈⢻⣿⠀⠋⢀⣀⡀⠙⣿⠀⠀⣿⣿⣿⠟⠀⢀⣿⡟⠁⣀⣀⠈⢻⣿⡟⠁⣀⣀⠈⢻⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⠏⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⠀⠾⠿⠿⠷⠀⣿⠀⣾⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⣠⣿⣿⠀⠾⠿⠿⠷⠀⣿⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠋⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣦⡀⠈⠻⠟⠁⢀⣴⣿⠀⢶⣶⣶⣶⣶⣿⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣧⠀⠘⣿⣿⠀⢶⣶⣶⣶⣶⣿⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⣿⣿⣷⣦⣤⣤⣤⣤⣴⣾⠋⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣦⡀⢀⣴⣿⣿⣿⣧⡀⠉⠉⢀⣼⣿⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣧⠀⠘⣿⣧⡀⠉⠉⢀⣼⣿⣧⡀⠉⠉⢀⣼⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠙⢷⣄⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⠻⣦⣤⣿⣿⣿⣿⣿⣿⣿⣿⣤⣤⣤⣤⣽⣷⣤⣤⣤⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟')
	# [Console]::ResetColor()
	Write-Output (" {0,$(72 - $script:appVersion.Length)}Version. {1}  " -f ' ', $script:appVersion)
}

#----------------------------------------------------------------------
# バージョン比較
#----------------------------------------------------------------------
function Compare-Version {
	param (
		[String]$remote,
		[String]$local
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($remote -eq $local) { return 0 }
	# バージョンを"."でユニットに切り分ける
	$remoteUnits = $remote -split '\.' | ForEach-Object { [Int]$_ }
	$localUnits = $local -split '\.' | ForEach-Object { [Int]$_ }
	# ユニット数が少ない方の表記に探索幅を合わせる
	$unitLength = [Math]::Min($remoteUnits.Count, $localUnits.Count)
	# 探索幅に従ってユニット毎に比較していく
	for ($i = 0; $i -lt $unitLength; $i++) {
		if ($remoteUnits[$i] -gt $localUnits[$i]) { return 1 }
		if ($remoteUnits[$i] -lt $localUnits[$i]) { return -1 }
	}
	# 個々のユニットが完全に一致している場合はユニット数が多い方が大きいとする
	return [Math]::Sign($remoteUnits.Count - $localUnits.Count)
	Remove-Variable -Name remote, local, remoteUnits, localUnits, unitLength, i -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# TVerRec最新化確認
#----------------------------------------------------------------------
function Invoke-TVerRecUpdateCheck {
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$progressPreference = 'silentlyContinue'
	Invoke-StatisticsCheck -Operation 'launch'
	# TVerRecの最新バージョン取得
	$repo = 'dongaba/TVerRec'
	$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)
	try {
		$appReleases = (Invoke-RestMethod -Uri $releases -Method 'GET' -TimeoutSec $script:timeoutSec).where{ !$_.prerelease }
		if (!$appReleases) { Write-Warning ($script:msg.ToolLatestNotIdentified -f 'TVerRec') ; return }
	} catch { Write-Warning ($script:msg.ToolLatestNotRetrieved -f 'TVerRec') ; return }
	finally { $progressPreference = 'Continue' }
	# GitHub側最新バージョンの整形
	$latestVersion = $appReleases[0].Tag_Name.Trim('v', ' ')	# v1.2.3 → 1.2.3
	$latestMajorVersion = $latestVersion.split(' ')[0]			# 1.2.3 beta 4 → 1.2.3
	# ローカル側バージョンの整形
	$appMajorVersion = $script:appVersion.split(' ')[0]			# 1.2.3 beta 4 → 1.2.3
	# バージョン判定
	$versionUp = (Compare-Version $latestMajorVersion $appMajorVersion) -gt 0
	# バージョンアップメッセージ
	if ($versionUp) {
		[Console]::ForegroundColor = 'Green'
		Write-Output ('')
		Write-Warning ($script:msg.ToolOutdated -f 'TVerRec')
		Write-Warning ($script:msg.ToolLocalVersion -f $script:appVersion)
		Write-Warning ($script:msg.ToolRemoteVersion -f $latestVersion)
		Write-Output ('')
		[Console]::ResetColor()
		# 変更履歴の表示
		foreach ($appRelease in @($appReleases.where({ $_.Tag_Name.Trim('v', ' ') -gt $appMajorVersion }))) {
			[Console]::ForegroundColor = 'Green'
			Write-Output ($script:msg.MediumBoldBorder)
			Write-Output ($script:msg.ToolUpdateLog -f $appRelease.tag_name)
			Write-Output ($script:msg.MediumBoldBorder)
			Write-Output $appRelease.body.Replace('###', '■')
			Write-Output ('')
			[Console]::ResetColor()
		}
		# 最新のアップデータを取得
		$latestUpdater = 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1'
		Invoke-WebRequest -Uri $latestUpdater -OutFile (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') -ConnectionTimeoutSeconds $script:timeoutSec
		if (!($IsLinux)) { Unblock-File -LiteralPath (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') }
		# アップデート実行
		Write-Warning ($script:msg.ToolUpdateInstruction -f 'TVerRec', 'update_tverrec')
		foreach ($i in (1..10)) {
			$complete = ('█' * $i) * 5
			$remaining = ('▁' * (10 - $i)) * 5
			Write-Warning ($script:msg.SecWaitRemaining -f $complete, $remaining, (10 - $i) )
			Start-Sleep -Second 1
		}
	}
	Remove-Variable -Name versionUp, repo, releases, appReleases, latestVersion, latestMajorVersion, appMajorVersion, appRelease, latestUpdater, i, complete, remaining -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ytdl/ffmpegの最新化確認
#----------------------------------------------------------------------
function Invoke-ToolUpdateCheck {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$scriptName,
		[Parameter(Mandatory = $true)][String]$targetName
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	& (Join-Path $scriptRoot ('functions/{0}' -f $scriptName) )
	if (!$?) { Throw ($script:msg.ToolUpdateFailed -f $targetName) }
	Remove-Variable -Name scriptName, targetName -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ファイル・ディレクトリの存在チェック、なければサンプルファイルコピー
#----------------------------------------------------------------------
function Invoke-TverrecPathCheck {
	Param (
		[Parameter(Mandatory = $true )][String]$path,
		[Parameter(Mandatory = $true )][String]$errorMessage,
		[Parameter(Mandatory = $false)][Switch]$isFile,
		[Parameter(Mandatory = $false)][String]$sampleFilePath,
		[Parameter(Mandatory = $false)][Boolean]$continue
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	$pathType = if ($isFile) { 'Leaf' } else { 'Container' }
	if (!(Test-Path $path -PathType $pathType)) {
		if (!($sampleFilePath -and (Test-Path $sampleFilePath -PathType 'Leaf'))) {
			if ($continue) { Write-Warning ($script:msg.NotExistContinue -f $errorMessage) ; return }
			else { Throw ($script:msg.NotExist -f $errorMessage) }
		}
		Copy-Item -LiteralPath $sampleFilePath -Destination $path -Force | Out-Null
	}
	Remove-Variable -Name path, errorMessage, isFile, sampleFilePath, continue, pathType -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function Invoke-RequiredFileCheck {
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:downloadBaseDir) { Throw ($script:msg.DirNotSpecified -f $script:msg.DownloadDir) }
	else { Invoke-TverrecPathCheck -Path $script:downloadBaseDir -errorMessage $script:msg.DownloadDir }
	$script:downloadBaseDir = $script:downloadBaseDir.TrimEnd('\/')
	if (!$script:downloadWorkDir) { Throw ($script:msg.DirNotSpecified -f $script:msg.WorkDir) }
	else { Invoke-TverrecPathCheck -Path $script:downloadWorkDir -errorMessage $script:msg.WorkDir }
	$script:downloadWorkDir = $script:downloadWorkDir.TrimEnd('\/')
	if ($script:saveBaseDir) {
		$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim().TrimEnd('\/')
		foreach ($saveDir in $script:saveBaseDirArray) { Invoke-TverrecPathCheck -Path $saveDir.Trim() -errorMessage $script:msg.SaveDir -continue $true }
	}
	Invoke-TverrecPathCheck -Path $script:ytdlPath -errorMessage 'youtube-dl' -isFile
	Invoke-TverrecPathCheck -Path $script:ffmpegPath -errorMessage 'ffmpeg' -isFile
	if ($script:simplifiedValidation) { Invoke-TverrecPathCheck -Path $script:ffprobePath -errorMessage 'ffprobe' -isFile }
	Invoke-TverrecPathCheck -Path $script:keywordFilePath -errorMessage $script:msg.KeywordFile -isFile -sampleFilePath $script:keywordFileSamplePath
	Invoke-TverrecPathCheck -Path $script:ignoreFilePath -errorMessage $script:msg.IgnoreFile -isFile -sampleFilePath $script:ignoreFileSamplePath
	Invoke-TverrecPathCheck -Path $script:histFilePath -errorMessage $script:msg.HistFile -isFile -sampleFilePath $script:histFileSamplePath
	Invoke-TverrecPathCheck -Path $script:listFilePath -errorMessage $script:msg.ListFile -isFile -sampleFilePath $script:listFileSamplePath
	Remove-Variable -Name saveDir -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function Read-KeywordList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$keywords = @()
	# コメントと空行を除いて抽出
	try { $keywords = @((Get-Content $script:keywordFilePath -Encoding UTF8).Where({ $_ -notmatch '^\s*$|^#.*$' })) }
	catch { Throw ($script:msg.LoadFailed -f $script:msg.KeywordFile) }
	return $keywords
	Remove-Variable -Name keywords -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード履歴の読み込み
#----------------------------------------------------------------------
function Read-HistoryFile {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$histFileData = @()
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$histFileData = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
	} catch { Throw ($script:msg.LoadFailed -f $script:msg.HistFile) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	return $histFileData
	Remove-Variable -Name histFileData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロードリストの読み込み
#----------------------------------------------------------------------
function Read-DownloadList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$listFileData = @()
	try {
		while (-not (Lock-File $script:listLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$listFileData = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
	} catch { Throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	return $listFileData
	Remove-Variable -Name listFileData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロードリストからダウンロードリンクの読み込み
#----------------------------------------------------------------------
function Get-LinkFromDownloadList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-Path $script:listFilePath -PathType Leaf) {
		try {
			while (-not (Lock-File $script:listLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			# 空行とダウンロード対象外を除き、EpisodeIDのみを抽出
			$videoLinks = @((Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_.EpisodeID -cmatch '^#') }) | Select-Object episodeID)
		} catch { Throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
		finally { Unlock-File $script:listLockFilePath | Out-Null }
	} else { $videoLinks = @() }
	$videoLinks = $videoLinks.episodeID -replace '^(.+)', 'https://tver.jp/episodes/$1'
	return @($videoLinks)
	Remove-Variable -Name videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード対象外番組の読み込み
#----------------------------------------------------------------------
function Read-IgnoreList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreTitles = @()
	try {
		while (-not (Lock-File $script:ignoreLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		# コメントと空行を除いて抽出
		$ignoreTitles = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^;.*$') }))
	} catch { Throw ($script:msg.LoadFailed -f $script:msg.IgnoreFile) }
	finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	return $ignoreTitles
	Remove-Variable -Name ignoreTitles -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function Update-IgnoreList {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][String]$ignoreTitle)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreLists = @()
	$ignoreComment = @()
	$ignoreTarget = @()
	$ignoreElse = @()
	$ignoreListNew = @()
	if (Test-Path $script:ignoreFilePath -PathType Leaf) {
		try {
			while (-not (Lock-File $script:ignoreLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			$ignoreLists = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where( { $_ -notmatch '^\s*$|^(;;.*)$' }))
			$ignoreComment = @(Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
			$ignoreTarget = @($ignoreLists.Where({ $_ -eq $ignoreTitle }) | Sort-Object -Unique)
			$ignoreElse = @($ignoreLists.Where({ $_ -notin $ignoreTitle }))
			if ($ignoreComment) { $ignoreListNew += $ignoreComment }
			if ($ignoreTarget) { $ignoreListNew += $ignoreTarget }
			if ($ignoreElse) { $ignoreListNew += $ignoreElse }
			try {
				# 改行コードLFを強制 + NFCで出力
				$ignoreListNew.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC) | Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline
				Write-Debug ($script:msg.IgnoreFileSortCompleted)
			} catch {
				# 更新後の対象外リストの書き込みに失敗したら読み込んだ対象外リストの出力を試みる
				$ignoreLists.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC) | Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline
				Write-Error ($script:msg.IgnoreFileSortFailed)
			}
		} catch { Write-Warning ($script:msg.IgnoreFileSortFailed) }
		finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	}
	Remove-Variable -Name ignoreTitle, ignoreLists, ignoreComment, ignoreTarget, ignoreElse, ignoreListNew -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# URLが既にダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryMatchCheck {
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Read-HistoryFile)
	if ($histFileData.Count -eq 0) { $histVideoPages = @() } else { $histVideoPages = @($histFileData.VideoPage) }
	# URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$histCompResult = @(Compare-Object -IncludeEqual $resultLinks $histVideoPages)
	try { $processedCount = ($histCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($histCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, histFileData, histVideoPages, histCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# URLが既にダウンロードリストに存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-ListMatchCheck {
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	# $listVideoPages = $listFileData | ForEach-Object { 'https://tver.jp/episodes/{0}' -f $_.EpisodeID.Replace('#', '') }
	$listVideoPages = New-Object System.Collections.Generic.List[String]
	foreach ($item in $listFileData) {
		$listVideoPages.Add('https://tver.jp/episodes/{0}' -f $item.EpisodeID.Replace('#', ''))
	}
	# URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = @(Compare-Object -IncludeEqual $resultLinks $listVideoPages)
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, listFileData, listVideoPages, listFileLine, listCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# URLが既にダウンロードリストまたはダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryAndListMatchCheck {
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoPages = New-Object System.Collections.Generic.List[Object]
	foreach ($listFileLine in $listFileData) { $listVideoPages.Add(@('https://tver.jp/episodes/{0}' -f $listFileLine.EpisodeID.Replace('#', ''))) }
	# ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Read-HistoryFile)
	$histVideoPages = if ($histFileData.Count -eq 0) { @() } else { $histFileData.VideoPage }
	# ダウンロードリストとダウンロード履歴をマージ
	$listVideoPages.AddRange($histVideoPages)
	# URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = Compare-Object -IncludeEqual $resultLinks $listVideoPages
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, listFileData, listVideoPages, listFileLine, histFileData, histVideoPages, listCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function Wait-YtdlProcess {
	[OutputType([Void])]
	Param ([Int32]$parallelDownloadFileNum)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# youtube-dlのプロセスが設定値を超えたら一時待機
	while ($true) {
		$ytdlCount = [Int](Get-YtdlProcessCount)
		# $ffmpegCount = [Int](Get-FfmpegProcessCount)
		# if (([Int]$ytdlCount + [Int]$ffmpegCount) -lt [Int]$parallelDownloadFileNum ) { break }
		if ([Int]$ytdlCount -lt [Int]$parallelDownloadFileNum ) { break }
		Write-Output ($script:msg.WaitingNumDownloadProc -f $parallelDownloadFileNum)
		# Write-Information ($script:msg.NumDownloadProc -f (Get-Date), ($ytdlCount + $ffmpegCount))
		Write-Information ($script:msg.NumDownloadProc -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 60
	}
	Remove-Variable -Name parallelDownloadFileNum, ytdlCount -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード履歴データの成形
#----------------------------------------------------------------------
function Format-HistoryRecord {
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	return [PSCustomObject]@{
		videoPage       = $videoInfo.episodePageURL
		videoSeriesPage = $videoInfo.seriesPageURL
		genre           = $videoInfo.keyword
		series          = $videoInfo.seriesName
		season          = $videoInfo.seasonName
		title           = $videoInfo.episodeName
		media           = $videoInfo.mediaName
		broadcastDate   = $videoInfo.broadcastDate
		downloadDate    = Get-TimeStamp
		videoDir        = $videoInfo.fileDir
		videoName       = $videoInfo.fileName
		videoPath       = $videoInfo.fileRelPath
		videoValidated  = $videoInfo.validated
	}
}

#----------------------------------------------------------------------
# ダウンロードリストデータの成形
#----------------------------------------------------------------------
function Format-ListRecord {
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$downloadListItem = [PSCustomObject]@{
		seriesName     = $videoInfo.seriesName
		seriesID       = $videoInfo.seriesID
		seriesPageURL  = $videoInfo.seriesPageURL
		seasonName     = $videoInfo.seasonName
		seasonID       = $videoInfo.seasonID
		episodeNo      = $videoInfo.episodeNum
		episodeName    = $videoInfo.episodeName
		episodeID      = $videoInfo.episodeID
		episodePageURL = $videoInfo.episodePageURL
		media          = $videoInfo.mediaName
		provider       = $videoInfo.providerName
		broadcastDate  = $videoInfo.broadcastDate
		endTime        = $videoInfo.endTime
		keyword        = $videoInfo.keyword
		ignoreWord     = $videoInfo.ignoreWord
	}
	if ($script:extractDescTextToList) { $downloadListItem | Add-Member -NotePropertyName descriptionText -NotePropertyValue $videoInfo.descriptionText }
	else { $downloadListItem | Add-Member -NotePropertyName descriptionText -NotePropertyValue '' }
	return $downloadListItem
	Remove-Variable -Name downloadListItem -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 「《」と「》」、「【」と「】」で挟まれた文字を除去
#----------------------------------------------------------------------
Function Remove-SpecialNote {
	Param ($text)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# 特殊文字の位置を取得し、長さを計算
	$length1 = [Math]::Max(0, $text.IndexOf('》') - $text.IndexOf('《'))
	$length2 = [Math]::Max(0, $text.IndexOf('】') - $text.IndexOf('【'))
	# 10文字以上あれば特殊文字とその間を削除
	if (($length1 -gt 10) -or ($length2 -gt 10)) { $text = ($text -replace '《.*?》|【.*?】', '').Replace('  ', ' ').Trim() }
	return $text
	Remove-Variable -Name text, length1, length2 -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function Invoke-VideoDownload {
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String][Ref]$keyword,
		[Parameter(Mandatory = $true )][String][Ref]$videoLink,
		[Parameter(Mandatory = $false)][Boolean]$force = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$newVideo = $null
	$skipDownload = $false
	$episodeID = $videoLink.Replace('https://tver.jp/episodes/', '')
	# TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ($script:msg.EpisodeInfoRetrievalFailed) ; continue }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	# ダウンロードファイル名を生成
	Format-VideoFileInfo ([Ref]$videoInfo)
	# 番組タイトルが取得できなかった場合はスキップ次の番組へ
	if (($videoInfo.fileName -eq '.mp4') -or ($videoInfo.fileName -eq '.ts')) { Write-Warning ($script:msg.EpisodeTitleRetrievalFailed) ; continue }
	# 番組情報のコンソール出力
	Show-VideoInfo ([Ref]$videoInfo)
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo ([Ref]$videoInfo) }
	if ($force) {
		$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
		$newVideo = Format-HistoryRecord ([Ref]$videoInfo)
	} else {
		# ここまで来ているということはEpisodeIDでは履歴とマッチしなかったということ
		# 考えられる原因は履歴ファイルがクリアされてしまっていること、または、EpisodeIDが変更になったこと
		#	履歴ファイルに存在する	→番組IDが変更になったあるいは、番組名の重複
		#		ID変更時のダウンロード設定あり
		#			検証済	→再ダウンロード
		#			検証中	→元々の番組IDとしてはそのうち検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
		#			未検証	→元々の番組IDとしては次回検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
		#		ID変更時のダウンロード設定なし
		#			検証済	→元々の番組IDとしては問題ないのでSKIP
		#			検証中	→元々の番組IDとしてはそのうち検証されるのでSKIP
		#			未検証	→元々の番組IDとしては次回検証されるのでSKIP
		#	履歴ファイルに存在しない
		#		ファイルが存在する	→検証だけする
		#		ファイルが存在しない
		#			ダウンロード対象外リストに存在する	→無視
		#			ダウンロード対象外リストに存在しない	→ダウンロード
		#ダウンロード履歴ファイルのデータを読み込み
		$histFileData = @(Read-HistoryFile)
		if ($videoInfo.fileRelPath) { $histMatch = @($histFileData.Where({ $_.videoPath -eq $videoInfo.fileRelPath })) }
		else { Write-Warning ($script:msg.FileNameRetrievalFailed) ; continue }

		if ($script:downloadWhenEpisodeIdChanged) {
			if (($histMatch.Count -ne 0) -or (Test-Path $videoInfo.filePath)) {
				$ignoreTitles = @(Read-IgnoreList)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (($videoInfo.fileName -like ('*{0}*' -f $ignoreTitle)) -or ($videoInfo.seriesName -like ('*{0}*' -f $ignoreTitle))) {
						# エピソードIDが変更になったがダウンロード対象外リストと合致	→無視する
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
						$videoInfo.fileName = '-- IGNORED --'
						$videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord ([Ref]$videoInfo) ; $skipDownload = $true
						break
					}
				}
				# エピソードIDが変更になった	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeIdChanged)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord ([Ref]$videoInfo)
				}
			} else {
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
				$ignoreTitles = @(Read-IgnoreList)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (($videoInfo.fileName -like ('*{0}*' -f $ignoreTitle)) -or ($videoInfo.seriesName -like ('*{0}*' -f $ignoreTitle))) {
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
						$videoInfo.fileName = '-- IGNORED --'
						$videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord ([Ref]$videoInfo) ; $skipDownload = $true
						break
					}
				}
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeAdded)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord ([Ref]$videoInfo)
				}
			}
		} else {
			if ($histMatch.Count -ne 0) {
				# 履歴ファイルに存在する	→スキップして次のファイルに
				Write-Warning ($script:msg.DownloadHistExists)
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '1' ; $videoInfo.fileName = '-- SKIPPED --'
				$newVideo = Format-HistoryRecord ([Ref]$videoInfo) ; $skipDownload = $true
			} elseif (Test-Path $videoInfo.filePath) {
				# 履歴ファイルに存在しないが、実ファイルが存在する	→検証だけする
				Write-Warning ($script:msg.DownloadFileExists)
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- SKIPPED --'
				$newVideo = Format-HistoryRecord ([Ref]$videoInfo) ; $skipDownload = $true
			} else {
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
				$ignoreTitles = @(Read-IgnoreList)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (($videoInfo.fileName -like ('*{0}*' -f $ignoreTitle)) -or ($videoInfo.seriesName -like ('*{0}*' -f $ignoreTitle))) {
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- IGNORED --' ; $videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord ([Ref]$videoInfo) ; $skipDownload = $true
						break
					}
				}
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeAdded)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord ([Ref]$videoInfo)
				}
			}
		}
	}

	# ダウンロード履歴CSV書き出し
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$newVideo | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append
		Write-Debug ($script:msg.HistWritten)
	} catch { Write-Warning ($script:msg.HistUpdateFailed) ; continue }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	# スキップ対象やダウンロード対象外は飛ばして次のファイルへ
	if ($skipDownload) { continue }
	# 番組ディレクトリがなければ作成
	if ($script:sortVideoBySeries -and !(Test-Path $videoInfo.fileDir -PathType Container)) {
		try { New-Item -ItemType Directory -Path $videoInfo.fileDir -Force | Out-Null }
		catch { Write-Warning ($script:msg.CreateEpisodeDirFailed) ; continue }
	}
	# youtube-dl起動
	if ($script:ytdlRandomIp -and $script:proxyUrl) {
		Write-Output ($script:msg.MediumBoldBorder)
		Write-Output ($script:msg.NotifyYtdlOptions1)
		Write-Output ($script:msg.NotifyYtdlOptions2)
		Write-Output ($script:msg.NotifyYtdlOptions3)
		Write-Output ($script:msg.MediumBoldBorder)
	}
	try { Invoke-Ytdl ([Ref]$videoInfo) }
	catch { Write-Warning ($script:msg.InvokeYtdlFailed) }
	# 5秒待機
	Start-Sleep -Seconds 5
	Remove-Variable -Name keyword, videoLink, force, newVideo, skipDownload, episodeID, histFileData, histMatch, ignoreTitles, ignoreTitle -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function Update-VideoList {
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String][Ref]$keyword,
		[Parameter(Mandatory = $true)][String][Ref]$videoLink
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreWord = ''
	$newVideo = $null
	$ignore = $false
	$episodeID = $videoLink.Replace('https://tver.jp/episodes/', '')
	# TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ($script:msg.EpisodeInfoRetrievalFailed) ; continue }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	# ダウンロード対象外に入っている番組の場合はリスト出力しない
	$ignoreTitles = @(Read-IgnoreList)
	foreach ($ignoreTitle in $ignoreTitles) {
		if ($ignoreTitle) {
			if (($videoInfo.seriesName -cmatch [RegEx]::Escape($ignoreTitle)) -or ($videoInfo.episodeName -cmatch [RegEx]::Escape($ignoreTitle))) {
				$ignoreWord = $ignoreTitle ; Update-IgnoreList $ignoreTitle ; $ignore = $true
				$videoInfo.episodeID = ('#{0}' -f $videoInfo.episodeID)
				break
			}
		}
	}
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'ignoreWord' -Value $ignoreWord
	# 番組情報のコンソール出力
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo ([Ref]$videoInfo) }
	# スキップフラグが立っているかチェック
	if ($ignore) { Write-Warning ($script:msg.ListIgnoredAdded) ; $newVideo = Format-ListRecord ([Ref]$videoInfo) }
	else { Write-Output ($script:msg.ListAdded) ; $newVideo = Format-ListRecord ([Ref]$videoInfo) }
	# ダウンロードリストCSV書き出し
	try {
		while ((Lock-File $script:listLockFilePath).result -ne $true) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append
		Write-Debug ($script:msg.ListWritten)
	} catch { Write-Warning ($script:msg.ListUpdateFailed) ; continue }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	Remove-Variable -Name keyword, videoLink, ignoreWord, newVideo, ignore, episodeID, ignoreTitles, ignoreTitle -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 保存ファイル名を設定
#----------------------------------------------------------------------
function Format-VideoFileInfo {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$videoName = ''
	# ファイル名を生成
	if ($script:addSeriesName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seriesName) }
	if ($script:addSeasonName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seasonName) }
	if ($videoName.Trim() -ne $videoInfo.episodeName.Trim() ) {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターンもある
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
		$videoName = ('{0}{1}' -f $videoName, $videoInfo.episodeName)
	} else {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate) }
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
	}
	# ファイル名にできない文字列を除去
	$videoName = (Get-FileNameWithoutInvalidChars $videoName).Replace('  ', ' ').Trim()
	# SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング。youtube-dlの中間ファイル等を考慮して安全目の上限値
	$fileNameLimit = $script:fileNameLengthMax - 30
	if ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
		while ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) { $videoName = $videoName.Substring(0, $videoName.Length - 1) }
		$videoName = ('{0}……' -f $videoName)
	}
	$videoName = Get-FileNameWithoutInvalidChars ('{0}.{1}' -f $videoName, $script:videoContainerFormat)
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileName' -Value $videoName
	# フォルダ名を生成
	if ($script:sortVideoBySeries) {
		$videoFileDir = Get-FileNameWithoutInvalidChars (Remove-SpecialCharacter ('{0} {1}' -f $videoInfo.seriesName, $videoInfo.seasonName ).Trim(' ', '.'))
		if ($script:sortVideoByMedia) { $videoFileDir = (Join-Path $script:downloadBaseDir (Get-FileNameWithoutInvalidChars $videoInfo.mediaName) | Join-Path -ChildPath $videoFileDir) }
		else { $videoFileDir = (Join-Path $script:downloadBaseDir $videoFileDir) }
		$videoFilePath = Join-Path $videoFileDir $videoInfo.fileName
	} else {
		$videoFileDir = $script:downloadBaseDir
		$videoFilePath = $videoInfo.fileName
	}
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileDir' -Value $videoFileDir
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'filePath' -Value $videoFilePath
	$videoFileRelPath = $videoInfo.filePath.Replace($script:downloadBaseDir, '').Replace('\', '/').TrimStart('/')
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileRelPath' -Value $videoFileRelPath
	Remove-Variable -Name videoName, fileNameLimit, videoFileDir, videoFilePath, videoFileRelPath -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 番組情報表示
#----------------------------------------------------------------------
function Show-VideoInfo {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Output ($script:msg.EpisodeName -f $videoInfo.fileName.Replace($script:videoContainerFormat, ''))
	Write-Output ($script:msg.BroadcastDate -f $videoInfo.broadcastDate)
	Write-Output ($script:msg.MediaName -f $videoInfo.mediaName)
	Write-Output ($script:msg.EndDate -f $videoInfo.endTime)
	# Write-Output ($script:msg.IsBrightcove -f $videoInfo.isBrightcove)
	# Write-Output ($script:msg.IsStreaks -f $videoInfo.isStreaks)
	Write-Output ($script:msg.EpisodeDetail -f $videoInfo.descriptionText)
}
#----------------------------------------------------------------------
# 番組情報デバッグ表示
#----------------------------------------------------------------------
function Show-VideoDebugInfo {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Debug $videoInfo.episodePageURL
}

#----------------------------------------------------------------------
# ffmpegを使ったダウンロードプロセスの起動
#----------------------------------------------------------------------
# function Invoke-FfmpegDownload {
# 	[OutputType([Void])]
# 	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
# 	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
# 	Invoke-StatisticsCheck -Operation 'download-ffmpeg'
# 	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
# 	$ffmpegArgs = @()
# 	$ffmpegArgs += (' -y -http_multiple 1 -seg_max_retry 10 -timeout 5000000')
# 	$ffmpegArgs += (' -reconnect 1 -reconnect_on_network_error 1 -reconnect_on_http_error 1 -reconnect_streamed 1')
# 	$ffmpegArgs += (' -reconnect_max_retries 10 -reconnect_delay_max 30 -reconnect_delay_total_max 600')
# 	$ffmpegArgs += (' -i "{0}"' -f $videoInfo.m3u8URL)
# 	if ($script:videoContainerFormat -eq 'mp4') {
# 		$ffmpegArgs += (' -c copy')
# 		$ffmpegArgs += (' -c:v copy -c:a copy')
# 		# $ffmpegArgs += (' -bsf:a aac_adtstoasc')
# 		$ffmpegArgs += (' -c:s mov_text')
# 		$ffmpegArgs += (' -metadata:s:s:0 language=ja')
# 	}
# 	$ffmpegArgs += (' "{0}"' -f $videoInfo.filePath)
# 	$ffmpegArgsString = $ffmpegArgs -join ''
# 	Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $ffmpegArgsString)
# 	if ($script:appName -eq 'TVerRecContainer') {
# 		$startProcessParams = @{
# 			FilePath     = 'timeout'
# 			ArgumentList = "3600 $script:ffmpegPath $ffmpegArgsString"
# 			PassThru     = $true
# 		}
# 	} else {
# 		$startProcessParams = @{
# 			FilePath     = $script:ffmpegPath
# 			ArgumentList = $ffmpegArgsString
# 			PassThru     = $true
# 		}
# 	}
# 	if ($IsWindows) { $startProcessParams.WindowStyle = $script:windowShowStyle }
# 	else {
# 		$startProcessParams.RedirectStandardOutput = '/dev/null'
# 		$startProcessParams.RedirectStandardError = '/dev/zero'
# 	}
# 	try {
# 		$ffmpegProcess = Start-Process @startProcessParams
# 		$ffmpegProcess.Handle | Out-Null
# 	} catch { Write-Warning ($script:msg.ExecFailed -f 'ffmpeg') ; return }
# 	Remove-Variable -Name ffmpegArgs, ffmpegArgsString -ErrorAction SilentlyContinue
# }

#----------------------------------------------------------------------
# youtube-dlプロセスの起動
#----------------------------------------------------------------------
function Invoke-Ytdl {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'download'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $videoInfo.fileDir)

	$ytdlArgs = @(
		$script:ytdlBaseArgs
		('{0} {1}' -f '--concurrent-fragments', $script:parallelDownloadNumPerFile)
		('{0} {1}' -f '--add-header', $script:ytdlHttpHeader)
		('{0} "{1}"' -f '--paths', $saveDir)
		('{0} "{1}"' -f '--paths', $tmpDir)
		('{0} "{1}"' -f '--ffmpeg-location', $script:ffmpegPath)
	)
	if ($script:proxyUrl) { $ytdlArgs += ('{0} {1}' -f '--geo-verification-proxy', $script:proxyUrl) }
	if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { $ytdlArgs += ('{0} "{1}/32"' -f '--xff', $script:jpIP) }
	if ($script:rateLimit -notin @(0, '')) {
		$rateLimit = [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8)
		$ytdlArgs += ('{0} {1}M' -f '--limit-rate', $rateLimit)
	}
	if ($script:videoContainerFormat -eq 'mp4') {
		$ytdlArgs += '--merge-output-format mp4 --embed-thumbnail --embed-chapters'
		$ytdlArgs += @('subtitle', 'thumbnail', 'chapter', 'description') | ForEach-Object { ('{0} "{1}:{2}"' -f '--paths', $_, $script:downloadWorkDir) }
		if ($script:embedSubtitle) { $ytdlArgs += '--sub-langs all --convert-subs srt --embed-subs' }
		if ($script:embedMetatag) { $ytdlArgs += '--embed-metadata' }
	}

	$pwshRemoveIfExists = 'Remove-Item -LiteralPath ''{0}'' -Force -ErrorAction SilentlyContinue' -f $videoInfo.filePath
	$ytdlTempOutFile = ('{0}/{1}.{2}' -f $videoInfo.fileDir, $videoInfo.episodeID, $script:videoContainerFormat)
	$pwshRenameFile = 'Rename-Item -LiteralPath ''{0}'' -NewName ''{1}'' -Force -ErrorAction SilentlyContinue' -f $ytdlTempOutFile, $videoInfo.fileName
	$ytdlExecArg = 'pwsh -Command \"{0} ; {1}\"' -f $pwshRemoveIfExists, $pwshRenameFile
	$ytdlArgs += ('--exec "after_video:{0}"' -f $ytdlExecArg)
	$ytdlArgs += $script:ytdlOption, $videoInfo.episodePageURL, ('{0} "{1}.{2}"' -f '--output', $videoInfo.episodeID, $script:videoContainerFormat)

	$ytdlArgsString = $ytdlArgs -join ' '
	Write-Debug ($script:msg.ExecCommand -f 'youtube-dl', $script:ytdlPath, $ytdlArgsString)

	$startProcessParams = @{
		FilePath     = if ($script:appName -eq 'TVerRecContainer') { 'timeout' } else { $script:ytdlPath }
		ArgumentList = if ($script:appName -eq 'TVerRecContainer') { "3600 $script:ytdlPath $ytdlArgsString" } else { $ytdlArgsString }
		PassThru     = $true
	}
	if ($IsWindows) { $startProcessParams.WindowStyle = $script:windowShowStyle }
	else {
		$startProcessParams.RedirectStandardOutput = '/dev/null'
		$startProcessParams.RedirectStandardError = '/dev/zero'
	}
	try {
		$ytdlProcess = Start-Process @startProcessParams
		$ytdlProcess.Handle | Out-Null
	} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
	Remove-Variable -Name tmpDir, saveDir, saveFile, ytdlArgs, paths, ytdlArgsString, pwshRemoveIfExists, ytdlTempOutFile, pwshRenameFile, ytdlExecArg, startProcessParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlプロセスの起動 (TVer以外のサイトへの対応)
#----------------------------------------------------------------------
function Invoke-NonTverYtdl {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][Alias('URL')][String]$videoPageURL)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'nontver'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $script:downloadBaseDir)
	$saveFile = ('{0}' -f $script:ytdlNonTVerFileName)

	$ytdlArgs = @(
		$script:nonTVerYtdlBaseArgs
		('{0} {1}' -f '--concurrent-fragments', $script:parallelDownloadNumPerFile)
		('{0} {1}' -f '--add-header', $script:ytdlHttpHeader)
		('{0} "{1}"' -f '--paths', $saveDir)
		('{0} "{1}"' -f '--paths', $tmpDir)
		('{0} "{1}"' -f '--ffmpeg-location', $script:ffmpegPath)
		$(if ($script:proxyUrl) { "--geo-verification-proxy $script:proxyUrl" })
		$(if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { "--xff $script:jpIP/32" })
		$(if ($script:rateLimit -notin @(0, '')) {
				$rateLimit = [math]::Ceiling([int]$script:rateLimit / $script:parallelDownloadNumPerFile / 8)
				"--limit-rate ${rateLimit}M"
			})
		'--merge-output-format mp4 --embed-thumbnail --embed-chapters'
		$(@('subtitle', 'thumbnail', 'chapter', 'description') | ForEach-Object { ('{0} "{1}:{2}"' -f '--paths', $_, $script:downloadWorkDir) })
		$(if ($script:embedSubtitle) { '--sub-langs all --convert-subs srt --embed-subs' })
		$(if ($script:embedMetatag) { '--embed-metadata' })
		$script:ytdlOption
		"$videoPageURL"
		"--output `"$saveFile`""
	)
	$ytdlArgsString = $ytdlArgs -join ' '
	Write-Debug ($script:msg.ExecCommand -f 'youtube-dl', $script:ytdlPath, $ytdlArgsString)
	$startProcessParams = @{
		FilePath     = if ($script:appName -eq 'TVerRecContainer') { 'timeout' } else { $script:ytdlPath }
		ArgumentList = if ($script:appName -eq 'TVerRecContainer') { "3600 $script:ytdlPath $ytdlArgsString" } else { $ytdlArgsString }
		PassThru     = $true
	}
	if ($IsWindows) { $startProcessParams.WindowStyle = $script:windowShowStyle }
	else {
		$startProcessParams.RedirectStandardOutput = '/dev/null'
		$startProcessParams.RedirectStandardError = '/dev/zero'
	}
	try {
		$ytdlProcess = Start-Process @startProcessParams
		$ytdlProcess.Handle | Out-Null
	} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
	Remove-Variable -Name videoPageURL, tmpDir, baseDir, subttlDir, thumbDir, chaptDir, descDir, saveFile, ytdlArgs, ytdlArgsString, rateLimit, startProcessParams, ytdlProcess -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlのプロセスカウントを取得
#----------------------------------------------------------------------
function Get-YtdlProcessCount {
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$processName = switch ($script:preferredYoutubedl) {
		'yt-dlp' { 'yt-dlp' }
		'ytdl-patched' { 'youtube-dl' }
		'yt-dlp-nightly' { 'yt-dlp' }
	}
	try {
		switch ($true) {
			$IsWindows { return [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2, [MidpointRounding]::AwayFromZero ); continue }
			$IsLinux { return @(Get-Process -ErrorAction Ignore -Name $processName).Count ; continue }
			$IsMacOS { $psCmd = 'ps' ; return (& $psCmd | grep yt-dlp | grep -v grep | grep -c ^).Trim() ; continue }
			default { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
		}
	} catch { return 0 }
	Remove-Variable -Name processName, psCmd -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ffmpegのプロセスカウントを取得
#----------------------------------------------------------------------
function Get-FfmpegProcessCount {
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$processName = 'ffmpeg'
	try {
		switch ($true) {
			$IsWindows { return [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name $processName).Count, [MidpointRounding]::AwayFromZero ); continue }
			$IsLinux { return @(Get-Process -ErrorAction Ignore -Name $processName).Count ; continue }
			$IsMacOS { $psCmd = 'ps' ; return (& $psCmd | grep ffmpeg | grep -v grep | grep -c ^).Trim() ; continue }
			default { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
		}
	} catch { return 0 }
	Remove-Variable -Name processName, psCmd -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function Wait-DownloadCompletion () {
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = [Int](Get-YtdlProcessCount)
	# $ffmpegCount = [Int](Get-FfmpegProcessCount)
	# while (($ytdlCount + $ffmpegCount) -ne 0) {
	while ($ytdlCount -ne 0) {
		# Write-Information ($script:msg.NumDownloadProc -f (Get-Date), ($ytdlCount + $ffmpegCount))
		Write-Information ($script:msg.NumDownloadProc -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 60
		$ytdlCount = [Int](Get-YtdlProcessCount)
		# $ffmpegCount = [Int](Get-FfmpegProcessCount)
	}
	Remove-Variable -Name ytdlCount -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロードスケジュールに合わせたスケジュール制御
#----------------------------------------------------------------------
function Suspend-Process () {
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($script:scheduleStop) {
		Write-Debug ('Checking execution schedule')
		while ($true) {
			$currentDateTime = Get-Date
			$currentDay = ($currentDateTime).DayOfWeek.ToString().Substring(0, 3)
			$currentHour = ($currentDateTime).Hour
			if ($script:stopSchedule.ContainsKey($currentDay)) {
				if ($script:stopSchedule[$currentDay] -contains $currentHour) {
					Write-Output ($script:msg.WaitSuspendTime -f ($currentDateTime))
					# 次の正時までの時間差を計算
					$timeDifference = $currentDateTime.AddHours(1).Date.AddHours($currentDateTime.Hour + 1) - $currentDateTime
					Start-Sleep -Seconds ([math]::Ceiling($timeDifference.TotalSeconds))
				} else { break }
			} else { break }
		}
	}
	Remove-Variable -Name currentDateTime, currentDay, currentHour, timeDifference -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function Optimize-HistoryFile {
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$cleanedHist = @()
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$originalLists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$cleanedHist = $originalLists.Where({
			($null -ne $_.videoValidated) `
					-and ([Int]::TryParse($_.videoValidated, [Ref]0)) `
					-and ([DateTime]::TryParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null, [System.Globalization.DateTimeStyles]::None, [Ref]([DateTime]::MinValue)))
			})
		try { $cleanedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch {
			# 不整合解消後のダウンロード履歴の書き込みに失敗したら読み込んだダウンロード履歴の出力を試みる
			$originalLists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		}
	} catch { Write-Warning ($script:msg.OptimizeHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name cleanedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 指定日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function Limit-HistoryFile {
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][Int32]$retentionPeriod)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$originalLists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$purgedHist = $originalLists.Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * $retentionPeriod) })
		try { $purgedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch {
			# 指定日以上前の履歴を削除後のダウンロード履歴の書き込みに失敗したら読み込んだダウンロード履歴の出力を試みる
			$originalLists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		}
	} catch { Write-Warning ($script:msg.CleanupHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name retentionPeriod, purgedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function Repair-HistoryFile {
	[OutputType([Void])]
	Param ()
	# $uniquedHist = @()
	$uniquedHist = New-Object System.Collections.Generic.List[Object]
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$originalLists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		# videoPageで1つしかないもの残し、ダウンロード日時でソート
		$uniquedHist = @(($originalLists | Group-Object -Property 'videoPage').Where({ $_.Count -eq 1 }) | ForEach-Object { $_.Group } | Sort-Object -Property downloadDate)
		$uniquedHist = $uniquedHist | Sort-Object -Property downloadDate
		try { $uniquedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch {
			# 重複削除後のダウンロード履歴の書き込みに失敗したら読み込んだダウンロード履歴の出力を試みる
			$originalLists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		}
	} catch { Write-Warning ($script:msg.DistinctHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name uniquedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ffmpeg/ffprobeプロセスの起動
#----------------------------------------------------------------------
function Invoke-FFmpegProcess {
	param (
		[String]$filePath,
		[String]$ffmpegArgs,
		[String]$execName
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$commonParams = @{
		FilePath              = $filePath
		ArgumentList          = $ffmpegArgs
		PassThru              = $true
		RedirectStandardError = $script:ffmpegErrorLogPath
		Wait                  = $true
	}
	Invoke-StatisticsCheck -Operation 'validate'
	if ($IsWindows) { $commonParams.WindowStyle = $script:windowShowStyle }
	else { $commonParams.RedirectStandardOutput = '/dev/null' }
	try {
		# プロセスの開始
		$process = Start-Process @commonParams
		$process.Handle | Out-Null  # プロセスハンドルをキャッシュ。PS7.4.0の終了コードを捕捉しないバグのために必要
		$process.WaitForExit()
	} catch { Write-Warning ($script:msg.ExecFailed -f $execName) ; return }
	return $process.ExitCode
	Remove-Variable -Name commonParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 番組の整合性チェック
#----------------------------------------------------------------------
function Invoke-IntegrityCheck {
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$videoHist,
		[Parameter(Mandatory = $false)][String]$decodeOption = ''
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ffmpegProcessExitCode = 0
	$errorCount = 0
	$checkStatus = 0
	$videoFilePath = Join-Path (Convert-Path $script:downloadBaseDir) $videoHist.videoPath
	try { New-Item -Path $script:ffmpegErrorLogPath -ItemType File -Force | Out-Null }
	catch { Write-Warning ($script:msg.InitializeErrorFileFailed) ; return }

	# これからチェックする番組のステータスをチェック
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$checkStatus = ($videoHists.Where({ $_.videoPage -eq $videoHist.videoPage })).videoValidated
		switch ($checkStatus) {
			# 0:未チェック、1:チェック済、2:チェック中、レコードなしは履歴が削除済み
			# 「0:未チェック」のレコードは「2:チェック中」に変更して出力
			# 「0:未チェック」以外のステータスの際はスキップして次を処理
			'0' {
				$videoHists.Where({ $_.videoPage -eq $videoHist.videoPage }).Where({ $_.videoValidated = '2' })
				$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
				continue
			}
			'1' { Write-Output ($script:msg.ValidationCompleted) ; return }
			'2' { Write-Output ($script:msg.ValidationInProgress) ; return }
			default { Write-Warning ($script:msg.HistRecordRemoved -f $videoHist.videoPage) ; return }
		}
	} catch { Write-Warning ($script:msg.HistUpdateFailed) ; return }
	finally { Unlock-File $script:histLockFilePath | Out-Null }

	if ($script:simplifiedValidation) {
		# ffprobeを使った簡易検査
		$ffprobeArgs = ('-hide_banner -v error -err_detect explode -i "{0}"' -f $videoFilePath)
		Write-Debug ($script:msg.ExecCommand -f 'ffprobe', $script:ffprobePath, $ffprobeArgs)
		$ffmpegProcessExitCode = Invoke-FFmpegProcess -filePath $script:ffprobePath -ffmpegArgs $ffprobeArgs -execName 'ffprobe'
	} else {
		# ffmpegを使った完全検査
		$ffmpegArgs = ('-hide_banner -v error -xerror {0} -i "{1}" -f null - ' -f $decodeOption, $videoFilePath)
		Write-Debug ($script:msg.ExecCommand -f 'ffmpeg', $script:ffmpegPath, $ffmpegArgs)
		$ffmpegProcessExitCode = Invoke-FFmpegProcess -filePath $script:ffmpegPath -ffmpegArgs $ffmpegArgs -execName 'ffmpeg'
	}

	# ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffmpegErrorLogPath) {
			$errorCount = (Get-Content -LiteralPath $script:ffmpegErrorLogPath | Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffmpegErrorLogPath -Encoding UTF8 | Write-Debug
		}
	} catch { Write-Warning ($script:msg.ErrorCountFailed) ; $errorCount = 9999999 }
	# エラーをカウントしたらファイルを削除
	try { if (Test-Path $script:ffmpegErrorLogPath) { Remove-Item -LiteralPath $script:ffmpegErrorLogPath -Force -ErrorAction SilentlyContinue | Out-Null } }
	catch { Write-Warning ($script:msg.DeleteErrorFailed) }

	# 終了コードが0以外 または エラーが一定以上
	if (($ffmpegProcessExitCode -ne 0) -or ($errorCount -gt 30)) {
		# ダウンロード履歴とファイルを削除
		Write-Warning ($script:msg.ValidationNG) ; Write-Verbose ($script:msg.ErrorCount -f $ffmpegProcessExitCode, $errorCount)
		$script:validationFailed = $true
		# 整合性検証に失敗したダウンロードファイルをダウンロード履歴から削除
		try {
			while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			$originalHistFile = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			# 該当の番組のレコードを削除
			$updatedHistFile = @($originalHistFile.Where({ $_.videoPage -ne $videoHist.videoPage }))
			try { $updatedHistFile | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
			catch {
				# 該当の番組のレコード削除後のダウンロード履歴の書き込みに失敗したら読み込んだダウンロード履歴の出力を試みる
				$originalHistFile | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
			}
		} catch { Write-Warning ($script:msg.HistUpdateFailed) }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
		# 破損しているダウンロードファイルを削除
		try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction SilentlyContinue | Out-Null }
		catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
	} else {
		# 終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
		Write-Output ($script:msg.ValidationOK)
		try {
			while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			$originalHistFile = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			# 該当の番組のチェックステータスを1に
			$updatedHistFile = $originalHistFile
			$updatedHistFile.Where({ $_.videoPage -eq $videoHist.videoPage }).Where({ $_.videoValidated = '1' })
			try { $updatedHistFile | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
			catch {
				# 該当の番組のチェックステータス更新後のダウンロード履歴の書き込みに失敗したら読み込んだダウンロード履歴の出力を試みる
				$originalHistFile | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
			}
		} catch { Write-Warning ($script:msg.HistUpdateFailed) }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
	}
	Remove-Variable -Name ffmpegProcessExitCode, decodeOption, errorCount, checkStatus, videoFilePath, videoHists, ffprobeArgs, ffmpegProcess, ffmpegArgs -ErrorAction SilentlyContinue
}

# region 環境
#----------------------------------------------------------------------
# 設定取得
#----------------------------------------------------------------------
function Get-Setting {
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$filePathList = @((Join-Path $script:confDir 'system_setting.ps1'), (Join-Path $script:confDir 'user_setting.ps1'))
	$configList = @{}
	foreach ($filePath in $filePathList) {
		if (Test-Path $filePath) {
			$configs = (Select-String $filePath -Pattern '^(\$.+)=(.+)(\s*)$').ForEach({ $_.line })
			$excludePattern = '(.*PSStyle.*|.*Base64)'
			foreach ($config in $configs) {
				$configParts = $config -split '='
				$key = $configParts[0].Replace('script:', '').Replace('$', '').Trim()
				if (!($key -match $excludePattern) -and (Get-Variable -Name $key)) { $configList[$key] = (Get-Variable -Name $key).Value }
			}
		}
	}
	return $configList.GetEnumerator() | Sort-Object -Property key
	Remove-Variable -Name configList, configs, excludePattern, filePath, filePathList, key, config, configParts -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 統計取得
#----------------------------------------------------------------------
function Invoke-StatisticsCheck {
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$operation,
		[Parameter(Mandatory = $false)][String]$tverType = 'none',
		[Parameter(Mandatory = $false)][String]$tverID = 'none'
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $operation)
	if (!$env:PESTER) {
		$progressPreference = 'silentlyContinue'
		$statisticsBase = 'https://hits.sh/github.com/dongaba/TVerRec/'
		try { Invoke-WebRequest -Uri ('{0}{1}.svg' -f $statisticsBase, $operation) -Method 'GET' -ConnectionTimeoutSeconds 5 | Out-Null }
		catch { Write-Debug ('Failed to collect count') }
		finally { $progressPreference = 'Continue' }
		if ($operation -eq 'search') { return }
		$epochTime = [Int64]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000)
		$userProperties = @{	# max 25 properties, max 24 chars of property name, 36 chars of property value
			PSVersion    = @{ 'value' = $PSVersionTable.PSVersion.ToString() }
			AppName      = @{ 'value' = $script:appName }
			AppVersion   = @{ 'value' = $script:appVersion }
			OS           = @{ 'value' = $script:os }
			Kernel       = @{ 'value' = $script:kernel }
			Architecture = @{ 'value' = $script:arch }
			Locale       = @{ 'value' = $script:locale }
			TimeZone     = @{ 'value' = $script:tz }
		}
		foreach ($clientEnv in $script:clientEnvs.GetEnumerator() ) {
			$value = [String]$clientEnv.Value
			$userProperties[$clientEnv.Key] = @{ 'value' = $value.Substring(0, [Math]::Min($value.Length, 36)) }
		}
		$eventParams = @{}	# max 25 parameters, max 40 chars of property name, 100 chars of property value
		foreach ($clientSetting in $script:clientSettings) {
			if (!($clientSetting.Name -match '(.*Schedule|my.*|embed.*|.*Update.*|.*Dir|.*Path|app.*|timeout.*|.*Preference|.*Max|.*Period|parallel.*|.*BaseArgs|.*FileName)')) {
				$paramValue = [String]((Get-Variable -Name $clientSetting.Name).Value)
				$eventParams[$clientSetting.Key] = $paramValue.Substring(0, [Math]::Min($paramValue.Length, 99))
			}
		}
		$gaBody = [PSCustomObject]@{
			client_id            = $script:guid
			timestamp_micros     = $epochTime
			non_personalized_ads = $true
			user_properties      = $userProperties
			events               = @(	# max 25 events, 40 chars of event name
				@{
					name   = $operation
					params = $eventParams
				}
			)
		} | ConvertTo-Json -Depth 3
		if ($DebugPreference -eq 'Continue') { $gaURL = 'https://www.google-analytics.com/debug/mp/collect' }
		else { $gaURL = 'https://www.google-analytics.com/mp/collect' }
		$gaKey = 'api_secret=3URTslDhRVu4Qpb66nDyAA'
		$gaID = 'measurement_id=G-V9TJN18D5Z'
		$gaHeaders = @{
			'HOST'         = 'www.google-analytics.com'
			'Content-Type' = 'application/json'
		}
		$progressPreference = 'silentlyContinue'
		try {
			$response = Invoke-RestMethod -Uri ('{0}?{1}&{2}' -f $gaURL, $gaKey, $gaID) -Method 'POST' -Headers $gaHeaders -Body $gaBody -TimeoutSec 5	#$script:timeoutSec
			if ($DebugPreference -eq 'Continue') { Write-Debug ('GA Response: {0}' -f $response) }
		} catch { Write-Debug ('Failed to collect statistics') }
		finally { $progressPreference = 'Continue' }
	}
	Remove-Variable -Name operation, tverType, tverID, statisticsBase, epochTime, userProperties, clientEnv, value, eventParams, clientSetting, paramValue, gaBody, gaURL, gaKey, gaID, gaHeaders, response -ErrorAction SilentlyContinue
}

# endregion 環境

#----------------------------------------------------------------------
# GUID等取得
#----------------------------------------------------------------------
$script:locale = (Get-Culture).Name
$script:tz = [String][TimeZoneInfo]::Local.BaseUtcOffset
$progressPreference = 'SilentlyContinue'
$script:clientEnvs = @{}
try {
	$geoIPValues = (Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=18030841' -TimeoutSec $script:timeoutSec).psobject.properties
	foreach ($geoIPValue in $geoIPValues) { $script:clientEnvs.Add($geoIPValue.Name, $geoIPValue.Value) | Out-Null }
} catch { Write-Debug ('Failed to check Geo IP') }
$progressPreference = 'Continue'

$script:clientSettings = Get-Setting
switch ($true) {
	$IsWindows {
		$osInfo = Get-CimInstance -Class Win32_OperatingSystem
		$script:os = $osInfo.Caption
		$script:kernel = $osInfo.Version
		$script:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
		$script:guid = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
		# Toast用AppID取得に必要
		if (!$script:disableToastNotification) {
			try {
				Import-Module StartLayout -SkipEditionCheck
				$script:appId = (Get-StartApps).Where({ $_.Name -cmatch 'PowerShell*' }, 'First').AppId
			} catch { Write-Debug 'Failed to import StartLayout module' }
		}
		continue
	}
	$IsLinux {
		$script:os = if (Test-Path '/etc/os-release') { (& grep 'PRETTY_NAME' /etc/os-release).Replace('PRETTY_NAME=', '').Replace('"', '') } else { (& uname -n) }
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = if (Test-Path '/etc/machine-id') { (Get-Content /etc/machine-id) } else { (New-Guid).ToString().Replace('-', '') }
		continue
	}
	$IsMacOS {
		$script:os = ('{0} {1}' -f (& sw_vers -productName), (& sw_vers -productVersion))
		$script:kernel = (&  uname -r)
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = (& system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }').Replace('-', '')
		continue
	}
	default {
		$script:os = [String][System.Environment]::OSVersion
		$script:kernel = 'Unknown'
		$script:arch = 'Unknown'
		$script:guid = 'Unknown'
	}
}
Remove-Variable -Name geoIPValues, geoIPValue, osInfo -ErrorAction SilentlyContinue
