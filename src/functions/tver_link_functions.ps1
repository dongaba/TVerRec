################################################################################
#
#		TVer固有関数スクリプト(番組リンクの取得)
#
################################################################################
<#
	.SYNOPSIS
		キーワード・各種ID・トップページ・サイトマップ・マイページから、番組ページのリンクやエピソードIDを取得する関数を定義します。

	.NOTES
		このファイルはtver_functions.ps1から読み込まれます。
		単体で読み込まず、tver_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#----------------------------------------------------------------------
# キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function Get-VideoLinksFromKeyword {
	<#
		.SYNOPSIS
			キーワードからTVerの番組リンクを取得します。

		.DESCRIPTION
			指定されたキーワードに基づいて、TVerの番組リンクを取得します。
			キーワードは以下の形式で指定できます：
			- episodes/{id}: 特定のエピソード
			- series/{id}: シリーズ
			- talents/{id}: タレント
			- tag/{id}: タグ
			- ranking/{id}: ランキング
			- new/{id}: 新着
			- end/{id}: 終了間近
			- mypage/{page}: マイページ
			- toppage: トップページ
			- sitemap: サイトマップ

		.PARAMETER keyword
			検索するキーワードを指定します。

		.EXAMPLE
			Get-VideoLinksFromKeyword -keyword "episodes/123456"

		.EXAMPLE
			Get-VideoLinksFromKeyword -keyword "series/789012"

		.OUTPUTS
			System.Collections.Generic.List[String]
			取得したエピソードリンクのリストを返します。

		.NOTES
			この関数は内部で他の関数を呼び出して、様々な種類のリンクを取得します。
	#>
	[CmdletBinding()]
	[OutputType([System.Collections.Generic.List[String]])]
	Param ([Parameter(Mandatory = $true)][String]$keyword)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# * 「lp/episodes/epxxxx」「lp/series/srxxxx」形式(TVerの共有URL由来)は「lp/」を除いて通常のIDとして扱う
	$keyword = $keyword -replace '^lp/(?=(episodes|series)/)', ''
	$linkCollection = [PSCustomObject]@{
		episodeLinks     = @{}
		seriesLinks      = New-Object System.Collections.Generic.List[String]
		seasonLinks      = New-Object System.Collections.Generic.List[String]
		talentLinks      = New-Object System.Collections.Generic.List[String]
		specialMainLinks = New-Object System.Collections.Generic.List[String]
		specialLinks     = New-Object System.Collections.Generic.List[String]
		categoryLinks    = New-Object System.Collections.Generic.List[String]
	}
	if ($keyword.IndexOf('/') -gt 0) {
		$key = $keyword.split(' ')[0].split("`t")[0].Split('/')[0]
		$tverID = Get-ContentWoComment(($keyword.Replace("$key/", '')).Trim())
		# * 共有URL由来の「?p=0」「?play=feature」などのクエリ文字列やフラグメントを除去 (#301)
		$tverID = ($tverID -split '[?#]')[0].TrimEnd('/')
	} else { $key = '' ; $tverID = '' }
	if (($keyword -eq 'sitemap') -or ($keyword -eq 'toppage')) { $key = $keyword }
	Invoke-StatisticsCheck -Operation 'search' -TVerType $key -TVerID $tverID
	switch ($key) {
		'episodes' { $linkCollection.episodeLinks[$tverID] = 0 ; break }	# キーワードファイルにあるEpisodeはEndAtが不明なので0を設定
		'series' { $linkCollection.seriesLinks.Add($tverID) ; break }
		'talents' { $linkCollection.talentLinks.Add($tverID) ; break }
		'tag' { Get-LinkFromKeyword -id $tverID -linkType 'tag' -LinkCollection ([Ref]$linkCollection) ; break }
		'ranking' { Get-LinkFromKeyword -id $tverID -linkType 'ranking' -LinkCollection ([Ref]$linkCollection) ; break }
		'new' { Get-LinkFromKeyword -id $tverID -linkType 'new' -LinkCollection ([Ref]$linkCollection)  ; break }
		'end' { Get-LinkFromKeyword -id $tverID -linkType 'end' -LinkCollection ([Ref]$linkCollection)  ; break }
		'mypage' { Get-LinkFromMyPage -Page $tverID -LinkCollection ([Ref]$linkCollection) ; break }
		'toppage' { Get-LinkFromTopPage ([Ref]$linkCollection) ; break }
		'sitemap' { Get-LinkFromSiteMap ([Ref]$linkCollection) ; break }
		default { Get-LinkFromKeyword -id $keyword -linkType 'keyword' -LinkCollection ([Ref]$linkCollection) }
	}
	while (($linkCollection.specialMainLinks.Count -ne 0) -or ($linkCollection.specialLinks.Count -ne 0) -or ($linkCollection.talentLinks.Count -ne 0) -or ($linkCollection.seriesLinks.Count -ne 0) -or ($linkCollection.seasonLinks.Count -ne 0)) {
		$linkTypes = @('specialMainLinks', 'specialLinks', 'talentLinks', 'seriesLinks', 'seasonLinks')
		foreach ($linkType in $linkTypes) {
			if ($linkCollection.$linkType.Count -ne 0) {
				Get-LinkFromBuffer -TverIDs $linkCollection.$linkType -TverIDType $linkType -LinkCollection ([Ref]$linkCollection)
				$linkCollection.$linkType.Clear()
			}
		}
	}
	if ($linkCollection.episodeLinks.Count -eq 0) { return }
	else { return ($linkCollection.episodeLinks.GetEnumerator() | Sort-Object Value).Name }
}

