###################################################################################
#
#		TVerRec固有関数スクリプト(ダウンロード履歴の読み書き・整理・字幕の記録)
#
###################################################################################
<#
	.SYNOPSIS
		ダウンロード履歴の読み書き・整理・字幕の記録の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

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
	$latestHists = @()
	try {
		Wait-FileLock $script:histLockFilePath
		# videoPageごとに最新のdownloadDateを持つレコードを取得
		$latestHists = (Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8) |
			Group-Object -Property 'videoPage' |
			ForEach-Object { $_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1 }
	} catch { throw ($script:msg.LoadFailed -f $script:msg.HistFile) }	# * 履歴を読めないまま空で続行すると全番組を未ダウンロード扱いにしてしまうため、他のRead系関数と同様に例外とする
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	return $latestHists
}

#----------------------------------------------------------------------
# ダウンロード履歴の最新レコードを取得(一括ダウンロード中はキャッシュを使用)
#----------------------------------------------------------------------
function Get-LatestHistoryCached {
	<#
		.SYNOPSIS
			ダウンロード履歴の最新レコードを取得します。キャッシュがあればキャッシュを返します。

		.DESCRIPTION
			`$script:histCache`が設定されている場合は、履歴ファイルを読み直さずにその内容を返します。
			設定されていない場合は`Get-LatestHistory`で履歴ファイルを読み込みます。
			一括ダウンロードで番組ごとに履歴ファイル(CSV)の全件読み込みが走るのを避けるために使用します。

		.OUTPUTS
			[PSCustomObject[]] 各ビデオページの最新履歴レコードの配列

		.NOTES
			キャッシュは呼び出し元(download_bulk.ps1)が設定・破棄します。
			キャッシュ中は、他のPCが履歴ファイルに追記した内容は反映されません。
	#>
	[OutputType([PSCustomObject])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ((Test-Path Variable:Script:histCache) -and ($null -ne $script:histCache)) { return $script:histCache }
	return (Get-LatestHistory)
}

#----------------------------------------------------------------------
# ダウンロード履歴のキャッシュに新しいレコードを反映
#----------------------------------------------------------------------
function Add-LatestHistoryCache {
	<#
		.SYNOPSIS
			ダウンロード履歴のキャッシュに、履歴ファイルへ追記したレコードを反映します。

		.DESCRIPTION
			`$script:histCache`が設定されている場合に、同じビデオページのレコードを新しいレコードで置き換えます。
			キャッシュが設定されていない場合は何もしません。

		.PARAMETER Record
			履歴ファイルに追記したレコードを指定します。

		.OUTPUTS
			[Void]
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'スクリプト内のキャッシュ変数を更新するだけで、システムの状態は変更しない')]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $false)][AllowNull()][PSCustomObject]$Record)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-Path Variable:Script:histCache) -or ($null -eq $script:histCache) -or ($null -eq $Record)) { return }
	$script:histCache = @(@($script:histCache).Where({ $_ -and ($_.videoPage -ne $Record.videoPage) })) + @($Record)
	$script:histIdSet = $null	# ダウンロード済みIDのキャッシュは次回に作り直す
}

#----------------------------------------------------------------------
# ダウンロード対象外リストを取得(一括ダウンロード中はキャッシュを使用)
#----------------------------------------------------------------------
function Get-IgnoreListCached {
	<#
		.SYNOPSIS
			ダウンロード対象外番組のリストを取得します。キャッシュがあればキャッシュを返します。

		.DESCRIPTION
			`$script:ignoreCache`が設定されている場合は、ファイルを読み直さずにその内容を返します。
			設定されていない場合は`Read-IgnoreList`でファイルを読み込みます。

		.OUTPUTS
			[String[]] ダウンロード対象外番組名の配列

		.NOTES
			キャッシュは呼び出し元(download_bulk.ps1)が設定・破棄します。
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ((Test-Path Variable:Script:ignoreCache) -and ($null -ne $script:ignoreCache)) { return $script:ignoreCache }
	return (Read-IgnoreList)
}

