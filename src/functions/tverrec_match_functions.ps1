###################################################################################
#
#		TVerRec固有関数スクリプト(ダウンロード済み・リスト登録済みの番組の除外)
#
###################################################################################
<#
	.SYNOPSIS
		ダウンロード済み・リスト登録済みの番組の除外の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

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
	try { $keywords = @((Get-Content $script:keywordFilePath -Encoding UTF8 -ErrorAction Stop).Where({ $_ -notmatch '^\s*$|^#.*$' })) }
	catch { throw ($script:msg.LoadFailed -f $script:msg.KeywordFile) }
	return $keywords
}

#----------------------------------------------------------------------
# URLが既にダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryMatchCheck {
	<#
		.SYNOPSIS
			指定されたエピソードIDがダウンロード履歴に存在するかチェックし、未ダウンロードのエピソードIDのみを返します。

		.DESCRIPTION
			指定されたエピソードIDのリストとダウンロード履歴を比較し、まだダウンロードされていない
			エピソードIDのみを返します。また、既にダウンロード済みのエピソードIDの数も返します。

		.PARAMETER episodeLinks
			チェック対象のエピソードIDのリストを指定します。

		.OUTPUTS
			[String[]]
			未ダウンロードのエピソードIDの配列と、既にダウンロード済みのエピソードIDの数を含む配列。

		.EXAMPLE
			$result = Invoke-HistoryMatchCheck -episodeLinks @("epXXXXXXXX", "epYYYYYYYY")

		.NOTES
			この関数は以下の処理を行います：
			1. 最新のダウンロード履歴を取得
			2. 履歴に存在するエピソードIDを抽出
			3. 指定されたエピソードIDのリストと履歴を比較
			4. 未ダウンロードのエピソードIDとダウンロード済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][String[]]$episodeLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# エピソードIDがすでにダウンロード履歴に存在する場合は検索結果から除外
	return (Select-UnregisteredEpisodeID -EpisodeLinks $episodeLinks -IdSets @(Get-DownloadedEpisodeIDSet))
}

#----------------------------------------------------------------------
# URLが既にダウンロードリストに存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-ListMatchCheck {
	<#
		.SYNOPSIS
			指定されたエピソードIDがダウンロードリストに存在するかチェックし、未登録のエピソードIDのみを返します。

		.DESCRIPTION
			指定されたエピソードIDのリストとダウンロードリストを比較し、まだ登録されていない
			エピソードIDのみを返します。また、既に登録済みのエピソードIDの数も返します。

		.PARAMETER resultLinks
			チェック対象のエピソードIDのリストを指定します。

		.OUTPUTS
			[String[]]
			未登録のエピソードIDの配列と、既に登録済みのエピソードIDの数を含む配列。

		.EXAMPLE
			$result = Invoke-ListMatchCheck -resultLinks @("epXXXXXXXX", "epYYYYYYYY")

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロードリストファイルを読み込み
			2. リストに存在するエピソードIDを抽出
			3. 指定されたエピソードIDのリストと比較
			4. 未登録のエピソードIDと登録済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# エピソードIDがすでにダウンロードリストに存在する場合は検索結果から除外
	return (Select-UnregisteredEpisodeID -EpisodeLinks $resultLinks -IdSets @(Get-ListedEpisodeIDSet))
}

#----------------------------------------------------------------------
# URLが既にダウンロードリストまたはダウンロード履歴に存在するかチェックし、存在しない番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryAndListMatchCheck {
	<#
		.SYNOPSIS
			指定されたエピソードIDがダウンロードリストまたはダウンロード履歴に存在するかチェックし、未登録のエピソードIDのみを返します。

		.DESCRIPTION
			指定されたエピソードIDのリストとダウンロードリスト、ダウンロード履歴を比較し、
			まだ登録されていないエピソードIDのみを返します。また、既に登録済みのエピソードIDの数も返します。

		.PARAMETER resultLinks
			チェック対象のエピソードIDのリストを指定します。

		.OUTPUTS
			[String[]]
			未登録のエピソードIDの配列と、既に登録済みのエピソードIDの数を含む配列。

		.EXAMPLE
			$result = Invoke-HistoryAndListMatchCheck -resultLinks @("epXXXXXXXX", "epYYYYYYYY")

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロードリストファイルを読み込み
			2. ダウンロード履歴ファイルを読み込み
			3. 両方のリストをマージ
			4. 指定されたエピソードIDのリストと比較
			5. 未登録のエピソードIDと登録済みの数を返す
	#>
	[OutputType([String[]])]
	Param ([Parameter(Mandatory = $true)][Alias('links')][String[]]$resultLinks)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# エピソードIDがすでにダウンロードリストかダウンロード履歴に存在する場合は検索結果から除外
	return (Select-UnregisteredEpisodeID -EpisodeLinks $resultLinks -IdSets @((Get-ListedEpisodeIDSet), (Get-DownloadedEpisodeIDSet)))
}