#----------------------------------------------------------------------
# エピソード以外のリンクをためたバッファを順次API呼び出し
#----------------------------------------------------------------------
function Get-LinkFromBuffer {
	<#
		.SYNOPSIS
			バッファに格納されたリンクからエピソードリンクを取得します。

		.DESCRIPTION
			エピソード以外のリンク（シリーズ、タレント、スペシャルなど）を格納したバッファから、
			実際のエピソードリンクを取得します。

		.PARAMETER tverIDs
			処理するTVerのIDの配列。

		.PARAMETER tverIDType
			リンクの種類を指定します。以下のいずれかを指定できます：
			- specialMainLinks
			- specialLinks
			- talentLinks
			- seriesLinks
			- seasonLinks

		.PARAMETER linkCollection
			リンクを格納するオブジェクトへの参照。

		.EXAMPLE
			Get-LinkFromBuffer -tverIDs @("123456", "789012") -tverIDType "seriesLinks" -linkCollection $linkCollection

		.NOTES
			この関数は内部でGet-LinkFromKeywordを呼び出して、実際のエピソードリンクを取得します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][Object[]]$tverIDs,
		[Parameter(Mandatory = $true)][ValidateSet('specialMainLinks', 'specialLinks', 'talentLinks', 'seriesLinks', 'seasonLinks')][String]$tverIDType,
		[Parameter(Mandatory = $true)][PSCustomObject]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($tverIDs) {
		foreach ($tverID in ($tverIDs | Sort-Object -Unique)) {
			Write-Information ($script:msg.ExtractingEpisodes -f (Get-Date), $tverIDType, $tverID)
			Get-LinkFromKeyword -id $tverID -linkType $tverIDType -LinkCollection ([Ref]$linkCollection)
		}
		$linkTypes = @('specialLinks', 'talentLinks', 'seriesLinks', 'seasonLinks')
		foreach ($linkType in $linkTypes) {
			if ($linkCollection.$linkType) {
				Write-Information ($script:msg.DistinctIDs -f (Get-Date), $linkType)
				$linkCollection.$linkType = [System.Collections.Generic.List[String]]($linkCollection.$linkType | Sort-Object -Unique)
			}
		}
	}
	Remove-Variable -Name tverID, tverIDs, tverIDType, linkTypes, linkType -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# IDまたはキーワードによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromKeyword {
	<#
		.SYNOPSIS
			IDまたはキーワードを使用してTVerの番組リンクを取得します。

		.DESCRIPTION
			指定されたIDまたはキーワードを使用して、TVerのAPIを呼び出し、
			番組のリンクを取得します。

		.PARAMETER id
			検索するIDまたはキーワード。

		.PARAMETER linkType
			リンクの種類を指定します。以下のいずれかを指定できます：
			- seriesLinks
			- seasonLinks
			- talentLinks
			- specialMainLinks
			- specialLinks
			- tag
			- new
			- end
			- ranking
			- keyword
			- category

		.PARAMETER linkCollection
			リンクを格納するオブジェクトへの参照。

		.EXAMPLE
			Get-LinkFromKeyword -id "123456" -linkType "seriesLinks" -linkCollection $linkCollection

		.EXAMPLE
			Get-LinkFromKeyword -id "ドラマ" -linkType "keyword" -linkCollection $linkCollection

		.NOTES
			この関数は内部でGet-SearchResultを呼び出して、実際の検索結果を取得します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$id,
		[Parameter(Mandatory = $false)][ValidateSet('seriesLinks', 'seasonLinks', 'talentLinks', 'specialMainLinks', 'specialLinks', 'tag', 'new', 'end', 'ranking', 'keyword', 'category')][String]$linkType,
		[Parameter(Mandatory = $true)][PSCustomObject]$linkCollection
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $id)
	$type = ''
	$keyword = ''
	# ベースURLをタイプに応じて設定
	$baseURL = switch ($linkType) {
		'seriesLinks' { ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}' -f $id) ; break }
		'seasonLinks' { ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $id) ; break }
		'talentLinks' { ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $id) ; break }
		'specialMainLinks' { ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $id) ; $type = 'specialmain' ; break }
		'specialLinks' { ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $id) ; $type = 'specialdetail' ; break }
		'tag' { ('https://platform-api.tver.jp/service/api/v1/callTagSearch/{0}' -f $id) ; break }
		'new' { ('https://platform-api.tver.jp/service/api/v1/callNewerDetail/{0}' -f $id) ; $type = 'new' ; break }
		'end' { ('https://platform-api.tver.jp/service/api/v1/callEnderDetail/{0}' -f $id) ; $type = 'end' ; break }
		'ranking' {
			if ($id -eq 'all') { 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' }
			else { ('https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/{0}' -f $id) }
			$type = 'ranking' ; break
		}
		'category' { ('https://platform-api.tver.jp/service/api/v1/callCategoryHome/{0}' -f $id) ; $type = 'category' ; break }
		'keyword' { 'https://platform-api.tver.jp/service/api/v2/callKeywordSearch'; $type = 'keyword' ; $keyword = $id ; break }
		default { Write-Warning $script:msg.InvalidTypeSpecified ; return }	# * 種類が不明なときは、URLが決まらないため検索せずに終了する
	}
	# 検索結果の取得
	Get-SearchResult -baseURL $baseURL -Type $type -Keyword $keyword -LinkCollection ([Ref]$linkCollection)
	Remove-Variable -Name id, linkType, type, baseURL, keyword -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-SearchResult {
	<#
		.SYNOPSIS
			TVerのAPIを使用して検索結果を取得します。

		.DESCRIPTION
			指定されたパラメータを使用してTVerのAPIを呼び出し、
			検索結果を取得してリンクコレクションに追加します。

		.PARAMETER baseURL
			検索に使用するAPIのベースURL。

		.PARAMETER type
			検索の種類を指定します。

		.PARAMETER keyword
			キーワード検索の場合の検索キーワード。

		.PARAMETER requireData
			マイページ検索の場合に必要なデータ。

		.PARAMETER loginRequired
			ログインが必要かどうかを指定します。

		.PARAMETER linkCollection
			リンクを格納するオブジェクトへの参照。

		.EXAMPLE
			Get-SearchResult -baseURL "https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/123456" -type "series" -linkCollection $linkCollection

		.EXAMPLE
			Get-SearchResult -baseURL "https://platform-api.tver.jp/service/api/v1/callKeywordSearch" -type "keyword" -keyword "ドラマ" -linkCollection $linkCollection

		.NOTES
			この関数は内部でTVerのAPIを呼び出し、結果を解析してリンクコレクションに追加します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $false)][String]$requireData,
		[Parameter(Mandatory = $false)][Boolean]$loginRequired,
		[Parameter(Mandatory = $true)][PSCustomObject]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# URLの整形
	$sid = $script:myMemberSID
	if (($script:myPlatformUID) -and ($script:myPlatformToken)) { $uid = $script:myPlatformUID ; $token = $script:myPlatformToken }
	else { $uid = $script:platformUID ; $token = $script:platformToken }
	if ($loginRequired) { $callSearchURL = '{0}?member_sid={1}' -f $baseURL, $sid }						# TVerIDにログインして使う場合
	else { $callSearchURL = '{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $uid, $token }		# TVerIDを匿名で使う場合
	switch ($type) {
		'keyword' { if ($keyword) { $callSearchURL += ('&keyword={0}' -f [Uri]::EscapeDataString($keyword)) } ; break }	# * 「King & Prince」のように「&」「#」を含む語が途中で切れないようURLエンコード
		'mypage' { if ($requireData) { $callSearchURL += "&require_data=$requireData" } ; break }
		default {}
	}
	# 取得した値をタイプごとに調整
	# 一括ダウンロード中は、シリーズ・シーズン・タレントのAPIの結果を実行中だけ使い回す(キーワード間で同じIDを何度も取得しないため)
	$useSearchCache = (Test-Path Variable:Script:searchCache) -and ($null -ne $script:searchCache) -and ($baseURL -match '/(callSeriesSeasons|callSeasonEpisodes|callTalentEpisode)/')
	if ($useSearchCache -and $script:searchCache.ContainsKey($callSearchURL)) { $searchResultsRaw = $script:searchCache[$callSearchURL] }
	else {
		try { $searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
		catch {
			if ($_.Exception.Message.Contains('The request was canceled due to the configured HttpClient.Timeout of')) {
				Write-Warning ($script:msg.HttpTimeout) ; return
			} else {
				# どのAPIで失敗したか(再帰呼び出し先を含む)を特定できるよう、トークン類を伏せたURLを併記する
				# * 例外メッセージは環境の言語で出力されるため、日本語環境ではHttpOtherError側に入る。どちらもURL付きで表示する
				$maskedURL = $callSearchURL -replace '(platform_uid|platform_token|member_sid)=[^&]+', '$1=***'
				$errorDetail = '{0} ({1})' -f $_.Exception.Message, $maskedURL
				if ($_.Exception.Message.Contains('Response status code does not indicate success:')) { Write-Warning ($script:msg.HttpBadResponse -f $errorDetail) ; return }
				else { Write-Warning ($script:msg.HttpOtherError -f $errorDetail) ; return }
			}
		}
		if ($useSearchCache) { $script:searchCache[$callSearchURL] = $searchResultsRaw }
	}

	# タイプ別に参照先を調整
	$searchResults = switch ($type) {
		'specialmain' { $searchResultsRaw.Result.specialContents ; break }
		'specialdetail' { $searchResultsRaw.Result.Contents.Content.Contents ; break }
		'category' { $searchResultsRaw.Result.components.contents ; break }
		{ $_ -in 'new', 'end', 'ranking' } { $searchResultsRaw.Result.Contents.Contents ; break }
		default { $searchResultsRaw.Result.Contents }
	}

	# 早期フィルタリング - 処理不要なタイプを除外
	$searchResults = $searchResults | Where-Object { $_.Type -notin @('live', 'banner') }

	# searchResultsを並び替え
	$order = @('specialMain', 'special', 'talent', 'series', 'season', 'episode')
	$sortedSearchResults = $searchResults | Sort-Object { $order.IndexOf($_.Type) }
	# タイプ別に再帰呼び出し
	foreach ($searchResult in $sortedSearchResults) {
		switch ($searchResult.Type) {
			'episode' { $linkCollection.episodeLinks[$searchResult.Content.Id] = $searchResult.Content.EndAt ; break }
			'season' { $linkCollection.seasonLinks.Add($searchResult.Content.Id) ; break }
			'series' { $linkCollection.seriesLinks.Add($searchResult.Content.Id) ; break }
			'talent' { $linkCollection.talentLinks.Add($searchResult.Content.Id) ; break }
			'special' {
				if ($type -eq 'specialmain') { $linkCollection.specialLinks.Add($searchResult.Content.Id) }
				else { Get-LinkFromKeyword -id $searchResult.Content.Id -linkType 'specialLinks' -LinkCollection ([Ref]$linkCollection) }
				break
			}
			'specialMain' { $linkCollection.specialMainLinks.Add($searchResult.Content.Id) ; break }
			default { Write-Warning ($script:msg.UnknownContentsType -f $searchResult.Type, $searchResult.Content.Id) }
		}
	}
	Remove-Variable -Name baseURL, type, keyword, requireData, loginRequired, sid, uid, token, callSearchURL, maskedURL, errorDetail, searchResultsRaw, searchResults, order, sortedSearchResults, useSearchCache, searchResult -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTopPage {
	<#
		.SYNOPSIS
			TVerのトップページから番組リンクを取得します。

		.DESCRIPTION
			TVerのトップページのコンテンツを解析し、表示されている番組のリンクを取得します。
			トップページには様々な種類のコンテンツ（新着、ランキング、タレントなど）が表示されています。

		.PARAMETER linkCollection
			リンクを格納するオブジェクトへの参照。

		.EXAMPLE
			Get-LinkFromTopPage -linkCollection $linkCollection

		.NOTES
			この関数はTVerのトップページAPIを呼び出し、表示されているコンテンツから
			番組リンクを抽出します。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject]$linkCollection)
	Write-Debug ('Dev - {0}' -f $MyInvocation.MyCommand.Name)
	# * v1/callHomeは2026年時点で空のresultを返すためv2を使用
	$callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v2/callHome'
	$callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $callSearchBaseURL, $script:platformUID, $script:platformToken)
	try { $searchResults = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning $script:msg.TopPageRetrievalFailed ; return }
	# * API仕様変更でresultが空になった場合(v1/callHome廃止時の挙動)に例外で止まらないようにする
	try { $components = @($searchResults.Result.Components) } catch { $components = @() }
	if ($components.Count -eq 0) { Write-Warning $script:msg.TopPageRetrievalFailed ; return }
	foreach ($component in $components) {
		switch ($component.Type) {
			{ $_ -in @('horizontal', 'richHorizontal', 'ranking', 'talents', 'billboard', 'episodeRanking', 'newer', 'ender', 'talent', 'special', 'specialContent', 'topics', 'spikeRanking', 'seasonEpisode') } {
				$contents = if ($component.Type -eq 'topics') { $component.Contents.Content.Content } else { $component.Contents }
				foreach ($content in $contents) {
					# * live/bannerはダウンロード対象外。breakだと残りのコンテンツを読み飛ばすためcontinue
					if ($content.Type -in @('live', 'banner')) { continue }
					switch ($content.Type) {
						'episode' { $linkCollection.episodeLinks[$content.Content.Id] = $content.Content.EndAt ; break }
						'series' { $linkCollection.seriesLinks.Add($content.Content.Id) ; break }
						'season' { $linkCollection.seasonLinks.Add($content.Content.Id) ; break }
						'talent' { $linkCollection.talentLinks.Add($content.Content.Id) ; break }
						'specialMain' { $linkCollection.specialMainLinks.Add($content.Content.Id) ; break }
						'special' { $linkCollection.specialLinks.Add($content.Content.Id) ; break }
						default { Write-Warning ($script:msg.UnknownContentsType -f $content.Type, $content.Content.Id) }
					}
				}
				break
			}
			# * ダウンロード対象を含まない(またはログインユーザー固有の)コンポーネント
			{ $_ -in @('banner', 'resume', 'favorite', 'onAirLiveEpisode', 'watchingSeries', 'similarSeries', 'watchlistReminder', 'welcome', 'channel') } { break }
			default { Write-Warning ($script:msg.UnknownComponentType -f $component.Type) }
		}
	}
	Remove-Variable -Name callSearchBaseURL, callSearchURL, searchResults, components, component, contents, content -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSiteMap {
	<#
		.SYNOPSIS
			TVerのサイトマップから番組リンクを取得します。

		.DESCRIPTION
			TVerのサイトマップを解析し、公開されている番組のリンクを取得します。
			サイトマップには様々な種類のコンテンツ（エピソード、シリーズ、スペシャルなど）が含まれています。

		.PARAMETER linkCollection
			リンクを格納するオブジェクトへの参照。

		.EXAMPLE
			Get-LinkFromSiteMap -linkCollection $linkCollection

		.NOTES
			この関数はTVerのサイトマップXMLを取得し、その中から番組リンクを抽出します。
			サイトマップには重複したリンクが含まれる可能性があるため、重複は除去されます。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject]$linkCollection)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$callSearchURL = 'https://tver.jp/sitemap.xml'
	try { $searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning $script:msg.SiteMapRetrievalFailed ; return }
	# Special Detailを拾わないように「/」2個目以降は無視して重複削除
	$searchResults = New-Object System.Collections.Generic.List[String]
	foreach ($url in $searchResultsRaw.urlset.url.loc) {
		$modifiedURL = $url.Replace('https://tver.jp/', '') -replace '^([^/]+/[^/]+).*', '$1'
		if (-not $searchResults.Contains($modifiedURL)) { $searchResults.Add($modifiedURL) }
	}
	foreach ($url in $searchResults) {
		try {
			$parts = $url.Split('/')
			if ($parts.Length -ge 2) {
				$tverID = @{ type = $parts[0] ; id = $parts[1] }
				switch ($tverID.type) {
					'episodes' { if (-not $linkCollection.episodeLinks.ContainsKey($tverID.id)) { $linkCollection.episodeLinks[$tverID.id] = 0 } ; break }	# サイトマップにあるEpisodeはEndAtが不明なので0を設定
					'series' { if (-not $script:sitemapParseEpisodeOnly) { if (-not $linkCollection.seriesLinks.Contains($tverID.id)) { $linkCollection.seriesLinks.Add($tverID.id) } } ; break }
					'specials' { if (-not $script:sitemapParseEpisodeOnly) { if (-not $linkCollection.specialMainLinks.Contains($tverID.id)) { $linkCollection.specialMainLinks.Add($tverID.id) } } ; break }	# * specials/{specialMainID}/{specialID}の形式なのでMainIDとして扱う
					'categories' { if (-not $script:sitemapParseEpisodeOnly) { if (-not $linkCollection.categoryLinks.Contains($tverID.id)) { $linkCollection.categoryLinks.Add($tverID.id) } } ; break }
				}
			}
		} catch {
			Write-Warning ($script:msg.UnknownContentsType -f $tverID.type, $tverID.id)
		}
	}

	# categoryLinksの処理 (specialMainLinks等は呼び出し元のループで処理される)
	if ((-not $script:sitemapParseEpisodeOnly) -and ($linkCollection.categoryLinks.Count -ne 0)) {
		foreach ($categoryID in @($linkCollection.categoryLinks | Select-Object -Unique)) {
			Write-Information ($script:msg.ExtractingEpisodes -f (Get-Date), 'categories', $categoryID)
			Get-LinkFromKeyword -id $categoryID -linkType 'category' -LinkCollection ([Ref]$linkCollection)
		}
		$linkCollection.categoryLinks.Clear()
	}
	Remove-Variable -Name callSearchURL, searchResultsRaw, searchResults, url, tverID, categoryID -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# マイページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromMyPage {
	<#
		.SYNOPSIS
			TVerのマイページから番組リンクを取得します。

		.DESCRIPTION
			TVerのマイページのコンテンツを解析し、ユーザーに関連する番組のリンクを取得します。
			マイページには以下のようなコンテンツが含まれます：
			- お気に入り
			- あとで見る
			- 視聴履歴
			- お気に入り

		.PARAMETER page
			取得するマイページの種類を指定します：
			- fav: お気に入り
			- later: あとで見る
			- resume: 視聴履歴
			- favorite: お気に入り

		.PARAMETER linkCollection
			リンクを格納するオブジェクトへの参照。

		.EXAMPLE
			Get-LinkFromMyPage -page "fav" -linkCollection $linkCollection

		.EXAMPLE
			Get-LinkFromMyPage -page "later" -linkCollection $linkCollection

		.NOTES
			この関数はTVerのマイページAPIを呼び出し、ユーザーに関連するコンテンツから
			番組リンクを抽出します。ログインが必要な場合があります。
	#>
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$page,
		[Parameter(Mandatory = $true)][PSCustomObject]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$baseURLPrefix = if ($script:myMemberSID) { 'https://member-api.tver.jp' ; $loginRequired = $true } else { 'https://platform-api.tver.jp' ; $loginRequired = $false }
	switch ($page) {
		'fav' { $baseURL = ('{0}/service/api/v2/callMylistDetail/{1}' -f $baseURLPrefix, (ConvertTo-UnixTime (Get-Date))) ; $requireData = 'mylist' ; break }
		'later' { $baseURL = ('{0}/service/api/v2/callMyLater' -f $baseURLPrefix) ; $requireData = $page ; break }
		'resume' { $baseURL = ('{0}/service/api/v2/callMyResume' -f $baseURLPrefix) ; $requireData = $page ; break }
		'favorite' { $baseURL = ('{0}/service/api/v2/callMyFavorite' -f $baseURLPrefix) ; $requireData = 'mylist' ; break }
		default { Write-Warning ($script:msg.UnknownContentsType -f 'mypage', $page) ; return }
	}
	Get-SearchResult -baseURL $baseURL -Type 'mypage' -RequireData $requireData -LoginRequired $loginRequired -LinkCollection ([Ref]$linkCollection)
	Remove-Variable -Name baseURLPrefix, baseURL, requireData, loginRequired -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# TVerの番組URLからエピソードIDを抽出