#----------------------------------------------------------------------
# 字幕の有無の記録と再ダウンロードが有効かの判定
#----------------------------------------------------------------------
function Test-SubtitleTrackingEnabled {
	<#
		.SYNOPSIS
			字幕の有無の記録と、字幕が追加された番組の再ダウンロードが有効かを判定します。

		.DESCRIPTION
			`$script:redownloadWhenSubtitleAdded`が有効で、字幕の埋め込みが有効、かつ、mp4形式のときだけ有効とみなします。
			(字幕を埋め込まない場合は、字幕の有無を判定する意味がないため)

		.OUTPUTS
			[Boolean]
	#>
	[OutputType([Boolean])]
	Param ()
	return [Boolean]($script:redownloadWhenSubtitleAdded -and $script:embedSubtitle -and ($script:videoContainerFormat -eq 'mp4'))
}

#----------------------------------------------------------------------
# 番組の字幕の有無をyoutube-dlで確認
#----------------------------------------------------------------------
function Get-VideoSubtitleStatus {
	<#
		.SYNOPSIS
			TVerの番組に字幕が提供されているかを、ダウンロード前に確認します。

		.DESCRIPTION
			エピソードJSONのisSubtitle(Get-VideoInfoが取得済み)が渡されたときは、それをそのまま使います。
			渡されなかったとき(取得できなかったとき)は、
			`yt-dlp --skip-download --print %(subtitles)j`で字幕の一覧だけを取得します。
			字幕があれば`1`、字幕がなければ`0`を返します。
			取得に失敗した場合(配信終了や通信エラーなど)は、字幕の有無を判断できないため空文字を返します。

		.PARAMETER EpisodePageURL
			エピソードページのURLを指定します。

		.OUTPUTS
			[String]
			`1`: 字幕あり、`0`: 字幕なし、空文字: 不明
	#>
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true)][String]$EpisodePageURL,
		[Object]$IsSubtitle = $null
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($IsSubtitle -is [Boolean]) { return $(if ($IsSubtitle) { '1' } else { '0' }) }
	$ytdlArgs = @('--skip-download', '--no-warnings', '--socket-timeout', '30', '--print', '%(subtitles)j')
	if ($script:proxyUrl) { $ytdlArgs += @('--geo-verification-proxy', $script:proxyUrl) }
	if (($script:ytdlRandomIp) -and (!$script:proxyUrl)) { $ytdlArgs += @('--xff', ('{0}/32' -f $script:jpIP)) }
	$ytdlArgs += $EpisodePageURL
	try {
		$output = @(& $script:ytdlPath @ytdlArgs 2>$null)
		if ($LASTEXITCODE -ne 0) { return '' }
		$text = ($output -join '').Trim()
		if (($text -eq 'NA') -or ($text -eq 'null')) { return '0' }	# 字幕がない番組はNAが返る
		$subtitles = $text | ConvertFrom-Json -ErrorAction Stop
		if ($subtitles -isnot [PSCustomObject]) { return '' }
		if (@($subtitles.PSObject.Properties).Count -gt 0) { return '1' }
		return '0'
	} catch { Write-Debug $_ ; return '' }
}

#----------------------------------------------------------------------
# 番組ファイルの字幕の有無をffprobeで確認
#----------------------------------------------------------------------
function Test-VideoFileHasSubtitle {
	<#
		.SYNOPSIS
			番組ファイルに字幕ストリームが含まれているかをffprobeで確認します。

		.PARAMETER VideoPath
			番組ファイルのパスを指定します。

		.OUTPUTS
			[Nullable[Boolean]]
			字幕があれば$true、なければ$false、確認できなければ$nullを返します。
	#>
	[OutputType([Object])]
	Param ([Parameter(Mandatory = $true)][String]$VideoPath)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-Path -LiteralPath $VideoPath -PathType Leaf)) { return $null }
	if (!(Test-Path -LiteralPath $script:ffprobePath -PathType Leaf)) { return $null }
	$probeOutPath = Join-Path ([IO.Path]::GetTempPath()) ('tverrec_subprobe_{0}.txt' -f [Guid]::NewGuid().ToString('N'))
	try {
		$probeArgs = ('-v error -select_streams s -show_entries stream=index -of csv=p=0 "{0}"' -f $VideoPath)
		$probe = Start-Process -FilePath $script:ffprobePath -ArgumentList $probeArgs -RedirectStandardOutput $probeOutPath -NoNewWindow -Wait -PassThru
		if (($probe.ExitCode -ne 0) -or !(Test-Path -LiteralPath $probeOutPath)) { return $null }
		return [Boolean](@(Get-Content -LiteralPath $probeOutPath -Encoding UTF8 | Where-Object { $_.Trim() -ne '' }).Count -gt 0)
	} catch { Write-Debug $_ ; return $null }
	finally { Remove-Item -LiteralPath $probeOutPath -Force -ErrorAction SilentlyContinue }
}

