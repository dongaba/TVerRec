###################################################################################
#
#		TVerRec固有関数スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
Add-Type -AssemblyName 'System.Globalization' | Out-Null

#----------------------------------------------------------------------
#TVerRec Logo表示
#----------------------------------------------------------------------
function Show-Logo {
	[OutputType([System.Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#[Console]::ForegroundColor = 'Red'
	Write-Output ('⣴⠟⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠛⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦')
	Write-Output ('⣿⠀⠀⣿⣿⣿⣿⡿⠟⠛⠛⠛⠛⠳⢦⣄⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⡆⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣦⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⡟⠁⣀⣀⠈⢻⣿⠀⠋⢀⣀⡀⠙⣿⠀⠀⣿⣿⣿⠟⠀⢀⣿⡟⠁⣀⣀⠈⢻⣿⡟⠁⣀⣀⠈⢻⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⠇⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⠀⠾⠿⠿⠷⠀⣿⠀⣾⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⣠⣿⣿⠀⠾⠿⠿⠷⠀⣿⠀⣾⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣦⡀⠈⠻⠟⠁⢀⣴⣿⠀⢶⣶⣶⣶⣶⣿⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣧⠀⠘⣿⣿⠀⢶⣶⣶⣶⣶⣿⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⣿⣿⣷⣦⣤⣤⣤⣤⣴⣾⠋⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⣿⣿⣦⡀⢀⣴⣿⣿⣿⣧⡀⠉⠉⢀⣼⣿⠀⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣧⠀⠘⣿⣧⡀⠉⠉⢀⣼⣿⣧⡀⠉⠉⢀⣼⣿⣿⣿⣿')
	Write-Output ('⣿⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠙⢷⣄⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿')
	Write-Output ('⠻⣦⣤⣿⣿⣿⣿⣿⣿⣿⣿⣤⣤⣤⣤⣽⣷⣤⣤⣤⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟')
	#[Console]::ResetColor()
	Write-Output (" {0,$(72 - $script:appVersion.Length)}Version. {1}  " -f ' ', $script:appVersion)
}

#----------------------------------------------------------------------
#TVerRec最新化確認
#----------------------------------------------------------------------
function Invoke-TVerRecUpdateCheck {
	[OutputType([System.Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$progressPreference = 'silentlyContinue'
	Invoke-StatisticsCheck -Operation 'launch'
	$versionUp = $false
	#TVerRecの最新バージョン取得
	$repo = 'dongaba/TVerRec'
	$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)
	try {
		$appReleases = (Invoke-RestMethod -Uri $releases -Method 'GET' ).where{ ($_.prerelease -eq $false) }[0]
		if (!$appReleases) { Write-Warning '最新版の情報を取得できませんでした' ; return }
	} catch { Write-Warning '最新版の情報を取得できませんでした' ; return }
	#GitHub側最新バージョンの整形 v1.2.3 → 1.2.3
	$latestVersion = $appReleases[0].Tag_Name.Trim('v', ' ')
	$latestMajorVersion = $latestVersion.split(' ')[0]		#1.2.3 beta 4 → 1.2.3
	#ローカル側バージョンの整形 v1.2.3 beta 4 → 1.2.3
	$appMajorVersion = $script:appVersion.split(' ')[0]
	#バージョン判定
	$versionUp = switch ($true) {
		{ $latestMajorVersion -gt $appMajorVersion } { $true ; continue }
		{ ($latestMajorVersion -eq $appMajorVersion) -and ($appMajorVersion -ne $script:appVersion) } { $true ; continue }
		default { $false }
	}
	$progressPreference = 'Continue'
	#バージョンアップメッセージ
	if ($versionUp) {
		[Console]::ForegroundColor = 'Green'
		Write-Output ('')
		Write-Warning ('⚠️ TVerRecの更新版があるようです。')
		Write-Warning ('　Local Version {0}' -f $script:appVersion)
		Write-Warning ('　Latest Version {0}' -f $latestVersion)
		Write-Output ('')
		[Console]::ResetColor()
		#変更履歴の表示
		foreach ($appRelease in @($appReleases | Where-Object { $_.Tag_Name.Trim('v', ' ') -gt $appMajorVersion })) {
			[Console]::ForegroundColor = 'Green'
			Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
			Write-Output ('{0}の更新内容' -f $appRelease.tag_name)
			Write-Output ('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
			Write-Output $appRelease.body.Replace('###', '■')
			Write-Output ('')
			[Console]::ResetColor()
		}
		#最新のアップデータを取得
		$latestUpdater = 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1'
		Invoke-WebRequest -Uri $latestUpdater -OutFile (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1')
		if (!($IsLinux)) { Unblock-File -LiteralPath (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') }
		#アップデート実行
		Write-Warning ('TVerRecをアップデートするにはこのウィンドウを閉じ update_tverrec を実行してください。')
		foreach ($i in (1..10)) {
			$complete = ('#' * $i) * 5
			$remaining = ('.' * (10 - $i)) * 5
			Write-Warning ('残り{0}秒... [{1}{2}]' -f (10 - $i), $complete, $remaining)
			Start-Sleep -Second 1
		}
	}
	Remove-Variable -Name versionUp, repo, releases, appReleases, latestVersion, latestMajorVersion, appMajorVersion, appRelease, latestUpdater, i, complete, remaining -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ytdl/ffmpegの最新化確認
#----------------------------------------------------------------------
function Invoke-ToolUpdateCheck {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true)][string]$scriptName,
		[Parameter(Mandatory = $true)][string]$targetName
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$progressPreference = 'silentlyContinue'
	& (Join-Path $scriptRoot ('functions/{0}' -f $scriptName) )
	if (!$?) { Throw ('　❌️ {0}の更新に失敗しました' -f $targetName) }
	$progressPreference = 'Continue'
	Remove-Variable -Name scriptName, targetName -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ファイル・ディレクトリの存在チェック、なければサンプルファイルコピー
#----------------------------------------------------------------------
function Invoke-TverrecPathCheck {
	Param (
		[Parameter(Mandatory = $true )][string]$path,
		[Parameter(Mandatory = $true )][string]$errorMessage,
		[Parameter(Mandatory = $false)][switch]$isFile,
		[Parameter(Mandatory = $false)][string]$sampleFilePath
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$pathType = if ($isFile) { 'Leaf' } else { 'Container' }
	if (!(Test-Path $path -PathType $pathType)) {
		if (!($sampleFilePath -and (Test-Path $sampleFilePath -PathType 'Leaf'))) { Throw ('　❌️ {0}が存在しません。終了します。' -f $errorMessage) }
		Copy-Item -LiteralPath $sampleFilePath -Destination $path -Force | Out-Null
	}
	Remove-Variable -Name path, errorMessage, isFile, sampleFilePath, pathType -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function Invoke-RequiredFileCheck {
	[OutputType([System.Void])]
	Param ()
	Write-Debug ($MyInvocation.MyCommand.Name)
	if ($script:downloadBaseDir -eq '') { Throw ('　❌️ 番組ダウンロード先ディレクトリが設定されていません。終了します。') }
	else { Invoke-TverrecPathCheck -Path $script:downloadBaseDir -errorMessage '番組ダウンロード先ディレクトリ' }
	$script:downloadBaseDir = $script:downloadBaseDir.TrimEnd('\/')
	if ($script:downloadWorkDir -eq '') { Throw ('　❌️ ダウンロード作業ディレクトリが設定されていません。終了します。') }
	else { Invoke-TverrecPathCheck -Path $script:downloadWorkDir -errorMessage 'ダウンロード作業ディレクトリ' }
	$script:downloadWorkDir = $script:downloadWorkDir.TrimEnd('\/')
	if ($script:saveBaseDir -ne '') {
		$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim().TrimEnd('\/')
		foreach ($saveDir in $script:saveBaseDirArray) { Invoke-TverrecPathCheck -Path $saveDir.Trim() -errorMessage '番組移動先ディレクトリ' }
	}
	Invoke-TverrecPathCheck -Path $script:ytdlPath -errorMessage 'youtube-dl' -isFile
	Invoke-TverrecPathCheck -Path $script:ffmpegPath -errorMessage 'ffmpeg' -isFile
	if ($script:simplifiedValidation) { Invoke-TverrecPathCheck -Path $script:ffprobePath -errorMessage 'ffprobe' -isFile }
	Invoke-TverrecPathCheck -Path $script:keywordFilePath -errorMessage 'ダウンロード対象キーワードファイル' -isFile -sampleFilePath $script:keywordFileSamplePath
	Invoke-TverrecPathCheck -Path $script:ignoreFilePath -errorMessage 'ダウンロード対象外番組ファイル' -isFile -sampleFilePath $script:ignoreFileSamplePath
	Invoke-TverrecPathCheck -Path $script:histFilePath -errorMessage 'ダウンロード履歴ファイル' -isFile -sampleFilePath $script:histFileSamplePath
	Invoke-TverrecPathCheck -Path $script:listFilePath -errorMessage 'ダウンロードリストファイル' -isFile -sampleFilePath $script:listFileSamplePath
	Remove-Variable -Name saveDir -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function Read-KeywordList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$keywords = @()
	#コメントと空行を除いて抽出
	try { $keywords = @((Get-Content $script:keywordFilePath -Encoding UTF8).Where({ $_ -notmatch '^\s*$|^#.*$' })) }
	catch { Throw ('　❌️ ダウンロード対象キーワードの読み込みに失敗しました') }
	return $keywords
	Remove-Variable -Name keywords -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード履歴の読み込み
#----------------------------------------------------------------------
function Read-HistoryFile {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$histFileData = @()
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$histFileData = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
	} catch { Throw ('　❌️ ダウンロード履歴の読み込みに失敗しました') }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	return $histFileData
	Remove-Variable -Name histFileData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロードリストの読み込み
#----------------------------------------------------------------------
function Read-DownloadList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$listFileData = @()
	try {
		while ((Lock-File $script:listLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$listFileData = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
	} catch { Throw ('　❌️ ダウンロードリストの読み込みに失敗しました') }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	return $listFileData
	Remove-Variable -Name listFileData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロードリストからダウンロードリンクの読み込み
#----------------------------------------------------------------------
function Get-LinkFromDownloadList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-Path $script:listFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:listLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			#空行とダウンロード対象外を除き、EpisodeIDのみを抽出
			$videoLinks = @((Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_.EpisodeID -cmatch '^#') }) | Select-Object episodeID)
		} catch { Throw ('　❌️ ダウンロードリストの読み込みに失敗しました') }
		finally { Unlock-File $script:listLockFilePath | Out-Null }
	} else { $videoLinks = @() }
	$videoLinks = $videoLinks.episodeID -replace '^(.+)', 'https://tver.jp/episodes/$1'
	return @($videoLinks)
	Remove-Variable -Name videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード対象外番組の読み込
#----------------------------------------------------------------------
function Read-IgnoreList {
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreTitles = @()
	try {
		while ((Lock-File $script:ignoreLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		#コメントと空行を除いて抽出
		$ignoreTitles = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^;.*$') }))
	} catch { Throw ('　❌️ ダウンロード対象外の読み込みに失敗しました') }
	finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	return $ignoreTitles
	Remove-Variable -Name ignoreTitles -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function Update-IgnoreList {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][String]$ignoreTitle)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreListNew = @()
	$ignoreComment = @()
	$ignoreTarget = @()
	$ignoreElse = @()
	if (Test-Path $script:ignoreFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:ignoreLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$ignoreLists = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where( { $_ -notmatch '^\s*$|^(;;.*)$' }))
			$ignoreComment = @(Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
			$ignoreTarget = @($ignoreLists.Where({ $_ -eq $ignoreTitle }) | Sort-Object -Unique)
			$ignoreElse = @($ignoreLists.Where({ $_ -notin $ignoreTitle }))
			if ($ignoreComment) { $ignoreListNew += $ignoreComment }
			if ($ignoreTarget) { $ignoreListNew += $ignoreTarget }
			if ($ignoreElse) { $ignoreListNew += $ignoreElse }
			#改行コードLFを強制 + NFCで出力
			$ignoreListNew.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC)  | Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline
			Write-Debug ('　ダウンロード対象外リストのソート更新完了')
		} catch { Write-Warning ('　⚠️ ダウンロード対象外リストのソートに失敗しました') }
		finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	}
	Remove-Variable -Name ignoreTitle, ignoreListNew, ignoreComment, ignoreTarget, ignoreElse, ignoreLists -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#URLが既にダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryMatchCheck {
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Read-HistoryFile)
	if ($histFileData.Count -eq 0) { $histVideoPages = @() } else { $histVideoPages = @($histFileData.VideoPage) }
	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$histCompResult = @(Compare-Object -IncludeEqual $resultLinks $histVideoPages)
	try { $processedCount = ($histCompResult | Where-Object { $_.SideIndicator -eq '==' }).Count } catch { $processedCount = 0 }
	try { $videoLinks = @(($histCompResult | Where-Object { $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, histFileData, histVideoPages, histCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#URLが既にダウンロードリストに存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-ListMatchCheck {
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoPages = $listFileData | ForEach-Object { 'https://tver.jp/episodes/{0}' -f $_.EpisodeID.Replace('#', '') }
	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = @(Compare-Object -IncludeEqual $resultLinks $listVideoPages)
	try { $processedCount = ($listCompResult | Where-Object { $_.SideIndicator -eq '==' }).Count } catch { $processedCount = 0 }
	try { $videoLinks = @(($listCompResult | Where-Object { $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, listFileData, listVideoPages, listFileLine, listCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#URLが既にダウンロードリストまたはダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryAndListMatchCheck {
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoPages = $listFileData | ForEach-Object { 'https://tver.jp/episodes/{0}' -f $_.EpisodeID.Replace('#', '') }
	#ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Read-HistoryFile)
	$histVideoPages = if ($histFileData.Count -eq 0) { @() } else { $histFileData | Select-Object -ExpandProperty VideoPage }
	#ダウンロードリストとダウンロード履歴をマージ
	$listVideoPages += $histVideoPages
	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = @(Compare-Object -IncludeEqual $resultLinks $listVideoPages)
	try { $processedCount = ($listCompResult | Where-Object { $_.SideIndicator -eq '==' }).Count } catch { $processedCount = 0 }
	try { $videoLinks = @(($listCompResult | Where-Object { $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, listFileData, listVideoPages, listFileLine, histFileData, histVideoPages, listCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function Wait-YtdlProcess {
	[OutputType([System.Void])]
	Param ([Int32]$parallelDownloadFileNum)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#youtube-dlのプロセスが設定値を超えたら一時待機
	while ($true) {
		$ytdlCount = Get-YtdlProcessCount
		if ([Int]$ytdlCount -lt [Int]$parallelDownloadFileNum ) { break }
		Write-Output ('ダウンロードが{0}多重に達したので一時待機します。' -f $parallelDownloadFileNum)
		Write-Information ('{0} - 現在のダウンロードプロセス一覧 ({1}個)' -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 60
	}
	Remove-Variable -Name parallelDownloadFileNum, ytdlCount -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード履歴データの作成
#----------------------------------------------------------------------
function Format-HistoryRecord {
	Param ([Parameter(Mandatory = $true)][pscustomobject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	return [pscustomobject]@{
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
	Remove-Variable -Name videoInfo -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロードリストデータの作成
#----------------------------------------------------------------------
function Format-ListRecord {
	Param ([Parameter(Mandatory = $true)][pscustomobject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$customObject = [pscustomobject]@{
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
	if ($script:extractDescTextToList) { $customObject | Add-Member -NotePropertyName descriptionText -NotePropertyValue $videoInfo.descriptionText }
	else { $customObject | Add-Member -NotePropertyName descriptionText -NotePropertyValue '' }
	return $customObject
	Remove-Variable -Name videoInfo, customObject -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#「《」と「》」、「【」と「】」で挟まれた文字を除去
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
	Remove-Variable -Name text, start1, end1, start2, end2, length1, length2 -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function Invoke-VideoDownload {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$keyword,
		[Parameter(Mandatory = $true )][String]$episodePage,
		[Parameter(Mandatory = $false)][Boolean]$force = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$newVideo = $null
	$skipDownload = $false
	$episodeID = $episodePage.Replace('https://tver.jp/episodes/', '')
	#TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ('　⚠️ 番組情報を取得できませんでした。スキップします') ; continue }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	#ダウンロードファイル名を生成
	$videoInfo = Format-VideoFileInfo $videoInfo
	#番組タイトルが取得できなかった場合はスキップ次の番組へ
	if (($videoInfo.fileName -eq '.mp4') -or ($videoInfo.fileName -eq '.ts')) { Write-Warning ('　⚠️ 番組タイトルを特定できませんでした。スキップします') ; continue }
	#番組情報のコンソール出力
	Show-VideoInfo $videoInfo
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo $videoInfo }
	if ($force) {
		$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
		$newVideo = Format-HistoryRecord $videoInfo
	} else {
		#ここまで来ているということはEpisodeIDでは履歴とマッチしなかったということ
		#考えられる原因は履歴ファイルがクリアされてしまっていること、または、EpisodeIDが変更になったこと
		#	履歴ファイルに存在する	→番組IDが変更になったあるいは、番組名の重複
		#		検証済	→元々の番組IDとしては問題ないのでSKIP
		#		検証中	→元々の番組IDとしてはそのうち検証されるのでSKIP
		#		未検証	→元々の番組IDとしては次回検証されるのでSKIP
		#	履歴ファイルに存在しない
		#		ファイルが存在する	→検証だけする
		#		ファイルが存在しない
		#			ダウンロード対象外リストに存在する	→無視
		#			ダウンロード対象外リストに存在しない	→ダウンロード
		#ダウンロード履歴ファイルのデータを読み込み
		$histFileData = @(Read-HistoryFile)
		if ($videoInfo.fileRelPath) { $histMatch = @($histFileData.Where({ $_.videoPath -eq $videoInfo.fileRelPath })) }
		else { Write-Warning ('　⚠️ ファイル名が取得できませんでした。スキップします') ; continue }
		if (($histMatch.Count -ne 0)) {
			#履歴ファイルに存在する	→スキップして次のファイルに
			Write-Warning ('　⚠️ 同名のファイルがすでに履歴ファイルに存在します。番組IDが変更になった可能性があります。ダウンロードをスキップします')
			$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '1' ; $videoInfo.fileName = '-- SKIPPED --'
			$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
		} elseif ( Test-Path $videoInfo.filePath) {
			#履歴ファイルに存在しないが、実ファイルが存在する	→検証だけする
			Write-Warning ('　⚠️ 履歴ファイルに存在しませんが番組ファイルが存在します。整合性検証の対象とします')
			$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- SKIPPED --'
			$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
		} else {
			#履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
			$ignoreTitles = @(Read-IgnoreList)
			foreach ($ignoreTitle in $ignoreTitles) {
				if (($videoInfo.fileName -like ('*{0}*' -f $ignoreTitle)) -or ($videoInfo.seriesName -like ('*{0}*' -f $ignoreTitle))) {
					Update-IgnoreList $ignoreTitle ; Write-Warning ('　⚠️ ダウンロード対象外としたファイルをダウンロード履歴に追加します')
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- IGNORED --' ; $videoInfo.fileRelPath = '-- IGNORED --'
					$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
					break
				}
			}
			#履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
			if (!$skipDownload) {
				Write-Output ('　💡 ダウンロードするファイルをダウンロード履歴に追加します')
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
				$newVideo = Format-HistoryRecord $videoInfo
			}
		}
	}
	#ダウンロード履歴CSV書き出し
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$newVideo | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append
		Write-Debug ('ダウンロード履歴を書き込みました')
	} catch { Write-Warning ('　⚠️ ダウンロード履歴を更新できませんでした。処理をスキップします') ; continue }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	#スキップ対象やダウンロード対象外は飛ばして次のファイルへ
	if ($skipDownload) { continue }
	#移動先ディレクトリがなければ作成
	if (!(Test-Path $videoInfo.fileDir -PathType Container)) {
		try { New-Item -ItemType Directory -Path $videoInfo.fileDir -Force | Out-Null }
		catch { Write-Warning ('　⚠️ 移動先ディレクトリを作成できませんでした') ; continue }
	}
	#youtube-dl起動
	try { Invoke-Ytdl $videoInfo }
	catch { Write-Warning ('　⚠️ youtube-dlの起動に失敗しました') }
	#5秒待機
	Start-Sleep -Seconds 5
	Remove-Variable -Name keyword, episodePage, force, newVideo, skipDownload, episodeID, videoInfo, newVideo, histFileData, histMatch, ignoreTitles, ignoreTitle -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function Update-VideoList {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$keyword,
		[Parameter(Mandatory = $true)][String]$episodePage
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreWord = ''
	$newVideo = $null
	$ignore = $false
	$episodeID = $episodePage.Replace('https://tver.jp/episodes/', '')
	#TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ('　⚠️ 番組情報を取得できませんでした。スキップします') ; continue }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	#ダウンロード対象外に入っている番組の場合はリスト出力しない
	$ignoreTitles = @(Read-IgnoreList)
	foreach ($ignoreTitle in $ignoreTitles) {
		if ($ignoreTitle -ne '') {
			if (($videoInfo.seriesName -cmatch [Regex]::Escape($ignoreTitle)) -or ($videoInfo.episodeName -cmatch [Regex]::Escape($ignoreTitle))) {
				$ignoreWord = $ignoreTitle ; Update-IgnoreList $ignoreTitle ; $ignore = $true
				$videoInfo.episodeID = ('#{0}' -f $videoInfo.episodeID)
				break
			}
		}
	}
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'ignoreWord' -Value $ignoreWord
	#番組情報のコンソール出力
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo $videoInfo }
	#スキップフラグが立っているかチェック
	if ($ignore) { Write-Warning ('　　⚠️ 番組をコメントアウトした状態でリストファイルに追加します') ; $newVideo = Format-ListRecord $videoInfo }
	else { Write-Output ('　　💡 番組をリストファイルに追加します') ; $newVideo = Format-ListRecord $videoInfo }
	#ダウンロードリストCSV書き出し
	try {
		while ((Lock-File $script:listLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append
		Write-Debug ('ダウンロードリストを書き込みました')
	} catch { Write-Warning ('　　⚠️ ダウンロードリストを更新できませんでした。スキップします') ; continue }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	Remove-Variable -Name keyword, episodePage, ignoreWord, newVideo, ignore, episodeID, videoInfo, ignoreTitles, ignoreTitle -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function Get-VideoInfo {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][String]$episodeID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#----------------------------------------------------------------------
	#番組説明以外
	$tverVideoInfoBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$tverVideoInfoURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $tverVideoInfoBaseURL, $episodeID, $script:platformUID, $script:platformToken)
	try { $response = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning ('⚠️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) ; return }
	#シリーズ
	#	Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
	#	Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
	#	3.2.2からEpisode.Content.SeriesTitleを採用することとする。
	#	理由は、Series.Content.Titleだとファイル名が冗長になることがあることと、複数シーズン配信時に最新シーズン名になってしまうことがあるため。
	$videoSeries = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Episode.Content.SeriesTitle))).Trim()
	$videoSeriesID = $response.Result.Series.Content.Id
	$videoSeriesPageURL = ('https://tver.jp/series/{0}' -f $response.Result.Series.Content.Id)
	#シーズン
	$videoSeason = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Season.Content.Title))).Trim()
	$videoSeasonID = $response.Result.Season.Content.Id
	#エピソード
	$episodeName = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Episode.Content.Title))).Trim()
	$videoEpisodeID = $response.Result.Episode.Content.Id
	$videoEpisodePageURL = ('https://tver.jp/episodes/{0}' -f $videoEpisodeID)
	#放送局
	$mediaName = (Get-NarrowChars ($response.Result.Episode.Content.BroadcasterName)).Trim()
	$providerName = (Get-NarrowChars ($response.Result.Episode.Content.ProductionProviderName)).Trim()
	#放送日
	$broadcastDate = (($response.Result.Episode.Content.BroadcastDateLabel).Replace('ほか', '').Replace('放送分', '放送').Replace('配信分', '配信')).Trim()
	#配信終了日時
	$endTime = (ConvertFrom-UnixTime ($response.Result.Episode.Content.EndAt)).AddHours(9)
	#----------------------------------------------------------------------
	#番組説明
	try {
		$versionNum = $response.Result.Episode.Content.version
		$tverVideoInfoBaseURL = 'https://statics.tver.jp/content/episode/'
		$tverVideoInfoURL = ('{0}{1}.json?v={2}' -f $tverVideoInfoBaseURL, $episodeID, $versionNum)
		$videoInfo = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
		$descriptionText = (Get-NarrowChars ($videoInfo.Description).Replace('&amp;', '&')).Trim()
		$videoEpisodeNum = (Get-NarrowChars ($videoInfo.No)).Trim()
		$accountID = $videoInfo.video.accountID
		$videoRefID = if ($videoInfo.video.PSObject.Properties.Name -contains 'videoRefID') { ('ref%3A{0}' -f $videoInfo.video.videoRefID) } else { $videoInfo.video.videoID }
		$playerID = $videoInfo.video.playerID
	} catch { Write-Warning ('⚠️ エラーが発生しました。番組情報を取得できません。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) ; return }
	#Brightcoveキー取得
	try {
		$brightcoveJsURL = ('https://players.brightcove.net/{0}/{1}_default/index.min.js' -f $accountID, $playerID)
		$brightcovePk = if ((Invoke-RestMethod -Uri $brightcoveJsURL -Method 'GET' -Headers $script:requestHeader) -match 'policyKey:"([a-zA-Z0-9_-]*)"') { $matches[1] }
	} catch { Write-Warning ('⚠️ エラーが発生しました。m3u8ファイル取得のキーが取得できません。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) ; return }
	#m3u8とmpd URL取得
	try {
		$brightcoveURL = ('https://edge.api.brightcove.com/playback/v1/accounts/{0}/videos/{1}' -f $accountID, $videoRefID)
		$headers = @{
			'Accept'          = ('application/json;pk={0}' -f $brightcovePk)
			'X-Forwarded-For' = $script:jpIP
		}
		$response = Invoke-RestMethod -Uri $brightcoveURL -Method 'GET' -Headers $headers
		$m3u8URL = $response.sources.where({ $_.src -like 'https://*' }).where({ $_.type -like '*mpeg*' }).where({ $_.ext_x_version -eq 4 })[0].src
		$mpdURL = $response.sources.where({ $_.src -like 'https://*' }).where({ $_.type -like '*dash*' })[0].src
	} catch { Write-Warning ('⚠️ エラーが発生しました。m3u8ファイルが取得できません。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) ; return }
	#「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote) { $videoSeason = Remove-SpecialNote $videoSeason ; $episodeName = Remove-SpecialNote $episodeName }
	#シーズン名が本編の場合はシーズン名をクリア
	if ($videoSeason -eq '本編') { $videoSeason = '' }
	#シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($videoSeries -cmatch [Regex]::Escape($videoSeason)) { $videoSeason = '' }
	#エピソード番号を極力修正
	if ((($videoEpisodeNum -eq 1) -or ($videoEpisodeNum % 10 -eq 0)) -and ($episodeName -imatch '([#|第|Episode|ep|Take|Vol|Part|Chapter|Flight|Karte|Case|Stage|Mystery|Ope|Story|Sign|Trap|Letter|Act]+\.?\s?)(\d+)(.*)')) { $videoEpisodeNum = $matches[2] }
	#エピソード番号が1桁の際は頭0埋めして2桁に
	$videoEpisodeNum = $videoEpisodeNum.PadLeft(2, '0')
	#放送日を整形
	if ($broadcastDate -cmatch '([0-9]+)(月)([0-9]+)(日)(.+?)(放送|配信)') {
		$currentYear = (Get-Date).Year
		$parsedBroadcastDate = [DateTime]::ParseExact(('{0}{1}{2}' -f $currentYear, $matches[1].padleft(2, '0'), $matches[3].padleft(2, '0')), 'yyyyMMdd', $null)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する(年末の番組を年初にダウンロードするケース)
		$broadcastYear = $parsedBroadcastDate -gt (Get-Date).AddDays(+1) ? $currentYear - 1 : $currentYear
		$broadcastDate = ('{0}年{1}{2}{3}{4}{5}' -f $broadcastYear, $matches[1].padleft(2, '0'), $matches[2], $matches[3].padleft(2, '0'), $matches[4], $matches[6])
	}
	return [pscustomobject]@{
		seriesName      = $videoSeries
		seriesID        = $videoSeriesID
		seriesPageURL   = $videoSeriesPageURL
		seasonName      = $videoSeason
		seasonID        = $videoSeasonID
		episodeNum      = $videoEpisodeNum
		episodeID       = $videoEpisodeID
		episodePageURL  = $videoEpisodePageURL
		episodeName     = $episodeName
		mediaName       = $mediaName
		providerName    = $providerName
		broadcastDate   = $broadcastDate
		endTime         = $endTime
		versionNum      = $versionNum
		videoInfoURL    = $tverVideoInfoURL
		descriptionText = $descriptionText
		m3u8URL         = $m3u8URL
		mpdURL          = $mpdURL
	}
	Remove-Variable -Name episodeID, tverVideoInfoBaseURL, tverVideoInfoURL, response -ErrorAction SilentlyContinue
	Remove-Variable -Name videoSeries, videoSeriesID, videoSeriesPageURL, videoSeason, videoSeasonID, episodeName, videoEpisodeID, videoEpisodePageURL -ErrorAction SilentlyContinue
	Remove-Variable -Name mediaName, providerName, broadcastDate, endTime, versionNum, videoInfo, descriptionText, videoEpisodeNum -ErrorAction SilentlyContinue
	Remove-Variable -Name currentYear, parsedBroadcastDate, broadcastYear, matches -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function Format-VideoFileInfo {
	[OutputType([pscustomobject])]
	Param ([Parameter(Mandatory = $true)][pscustomobject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$videoName = ''
	#ファイル名を生成
	if ($script:addSeriesName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seriesName) }
	if ($script:addSeasonName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seasonName) }
	if ($script:addBrodcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate) }
	if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
	$videoName = ('{0}{1}' -f $videoName, $videoInfo.episodeName)
	#ファイル名にできない文字列を除去
	$videoName = (Get-FileNameWithoutInvalidChars $videoName).Replace('  ', ' ').Trim()
	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング。youtube-dlの中間ファイル等を考慮して安全目の上限値
	$fileNameLimit = $script:fileNameLengthMax - 25
	if ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
		while ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) { $videoName = $videoName.Substring(0, $videoName.Length - 1) }
		$videoName = ('{0}……' -f $videoName)
	}
	$videoName = Get-FileNameWithoutInvalidChars ('{0}.{1}' -f $videoName, $script:videoContainerFormat)
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileName' -Value $videoName
	$videoFileDir = Get-FileNameWithoutInvalidChars (Remove-SpecialCharacter ('{0} {1}' -f $videoInfo.seriesName, $videoInfo.seasonName ).Trim(' ', '.'))
	if ($script:sortVideoByMedia) { $videoFileDir = (Join-Path $script:downloadBaseDir (Get-FileNameWithoutInvalidChars $videoInfo.mediaName) | Join-Path -ChildPath $videoFileDir) }
	else { $videoFileDir = (Join-Path $script:downloadBaseDir $videoFileDir) }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileDir' -Value $videoFileDir
	$videoFilePath = Join-Path $videoFileDir $videoInfo.fileName
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'filePath' -Value $videoFilePath
	$videoFileRelPath = $videoInfo.filePath.Replace($script:downloadBaseDir, '').Replace('\', '/').TrimStart('/')
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileRelPath' -Value $videoFileRelPath
	return $videoInfo
	Remove-Variable -Name videoInfo, videoName, fileNameLimit, videoFileDir, videoFilePath, videoFileRelPath -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#番組情報表示
#----------------------------------------------------------------------
function Show-VideoInfo {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][pscustomobject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Output ('　番組名:　 {0}' -f $videoInfo.fileName.Replace($script:videoContainerFormat, ''))
	Write-Output ('　放送日:　 {0}' -f $videoInfo.broadcastDate)
	Write-Output ('　テレビ局: {0}' -f $videoInfo.mediaName)
	Write-Output ('　配信終了: {0}' -f $videoInfo.endTime)
	Write-Output ('　番組説明: {0}' -f $videoInfo.descriptionText)
	Remove-Variable -Name videoInfo -ErrorAction SilentlyContinue
}
#----------------------------------------------------------------------
#番組情報デバッグ表示
#----------------------------------------------------------------------
function Show-VideoDebugInfo {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][pscustomobject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Debug $videoInfo.episodePageURL
	Remove-Variable -Name videoInfo -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動
#----------------------------------------------------------------------
function Invoke-Ytdl {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][pscustomobject]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'download'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $videoInfo.fileDir)
	$saveFile = ('{0}' -f $videoInfo.fileName)
	$ytdlArgs = (' {0}' -f $script:ytdlBaseArgs)
	$ytdlArgs += (' {0} {1}' -f '--concurrent-fragments', $script:parallelDownloadNumPerFile)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $saveDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $tmpDir)
	$ytdlArgs += (' {0} {1}' -f '--add-header', $script:ytdlHttpHeader)
	$ytdlArgs += (' {0} "{1}"' -f '--ffmpeg-location', $script:ffmpegPath)
	if ($script:rateLimit -notin @(0, '')) {
		$rateLimit = [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8)
		$ytdlArgs += (' {0} {1}M' -f '--limit-rate', $rateLimit)
	}
	if ($script:videoContainerFormat -eq 'mp4') {
		$ytdlArgs += (' {0}' -f '--merge-output-format mp4 --embed-thumbnail --embed-chapters')
		$subttlDir = ('subtitle:{0}' -f $script:downloadWorkDir)
		$thumbDir = ('thumbnail:{0}' -f $script:downloadWorkDir)
		$chaptDir = ('chapter:{0}' -f $script:downloadWorkDir)
		$descDir = ('description:{0}' -f $script:downloadWorkDir)
		$ytdlArgs += (' {0} "{1}"' -f '--paths', $subttlDir)
		$ytdlArgs += (' {0} "{1}"' -f '--paths', $thumbDir)
		$ytdlArgs += (' {0} "{1}"' -f '--paths', $chaptDir)
		$ytdlArgs += (' {0} "{1}"' -f '--paths', $descDir)
		if ($script:embedSubtitle) { $ytdlArgs += (' {0}' -f '--sub-langs all --convert-subs srt --embed-subs') }
		if ($script:embedMetatag) { $ytdlArgs += (' {0}' -f '--embed-metadata') }
	}
	$ytdlArgs += (' {0}' -f $script:ytdlOption)
	$ytdlArgs += (' {0}' -f $videoInfo.episodePageURL)
	$ytdlArgs += (' {0} "{1}"' -f '--output', $saveFile)
	Write-Debug ('youtube-dl起動コマンド: {0}{1}' -f $script:ytdlPath, $ytdlArgs)
	try {
		$startProcessParams = @{
			FilePath     = $script:ytdlPath
			ArgumentList = $ytdlArgs
			PassThru     = $true
		}
		if ($IsWindows) {
			$startProcessParams.WindowStyle = $script:windowShowStyle
		} else {
			$startProcessParams.RedirectStandardOutput = '/dev/null'
			$startProcessParams.RedirectStandardError = '/dev/zero'
		}
		$ytdlProcess = Start-Process @startProcessParams
		$ytdlProcess.Handle | Out-Null
	} catch { Write-Warning '　⚠️ youtube-dlの起動に失敗しました' ; return }
	Remove-Variable -Name videoInfo, tmpDir, saveDir, subttlDir, thumbDir, chaptDir, descDir, saveFile, ytdlArgs, rateLimit, startProcessParams, ytdlProcess -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動 (TVer以外のサイトへの対応)
#----------------------------------------------------------------------
function Invoke-NonTverYtdl {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][Alias('URL')]	[String]$videoPageURL)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'nontver'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$baseDir = ('home:{0}' -f $script:downloadBaseDir)
	$saveFile = ('{0}' -f $script:ytdlNonTVerFileName)
	$ytdlArgs = (' {0}' -f $script:nonTVerYtdlBaseArgs)
	$ytdlArgs += (' {0} {1}' -f '--concurrent-fragments', $script:parallelDownloadNumPerFile)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $baseDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $tmpDir)
	$ytdlArgs += (' {0} {1}' -f '--add-header', $script:ytdlHttpHeader)
	$ytdlArgs += (' {0} "{1}"' -f '--ffmpeg-location', $script:ffmpegPath)
	if ($script:rateLimit -notin @(0, '')) {
		$rateLimit = [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8)
		$ytdlArgs += (' {0} {1}M' -f '--limit-rate', $rateLimit)
	}
	$ytdlArgs += (' {0}' -f '--merge-output-format mp4 --embed-thumbnail --embed-chapters')
	$subttlDir = ('subtitle:{0}' -f $script:downloadWorkDir)
	$thumbDir = ('thumbnail:{0}' -f $script:downloadWorkDir)
	$chaptDir = ('chapter:{0}' -f $script:downloadWorkDir)
	$descDir = ('description:{0}' -f $script:downloadWorkDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $subttlDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $thumbDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $chaptDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $descDir)
	if ($script:embedSubtitle) { $ytdlArgs += (' {0}' -f '--sub-langs all --convert-subs srt --embed-subs') }
	if ($script:embedMetatag) { $ytdlArgs += (' {0}' -f '--embed-metadata') }
	$ytdlArgs += (' {0}' -f $script:ytdlOption)
	$ytdlArgs += (' {0}' -f $videoPageURL)
	$ytdlArgs += (' {0} "{1}"' -f '--output', $saveFile)
	Write-Debug ('youtube-dl起動コマンド: {0}{1}' -f $script:ytdlPath, $ytdlArgs)
	try {
		$startProcessParams = @{
			FilePath     = $script:ytdlPath
			ArgumentList = $ytdlArgs
			PassThru     = $true
		}
		if ($IsWindows) {
			$startProcessParams.WindowStyle = $script:windowShowStyle
		} else {
			$startProcessParams.RedirectStandardOutput = '/dev/null'
			$startProcessParams.RedirectStandardError = '/dev/zero'
		}
		$ytdlProcess = Start-Process @startProcessParams
		$ytdlProcess.Handle | Out-Null
	} catch { Write-Warning '　⚠️ youtube-dlの起動に失敗しました' ; return }
	Remove-Variable -Name videoPageURL, tmpDir, baseDir, subttlDir, thumbDir, chaptDir, descDir, saveFile, ytdlArgs, rateLimit, startProcessParams, ytdlProcess -ErrorAction SilentlyContinue
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
	}
	try {
		switch ($true) {
			$IsWindows { return [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero ); continue }
			$IsLinux { return @(Get-Process -ErrorAction Ignore -Name $processName).Count ; continue }
			$IsMacOS { $psCmd = 'ps' ; return (& $psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; continue }
			default { Write-Debug ('ダウンロードプロセスの数を取得できませんでした') ; return 0 }
		}
	} catch { return 0 }
	Remove-Variable -Name processName, psCmd -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function Wait-DownloadCompletion () {
	[OutputType([System.Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = Get-YtdlProcessCount
	while ($ytdlCount -ne 0) {
		Write-Information ('{0} - 現在のダウンロードプロセス一覧 ({1}個)' -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 60
		$ytdlCount = Get-YtdlProcessCount
	}
	Remove-Variable -Name ytdlCount -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function Optimize-HistoryFile {
	[OutputType([System.Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$mergedHistData = @()
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$mergedHistData = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 | Where-Object { $null -ne $_.videoValidated } )
		$mergedHistData | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
	} catch { Write-Warning ('　⚠️ ダウンロード履歴の更新に失敗しました') }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name mergedHistData, histData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#指定日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function Limit-HistoryFile {
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true)][Int32]$retentionPeriod)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$purgedHist = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * [Int32]$retentionPeriod) }))
		$purgedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
	} catch { Write-Warning ('　⚠️ ダウンロード履歴のクリーンアップに失敗しました') }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name retentionPeriod, purgedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function Repair-HistoryFile {
	[OutputType([System.Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$uniquedHist = @()
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		#videoPageで1つしかないもの残し、ダウンロード日時でソート
		$uniquedHist = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 | Group-Object -Property 'videoPage' | Where-Object count -EQ 1 | Select-Object -ExpandProperty group | Sort-Object -Property downloadDate)
		$uniquedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
	} catch { Write-Warning ('　⚠️ ダウンロード履歴の更新に失敗しました') }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name uniquedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#番組の整合性チェック
#----------------------------------------------------------------------
function Invoke-ValidityCheck {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$path,
		[Parameter(Mandatory = $false)][String]$decodeOption = ''
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$errorCount = 0
	$checkStatus = 0
	$videoFilePath = Join-Path (Convert-Path $script:downloadBaseDir) $path
	try { New-Item -Path $script:ffpmegErrorLogPath -ItemType File -Force | Out-Null }
	catch { Write-Warning ('　⚠️ ffmpegエラーファイルを初期化できませんでした') ; return }
	#これからチェックする番組のステータスをチェック
	try {
		while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$checkStatus = ($videoHists.Where({ $_.videoPath -eq $path })).videoValidated
		switch ($checkStatus) {
			#0:未チェック、1:チェック済、2:チェック中
			'0' { $videoHists.Where({ $_.videoPath -eq $path }).Where({ $_.videoValidated = '2' }) ; $videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 ; continue }
			'1' { Write-Output ('　💡 他プロセスでチェック済です') ; return ; continue }
			'2' { Write-Output ('　💡 他プロセスでチェック中です') ; return ; continue }
			default { Write-Warning ('　⚠️ 既にダウンロード履歴から削除されたようです: {0}' -f $path) ; return }
		}
	} catch { Write-Warning ('　⚠️ ダウンロード履歴を更新できませんでした: {0}' -f $path) ; return }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Invoke-StatisticsCheck -Operation 'validate'
	if ($script:simplifiedValidation) {
		#ffprobeを使った簡易検査
		$ffprobeArgs = ('-hide_banner -v error -err_detect explode -i "{0}"' -f $videoFilePath)
		Write-Debug ('ffprobe起動コマンド: {0} {1}' -f $script:ffprobePath, $ffprobeArgs)
		$commonParams = @{
			FilePath              = $script:ffprobePath
			ArgumentList          = $ffprobeArgs
			PassThru              = $true
			RedirectStandardError = $script:ffpmegErrorLogPath
			Wait                  = $true
		}
		if ($IsWindows) { $commonParams.WindowStyle = $script:windowShowStyle }
		else { $commonParams.RedirectStandardOutput = '/dev/null' }
		try {
			# ffmpegプロセスの開始
			$ffmpegProcess = Start-Process @commonParams
			$ffmpegProcess.Handle | Out-Null  # ffmpegProcess.Handleをキャッシュ。PS7.4.0の終了コードを捕捉しないバグのために必要
			$ffmpegProcess.WaitForExit()
		} catch { Write-Warning ('　⚠️ ffprobeを起動できませんでした') ; return }
	} else {
		#ffmpegeを使った完全検査
		$ffmpegArgs = ('-hide_banner -v error -xerror {0} -i "{1}" -f null - ' -f $decodeOption, $videoFilePath)
		Write-Debug ('ffmpeg起動コマンド: {0} {1}' -f $script:ffmpegPath, $ffmpegArgs)
		$commonParams = @{
			FilePath              = $script:ffmpegPath
			ArgumentList          = $ffmpegArgs
			PassThru              = $true
			RedirectStandardError = $script:ffpmegErrorLogPath
		}
		if ($IsWindows) { $commonParams.WindowStyle = $script:windowShowStyle }
		else { $commonParams.RedirectStandardOutput = '/dev/null' }
		try {
			# ffmpegプロセスの開始
			$ffmpegProcess = Start-Process @commonParams
			$ffmpegProcess.Handle | Out-Null  # ffmpegProcess.Handleをキャッシュ。PS7.4.0の終了コードを捕捉しないバグのために必要
			$ffmpegProcess.WaitForExit()
		} catch { Write-Warning ('　⚠️ ffmpegを起動できませんでした') ; return }
	}
	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			$errorCount = (Get-Content -LiteralPath $script:ffpmegErrorLogPath | Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffpmegErrorLogPath -Encoding UTF8 | Write-Debug
		}
	} catch { Write-Warning ('　⚠️ ffmpegエラーの数をカウントできませんでした') ; $errorCount = 9999999 }
	#エラーをカウントしたらファイルを削除
	try { if (Test-Path $script:ffpmegErrorLogPath) { Remove-Item -LiteralPath $script:ffpmegErrorLogPath -Force -ErrorAction SilentlyContinue | Out-Null } }
	catch { Write-Warning ('　⚠️ ffmpegエラーファイルを削除できませんでした') }
	if ($ffmpegProcess.ExitCode -ne 0 -or $errorCount -gt 30) {
		#終了コードが0以外 または エラーが一定以上 はダウンロード履歴とファイルを削除
		Write-Warning ('　⚠️ チェックNGでした') ; Write-Verbose ('　　Exit Code: {0} Error Count: {1}' -f $ffmpegProcess.ExitCode, $errorCount)
		$script:validationFailed = $true
		#破損しているダウンロードファイルをダウンロード履歴から削除
		try {
			while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			#該当の番組のレコードを削除
			$videoHists = @($videoHists.Where({ $_.videoPath -ne $path }))
			$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		} catch { Write-Warning ('　⚠️ ダウンロード履歴の更新に失敗しました: {0}' -f $path) }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
		#破損しているダウンロードファイルを削除
		try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction SilentlyContinue | Out-Null }
		catch { Write-Warning ('　⚠️ ファイル削除できませんでした: {0}' -f $videoFilePath) }
	} else {
		#終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
		Write-Output ('　✅ 整合性チェック成功')
		try {
			while ((Lock-File $script:histLockFilePath).result -ne $true) { Write-Information ('　ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			#該当の番組のチェックステータスを1に
			$videoHists.Where({ $_.videoPath -eq $path }).Where({ $_.videoValidated = '1' })
			$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		} catch { Write-Warning ('　⚠️ ダウンロード履歴を更新できませんでした: {0}' -f $path) }
		finally { Unlock-File $script:histLockFilePath | Out-Null }
	}
	Remove-Variable -Name path, decodeOption, errorCount, checkStatus, videoFilePath, videoHists, ffprobeArgs, ffmpegProcess, ffmpegArgs -ErrorAction SilentlyContinue
}

#region 環境
#----------------------------------------------------------------------
#Geo IP関連
#----------------------------------------------------------------------
function Get-JpIP {
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#日本に割り当てられているIPアドレスレンジの取得
	$allCIDR = Import-Csv $script:jpIPList
	Do {
		#ランダムなIPアドレスの取得
		$randomCIDR = $allCIDR | Get-Random
		$startIPArray = [System.Net.IPAddress]::Parse($randomCIDR[0].start).GetAddressBytes()
		$endIPArray = [System.Net.IPAddress]::Parse($randomCIDR[0].end).GetAddressBytes()
		[Array]::Reverse($startIPArray) ; $startIPInt = [BitConverter]::ToUInt32($startIPArray, 0)
		[Array]::Reverse($endIPArray) ; $endIPInt = [BitConverter]::ToUInt32($endIPArray, 0)
		$randomIPInt = $startIPInt + [UInt32](Get-Random -Maximum ($endIPInt - $startIPInt - 1)) + 1	#CIDR範囲の先頭と末尾を除く
		$randomIPArray = [System.BitConverter]::GetBytes($randomIPInt)
		[Array]::Reverse($randomIPArray) ; $jpIP = [System.Net.IPAddress]::new($randomIPArray).ToString()
		$check = Invoke-RestMethod -Uri ('http://ip-api.com/json/{0}?fields=16785410' -f $jpIP)
	} While (($check.countryCode -ne 'JP') -or ($check.hosting) )
	return $jpIP
	Remove-Variable -Name jpIP, check, allCIDR, randomCIDR, startIPArray, endIPArray, startIPInt, endIPInt, randomIPInt, randomIPArray -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#設定取得
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
				$key = $configParts[0].replace('script:', '').replace('$', '').trim()
				if (!($key -match $excludePattern) -and (Get-Variable -Name $key)) { $configList[$key] = (Get-Variable -Name $key).Value }
			}
		}
	}
	return $configList.GetEnumerator() | Sort-Object -Property key
	Remove-Variable -Name filePathList, configList, filePath, configs, excludePattern, config, configParts, key -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#統計取得
#----------------------------------------------------------------------
function Invoke-StatisticsCheck {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$operation,
		[Parameter(Mandatory = $false)][String]$tverType = 'none',
		[Parameter(Mandatory = $false)][String]$tverID = 'none'
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$env:PESTER) {
		$progressPreference = 'silentlyContinue'
		$statisticsBase = 'https://hits.sh/github.com/dongaba/TVerRec/'
		try { Invoke-WebRequest -Uri ('{0}{1}.svg' -f $statisticsBase, $operation) -Method 'GET' -TimeoutSec $script:timeoutSec | Out-Null }
		catch { Write-Debug ('Failed to collect count') }
		finally { $progressPreference = 'Continue' }
		if ($operation -eq 'search') { return }
		$epochTime = [Int64]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000)
		$userProperties = @{	#max 25 properties, max 24 chars of property name, 36 chars of property value
			PSVersion    = @{ 'value' = $PSVersionTable.PSVersion.tostring() }
			AppVersion   = @{ 'value' = $script:appVersion }
			OS           = @{ 'value' = $script:os }
			Kernel       = @{ 'value' = $script:kernel }
			Architecture = @{ 'value' = $script:arch }
			Locale       = @{ 'value' = $script:locale }
			TimeZone     = @{ 'value' = $script:tz }
		}
		foreach ($clientEnv in $script:clientEnvs) {
			$value = [string]$clientEnv.Value
			$userProperties[$clientEnv.Key] = @{ 'value' = $value.Substring(0, [Math]::Min($value.Length, 36)) }
		}
		$eventParams = @{}	#max 25 parameters, max 40 chars of property name, 100 chars of property value
		foreach ($clientSetting in $script:clientSettings) {
			if (!($clientSetting.Name -match '(.*Dir|.*Path|app.*|timeout.*|.*Preference|.*Max|.*Period|parallel.*|.*BaseArgs|.*FileName)')) {
				$paramValue = [String]((Get-Variable -Name $clientSetting.Name).Value)
				$eventParams[$clientSetting.Key] = $paramValue.Substring(0, [Math]::Min($paramValue.Length, 99))
			}
		}
		$gaBody = [PSCustomObject]@{
			client_id            = $script:guid
			timestamp_micros     = $epochTime
			non_personalized_ads = $true
			user_properties      = $userProperties
			events               = @(	#max 25 events, 40 chars of event name
				@{
					name   = $operation
					params = $eventParams
				}
			)
		} | ConvertTo-Json -Depth 3
		$gaURL = 'https://www.google-analytics.com/mp/collect'
		$gaKey = 'api_secret=3URTslDhRVu4Qpb66nDyAA'
		$gaID = 'measurement_id=G-V9TJN18D5Z'
		$gaHeaders = @{
			'HOST'         = 'www.google-analytics.com'
			'Content-Type' = 'application/json'
		}
		$progressPreference = 'silentlyContinue'
		try { null = Invoke-RestMethod -Uri ('{0}?{1}&{2}' -f $gaURL, $gaKey, $gaID) -Method 'POST' -Headers $gaHeaders -Body $gaBody -TimeoutSec $script:timeoutSec | Out-Null }
		catch { Write-Debug ('Failed to collect statistics') }
		finally { $progressPreference = 'Continue' }
	}
	Remove-Variable -Name operation, tverType, tverID, statisticsBase, epochTime, userProperties, clientEnv, value, eventParams, clientSetting, paramValue -ErrorAction SilentlyContinue
	Remove-Variable -Name gaBody, gaURL, gaKey, gaID, gaHeaders -ErrorAction SilentlyContinue
}

#endregion 環境

#----------------------------------------------------------------------
#GUID等取得
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
$script:clientEnvs = $script:clientEnvs.GetEnumerator() | Sort-Object -Property key
$script:clientSettings = Get-Setting
switch ($true) {
	$IsWindows {
		$script:os = (Get-CimInstance -Class Win32_OperatingSystem).Caption
		$script:kernel = (Get-CimInstance -Class Win32_OperatingSystem).Version
		$script:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
		$script:guid = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
		$script:appId = (Get-StartApps | Where-Object { $_.Name -cmatch 'PowerShell*' })[0].AppId
		continue
	}
	$IsLinux {
		$script:os = if (Test-Path '/etc/os-release') { (& grep 'PRETTY_NAME' /etc/os-release).Replace('PRETTY_NAME=', '').Replace('"', '') } else { (& uname -n) }
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = if (Test-Path '/etc/machine-id') { (Get-Content /etc/machine-id) } else { ([guid]::NewGuid()).tostring().replace('-', '') }
		continue
	}
	$IsMacOS {
		$script:os = ('{0} {1}' -f (& sw_vers -productName), (& sw_vers -productVersion))
		$script:kernel = (&  uname -r)
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = (& system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }').replace('-', '')
		continue
	}
	default {
		$script:os = [String][System.Environment]::OSVersion
		$script:kernel = ''
		$script:arch = ''
		$script:guid = ''
	}
}