#----------------------------------------------------------------------
function Get-EpisodeIDFromURL {
	<#
		.SYNOPSIS
			TVerの番組URLからエピソードIDを抽出します。

		.DESCRIPTION
			「https://tver.jp/episodes/epxxxxxxxx?p=0」のように、共有時にクエリ文字列や
			フラグメントが付与されたURLや、「https://tver.jp/lp/episodes/epxxxxxxxx」形式のURLからも
			エピソードIDのみを取り出します。
			エピソードのURLでない場合(シリーズや特集のURLなど)は空文字を返します。

		.PARAMETER url
			TVerの番組URL。

		.EXAMPLE
			Get-EpisodeIDFromURL -url 'https://tver.jp/episodes/epuaqm8ooq?play=feature&p=0'
			# epuaqm8ooq

		.OUTPUTS
			String
	#>
	[CmdletBinding()]
	[OutputType([String])]
	Param ([Parameter(Mandatory = $true)][AllowEmptyString()][String]$url)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $url)
	# * 「https://tver.jp/lp/episodes/epxxxx」形式(/episodes/へリダイレクトされる)にも対応
	if ($url -match '^https?://(?:www\.)?tver\.jp/(?:lp/)?episodes?/(ep[0-9a-z]+)(?:[/?#]|$)') { return $matches[1] }
	return ''
}