#----------------------------------------------------------------------
# ダウンロード履歴にsubtitle列があるかの判定
#----------------------------------------------------------------------
function Test-HistorySubtitleColumn {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルに字幕の有無を記録する列(subtitle)があるかを判定します。

		.OUTPUTS
			[Boolean]
	#>
	[OutputType([Boolean])]
	Param ()
	if ((Test-Path Variable:Script:histHasSubtitleColumn) -and $script:histHasSubtitleColumn) { return $true }
	try {
		$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
		try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
	} catch { return $false }
	$has = [Boolean]($header -and ($header -match '(^|,)"?subtitle"?(,|$)'))
	if ($has) { $script:histHasSubtitleColumn = $true }
	return $has
}

#----------------------------------------------------------------------
# ダウンロード履歴にsubtitle列を追加
#----------------------------------------------------------------------
function Add-HistorySubtitleColumn {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルに字幕の有無を記録する列(subtitle)を追加します。

		.DESCRIPTION
			既存の履歴の字幕の有無は不明なので、追加する列は空にします。
			すでに列がある場合は何もしません。
			追加前の履歴は`history.csv.bak`に退避します。

		.OUTPUTS
			[String]
			`Exists`: すでに列がある、`Added`: 追加した、`Failed`: 追加に失敗した
	#>
	[OutputType([String])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-HistorySubtitleColumn) { return 'Exists' }
	$locked = $false
	$tempPath = $null
	try {
		Wait-FileLock $script:histLockFilePath
		$locked = $true
		# ロックを待つ間に他のプロセスが追加した場合
		if (Test-HistorySubtitleColumn) { return 'Exists' }
		$tempPath = '{0}.{1}.tmp' -f $script:histFilePath, [Guid]::NewGuid().ToString('N')
		$hists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -ErrorAction Stop)
		if ($hists.Count -gt 0) {
			$hists | Select-Object -Property *, @{ Name = 'subtitle' ; Expression = { '' } } | Export-Csv -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
		} else {
			$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
			try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
			if ([String]::IsNullOrWhiteSpace($header)) { throw 'History CSV header is missing.' }
			[IO.File]::WriteAllText($tempPath, ('{0},"subtitle"{1}' -f $header, [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
		}
		[IO.File]::Replace($tempPath, $script:histFilePath, ('{0}.bak' -f $script:histFilePath))
		$script:histHasSubtitleColumn = $true
		return 'Added'
	} catch { Write-Debug $_ ; return 'Failed' }
	finally {
		try { if ($null -ne $tempPath -and [IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } }
		finally { if ($locked) { Unlock-File $script:histLockFilePath | Out-Null } }
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴の字幕の有無を更新
#----------------------------------------------------------------------
function Set-HistorySubtitleStatus {
	<#
		.SYNOPSIS
			ダウンロード履歴の字幕の有無を更新するレコードを追記します。

		.PARAMETER VideoHist
			更新対象の番組の履歴レコード(Get-LatestHistoryで取得したもの)を指定します。

		.PARAMETER Status
			`1`: 字幕あり、`0`: 字幕なし、空文字: 不明
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)]$VideoHist,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$Status
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!(Test-HistorySubtitleColumn)) { return }
	if (!$PSCmdlet.ShouldProcess($script:histFilePath, 'Update subtitle status')) { return }
	$record = $VideoHist.PSObject.Copy()
	$record.subtitle = $Status
	$record.downloadDate = Get-TimeStamp
	Wait-FileLock $script:histLockFilePath
	try { $record | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1 }
	catch { Write-Warning ($script:msg.HistUpdateFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
}

#----------------------------------------------------------------------
# 字幕の再確認の対象をダウンロード済みから除外
#----------------------------------------------------------------------
function Remove-SubtitleRecheckTarget {
	<#
		.SYNOPSIS
			ダウンロード履歴から、字幕の再確認の対象になる番組(字幕なしで保存済み)を除きます。

		.DESCRIPTION
			ダウンロード済みの番組を判定する際に、字幕の再確認の対象を「ダウンロード済み」に含めないために使用します。
			字幕の再確認が有効でない場合は、履歴をそのまま返します。

		.PARAMETER Hist
			ダウンロード履歴のレコードを指定します。

		.OUTPUTS
			[Object[]]
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '履歴のレコードを絞り込んで返すだけで、システムの状態は変更しない')]
	[OutputType([Object[]])]
	Param ([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()][Object[]]$Hist)
	if (!(Test-SubtitleTrackingEnabled)) { return @($Hist) }
	return @($Hist.Where({ !($_.PSObject.Properties['subtitle'] -and ($_.subtitle -eq '0')) }))
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
			- subtitle: 字幕の有無(1:字幕あり、0:字幕なし、空:不明)

		.EXAMPLE
			$historyRecord = Format-HistoryRecord -videoInfo $videoInfo

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオ情報から必要なデータを抽出
			2. ダウンロード履歴レコードの形式に整形
			3. 整形したレコードを返す
	#>
	Param ([Parameter(Mandatory = $true)][PSCustomObject]$videoInfo)
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
		subtitle        = if ($videoInfo.PSObject.Properties['subtitle']) { [String]$videoInfo.subtitle } else { '' }
	}
}

#----------------------------------------------------------------------
# ダウンロード履歴ファイルの安全な保存(一時ファイル経由で置換)
#----------------------------------------------------------------------
function Save-HistoryFile {
	<#
		.SYNOPSIS
			ダウンロード履歴ファイルを、一時ファイル経由で安全に書き換えます。

		.DESCRIPTION
			履歴の内容をいったん一時ファイルに書き出し、書き出しが成功してから履歴ファイルと置換します。
			書き出し中に失敗したり、処理が強制停止されたりしても、元の履歴ファイルは変更されません。
			置換時には直前の履歴を「.bak」として退避します。
			呼び出し元で履歴ファイルのロック(Wait-FileLock)を取得した状態で使用してください。

		.PARAMETER Records
			CSV形式で保存するレコードを指定します。0件の場合は元のCSVヘッダーだけを残します。

		.PARAMETER Lines
			テキスト行として保存する内容を指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。失敗時は例外をスローします。
	#>
	[CmdletBinding(DefaultParameterSetName = 'Csv')]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Csv')][AllowEmptyCollection()][AllowNull()][Object[]]$Records,
		[Parameter(Mandatory = $true, ParameterSetName = 'Text')][AllowEmptyCollection()][AllowNull()][String[]]$Lines
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tempPath = '{0}.{1}.tmp' -f $script:histFilePath, [Guid]::NewGuid().ToString('N')
	try {
		if ($PSCmdlet.ParameterSetName -eq 'Text') {
			if ($Lines) { $Lines | Set-Content -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop }
			else { New-Item -ItemType File -Path $tempPath -Force -ErrorAction Stop | Out-Null }
		} elseif ($null -ne $Records -and @($Records).Count -gt 0) {
			$Records | Export-Csv -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
		} else {
			# 全件削除でもCSVヘッダーを残し、次回の追記を読み取れるようにする
			$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
			try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
			if ([String]::IsNullOrWhiteSpace($header)) { throw 'History CSV header is missing.' }
			[IO.File]::WriteAllText($tempPath, $header + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
		}
		# 共有フォルダやウイルス対策ソフトによる一時的なアクセス競合に備えて、置換を数回リトライする
		for ($retry = 1 ; $retry -le 5 ; $retry++) {
			try { [IO.File]::Replace($tempPath, $script:histFilePath, $script:histFilePath + '.bak') ; break }
			catch { if ($retry -ge 5) { throw } ; Start-Sleep -Milliseconds 200 }
		}
	} finally {
		try { if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } } catch { Write-Debug $_.Exception.Message }
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
		Wait-FileLock $script:histLockFilePath
		$originalLists = @(Get-Content -LiteralPath $script:histFilePath -Encoding UTF8 -ErrorAction Stop)
		# NULL文字(0x00)を含む行をフィルタリング
		$cleanedHist = $originalLists.Where({ $_ -notmatch "`0" })
		# 一時ファイル経由で置換(途中で失敗・強制停止されても元の履歴は壊れない)
		try { Save-HistoryFile -Lines $cleanedHist }
		finally { Start-Sleep -Seconds 1 }
	} catch { Write-Warning ($script:msg.OptimizeHistFailed) }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	try {
		Wait-FileLock $script:histLockFilePath
		$originalLists = Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		# videoValidatedがNullでなく、整数に変換可能。downloadDateが日付に変換できるものを残す
		$cleanedHist = $originalLists.Where({
			($null -ne $_.videoValidated) `
					-and ([Int]::TryParse($_.videoValidated, [Ref]0)) `
					-and ([DateTime]::TryParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null, [System.Globalization.DateTimeStyles]::None, [Ref]([DateTime]::MinValue)))
			})
		# 一時ファイル経由で置換(途中で失敗・強制停止されても元の履歴は壊れない)
		try { Save-HistoryFile -Records $cleanedHist }
		finally { Start-Sleep -Seconds 1 }
	} catch {
		Write-Warning ($script:msg.OptimizeHistFailed)
	} finally {
		Unlock-File $script:histLockFilePath | Out-Null
		Remove-Variable -Name cleanedHist -ErrorAction SilentlyContinue
	}
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
		Wait-FileLock $script:histLockFilePath
		$originalLists = Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		$purgedHist = $originalLists.Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * $retentionPeriod) })
		# 一時ファイル経由で置換(途中で失敗・強制停止されても元の履歴は壊れない)
		try { Save-HistoryFile -Records $purgedHist }
		finally { Start-Sleep -Seconds 1 }
	} catch {
		Write-Warning ($script:msg.CleanupHistFailed)
	} finally {
		Unlock-File $script:histLockFilePath | Out-Null
		Remove-Variable -Name retentionPeriod, purgedHist -ErrorAction SilentlyContinue
	}
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
	$locked = $false
	$tempPath = $null
	try {
		# 読み込みから置換まで同じロックを保持し、途中の追記を失わないようにする
		Wait-FileLock $script:histLockFilePath
		$locked = $true
		$latestHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -ErrorAction Stop |
			Group-Object -Property 'videoPage' |
			ForEach-Object { $_.Group | Sort-Object -Property downloadDate, videoValidated -Descending | Select-Object -First 1 })
		$uniquedHist = @($latestHists.Where({ $_.videoValidated -ne '3' }))
		$tempPath = '{0}.{1}.tmp' -f $script:histFilePath, [Guid]::NewGuid().ToString('N')
		if ($uniquedHist.Count -gt 0) {
			$uniquedHist | Export-Csv -LiteralPath $tempPath -Encoding UTF8 -ErrorAction Stop
		} else {
			# 全件削除でもCSVヘッダーを残し、次回の追記を読み取れるようにする
			$reader = [IO.StreamReader]::new($script:histFilePath, [Text.Encoding]::UTF8, $true)
			try { $header = $reader.ReadLine() } finally { $reader.Dispose() }
			if ([String]::IsNullOrWhiteSpace($header)) { throw 'History CSV header is missing.' }
			[IO.File]::WriteAllText($tempPath, $header + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
		}
		# 一時ファイルの保存失敗時は元履歴に触れず、置換時に直前の履歴を退避する
		[IO.File]::Replace($tempPath, $script:histFilePath, $script:histFilePath + '.bak')
	} catch {
		Write-Warning ($script:msg.DistinctHistFailed)
	} finally {
		try {
			if ($null -ne $tempPath -and [IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
		} finally {
			if ($locked) { Unlock-File $script:histLockFilePath | Out-Null }
		}
	}

}
#endregion ダウンロード履歴関連
