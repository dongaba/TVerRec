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
	# ダウンロード履歴ファイルのデータを読み込み
	# 一括ダウンロード中(履歴キャッシュあり)は、ダウンロード済みのIDをHashSetにして使い回す(キーワードごとの全件処理を避けるため)
	if ((Test-Path Variable:Script:histCache) -and ($null -ne $script:histCache)) {
		if (!(Test-Path Variable:Script:histIdSet) -or ($null -eq $script:histIdSet)) {
			$histFileData = @(Remove-SubtitleRecheckTarget @(Get-LatestHistoryCached))	# 字幕の再確認の対象は「ダウンロード済み」に含めない
			$histIdList = [System.Collections.Generic.List[String]]::new()
			foreach ($histRecord in $histFileData.Where({ $_ })) { $histIdList.Add($histRecord.videoPage.Replace('https://tver.jp/episodes/', '')) }
			# * Compare-Objectと同様に大文字小文字を区別しない
			$script:histIdSet = [System.Collections.Generic.HashSet[String]]::new($histIdList, [System.StringComparer]::OrdinalIgnoreCase)
		}
		$videoLinks = [System.Collections.Generic.List[String]]::new()
		$processedCount = 0
		foreach ($episodeLink in $episodeLinks) {
			if ($script:histIdSet.Contains($episodeLink)) { $processedCount++ } else { $videoLinks.Add($episodeLink) }
		}
		return @($videoLinks.ToArray(), $processedCount)
	}
	$histFileData = @(Get-LatestHistoryCached)
	$histFileData = @(Remove-SubtitleRecheckTarget $histFileData)	# 字幕の再確認の対象は「ダウンロード済み」に含めない
	if ($histFileData.Count -eq 0) { $histVideoPages = @() } else { $histVideoPages = @($histFileData.videoPage.Replace('https://tver.jp/episodes/', '')) }
	# エピソードIDがすでにダウンロード履歴に存在する場合は検索結果から除外
	$histCompResult = @(Compare-Object -IncludeEqual $episodeLinks $histVideoPages)
	try { $processedCount = ($histCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($histCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	Remove-Variable -Name episodeLinks, histFileData, histVideoPages, histCompResult -ErrorAction SilentlyContinue
	return @($videoLinks, $processedCount)
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
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	# エピソードIDで照合する(検索結果もダウンロードリストもエピソードID。#で始まるダウンロード対象外も登録済みとして扱う)
	$listVideoIDs = New-Object System.Collections.Generic.List[String]
	foreach ($item in $listFileData) { $listVideoIDs.Add($item.EpisodeID.Replace('#', '')) }
	# エピソードIDがすでにダウンロードリストに存在する場合は検索結果から除外
	$listCompResult = @(Compare-Object -IncludeEqual $resultLinks $listVideoIDs)
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	Remove-Variable -Name resultLinks, listFileData, listVideoIDs, listFileLine, listCompResult -ErrorAction SilentlyContinue
	return @($videoLinks, $processedCount)
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
	# ダウンロードリストファイルのデータを読み込み
	$listFileData = @(Read-DownloadList)
	$listVideoID = New-Object System.Collections.Generic.List[Object]
	foreach ($listFileLine in $listFileData) { $listVideoID.Add(@($listFileLine.EpisodeID.Replace('#', ''))) }
	# ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-LatestHistory)
	$histFileData = @(Remove-SubtitleRecheckTarget $histFileData)	# 字幕の再確認の対象は「ダウンロード済み」に含めない
	# 履歴が1件だけの場合に配列が文字列に展開されないよう、@()で包む
	$histVideoID = @(if ($histFileData.Count -eq 0) { @() } else { $histFileData.VideoPage.Replace('https://tver.jp/episodes/', '') })
	# ダウンロードリストとダウンロード履歴をマージ
	if ($histVideoID) { $listVideoID.AddRange($histVideoID) }
	# エピソードIDがすでにダウンロード履歴に存在する場合は検索結果から除外
	$listCompResult = Compare-Object -IncludeEqual $resultLinks $listVideoID
	try { $processedCount = ($listCompResult.Where({ $_.SideIndicator -eq '==' })).Count } catch { $processedCount = 0 }
	try { $videoLinks = @($listCompResult.Where({ $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }
	return @($videoLinks, $processedCount)
}
#endregion ダウンロード対象判定処理
