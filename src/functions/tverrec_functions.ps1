###################################################################################
#
#		TVerRec固有関数スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
Add-Type -AssemblyName 'System.Globalization' | Out-Null

#region 起動時関連
#----------------------------------------------------------------------
# TVerRec Logo表示
#----------------------------------------------------------------------
function Show-Logo {
	<#
		.SYNOPSIS
			TVerRecのロゴを表示します。

		.DESCRIPTION
			TVerRecのロゴをコンソールに表示します。

		.EXAMPLE
			Show-Logo
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# [Console]::ForegroundColor = 'Red'
	foreach ($line in $script:logoLines) { Write-Output $line }
	# [Console]::ResetColor()
	Write-Output (" {0,$(72 - $script:appVersion.Length)}Version. {1}  " -f ' ', $script:appVersion)
}

#----------------------------------------------------------------------
# バージョン比較
#----------------------------------------------------------------------
function Compare-Version {
	<#
		.SYNOPSIS
			バージョン文字列を比較します。

		.DESCRIPTION
			2つのバージョン文字列を比較し、大小関係を返します。

		.PARAMETER remote
			比較対象のリモートバージョン文字列です。

		.PARAMETER local
			比較対象のローカルバージョン文字列です。

		.OUTPUTS
			[int] バージョンの大小関係を示す整数値。
			リモートバージョンが新しい場合は1、ローカルバージョンが新しい場合は-1、同じ場合は0を返します。

		.EXAMPLE
			$result = Compare-Version -remote "1.2.3" -local "1.2.2"
			Write-Output $result

		.NOTES
			この関数は、バージョン文字列を"."でユニットに切り分け、ユニット毎に比較します。
			ユニット数が少ない方の表記に探索幅を合わせ、探索幅に従ってユニット毎に比較していきます。
			個々のユニットが完全に一致している場合は、ユニット数が多い方が大きいとします。
	#>
	param (
		[String]$remote,
		[String]$local
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($remote -eq $local) { return 0 }
	# バージョンを"."でユニットに切り分ける
	$remoteUnits = ($remote -split '\.').ForEach{ [int]$_ }
	$localUnits = ($local -split '\.').ForEach{ [int]$_ }
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
	<#
		.SYNOPSIS
			TVerRecの最新バージョンを確認し、必要に応じて更新を促します。

		.DESCRIPTION
			GitHubのリリースページからTVerRecの最新バージョンを取得し、
			現在のバージョンと比較します。新しいバージョンが存在する場合は、
			更新を促すメッセージを表示し、変更履歴を表示します。

		.EXAMPLE
			Invoke-TVerRecUpdateCheck

		.NOTES
			この関数は以下の処理を行います：
			1. GitHubから最新リリース情報を取得
			2. 現在のバージョンと比較
			3. 新しいバージョンがある場合は更新を促す
			4. 変更履歴を表示
			5. 必要に応じてアップデーターを取得
	#>
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
		Invoke-WebRequest -Uri $latestUpdater -OutFile (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') -TimeoutSec $script:timeoutSec
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
	<#
		.SYNOPSIS
			ytdlまたはffmpegの更新スクリプトを実行します。

		.DESCRIPTION
			指定されたツールの更新スクリプトを実行し、更新処理を行います。
			更新に失敗した場合はエラーをスローします。

		.PARAMETER scriptName
			実行する更新スクリプトの名前を指定します。

		.PARAMETER targetName
			更新対象のツール名を指定します。

		.EXAMPLE
			Invoke-ToolUpdateCheck -scriptName "update_ytdl.ps1" -targetName "youtube-dl"

		.NOTES
			この関数は以下の処理を行います：
			1. 指定された更新スクリプトを実行
			2. 更新の成功/失敗を確認
			3. 失敗した場合はエラーをスロー
	#>
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
	<#
		.SYNOPSIS
			指定されたパスのファイルまたはディレクトリの存在を確認し、必要に応じてサンプルファイルをコピーします。

		.DESCRIPTION
			指定されたパスのファイルまたはディレクトリが存在するか確認します。
			存在しない場合、サンプルファイルが指定されていればそれをコピーします。
			サンプルファイルも存在しない場合は、エラーメッセージを表示します。

		.PARAMETER path
			確認するファイルまたはディレクトリのパスを指定します。

		.PARAMETER errorMessage
			パスが存在しない場合に表示するエラーメッセージを指定します。

		.PARAMETER isFile
			パスがファイルかディレクトリかを指定します。デフォルトはディレクトリです。

		.PARAMETER sampleFilePath
			サンプルファイルのパスを指定します。省略可能です。

		.PARAMETER continue
			エラーが発生した場合に処理を続行するかどうかを指定します。デフォルトは$falseです。

		.EXAMPLE
			Invoke-TverrecPathCheck -path "C:\TVerRec\config" -errorMessage "設定ディレクトリ" -isFile $false

		.NOTES
			この関数は以下の処理を行います：
			1. 指定されたパスの存在確認
			2. 存在しない場合、サンプルファイルのコピーを試みる
			3. サンプルファイルも存在しない場合、エラーメッセージを表示
	#>
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
	<#
		.SYNOPSIS
			設定で指定された必須ファイルとディレクトリの存在を確認します。

		.DESCRIPTION
			設定ファイルで指定された必須のファイルとディレクトリが存在するか確認します。
			存在しない場合はエラーをスローします。

		.EXAMPLE
			Invoke-RequiredFileCheck

		.NOTES
			この関数は以下のファイルとディレクトリの存在を確認します：
			1. ダウンロードベースディレクトリ
			2. 作業ディレクトリ
			3. 保存ベースディレクトリ
			4. youtube-dl実行ファイル
			5. ffmpeg実行ファイル
			6. ffprobe実行ファイル（簡易検証が有効な場合）
			7. キーワードファイル
			8. 無視ファイル
			9. 履歴ファイル
			10. リストファイル
	#>
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
#endregion 起動時関連

#region ダウンロード履歴関連
#----------------------------------------------------------------------
# ダウンロード履歴の最新履歴を取得
#----------------------------------------------------------------------
function Get-LatestHistory {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルから各ビデオページの最新の履歴を取得します。

		.DESCRIPTION
			ダウンロード履歴ファイルを読み込み、各ビデオページごとに
			最新のダウンロード日時を持つレコードを取得します。

		.OUTPUTS
			[PSCustomObject[]] 各ビデオページの最新履歴レコードの配列

		.EXAMPLE
			$latestHists = Get-LatestHistory

		.NOTES
			この関数は以下の処理を行います：
			1. 履歴ファイルをロック
			2. CSVファイルとして読み込み
			3. ビデオページごとにグループ化
			4. 各グループから最新のレコードを取得
			5. ロックを解除
	#>
	[OutputType([PSCustomObject])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
	try {
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = (Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8) |
			Group-Object -Property 'videoPage' |
			ForEach-Object { $_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1 }
	} catch { Write-Warning ($script:msg.LoadFailed -f $script:msg.HistFile) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	return $latestHists
	Remove-Variable -Name latestHists -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード履歴データの成形
#----------------------------------------------------------------------
function Format-HistoryRecord {
	<#
		.SYNOPSIS
			ビデオ情報をダウンロード履歴レコードの形式に整形します。

		.DESCRIPTION
			ビデオ情報オブジェクトを参照で受け取り、ダウンロード履歴ファイルに
			保存するための形式に整形します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[PSCustomObject]
			ダウンロード履歴レコード。以下のプロパティを含みます：
			- videoPage: エピソードページのURL
			- videoSeriesPage: シリーズページのURL
			- genre: ジャンル
			- series: シリーズ名
			- season: シーズン名
			- title: エピソードタイトル
			- media: メディア名
			- broadcastDate: 放送日
			- downloadDate: ダウンロード日時
			- videoDir: ビデオディレクトリ
			- videoName: ビデオファイル名
			- videoPath: ビデオファイルの相対パス
			- videoValidated: 検証状態

		.EXAMPLE
			$historyRecord = Format-HistoryRecord -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオ情報から必要なデータを抽出
			2. ダウンロード履歴レコードの形式に整形
			3. 整形したレコードを返す
	#>
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
# ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function Optimize-HistoryFile {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルの不整合を解消します。

		.DESCRIPTION
			ダウンロード履歴ファイルの不整合を解消します。
			NULL文字を含む行を削除し、videoValidatedとdownloadDateの形式を検証します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 履歴ファイルをロック
			2. NULL文字を含む行を削除
			3. videoValidatedとdownloadDateの形式を検証
			4. 検証に合格したレコードのみを残す
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$originalLists = @(Get-Content -LiteralPath $script:histFilePath -Encoding UTF8)
		# NULL文字(0x00)を含む行をフィルタリング
		$cleanedHist = $originalLists.Where({ $_ -notmatch "`0" })
		try { $cleanedHist | Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch { $originalLists | Set-Content -LiteralPath $script:histFilePath -Encoding UTF8 }
		finally { Start-Sleep -Seconds 1 }
	} catch { Write-Warning ($script:msg.OptimizeHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$originalLists = Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		# videoValidatedがNullでなく、整数に変換可能。downloadDateが日付に変換できるものを残す
		$cleanedHist = $originalLists.Where({
			($null -ne $_.videoValidated) `
					-and ([Int]::TryParse($_.videoValidated, [Ref]0)) `
					-and ([DateTime]::TryParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null, [System.Globalization.DateTimeStyles]::None, [Ref]([DateTime]::MinValue)))
			})
		try { $cleanedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch { $originalLists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		finally { Start-Sleep -Seconds 1 }
	} catch { Write-Warning ($script:msg.OptimizeHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name cleanedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 指定日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function Limit-HistoryFile {
	<#
		.SYNOPSIS
			指定された期間より古いダウンロード履歴を削除します。

		.DESCRIPTION
			指定された期間より古いダウンロード履歴を削除します。
			保持期間を過ぎたレコードは履歴ファイルから削除されます。

		.PARAMETER retentionPeriod
			履歴を保持する期間（日数）を指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Limit-HistoryFile -retentionPeriod 30

		.NOTES
			この関数は以下の処理を行います：
			1. 履歴ファイルをロック
			2. 指定期間より古いレコードをフィルタリング
			3. フィルタリングされたレコードを履歴ファイルに保存
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][Int32]$retentionPeriod)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	try {
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$originalLists = Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		$purgedHist = $originalLists.Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * $retentionPeriod) })
		try { $purgedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch { $originalLists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		finally { Start-Sleep -Seconds 1 }
	} catch { Write-Warning ($script:msg.CleanupHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name retentionPeriod, purgedHist -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function Repair-HistoryFile {
	<#
		.SYNOPSIS
			ダウンロード履歴から重複を削除します。

		.DESCRIPTION
			ダウンロード履歴から重複を削除します。
			videoPageごとに最新のdownloadDateを持つレコードを残し、
			videoValidatedが「3:チェック失敗」のものと同じvideoPageを持つレコードを削除します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. videoPageごとに最新のdownloadDateを持つレコードを取得
			2. videoValidatedが「3:チェック失敗」のものと同じvideoPageを持つレコードを削除
			3. 重複削除されたレコードを履歴ファイルに保存
	#>
	[OutputType([Void])]
	Param ()
	try {
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = Get-LatestHistory
		# videoValidatedが「3:チェック失敗」のものと同じvideoPageを持つレコードを削除
		$uniquedHist = $latestHists.Where({ $_.videoValidated -ne '3' })
		while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		try { $uniquedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		catch { $originalLists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 }
		finally { Start-Sleep -Seconds 1 }
	} catch { Write-Warning ($script:msg.DistinctHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	Remove-Variable -Name originalLists, latestHists, uniquedHist -ErrorAction SilentlyContinue
}
#endregion ダウンロード履歴関連

#region ダウンロードリスト関連
#----------------------------------------------------------------------
# ダウンロードリストの読み込み
#----------------------------------------------------------------------
function Read-DownloadList {
	<#
		.SYNOPSIS
			ダウンロードリストファイルからダウンロード対象の情報を読み込みます。

		.DESCRIPTION
			ダウンロードリストファイルをCSV形式で読み込み、ダウンロード対象の
			情報を配列として返します。

		.OUTPUTS
			[PSCustomObject[]] ダウンロード対象の情報の配列

		.EXAMPLE
			$downloadList = Read-DownloadList

		.NOTES
			この関数は以下の処理を行います：
			1. リストファイルをロック
			2. CSVファイルとして読み込み
			3. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$listFileData = @()
	try {
		while (-not (Lock-File $script:listLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
		$listFileData = Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8
	} catch { Throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	return $listFileData
	Remove-Variable -Name listFileData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ダウンロードリストからダウンロードリンクの読み込み
#----------------------------------------------------------------------
function Get-LinkFromDownloadList {
	<#
		.SYNOPSIS
			ダウンロードリストからTVerのエピソードリンクを取得します。

		.DESCRIPTION
			ダウンロードリストファイルからEpisodeIDを抽出し、TVerのエピソード
			リンクに変換して返します。

		.OUTPUTS
			[String[]] TVerのエピソードリンクの配列

		.EXAMPLE
			$videoLinks = Get-LinkFromDownloadList

		.NOTES
			この関数は以下の処理を行います：
			1. リストファイルをロック
			2. CSVファイルとして読み込み
			3. 空行とダウンロード対象外（#で始まる行）を除外
			4. EpisodeIDをTVerのエピソードリンクに変換
			5. ロックを解除
	#>
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
# ダウンロードリストデータの成形
#----------------------------------------------------------------------
function Format-ListRecord {
	<#
		.SYNOPSIS
			ビデオ情報をダウンロードリストレコードの形式に整形します。

		.DESCRIPTION
			ビデオ情報オブジェクトを参照で受け取り、ダウンロードリストファイルに
			保存するための形式に整形します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[PSCustomObject]
			ダウンロードリストレコード。以下のプロパティを含みます：
			- seriesName: シリーズ名
			- seriesID: シリーズID
			- seriesPageURL: シリーズページのURL
			- seasonName: シーズン名
			- seasonID: シーズンID
			- episodeNo: エピソード番号
			- episodeName: エピソードタイトル
			- episodeID: エピソードID
			- episodePageURL: エピソードページのURL
			- media: メディア名
			- provider: プロバイダー名
			- broadcastDate: 放送日
			- endTime: 終了時間
			- keyword: キーワード
			- ignoreWord: 無視する単語
			- descriptionText: 説明文（オプション）

		.EXAMPLE
			$listRecord = Format-ListRecord -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオ情報から必要なデータを抽出
			2. ダウンロードリストレコードの形式に整形
			3. 説明文の有無に応じてプロパティを追加
			4. 整形したレコードを返す
	#>
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
# TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function Update-VideoList {
	<#
		.SYNOPSIS
			TVer番組のダウンロードリストを作成・更新します。

		.DESCRIPTION
			指定されたURLからTVer番組の情報を取得し、ダウンロードリストに追加します。
			ダウンロード対象外リストに含まれる番組は無視されます。

		.PARAMETER keyword
			検索キーワードを参照で指定します。

		.PARAMETER videoLink
			ダウンロードするTVer番組のURLを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Update-VideoList -keyword ([ref]$keyword) -videoLink ([ref]$videoLink)

		.NOTES
			この関数は以下の処理を行います：
			1. 指定されたURLから番組情報を取得
			2. ダウンロード対象外リストとの照合
			3. ダウンロードリストへの追加
			4. リストファイルの更新
	#>
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

#endregion ダウンロードリスト関連

#region ダウンロード対象外リスト関連
#----------------------------------------------------------------------
# ダウンロード対象外番組の読み込み
#----------------------------------------------------------------------
function Read-IgnoreList {
	<#
		.SYNOPSIS
			ダウンロード対象外番組のリストを読み込みます。

		.DESCRIPTION
			ダウンロード対象外番組のリストファイルから、コメント行と空行を除いた
			番組名を読み込み、配列として返します。

		.OUTPUTS
			[String[]] ダウンロード対象外番組名の配列

		.EXAMPLE
			$ignoreTitles = Read-IgnoreList

		.NOTES
			この関数は以下の処理を行います：
			1. 無視ファイルをロック
			2. UTF8エンコーディングで読み込み
			3. コメント行（;で始まる行）と空行を除外
			4. ロックを解除
	#>
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
	<#
		.SYNOPSIS
			ダウンロード対象外番組リストを更新し、使用した番組をリストの先頭に移動します。

		.DESCRIPTION
			指定された番組名をダウンロード対象外リストに追加し、使用した番組を
			リストの先頭に移動します。リストの構造（コメント、対象番組、その他）を
			維持しながら更新します。

		.PARAMETER ignoreTitle
			ダウンロード対象外リストに追加する番組名を指定します。

		.EXAMPLE
			Update-IgnoreList -ignoreTitle "テスト番組"

		.NOTES
			この関数は以下の処理を行います：
			1. 無視ファイルをロック
			2. 既存のリストを読み込み
			3. コメント、対象番組、その他の行を分類
			4. 新しいリストを作成（コメント→対象番組→その他の順）
			5. リストを更新
			6. ロックを解除
	#>
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
			# 改行コードLFを強制 + NFCで出力
			try {
				$ignoreListNew.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC) |
					Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline ; Start-Sleep -Seconds 1
				Write-Debug ($script:msg.IgnoreFileSortCompleted)
			} catch {
				$ignoreLists.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC) |
					Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline ; Start-Sleep -Seconds 1
			} finally { Start-Sleep -Seconds 1 }
		} catch { Write-Warning ($script:msg.IgnoreFileSortFailed) }
		finally { Unlock-File $script:ignoreLockFilePath | Out-Null }
	}
	Remove-Variable -Name ignoreTitle, ignoreLists, ignoreComment, ignoreTarget, ignoreElse, ignoreListNew -ErrorAction SilentlyContinue
}
#endregion ダウンロード対象外リスト関連

#region ダウンロード対象判定処理
#----------------------------------------------------------------------
# ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function Read-KeywordList {
	<#
		.SYNOPSIS
			キーワードファイルからダウンロード対象のキーワードを読み込みます。

		.DESCRIPTION
			キーワードファイルからコメント行と空行を除いたキーワードを読み込み、
			配列として返します。

		.OUTPUTS
			[String[]] キーワードの配列

		.EXAMPLE
			$keywords = Read-KeywordList

		.NOTES
			この関数は以下の処理を行います：
			1. キーワードファイルをUTF8エンコーディングで読み込み
			2. コメント行（#で始まる行）と空行を除外
			3. 残りの行を配列として返す
	#>
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
# URLが既にダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryMatchCheck {
	<#
		.SYNOPSIS
			指定されたURLがダウンロード履歴に存在するかチェックし、未ダウンロードのURLのみを返します。

		.DESCRIPTION
			指定されたURLリストとダウンロード履歴を比較し、まだダウンロードされていない
			URLのみを返します。また、既にダウンロード済みのURLの数も返します。

		.PARAMETER resultLinks
			チェック対象のURLリストを指定します。

		.OUTPUTS
			[String[]]
			未ダウンロードのURLの配列と、既にダウンロード済みのURLの数を含む配列。

		.EXAMPLE
			$result = Invoke-HistoryMatchCheck -resultLinks @("https://tver.jp/...", "https://tver.jp/...")

		.NOTES
			この関数は以下の処理を行います：
			1. 最新のダウンロード履歴を取得
			2. 履歴に存在するURLを抽出
			3. 指定されたURLリストと履歴を比較
			4. 未ダウンロードのURLとダウンロード済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-LatestHistory)
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
	<#
		.SYNOPSIS
			指定されたURLがダウンロードリストに存在するかチェックし、未登録のURLのみを返します。

		.DESCRIPTION
			指定されたURLリストとダウンロードリストを比較し、まだ登録されていない
			URLのみを返します。また、既に登録済みのURLの数も返します。

		.PARAMETER resultLinks
			チェック対象のURLリストを指定します。

		.OUTPUTS
			[String[]]
			未登録のURLの配列と、既に登録済みのURLの数を含む配列。

		.EXAMPLE
			$result = Invoke-ListMatchCheck -resultLinks @("https://tver.jp/...", "https://tver.jp/...")

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロードリストファイルを読み込み
			2. リストに存在するURLを抽出
			3. 指定されたURLリストと比較
			4. 未登録のURLと登録済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoPages = New-Object System.Collections.Generic.List[String]
	foreach ($item in $listFileData) { $listVideoPages.Add('https://tver.jp/episodes/{0}' -f $item.EpisodeID.Replace('#', '')) }
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
	<#
		.SYNOPSIS
			指定されたURLがダウンロードリストまたはダウンロード履歴に存在するかチェックし、未登録のURLのみを返します。

		.DESCRIPTION
			指定されたURLリストとダウンロードリスト、ダウンロード履歴を比較し、
			まだ登録されていないURLのみを返します。また、既に登録済みのURLの数も返します。

		.PARAMETER resultLinks
			チェック対象のURLリストを指定します。

		.OUTPUTS
			[String[]]
			未登録のURLの配列と、既に登録済みのURLの数を含む配列。

		.EXAMPLE
			$result = Invoke-HistoryAndListMatchCheck -resultLinks @("https://tver.jp/...", "https://tver.jp/...")

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロードリストファイルを読み込み
			2. ダウンロード履歴ファイルを読み込み
			3. 両方のリストをマージ
			4. 指定されたURLリストと比較
			5. 未登録のURLと登録済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoPages = New-Object System.Collections.Generic.List[Object]
	foreach ($listFileLine in $listFileData) { $listVideoPages.Add(@('https://tver.jp/episodes/{0}' -f $listFileLine.EpisodeID.Replace('#', ''))) }
	# ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-LatestHistory)
	$histVideoPages = if ($histFileData.Count -eq 0) { @() } else { $histFileData.VideoPage }
	# ダウンロードリストとダウンロード履歴をマージ
	if ($histVideoPages) { $listVideoPages.AddRange($histVideoPages) }
	# URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = Compare-Object -IncludeEqual $resultLinks $listVideoPages
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
	Remove-Variable -Name resultLinks, listFileData, listVideoPages, listFileLine, histFileData, histVideoPages, listCompResult, processedCount, videoLinks -ErrorAction SilentlyContinue
}
#endregion ダウンロード対象判定処理

#region youtube-dl関連
#----------------------------------------------------------------------
# youtube-dlプロセスの起動
#----------------------------------------------------------------------
function Invoke-Ytdl {
	<#
		.SYNOPSIS
			youtube-dlを使用してTVer番組をダウンロードします。

		.DESCRIPTION
			youtube-dlを使用してTVer番組をダウンロードし、指定された形式で保存します。
			プロキシ設定、レート制限、字幕埋め込みなどのオプションをサポートします。

		.PARAMETER videoInfo
			ダウンロードする番組の情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-Ytdl -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード用の一時ディレクトリと保存ディレクトリを設定
			2. youtube-dlの引数を構築（プロキシ、レート制限、字幕設定など）
			3. 既存ファイルの削除とリネーム用のコマンドを設定
			4. youtube-dlプロセスを起動し、タイムアウト監視を開始
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Invoke-StatisticsCheck -Operation 'download'
	if ($IsWindows) { foreach ($dir in @($script:downloadWorkDir, $script:downloadBaseDir)) { if ($dir[-1] -eq ':') { $dir += '\\' } } }
	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $videoInfo.fileDir)

	$ytdlArgs = @(
		$script:ytdlBaseArgs
		('--concurrent-fragments {0}' -f $script:parallelDownloadNumPerFile)
		('--add-header {0}' -f $script:ytdlHttpHeader)
		('--paths "{0}"' -f $saveDir)
		('--paths "{0}"' -f $tmpDir)
		('--ffmpeg-location "{0}"' -f $script:ffmpegPath)
	)
	if ($script:proxyUrl) { $ytdlArgs += ('--geo-verification-proxy {0}' -f $script:proxyUrl) }
	if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { $ytdlArgs += ('--xff "{0}/32"' -f $script:jpIP) }
	if ($script:rateLimit -notin @(0, '')) {
		$rateLimit = [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8)
		$ytdlArgs += ('--limit-rate {0}M' -f $rateLimit)
	}
	if ($script:videoContainerFormat -eq 'mp4') {
		$ytdlArgs += '--merge-output-format mp4 --embed-thumbnail --embed-chapters'
		$ytdlArgs += @('subtitle', 'thumbnail', 'chapter', 'description').ForEach{ '--paths "{0}:{1}"' -f $_, $script:downloadWorkDir }
		if ($script:embedSubtitle) { $ytdlArgs += '--sub-langs all --convert-subs srt --embed-subs' }
		if ($script:embedMetatag) { $ytdlArgs += '--embed-metadata' }
	}

	$pwshRemoveIfExists = 'Remove-Item -LiteralPath ''{0}'' -Force -ErrorAction SilentlyContinue' -f $videoInfo.filePath.Replace("'", "''")
	$ytdlTempOutFile = ('{0}/{1}.{2}' -f $videoInfo.fileDir.Replace("'", "''"), $videoInfo.episodeID, $script:videoContainerFormat)
	$pwshRenameFile = 'Rename-Item -LiteralPath ''{0}'' -NewName ''{1}'' -Force -ErrorAction SilentlyContinue' -f $ytdlTempOutFile, $videoInfo.fileName.Replace("'", "''")
	$ytdlExecArg = 'pwsh -Command \"{0} ; {1}\"' -f $pwshRemoveIfExists, $pwshRenameFile
	$ytdlArgs += ('--exec "after_video:{0}"' -f $ytdlExecArg)
	$ytdlArgs += $script:ytdlOption, $videoInfo.episodePageURL, ('--output "{0}.{1}"' -f $videoInfo.episodeID, $script:videoContainerFormat)

	$ytdlArgsString = $ytdlArgs -join ' '
	Write-Debug ($script:msg.ExecCommand -f 'youtube-dl', $script:ytdlPath, $ytdlArgsString)

	if ((Test-Path Variable:Script:debugMode) -and $script:debugMode) {
		$startProcessParams = @{
			FilePath               = $script:ytdlPath
			ArgumentList           = $ytdlArgsString
			PassThru               = $true
			Wait                   = $true
			NoNewWindow            = $true
			RedirectStandardOutput = $script:ytdlStdOutLogPath
			RedirectStandardError  = $script:ytdlStdErrLogPath
		}
		Write-Output 'youtube-dlの実行中...'
		try {
			$ytdlProcess = Start-Process @startProcessParams
			$ytdlProcess.Handle | Out-Null
			if ($IsWindows) {
				$stdOutContent = [System.Text.Encoding]::GetEncoding(932).GetString([System.IO.File]::ReadAllBytes($script:ytdlStdOutLogPath))
				$stdErrContent = [System.Text.Encoding]::GetEncoding(932).GetString([System.IO.File]::ReadAllBytes($script:ytdlStdErrLogPath))
			} else {
				$stdOutContent = Get-Content -Path $script:ytdlStdOutLogPath -Encoding UTF8
				$stdErrContent = Get-Content -Path $script:ytdlStdErrLogPath -Encoding UTF8
			}
		} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') }
		finally {
			Write-Output $stdOutContent
			Write-Output $stdErrContent
			Write-Output ('Exit Code: {0}' -f $ytdlProcess.ExitCode)
		}
	} else {
		$startProcessParams = @{
			FilePath     = $script:ytdlPath
			ArgumentList = $ytdlArgsString
			PassThru     = $true
		}
		if ($IsWindows -and ($script:windowShowStyle -ne 'Hidden')) { $startProcessParams.WindowStyle = $script:windowShowStyle }
		else {
			if ($IsWindows -and ($script:windowShowStyle -eq 'Hidden')) { $startProcessParams.WindowStyle = $script:windowShowStyle }
			$randomNum = -join (1..16 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
			$logFiles = @(
				@{ Path = $script:ytdlStdOutLogPath; Redirect = 'RedirectStandardOutput' },
				@{ Path = $script:ytdlStdErrLogPath; Redirect = 'RedirectStandardError' }
			)
			foreach ($logFile in $logFiles) {
				$logFilePath = $logFile.Path.Replace('.log', ('_{0}.log' -f $randomNum))
				try { New-Item -Path $logFilePath -ItemType File -Force | Out-Null }
				catch { Write-Warning ($script:msg.FfmpegErrFileInitializeFailed) ; return }
				$startProcessParams[$logFile.Redirect] = $logFilePath
			}
		}
		if ($script:ytdlTimeoutSec -ne 0) {
			try {
				# youtube-dl プロセスを起動
				$ytdlProcess = Start-Process @startProcessParams
				$processId = $ytdlProcess.Id
				$ytdlProcess.Handle | Out-Null
				Write-Debug ('youtube-dl Process ID: {0}' -f $processId)
				# タイムアウト監視ジョブを開始
				$monitorJob = Start-Job -ScriptBlock {
					Param ($processId, $timeoutSeconds)
					$startTime = Get-Date
					while ((Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
						# 指定時間が経過したら強制終了
						if ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -ge $timeoutSeconds) {
							if ($IsWindows) { Start-Process -FilePath 'taskkill' -ArgumentList "/F /T /PID $processId" -NoNewWindow -Wait }
							else { Stop-Process -Id $processId -Force }
							Write-Warning ($script:msg.TerminateDueToTimeout -f 'youtube-dl', $script:ytdlTimeoutSec)
							break
						}
						Start-Sleep -Seconds 1
					}
					exit
				} -ArgumentList $processId, $script:ytdlTimeoutSec
				# ジョブIDを変数に追加
				$script:jobList += $monitorJob.Id
			} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
		} else {
			try {
				$ytdlProcess = Start-Process @startProcessParams
				$processId = $ytdlProcess.Id
				$ytdlProcess.Handle | Out-Null
				Write-Debug ('youtube-dl Process ID: {0}' -f $processId)
			} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
		}
	}

	Remove-Variable -Name tmpDir, saveDir, ytdlArgs, ytdlArgsString, ytdlExecArg, pwshRemoveIfExists, pwshRenameFile, startProcessParams, ytdlProcess, processId -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlプロセスの起動 (TVer以外のサイトへの対応)
#----------------------------------------------------------------------
function Invoke-NonTverYtdl {
	<#
		.SYNOPSIS
			youtube-dlを使用してTVer以外のサイトから動画をダウンロードします。

		.DESCRIPTION
			youtube-dlを使用してTVer以外のサイトから動画をダウンロードし、
			指定された形式で保存します。プロキシ設定やレート制限などの
			オプションをサポートします。

		.PARAMETER videoPageURL
			ダウンロードする動画のページURLを指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-NonTverYtdl -URL 'https://example.com/video'

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード用の一時ディレクトリと保存ディレクトリを設定
			2. youtube-dlの引数を構築（プロキシ、レート制限など）
			3. 既存ファイルの削除とリネーム用のコマンドを設定
			4. youtube-dlプロセスを起動
	#>
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
		('--concurrent-fragments {0}' -f $script:parallelDownloadNumPerFile)
		('--add-header {0}' -f $script:ytdlHttpHeader)
		('--paths "{0}"' -f $saveDir)
		('--paths "{0}"' -f $tmpDir)
		('--ffmpeg-location "{0}"' -f $script:ffmpegPath)
		$(if ($script:proxyUrl) { ('--geo-verification-proxy {0}' -f $script:proxyUrl) })
		$(if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { ('--xff "{0}/32"' -f $script:jpIP) })
		$(if ($script:rateLimit -notin @(0, '')) {
				$rateLimit = [math]::Ceiling([int]$script:rateLimit / $script:parallelDownloadNumPerFile / 8)
				('--limit-rate {0}M' -f $rateLimit)
			})
		'--merge-output-format mp4 --embed-thumbnail --embed-chapters'
		$(@('subtitle', 'thumbnail', 'chapter', 'description').ForEach{ '--paths "{0}:{1}"' -f $_, $script:downloadWorkDir })
		$(if ($script:embedSubtitle) { '--sub-langs all --convert-subs srt --embed-subs' })
		$(if ($script:embedMetatag) { '--embed-metadata' })
		$script:ytdlOption
		"$videoPageURL"
		"--output `"$saveFile`""
	)
	$ytdlArgsString = $ytdlArgs -join ' '
	Write-Debug ($script:msg.ExecCommand -f 'youtube-dl', $script:ytdlPath, $ytdlArgsString)
	$startProcessParams = @{
		FilePath     = $script:ytdlPath
		ArgumentList = $ytdlArgsString
		PassThru     = $true
	}
	if ($IsWindows -and ($script:windowShowStyle -ne 'Hidden')) { $startProcessParams.WindowStyle = $script:windowShowStyle }
	else {
		if ($IsWindows -and ($script:windowShowStyle -eq 'Hidden')) { $startProcessParams.WindowStyle = $script:windowShowStyle }
		$randomNum = -join (1..16 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
		$logFiles = @(
			@{ Path = $script:ytdlStdOutLogPath; Redirect = 'RedirectStandardOutput' },
			@{ Path = $script:ytdlStdErrLogPath; Redirect = 'RedirectStandardError' }
		)
		foreach ($logFile in $logFiles) {
			$logFilePath = $logFile.Path.Replace('.log', ('_{0}.log' -f $randomNum))
			try { New-Item -Path $logFilePath -ItemType File -Force | Out-Null }
			catch { Write-Warning ($script:msg.FfmpegErrFileInitializeFailed) ; return }
			$startProcessParams[$logFile.Redirect] = $logFilePath
		}
	}
	if ($script:ytdlTimeoutSec -ne 0) {
		try {
			# youtube-dl プロセスを起動
			$ytdlProcess = Start-Process @startProcessParams
			$processId = $ytdlProcess.Id
			$ytdlProcess.Handle | Out-Null
			Write-Debug ('youtube-dl Process ID: {0}' -f $processId)
			# タイムアウト監視ジョブを開始
			$monitorJob = Start-Job -ScriptBlock {
				Param ($processId, $timeoutSeconds)
				$startTime = Get-Date
				while ((Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
					# 指定時間が経過したら強制終了
					if ((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds -ge $timeoutSeconds) {
						if ($IsWindows) { Start-Process -FilePath 'taskkill' -ArgumentList "/F /T /PID $processId" -NoNewWindow -Wait }
						else { Stop-Process -Id $processId -Force }
						Write-Warning ($script:msg.TerminateDueToTimeout -f 'youtube-dl', $script:ytdlTimeoutSec)
						break
					}
					Start-Sleep -Seconds 1
				}
				exit
			} -ArgumentList $processId, $script:ytdlTimeoutSec
			# ジョブIDを変数に追加
			$script:jobList += $monitorJob.Id
		} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
	} else {
		try {
			$ytdlProcess = Start-Process @startProcessParams
			$processId = $ytdlProcess.Id
			$ytdlProcess.Handle | Out-Null
			Write-Debug ('youtube-dl Process ID: {0}' -f $processId)
		} catch { Write-Warning ($script:msg.ExecFailed -f 'youtube-dl') ; return }
	}
	Remove-Variable -Name videoPageURL, tmpDir, baseDir, subttlDir, thumbDir, chaptDir, descDir, saveFile, ytdlArgs, ytdlArgsString, rateLimit, startProcessParams, ytdlProcess -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlのプロセスカウントを取得
#----------------------------------------------------------------------
function Get-YtdlProcessCount {
	<#
		.SYNOPSIS
			現在実行中のyoutube-dlプロセスの数を取得します。

		.DESCRIPTION
			現在実行中のyoutube-dlプロセスの数を取得します。
			プラットフォームに応じて適切な方法でプロセス数をカウントします。

		.OUTPUTS
			[Int]
			実行中のyoutube-dlプロセスの数。

		.NOTES
			この関数は以下の処理を行います：
			1. プラットフォームに応じて適切な方法でプロセスをカウント
			2. Windows: youtube-dlプロセスの数を2で割って返す
			3. Linux: youtube-dlプロセスの数をそのまま返す
			4. macOS: psコマンドでyoutube-dlプロセスをカウント
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$processName = switch ($script:preferredYoutubedl) {
		'yt-dlp' { 'yt-dlp' }
		'ytdl-patched' { 'youtube-dl' }
		'yt-dlp-nightly' { 'yt-dlp' }
	}
	try {
		switch ($true) {
			$IsWindows { return [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name $processName).Count / 2, [MidpointRounding]::AwayFromZero ); break }
			$IsLinux { return @(Get-Process -ErrorAction Ignore -Name $processName).Count ; break }
			$IsMacOS { $psCmd = 'ps' ; return (& sh -c $psCmd | grep $processName | grep -v grep | grep -c ^).Trim() ; break }
			default { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
		}
	} catch { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
	Remove-Variable -Name processName, psCmd -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ffmpegプロセス数の取得
#----------------------------------------------------------------------
function Get-FfmpegProcessCount {
	<#
		.SYNOPSIS
			現在実行中のffmpegプロセスの数を取得します。

		.DESCRIPTION
			現在実行中のffmpegプロセスの数を取得します。
			プラットフォームに応じて適切な方法でプロセス数をカウントします。

		.OUTPUTS
			[Int]
			実行中のffmpegプロセスの数。

		.NOTES
			この関数は以下の処理を行います：
			1. プラットフォームに応じて適切な方法でプロセスをカウント
			2. Windows: ffmpegプロセスの数をそのまま返す
			3. Linux: ffmpegプロセスの数をそのまま返す
			4. macOS: psコマンドでffmpegプロセスをカウント
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$processName = 'ffmpeg'
	try {
		switch ($true) {
			$IsWindows { return [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name $processName).Count, [MidpointRounding]::AwayFromZero ); break }
			$IsLinux { return @(Get-Process -ErrorAction Ignore -Name $processName).Count ; break }
			$IsMacOS { $psCmd = 'ps' ; return (& sh -c $psCmd | grep $processName | grep -v grep | grep -c ^).Trim() ; break }
			default { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
		}
	} catch { Write-Debug ($script:msg.GetDownloadProcNumFailed) ; return 0 }
	Remove-Variable -Name processName, psCmd -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function Wait-DownloadCompletion () {
	<#
		.SYNOPSIS
			youtube-dlプロセスが終了するまで待機します。

		.DESCRIPTION
			youtube-dlプロセスが終了するまで待機します。
			1分ごとにプロセス数を確認し、すべてのプロセスが終了するまで待機します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在のyoutube-dlプロセス数を取得
			2. プロセス数が0になるまで1分ごとに確認
			3. プロセス数をコンソールに表示
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = [Int](Get-YtdlProcessCount)
	<# * ffmpegでのダウンロード機能を有効化時に必要
		$ffmpegCount = [Int](Get-FfmpegProcessCount)
		while (($ytdlCount + $ffmpegCount) -ne 0) {
	#>
	while ($ytdlCount -ne 0) {
		# Write-Information ($script:msg.NumDownloadProc -f (Get-Date), ($ytdlCount + $ffmpegCount))
		Write-Information ($script:msg.NumDownloadProc -f (Get-Date), $ytdlCount)
		Start-Sleep -Seconds 60
		$ytdlCount = [Int](Get-YtdlProcessCount)
		<# * ffmpegでのダウンロード機能を有効化時に必要
			# $ffmpegCount = [Int](Get-FfmpegProcessCount)
		#>
	}
	Remove-Variable -Name ytdlCount -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function Wait-YtdlProcess {
	<#
		.SYNOPSIS
			youtube-dlプロセスの数を確認し、指定された数以下になるまで待機します。

		.DESCRIPTION
			youtube-dlプロセスの数を監視し、指定された並列ダウンロード数以下になるまで
			待機します。定期的にプロセス数を表示しながら、60秒間隔でチェックします。

		.PARAMETER parallelDownloadFileNum
			並列ダウンロードの最大数を指定します。

		.EXAMPLE
			Wait-YtdlProcess -parallelDownloadFileNum 3

		.NOTES
			この関数は以下の処理を行います：
			1. youtube-dlプロセスの数を取得
			2. 指定された数以下になるまで待機
			3. プロセス数を表示
			4. 60秒間隔でチェックを繰り返す
	#>
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
#endregion youtube-dl関連

#region ダウンロード関連
#----------------------------------------------------------------------
# 「《」と「》」、「【」と「】」で挟まれた文字を除去
#----------------------------------------------------------------------
function Remove-SpecialNote {
	<#
		.SYNOPSIS
			特定の特殊文字で囲まれた文字列を削除します。

		.DESCRIPTION
			入力テキストから特定の特殊文字（《》、【】）で囲まれた文字列を削除します。
			ただし、文字列の長さが一定の閾値（10文字）を超える場合のみ削除を行います。

		.PARAMETER text
			処理対象のテキストを指定します。

		.OUTPUTS
			[String]
			特殊文字で囲まれた文字列が削除されたテキスト。

		.EXAMPLE
			$cleanedText = Remove-SpecialNote -text "これは【テスト】です"

		.NOTES
			この関数は以下の処理を行います：
			1. 《》と【】の各ペアの位置を検出
			2. 文字列の長さが閾値（10文字）を超える場合のみ削除
			3. 削除後、余分な空白を除去
			4. 処理後のテキストを返す
	#>
	Param ([Parameter(Mandatory = $true)][String]$text)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# 特殊文字の位置を取得し、長さを計算
	$length1 = [Math]::Max(0, $text.IndexOf('》') - $text.IndexOf('《'))
	$length2 = [Math]::Max(0, $text.IndexOf('】') - $text.IndexOf('【'))
	# 10文字以上あれば特殊文字とその間を削除
	if (($length1 -gt 10) -or ($length2 -gt 10)) { $text = (($text -replace '《.*?》|【.*?】', '') -replace '\s+', ' ').Trim() }
	return $text
	Remove-Variable -Name text, length1, length2 -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function Invoke-VideoDownload {
	<#
		.SYNOPSIS
			TVer番組のダウンロードを実行するメイン処理です。

		.DESCRIPTION
			指定されたURLからTVer番組をダウンロードし、必要な情報を記録します。
			ダウンロード履歴とダウンロードリストの両方を更新します。

		.PARAMETER keyword
			検索キーワードを参照で指定します。

		.PARAMETER videoLink
			ダウンロードするTVer番組のURLを参照で指定します。

		.PARAMETER force
			強制的にダウンロードを実行するかどうかを指定します。
			デフォルトは$falseです。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-VideoDownload -keyword ([ref]$keyword) -videoLink ([ref]$videoLink) -force $true

		.NOTES
			この関数は以下の処理を行います：
			1. 指定されたURLから番組情報を取得
			2. ダウンロード履歴とダウンロードリストを更新
			3. youtube-dlを使用して番組をダウンロード
			4. ダウンロード結果を記録

			状態の振り分け設定：
			- 履歴ファイルに存在する場合：
			- ID変更時のダウンロード設定あり：再ダウンロード
			- ID変更時のダウンロード設定なし：スキップ
			- 履歴ファイルに存在しない場合：
			- ファイルが存在する：検証のみ
			- ファイルが存在しない：
				- ダウンロード対象外リストに存在：無視
				- ダウンロード対象外リストに存在しない：ダウンロード
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $true)][String]$videoLink,
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
		<# * 状態の振り分け設定
			* ここまで来ているということはEpisodeIDでは履歴とマッチしなかったということ
			* 考えられる原因は履歴ファイルがクリアされてしまっていること、または、EpisodeIDが変更になったこと
				* 履歴ファイルに存在する	→番組IDが変更になったあるいは、番組名の重複
					* ID変更時のダウンロード設定あり
						検証済	→再ダウンロード
						検証中	→元々の番組IDとしてはそのうち検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
						未検証	→元々の番組IDとしては次回検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
					* ID変更時のダウンロード設定なし
						検証済	→元々の番組IDとしては問題ないのでSKIP
						検証中	→元々の番組IDとしてはそのうち検証されるのでSKIP
						未検証	→元々の番組IDとしては次回検証されるのでSKIP
				* 履歴ファイルに存在しない
					ファイルが存在する	→検証だけする
					ファイルが存在しない
						ダウンロード対象外リストに存在する	→無視
						ダウンロード対象外リストに存在しない	→ダウンロード
		#>
		#ダウンロード履歴ファイルのデータを読み込み
		$histFileData = @(Get-LatestHistory)
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
	while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
	try {
		$newVideo | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1
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
# 保存ファイル名を設定
#----------------------------------------------------------------------
function Format-VideoFileInfo {
	<#
		.SYNOPSIS
			ビデオファイルの保存情報を設定します。

		.DESCRIPTION
			ビデオ情報からファイル名、ディレクトリパス、相対パスなどの
			保存に必要な情報を生成します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Format-VideoFileInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. シリーズ名、シーズン名、エピソード番号などからファイル名を生成
			2. メディア名やシリーズ名に基づいてディレクトリパスを生成
			3. ファイル名の長さ制限を適用
			4. ビデオ情報オブジェクトに保存情報を追加
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$videoName = ''
	# ファイル名を生成
	if ($script:addSeriesName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seriesName) }
	if ($script:addSeasonName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seasonName) }
	if ($videoName.Trim() -ne $videoInfo.episodeName.Trim() ) {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターン
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
		$videoName = ('{0}{1}' -f $videoName, $videoInfo.episodeName)
	} else {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターン
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
	}
	# ファイル名にできない文字列を除去
	$videoName = ((Get-FileNameWoInvalidChars (Remove-SpecialCharacter $videoName)) -replace '\s+', ' ').Trim()
	# SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング。安全目の上限値としており、限界値は攻めていない
	$fileNameLimit = $script:fileNameLengthMax - 30
	if ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
		while ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) { $videoName = $videoName.Substring(0, $videoName.Length - 1) }
		$videoName = ('{0}……' -f $videoName)
	}
	$videoName = ('{0}.{1}' -f $videoName, $script:videoContainerFormat)
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileName' -Value $videoName

	# フォルダ名を生成
	$videoFileDir = @()
	if ($script:sortVideoByMedia) { $videoFileDir += Get-FileNameWoInvalidChars (Remove-SpecialCharacter ($videoInfo.mediaName).Trim(' ', '.')) }
	if ($script:sortVideoBySeries) { $videoFileDir += Get-FileNameWoInvalidChars (Remove-SpecialCharacter ('{0} {1}' -f $videoInfo.seriesName, $videoInfo.seasonName ).Trim(' ', '.')) }
	$videoFileDir = Join-Path $script:downloadBaseDir @videoFileDir		# 3コ以上行けるので配列のまま渡す
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileDir' -Value $videoFileDir.Replace('\', '/')

	$videoFilePath = Join-Path $videoFileDir $videoInfo.fileName
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'filePath' -Value $videoFilePath.Replace('\', '/')
	$videoFileRelPath = $videoFilePath.Replace($script:downloadBaseDir, '')
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileRelPath' -Value $videoFileRelPath.Replace('\', '/').TrimStart('/')

	Remove-Variable -Name videoName, fileNameLimit, videoFileDir, videoFilePath, videoFileRelPath -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 番組情報表示
#----------------------------------------------------------------------
function Show-VideoInfo {
	<#
		.SYNOPSIS
			番組の基本情報をコンソールに表示します。

		.DESCRIPTION
			指定されたビデオ情報から、番組名、放送日、メディア名、終了日時、
			エピソード詳細などの情報をコンソールに表示します。

		.PARAMETER videoInfo
			表示する番組情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Show-VideoInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の情報を表示します：
			1. エピソード名（ファイル名から拡張子を除いたもの）
			2. 放送日
			3. メディア名
			4. 終了日時
			5. エピソード詳細（説明文）
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Output ($script:msg.EpisodeName -f $videoInfo.fileName.Replace($script:videoContainerFormat, ''))
	Write-Output ($script:msg.BroadcastDate -f $videoInfo.broadcastDate)
	Write-Output ($script:msg.MediaName -f $videoInfo.mediaName)
	Write-Output ($script:msg.EndDate -f $videoInfo.endTime)
	<#
		Write-Output ($script:msg.IsBrightcove -f $videoInfo.isBrightcove)
		Write-Output ($script:msg.IsStreaks -f $videoInfo.isStreaks)
	#>
	Write-Output ($script:msg.EpisodeDetail -f $videoInfo.descriptionText)
}

#----------------------------------------------------------------------
# 番組情報デバッグ表示
#----------------------------------------------------------------------
function Show-VideoDebugInfo {
	<#
		.SYNOPSIS
			番組のデバッグ情報をコンソールに表示します。

		.DESCRIPTION
			指定されたビデオ情報から、デバッグ用の情報（エピソードページURL）を
			コンソールに表示します。

		.PARAMETER videoInfo
			表示する番組情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Show-VideoDebugInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の情報を表示します：
			1. エピソードページのURL
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Debug $videoInfo.episodePageURL
}

#----------------------------------------------------------------------
# ダウンロードスケジュールに合わせたスケジュール制御
#----------------------------------------------------------------------
function Suspend-Process () {
	<#
		.SYNOPSIS
			ダウンロードスケジュールに基づいてプロセスを一時停止します。

		.DESCRIPTION
			ダウンロードスケジュールに基づいてプロセスを一時停止します。
			指定された曜日と時間にダウンロードを停止し、次の正時まで待機します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在の日付と時刻を取得
			2. スケジュールに基づいて停止時間を確認
			3. 停止時間の場合は次の正時まで待機
	#>
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
#endregion ダウンロード関連


#region ダウンロード失敗ファイル削除関連
#----------------------------------------------------------------------
# 移動に失敗したファイルを削除(作業フォルダ)
#----------------------------------------------------------------------
<#
.SYNOPSIS
    作業フォルダ内の移動に失敗したファイルを削除します。

.DESCRIPTION
    作業フォルダ内の移動に失敗したファイルを削除します。
    ファイル名が特定のパターンに一致するファイルを削除します。

.OUTPUTS
    [Void]
    この関数は値を返しません。

.NOTES
    この関数は以下の処理を行います：
    1. 作業フォルダ内のファイルを検索
    2. ファイル名が特定のパターンに一致するファイルを削除
#>
function Remove-UnMovedTempFile {
	[CmdletBinding()]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	(Get-ChildItem -Path $script:downloadWorkDir -File).Where({ $_.Name -match '^ep[a-z0-9]{8}\..*\.(mp4|ts)$' }) | Remove-Item -Force -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# リネームに失敗したファイルを削除(ダウンロード先フォルダ)
#----------------------------------------------------------------------
function Remove-UnRenamedTempFile {
	<#
		.SYNOPSIS
			ダウンロード先フォルダ内のリネームに失敗したファイルを削除します。

		.DESCRIPTION
			ダウンロード先フォルダ内のリネームに失敗したファイルを削除します。
			ファイル名が特定のパターンに一致するファイルを削除します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード先フォルダ内のファイルを検索
			2. ファイル名が特定のパターンに一致するファイルを削除
	#>
	[CmdletBinding()]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($IsWindows) {
		$forCmd = "for %E in (mp4 ts) do for /r `"$script:downloadBaseDir`" %F in (ep*.%E) do @echo %F"
		(& cmd /c $forCmd).Where({ ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') }) | Remove-Item -Force -ErrorAction SilentlyContinue
	} else {
		$findCmd = "find `"$script:downloadBaseDir`" -type f -name 'ep*.mp4' -or -type f -name 'ep*.ts'"
		(& sh -c $findCmd).Where({ ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') }) | Remove-Item -Force -ErrorAction SilentlyContinue
	}
}
#endregion ダウンロード失敗ファイル削除関連


#region 整合性チェック関連処理
#----------------------------------------------------------------------
# ダウンロードプロセスの待機
#----------------------------------------------------------------------
function Wait-DownloadProcess {
	<#
		.SYNOPSIS
			ダウンロードプロセスが完了するまで待機します。

		.DESCRIPTION
			現在実行中のダウンロードプロセス（yt-dlpとffmpeg）が
			すべて完了するまで待機します。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在のダウンロードプロセス数を取得
			2. プロセス数が0になるまで60秒ごとにチェック
			3. プロセス数が0になったら待機を終了
	#>
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ytdlCount = [Int](Get-YtdlProcessCount)
	# ffmpegでのダウンロード機能を有効化時に必要
	$ffmpegCount = [Int](Get-FfmpegProcessCount)
	while (($ytdlCount + $ffmpegCount) -ne 0) {
		Write-Output ($script:msg.WaitingDownloadProcess -f ($ytdlCount + $ffmpegCount))
		Start-Sleep -Seconds 60
		$ytdlCount = [Int](Get-YtdlProcessCount)
		# ffmpegでのダウンロード機能を有効化時に必要
		$ffmpegCount = [Int](Get-FfmpegProcessCount)
	}
}

#----------------------------------------------------------------------
# ffmpeg/ffprobeプロセスの起動
#----------------------------------------------------------------------
function Invoke-FFmpegProcess {
	<#
		.SYNOPSIS
			ffmpegまたはffprobeプロセスを起動します。

		.DESCRIPTION
			ffmpegまたはffprobeプロセスを起動し、指定された引数で実行します。
			エラーログを記録し、プロセスの終了コードを返します。

		.PARAMETER filePath
			実行するffmpegまたはffprobeのパスを指定します。

		.PARAMETER ffmpegArgs
			ffmpegまたはffprobeに渡す引数を指定します。

		.PARAMETER execName
			実行するコマンドの名前（'ffmpeg'または'ffprobe'）を指定します。

		.OUTPUTS
			[Int]
			プロセスの終了コードを返します。

		.EXAMPLE
			Invoke-FFmpegProcess -filePath 'ffmpeg' -ffmpegArgs '-i input.mp4 output.mp4' -execName 'ffmpeg'

		.NOTES
			この関数は以下の処理を行います：
			1. プロセス起動用のパラメータを設定
			2. エラーログの出力先を設定
			3. プロセスを起動し、終了を待機
			4. プロセスの終了コードを返す
	#>
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
	<#
		.SYNOPSIS
			ダウンロードした番組の整合性をチェックします。

		.DESCRIPTION
			ダウンロードした番組の整合性をチェックします。
			ffmpegまたはffprobeを使用して、ビデオファイルのエラーを検出します。

		.PARAMETER videoHist
			チェックする番組の履歴情報を指定します。

		.PARAMETER decodeOption
			デコードオプションを指定します。デフォルトは空文字列です。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオファイルのパスを取得
			2. チェックステータスを確認
			3. ffmpegまたはffprobeを使用してエラーを検出
			4. エラー数に基づいてチェック結果を記録
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$videoHist,
		[Parameter(Mandatory = $false)][String]$decodeOption = ''
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ffmpegProcessExitCode = 0
	$errorCount = 0
	$videoFilePath = Join-Path (Convert-Path $script:downloadBaseDir) $videoHist.videoPath
	try { New-Item -Path $script:ffmpegErrorLogPath -ItemType File -Force | Out-Null }
	catch { Write-Warning ($script:msg.FfmpegErrFileInitializeFailed) ; return }

	# これからチェックする番組のステータスをチェック
	$latestHists = Get-LatestHistory
	$targetHist = $latestHists.Where({ $_.videoPage -eq $videoHist.videoPage }) | Select-Object -First 1
	if ($targetHist) {
		$checkStatus = $targetHist.videoValidated
		if ($null -ne $checkStatus) {
			# 0:未チェック、1:チェック済、2:チェック中、3:チェック失敗、レコードなしは履歴が削除済み
			switch ($checkStatus) {
				# 「0:未チェック」のレコードは「2:チェック中」に変更したレコードを追記。(downloadDateは現在日時)
				'0' {
					# 該当のレコードを複製
					$targetHist.downloadDate = Get-TimeStamp
					$targetHist.videoValidated = '2'
					while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
					try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
					catch { Write-Warning ($script:msg.HistUpdateFailed) ; return }
					finally { Unlock-File $script:histLockFilePath | Out-Null }
					break
				}
				# 「0:未チェック」以外のステータスの際はスキップして次を処理
				'1' { Write-Output ($script:msg.ValidationCompleted) ; return }
				'2' { Write-Output ($script:msg.ValidationInProgress) ; return }
				'3' { Write-Output ($script:msg.ValidationFailed) ; return }
				default { Write-Warning ($script:msg.HistRecordRemoved -f $videoHist.videoPage) ; return }
			}
		}
	}

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

	$latestHists = Get-LatestHistory
	$targetHist = $latestHists.Where({ $_.videoPage -eq $videoHist.videoPage }) | Select-Object -First 1
	if ($targetHist) {
		# 終了コードが0以外 または エラーが一定以上
		if ( ($ffmpegProcessExitCode -ne 0) -or ($errorCount -gt 30)) {
			Write-Warning ($script:msg.ValidationNG) ; Write-Verbose ($script:msg.ErrorCount -f $ffmpegProcessExitCode, $errorCount)
			# 「3:チェック失敗」に変更したレコードを追記。(downloadDateは現在日時)
			$targetHist.downloadDate = Get-TimeStamp
			$targetHist.videoValidated = '3'
			while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
			catch { Write-Warning ($script:msg.HistUpdateFailed) }
			finally { Unlock-File $script:histLockFilePath | Out-Null }
			# ファイルを削除
			try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction SilentlyContinue | Out-Null }
			catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
		} else {
			# 終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
			Write-Output ($script:msg.ValidationOK)
			$targetHist.downloadDate = Get-TimeStamp
			$targetHist.videoValidated = '1'
			while (-not (Lock-File $script:histLockFilePath).result) { Write-Information ($script:msg.WaitingLock) ; Start-Sleep -Seconds 1 }
			try { $targetHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
			catch { Write-Warning ($script:msg.HistUpdateFailed) }
			finally { Unlock-File $script:histLockFilePath | Out-Null }
		}
	} else {
		Write-Warning ($script:msg.HistRecordNotFound)
		# 該当のレコードがない場合は履歴が削除済み。念の為ファイルも消しておく
		try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction SilentlyContinue | Out-Null }
		catch { Write-Warning ($script:msg.DeleteVideoFailed -f $videoFilePath) }
	}
	Remove-Variable -Name videoFilePath, ffmpegProcessExitCode, errorCount, targetHist, checkStatus, latestHists -ErrorAction SilentlyContinue
}
#endregion 整合性チェック関連処理


#region 環境
#----------------------------------------------------------------------
# システム情報取得
#----------------------------------------------------------------------
function Get-SysInfo {
	<#
		.SYNOPSIS
			システム情報を取得します。

		.DESCRIPTION
			システム情報を取得し、変数に格納します。
			OSのバージョン、アーキテクチャ、GUIDなどの情報を取得します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. OSのバージョン、アーキテクチャ、GUIDを取得
			2. システム情報を変数に格納
			3. GeoIP情報を取得
	#>
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:locale = (Get-Culture).Name
	$script:tz = [String][TimeZoneInfo]::Local.BaseUtcOffset
	$progressPreference = 'SilentlyContinue'
	$script:clientEnvs = @{}
	try {
		$geoIPValues = (Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=18030841' -TimeoutSec 5).psobject.properties
		foreach ($geoIPValue in $geoIPValues) { $script:clientEnvs.Add($geoIPValue.Name, $geoIPValue.Value) | Out-Null }
	} catch { Write-Debug ('Failed to check Geo IP') }
	$progressPreference = 'Continue'

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
			break
		}
		$IsLinux {
			$script:os = if (Test-Path '/etc/os-release') { (& grep 'PRETTY_NAME' /etc/os-release).Replace('PRETTY_NAME=', '').Replace('"', '') } else { (& uname -n) }
			$script:kernel = [String][System.Environment]::OSVersion.Version
			$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
			$script:guid = if (Test-Path '/etc/machine-id') { (Get-Content /etc/machine-id) } else { (New-Guid).ToString().Replace('-', '') }
			break
		}
		$IsMacOS {
			$script:os = ('{0} {1}' -f (& sw_vers -productName), (& sw_vers -productVersion))
			$script:kernel = (&  uname -r)
			$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
			$script:guid = (& system_profiler SPHardwareDataType | awk '/Hardware UUID/ { print $3 }').Replace('-', '')
			break
		}
		default {
			$script:os = [String][System.Environment]::OSVersion
			$script:kernel = 'Unknown'
			$script:arch = 'Unknown'
			$script:guid = 'Unknown'
		}
	}
	Remove-Variable -Name geoIPValues, geoIPValue, osInfo -ErrorAction SilentlyContinue
}
Get-SysInfo

#----------------------------------------------------------------------
# 設定取得
#----------------------------------------------------------------------
function Get-Setting {
	<#
		.SYNOPSIS
			システム設定とユーザー設定を取得します。

		.DESCRIPTION
			システム設定とユーザー設定を取得します。
			設定ファイルから設定値を読み込み、変数に格納します。

		.OUTPUTS
			[System.Collections.Generic.Dictionary[string, object]]
			設定のキーと値のペアを含む辞書。

		.NOTES
			この関数は以下の処理を行います：
			1. 設定ファイルのパスを取得
			2. 設定ファイルから設定値を読み込み
			3. 設定値を変数に格納
	#>
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
$script:clientSettings = Get-Setting

#----------------------------------------------------------------------
# 統計取得
#----------------------------------------------------------------------
function Invoke-StatisticsCheck {
	<#
		.SYNOPSIS
			統計情報を取得します。

		.DESCRIPTION
			統計情報を取得します。
			指定された操作の統計情報を収集し、必要に応じて送信します。

		.PARAMETER operation
			統計を取得する操作を指定します。

		.PARAMETER tverType
			TVerのタイプを指定します。デフォルトは'none'です。

		.PARAMETER tverID
			TVerのIDを指定します。デフォルトは'none'です。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 統計情報のベースURLを設定
			2. 指定された操作の統計情報を取得
			3. 必要に応じて統計情報を送信
	#>
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
		try { Invoke-WebRequest -Uri ('{0}{1}.svg' -f $statisticsBase, $operation) -Method 'GET' -TimeoutSec 5 | Out-Null }
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
#endregion 環境
