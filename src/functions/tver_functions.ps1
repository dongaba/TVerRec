###################################################################################
#
#		TVer固有関数スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function Get-Token () {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$headers = @{
		'Content-Type'    = 'application/x-www-form-urlencoded'
		'X-Forwarded-For' = $script:jpIP
	}
	$requestBody = 'device_type=pc'
	try {
		$tokenResponse = Invoke-RestMethod -Uri $tverTokenURL -Method 'POST' -Headers $headers -Body $requestBody -TimeoutSec $script:timeoutSec
		$script:platformUID = $tokenResponse.Result.platform_uid
		$script:platformToken = $tokenResponse.Result.platform_token
	} catch { Throw ('　❌️ トークン取得エラー、終了します') }
	Remove-Variable -Name tverTokenURL, headers, requestBody, tokenResponse -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function Get-VideoLinksFromKeyword {
	[CmdletBinding()]
	[OutputType([System.Collections.Generic.List[string]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String][ref]$keyword)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$linkCollection = [PSCustomObject]@{
		episodeLinks     = [System.Collections.Generic.List[string]]::new()
		seriesLinks      = [System.Collections.Generic.List[string]]::new()
		seasonLinks      = [System.Collections.Generic.List[string]]::new()
		talentLinks      = [System.Collections.Generic.List[string]]::new()
		specialMainLinks = [System.Collections.Generic.List[string]]::new()
		specialLinks     = [System.Collections.Generic.List[string]]::new()
	}
	if ($keyword.IndexOf('/') -gt 0) { 
		$key = $keyword.split(' ')[0].split("`t")[0].Split('/')[0]
		$tverID = Remove-Comment(($keyword.Replace("$key/", '')).Trim())
	} else { $key = '' ; $tverID = '' }
	if (($keyword -eq 'sitemap') -or ($keyword -eq 'toppage')) { $key = $keyword }
	Invoke-StatisticsCheck -Operation 'search' -TVerType $key -TVerID $tverID
	switch ($key) {
		'episodes' { $linkCollection.episodeLinks.Add(('https://tver.jp/{0}/{1}' -f $key, $tverID)) ; continue }
		'series' { $linkCollection.seriesLinks.Add($tverID) ; continue }
		'talents' { $linkCollection.talentLinks.Add($tverID) ; continue }
		'tag' { Get-LinkFromKeyword -id $tverID -type 'tag' -LinkCollection ([ref]$linkCollection) ; continue }
		'ranking' { Get-LinkFromKeyword -id $tverID -type 'ranking' -LinkCollection ([ref]$linkCollection) ; continue }
		'new' { Get-LinkFromKeyword -id $tverID -type 'new' -LinkCollection ([ref]$linkCollection)  ; continue }
		'mypage' { Get-LinkFromMyPage -Page $tverID -LinkCollection ([ref]$linkCollection) ; continue }
		'toppage' { Get-LinkFromTopPage ([ref]$linkCollection) ; continue }
		'sitemap' { Get-LinkFromSiteMap ([ref]$linkCollection) ; continue }
		default { Get-LinkFromKeyword -id $keyword -type 'keyword' -LinkCollection ([ref]$linkCollection) }
	}
	while (($linkCollection.specialMainLinks.Count -ne 0) -or ($linkCollection.specialLinks.Count -ne 0) -or ($linkCollection.talentLinks.Count -ne 0) -or ($linkCollection.seriesLinks.Count -ne 0) -or ($linkCollection.seasonLinks.Count -ne 0)) {
		$linkTypes = @{
			'Special Main'   = 'specialMainLinks'
			'Special Detail' = 'specialLinks'
			'Talent'         = 'talentLinks'
			'Series'         = 'seriesLinks'
			'Season'         = 'seasonLinks'
		}
		foreach ($linkType in $linkTypes.GetEnumerator()) {
			$propertyName = $linkType.Value
			if ($linkCollection.$propertyName.Count -ne 0) {
				Convert-Buffer -TverIDs $linkCollection.$propertyName -TverIDType $linkType.Key -LinkCollection ([ref]$linkCollection)
				$linkCollection.$propertyName.Clear()
			}
		}
	}
	Remove-Variable -Name key, tverID, linkTypes, type -ErrorAction SilentlyContinue
	return $linkCollection.episodeLinks | Sort-Object -Unique
	Remove-Variable -Name linkCollection -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# IDまたはキーワードによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromKeyword {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$id,
		[Parameter(Mandatory = $false)][ValidateSet('series', 'season', 'talent', 'specialMain', 'specialDetail', 'tag', 'new', 'ranking', 'keyword')][string]$type,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][ref]$linkCollection
	)
	Write-Debug ($MyInvocation.MyCommand.Name)
	# ベースURLをタイプに応じて設定
	$baseURL = switch ($type) {
		'series' { ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}' -f $id) ; continue }
		'season' { ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $id) ; continue }
		'talent' { ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $id) ; continue }
		'specialMain' { ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $id) ; $type = 'specialmain' ; continue }
		'specialDetail' { ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $id) ; $type = 'specialdetail' ; continue }
		'tag' { ('https://platform-api.tver.jp/service/api/v1/callTagSearch/{0}' -f $id) ; continue }
		'new' { ('https://platform-api.tver.jp/service/api/v1/callNewerDetail/{0}' -f $id) ; $type = 'new' ; continue }
		'ranking' { 
			if ($id -eq 'all') { 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' } 
			else { ('https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/{0}' -f $id) }
			$type = 'ranking' ; continue
		}
		'keyword' { 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'; $keyword = $id ; continue }
		default { Write-Warning '無効なタイプが指定されました。' }
	}
	# 検索結果の取得
	Get-SearchResults -baseURL $baseURL -Type $type -Keyword $keyword -LinkCollection ([ref]$linkCollection)
	Remove-Variable -Name id, type, baseURL -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-SearchResults {
	[CmdletBinding()]
	[OutputType([System.Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $false)][String]$requireData,
		[Parameter(Mandatory = $false)][Boolean]$loginRequired,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][ref]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#URLの整形
	$sid = $script:myMemberSID
	if (($script:myPlatformUID -ne '') -and ($script:myPlatformToken -ne '')) { $uid = $script:myPlatformUID ; $token = $script:myPlatformToken }
	else { $uid = $script:platformUID ; $token = $script:platformToken }
	if ($loginRequired) { $callSearchURL = '{0}?member_sid={1}' -f $baseURL, $sid }						# TVerIDにログインして使う場合
	else { $callSearchURL = '{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $uid, $token }		# TVerIDを匿名で使う場合
	switch ($type) {
		'keyword' { if ($keyword) { $callSearchURL += "&keyword=$keyword" } ; continue }
		'mypage' { if ($requireData) { $callSearchURL += "&require_data=$requireData" } ; continue }
		default {}
	}
	#取得した値をタイプごとに調整
	try { $searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec } 
	catch {
		if ($_.Exception.Message.Contains('The request was canceled due to the configured HttpClient.Timeout of')) {
			Write-Warning ('⚠️ HTTP接続がタイムアウトしました。スキップして次のリンクを処理します。') ; return 
		} elseif ($_.Exception.Message.Contains('Response status code does not indicate success:')) {
			Write-Warning ('⚠️ HTTP接続が失敗しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) ; return 
		} else { Write-Warning ('⚠️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) ; return }
	}
	#タイプ別に参照先を調整
	$searchResults = switch ($type) {
		'specialmain' { $searchResultsRaw.Result.specialContents ; continue }
		'specialdetail' { $searchResultsRaw.Result.Contents.Content.Contents ; continue }
		{ $_ -in 'new', 'ranking' } { $searchResultsRaw.Result.Contents.Contents ; continue }
		default { $searchResultsRaw.Result.Contents }
	}
	#タイプ別に再帰呼び出し
	foreach ($searchResult in $searchResults) {
		switch ($searchResult.Type) {
			'live' { continue }
			'episode' { $linkCollection.episodeLinks.Add('https://tver.jp/episodes/{0}' -f $searchResult.Content.Id) ; continue }
			'season' { $linkCollection.seasonLinks.Add($searchResult.Content.Id) ; continue }
			'series' { $linkCollection.seriesLinks.Add($searchResult.Content.Id) ; continue }
			'talent' { $linkCollection.talentLinks.Add($searchResult.Content.Id) ; continue }
			'special' {
				if ($type -eq 'specialmain') { $linkCollection.specialLinks.Add($searchResult.Content.Id) }
				else { Get-LinkFromKeyword -id $searchResult.Content.Id -type 'specialDetail' -LinkCollection ([ref]$linkCollection) }
				continue
			}
			'specialMain' { $linkCollection.specialMainLinks.Add($searchResult.Content.Id) ; continue }
			default { $linkCollection.episodeLinks = & { $linkCollection.episodeLinks ; ('https://tver.jp/{0}/{1}' -f $searchResult.Type, $searchResult.Content.Id) } }
		}
	}
	Remove-Variable -Name baseURL, type, keyword, requireData -ErrorAction SilentlyContinue
	Remove-Variable -Name uid, token, callSearchURL, searchResultsRaw, searchResults, searchResult -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#エピソード以外のリンクをためたバッファを順次API呼び出し
#----------------------------------------------------------------------
function Convert-Buffer {
	[CmdletBinding()]
	[OutputType([System.Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $false)][Object[]]$tverIDs,
		[Parameter(Mandatory = $true)][ValidateSet('Special Main', 'Special Detail', 'Talent', 'Season', 'Series')][string]$tverIDType,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][ref]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($tverIDs) {
		foreach ($tverID in ($tverIDs | Sort-Object -Unique)) {
			Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverIDType, $tverID)
			switch ($tverIDType) {
				'Series' { Get-LinkFromKeyword -id $tverID -type 'series' -LinkCollection ([ref]$linkCollection) ; continue }
				'Season' { Get-LinkFromKeyword -id $tverID -type 'season' -LinkCollection ([ref]$linkCollection) ; continue }
				'Talent' { Get-LinkFromKeyword -id $tverID -type 'talent' -LinkCollection ([ref]$linkCollection) ; continue }
				'Special Main' { Get-LinkFromKeyword -id $tverID -type 'specialMain' -LinkCollection ([ref]$linkCollection) ; continue }
				'Special Detail' { Get-LinkFromKeyword -id $tverID -type 'specialDetail' -LinkCollection ([ref]$linkCollection) ; continue }
			}
		}
		$linkTypes = @('episodeLinks', 'seasonLinks', 'seriesLinks', 'specialLinks')
		foreach ($linkType in $linkTypes) { if ($linkCollection.$linkType) { $linkCollection.$linkType = [System.Collections.Generic.List[string]]($linkCollection.$linkType | Sort-Object -Unique) } }
	}
	Remove-Variable -Name tverIDs, tverIDType, linkCollection, tverID, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTopPage {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][ref]$linkCollection)
	Write-Debug ('Dev - {0}' -f $MyInvocation.MyCommand.Name)
	$callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $callSearchBaseURL, $script:platformUID, $script:platformToken)
	try { $searchResults = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning 'トップページを取得できませんでした' return }
	foreach ($component in $searchResults.Result.Components) {
		switch ($component.Type) {
			{ $_ -in @('horizontal', 'richHorizontal', 'ranking', 'talents', 'billboard', 'episodeRanking', 'newer', 'ender', 'talent', 'special', 'specialContent', 'topics', 'spikeRanking') } {
				$contents = if ($component.Type -eq 'topics') { $component.Contents.Content.Content } else { $component.Contents }
				foreach ($content in $contents) {
					if ($content.Type -eq 'live') { continue }
					switch ($content.Type) {
						'episode' { $linkCollection.episodeLinks.Add('https://tver.jp/episodes/{0}' -f $content.Content.Id) ; continue }
						'series' { $linkCollection.seriesLinks.Add($content.Content.Id) ; continue }
						'season' { $linkCollection.seasonLinks.Add($content.Content.Id) ; continue }
						'talent' { $linkCollection.talentLinks.Add($content.Content.Id) ; continue }
						'specialMain' { $linkCollection.specialMainLinks.Add($content.Content.Id) ; continue }
						'special' { $linkCollection.specialLinks.Add($content.Content.Id) ; continue }
						default { Write-Warning ('⚠️ 未知のコンテンツタイプです。 - {0}/{1}' -f $content.Type, $content.Content.Id) }
					}
				}
				continue
			}
			{ $_ -in @('banner', 'resume', 'favorite') } { continue }
			default { Write-Warning "⚠️ 未知のコンポーネントタイプです。 - $($component.Type)" }
		}
	}
	Remove-Variable -Name linkCollection, callSearchBaseURL, callSearchURL, searchResults, component, contents, content -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSiteMap {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][ref]$linkCollection)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$callSearchURL = 'https://tver.jp/sitemap.xml'
	try { $searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning 'サイトマップを取得できませんでした' ; return }
	#Special Detailを拾わないように「/」2個目以降は無視して重複削除
	$searchResults = $searchResultsRaw.urlset.url.loc | ForEach-Object { $_.Replace('https://tver.jp/', '') -replace '^([^/]+/[^/]+).*', '$1' } | Sort-Object -Unique
	foreach ($url in $searchResults) {
		try {
			$url = $url.Split('/')
			$tverID = @{
				type = $url[0]
				id   = $url[1]
			}
		} catch { $tverID = @{ type = $null ; id = $null } }
		if ($tverID.id) {
			switch ($tverID.type) {
				'episodes' { $linkCollection.episodeLinks.Add('https://tver.jp/episodes/{0}' -f $tverID.id) ; continue }
				'series' { if (!$script:sitemapParseEpisodeOnly) { $linkCollection.seriesLinks.Add($tverID.id) } ; continue }
				'ranking' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromKeyword -id $tverID.id -type 'ranking' -LinkCollection ([ref]$linkCollection)
					}
					continue
				}
				'specials' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromKeyword -id $tverID.id -type 'specialMain' -LinkCollection ([ref]$linkCollection)
					}
					continue
				}
				{ $_ -in @('info', 'live', 'mypage') } { continue }
				default { if (!$script:sitemapParseEpisodeOnly) { Write-Warning ('⚠️ 未知のパターンです。 - {0}/{1}' -f $tverID.type, $tverID.id) } }
			}
		}
	}
	Remove-Variable -Name callSearchURL, searchResultsRaw, searchResults, url, tverID, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#マイページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromMyPage {
	[CmdletBinding()]
	[OutputType([System.Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$page,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][ref]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$baseURLPrefix = if ($script:myMemberSID) { 'https://member-api.tver.jp' ; $loginRequired = $true } else { 'https://platform-api.tver.jp' ; $loginRequired = $false }
	switch ($page) {
		'fav' { $baseURL = ('{0}/service/api/v2/callMylistDetail/{1}' -f $baseURLPrefix, (ConvertTo-UnixTime (Get-Date))) ; $requireData = 'mylist' ; continue }
		'later' { $baseURL = ('{0}/service/api/v2/callMyLater' -f $baseURLPrefix) ; $requireData = $page ; continue }
		'resume' { $baseURL = ('{0}/service/api/v2/callMyResume' -f $baseURLPrefix) ; $requireData = $page ; continue }
		'favorite' { $baseURL = ('{0}/service/api/v2/callMyFavorite' -f $baseURLPrefix) ; $requireData = 'mylist' ; continue }
		default { Write-Warning ('⚠️ 未知のパターンです。 - mypage/{0}') -f $page }
	}
	Get-SearchResults -baseURL $baseURL -Type 'mypage' -RequireData $requireData -LoginRequired $loginRequired -LinkCollection ([ref]$linkCollection)
	Remove-Variable -Name page, baseURLPrefix, baseURL, loginRequired, requireData, tverIDs -ErrorAction SilentlyContinue
}