#----------------------------------------------------------------------
# ダウンロード済みのエピソードIDの集合を取得
#----------------------------------------------------------------------
function Get-DownloadedEpisodeIDSet {
	<#
		.SYNOPSIS
			ダウンロード履歴にあるエピソードIDの集合(HashSet)を返します。

		.DESCRIPTION
			字幕の再確認の対象は「ダウンロード済み」に含めません。
			`$script:histCache`が設定されている場合(一括ダウンロード・リスト作成中)は、作成したHashSetを`$script:histIdSet`に保存して使い回し、
			キーワードごとに履歴の全件処理が走るのを避けます。

		.OUTPUTS
			[System.Collections.Generic.HashSet[String]] 大文字小文字を区別しないエピソードIDの集合
	#>
	[OutputType([System.Collections.Generic.HashSet[String]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$useCache = (Test-Path Variable:Script:histCache) -and ($null -ne $script:histCache)
	if ($useCache) {
		Sync-LatestHistoryCache	# 他のPCなどが履歴を更新していれば、ダウンロード済みIDも作り直す
		if ((Test-Path Variable:Script:histIdSet) -and ($null -ne $script:histIdSet)) { return , $script:histIdSet }
	}
	$histFileData = @(Remove-SubtitleRecheckTarget @(Get-LatestHistoryCached))	# 字幕の再確認の対象は「ダウンロード済み」に含めない
	# * Compare-Objectと同様に大文字小文字を区別しない
	$histIdSet = [System.Collections.Generic.HashSet[String]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($histRecord in $histFileData.Where({ $_ -and $_.videoPage })) { $histIdSet.Add($histRecord.videoPage.Replace('https://tver.jp/episodes/', '')) | Out-Null }
	if ($useCache) { $script:histIdSet = $histIdSet }
	return , $histIdSet
}

#----------------------------------------------------------------------
# ダウンロードリストに登録済みのエピソードIDの集合を取得
#----------------------------------------------------------------------
function Get-ListedEpisodeIDSet {
	<#
		.SYNOPSIS
			ダウンロードリストにあるエピソードIDの集合(HashSet)を返します。

		.DESCRIPTION
			#で始まるダウンロード対象外の番組も、#を除いたエピソードIDで登録済みとして扱います。

		.OUTPUTS
			[System.Collections.Generic.HashSet[String]] 大文字小文字を区別しないエピソードIDの集合
	#>
	[OutputType([System.Collections.Generic.HashSet[String]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$listIdSet = [System.Collections.Generic.HashSet[String]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($listRecord in @(Read-DownloadList)) { if ($listRecord.EpisodeID) { $listIdSet.Add($listRecord.EpisodeID.Replace('#', '')) | Out-Null } }
	return , $listIdSet
}

#----------------------------------------------------------------------
# エピソードIDの集合に含まれない番組だけを返す
#----------------------------------------------------------------------
function Select-UnregisteredEpisodeID {
	<#
		.SYNOPSIS
			指定されたエピソードIDのうち、いずれの集合にも含まれないものと、含まれる件数を返します。

		.PARAMETER EpisodeLinks
			チェック対象のエピソードIDのリストを指定します。

		.PARAMETER IdSets
			登録済みのエピソードIDの集合(HashSet)の配列を指定します。

		.OUTPUTS
			[Object[]] 未登録のエピソードIDの配列と、登録済みの件数
	#>
	[OutputType([Object[]])]
	Param (
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][String[]]$EpisodeLinks,
		[Parameter(Mandatory = $true)][AllowEmptyCollection()][Object[]]$IdSets
	)
	$videoLinks = [System.Collections.Generic.List[String]]::new()
	$processedCount = 0
	foreach ($episodeLink in $EpisodeLinks) {
		$registered = $false
		foreach ($idSet in $IdSets) { if ($idSet.Contains($episodeLink)) { $registered = $true ; break } }
		if ($registered) { $processedCount++ } else { $videoLinks.Add($episodeLink) }
	}
	return @($videoLinks.ToArray(), $processedCount)
}
#endregion ダウンロード対象判定処理
