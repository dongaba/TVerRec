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
	[OutputType([System.Collections.Generic.List[string]])]
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
		'series' { $linkCollection.seriesLinks.Add($tverID) ; continue }
		'talents' { $linkCollection.talentLinks.Add($tverID) ; continue }
		'episodes' { $linkCollection.episodeLinks.Add(('https://tver.jp/{0}/{1}' -f $key, $tverID)) ; continue }
		'mypage' { $result = Get-LinkFromMyPage $tverID ; continue }
		'tag' { $result = Get-LinkFromID -id $tverID -type 'tag' ; continue }
		'ranking' { $result = Get-LinkFromID -id $tverID -type 'ranking' ; continue }
		'new' { $result = Get-LinkFromID -id $tverID -type 'new' ; continue }
		'toppage' { $result = Get-LinkFromTopPage ; continue }
		'sitemap' { $result = Get-LinkFromSiteMap ; continue }
		default { $result = Get-LinkFromID -id $keyword -type 'keyword' }
	}
	if (Test-Path Variable:result) { $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result }
	while (($linkCollection.specialMainLinks.Count -ne 0) -or ($linkCollection.specialLinks.Count -ne 0) -or ($linkCollection.talentLinks.Count -ne 0) -or ($linkCollection.seriesLinks.Count -ne 0) -or ($linkCollection.seasonLinks.Count -ne 0)) {
		if ($linkCollection.specialMainLinks) {
			$linkCollection = Convert-Buffer -TverIDs $linkCollection.specialMainLinks -TverIDType 'Special Main' -LinkCollection $linkCollection
			$linkCollection.specialMainLinks = [System.Collections.Generic.List[string]]::new()
		}
		if ($linkCollection.specialLinks) {
			$linkCollection = Convert-Buffer -TverIDs $linkCollection.specialLinks -TverIDType 'Special Detail' -LinkCollection $linkCollection
			$linkCollection.specialLinks = [System.Collections.Generic.List[string]]::new()
		}
		if ($linkCollection.talentLinks) {
			$linkCollection = Convert-Buffer -TverIDs $linkCollection.talentLinks -TverIDType 'Talent' -LinkCollection $linkCollection
			$linkCollection.talentLinks = [System.Collections.Generic.List[string]]::new()
		}
		if ($linkCollection.seriesLinks) {
			$linkCollection = Convert-Buffer -TverIDs $linkCollection.seriesLinks -TverIDType 'Series' -LinkCollection $linkCollection
			$linkCollection.seriesLinks = [System.Collections.Generic.List[string]]::new()
		}
		if ($linkCollection.seasonLinks) {
			$linkCollection = Convert-Buffer -TverIDs $linkCollection.seasonLinks -TverIDType 'Season' -LinkCollection $linkCollection
			$linkCollection.seasonLinks = [System.Collections.Generic.List[string]]::new()
		}
	}
	return $linkCollection.episodeLinks | Sort-Object -Unique
	Remove-Variable -Name keyword, linkCollection, key, tverID, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function ProcessSearchResults {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $false)][String]$requireData,
		[Parameter(Mandatory = $false)][Boolean]$loginRequired
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$episodeLinks = [System.Collections.Generic.List[string]]::new()
	$talentLinks = [System.Collections.Generic.List[string]]::new()
	$seasonLinks = [System.Collections.Generic.List[string]]::new()
	$seriesLinks = [System.Collections.Generic.List[string]]::new()
	$specialMainLinks = [System.Collections.Generic.List[string]]::new()
	$specialLinks = [System.Collections.Generic.List[string]]::new()
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
	try {
		$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
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
				'episode' { $episodeLinks.Add('https://tver.jp/episodes/{0}' -f $searchResult.Content.Id) ; continue }
				'season' { $seasonLinks.Add($searchResult.Content.Id) ; continue }
				'series' { $seriesLinks.Add($searchResult.Content.Id) ; continue }
				'talent' { $talentLinks.Add($searchResult.Content.Id) ; continue }
				'special' {
					if ($type -eq 'specialmain') { $specialLinks.Add($searchResult.Content.Id) }
					else { $episodeLinks = & { $episodeLinks ; (Get-LinkFromID -id $searchResult.Content.Id -type 'specialDetail') } }
					continue
				}
				'specialMain' { $specialMainLinks.Add($searchResult.Content.Id) ; continue }
				default { $episodeLinks = & { $episodeLinks ; ('https://tver.jp/{0}/{1}' -f $searchResult.Type, $searchResult.Content.Id) } }
			}
		}
	} catch {
		if ($_.Exception.Message.Contains('The request was canceled due to the configured HttpClient.Timeout of')) {
			Write-Warning ('⚠️ HTTP接続がタイムアウトしました。スキップして次のリンクを処理します。')
			Write-Warning ('　　{0}, {1}, {2}' -f $keyword, $type, $requireData)
		} elseif ($_.Exception.Message.Contains('Response status code does not indicate success:')) {
			Write-Warning ('⚠️ HTTP接続が失敗しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message)
			Write-Warning ('　　{0}, {1}, {2}' -f $keyword, $type, $requireData)
		} else {
			Write-Warning ('⚠️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message)
			Write-Warning ('　　{0}, {1}, {2}' -f $keyword, $type, $requireData)
		}
	}
	return [PSCustomObject]@{
		episodeLinks     = $episodeLinks | Sort-Object -Unique
		talentLinks      = $talentLinks | Sort-Object -Unique
		seasonLinks      = $seasonLinks | Sort-Object -Unique
		seriesLinks      = $seriesLinks | Sort-Object -Unique
		specialMainLinks = $specialMainLinks | Sort-Object -Unique
		specialLinks     = $specialLinks | Sort-Object -Unique
	}
	Remove-Variable -Name baseURL, type, keyword, requireData, episodeLinks, talentLinks, seasonLinks, seriesLinks, specialMainLinks, specialLinks -ErrorAction SilentlyContinue
	Remove-Variable -Name uid, token, callSearchURL, searchResultsRaw, searchResults, searchResult -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#エピソード以外のリンクをためたバッファを順次API呼び出し
#----------------------------------------------------------------------
function Convert-Buffer {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $false)][Object[]]$tverIDs,
		[Parameter(Mandatory = $true)][ValidateSet('Special Main', 'Special Detail', 'Talent', 'Season', 'Series')][string]$tverIDType,
		[Parameter(Mandatory = $true)][OutputType([PSCustomObject])]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($tverIDs) {
		foreach ($tverID in ($tverIDs | Sort-Object -Unique)) {
			Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverIDType, $tverID)
			$result = switch ($tverIDType) {
				'Series' { Get-LinkFromID -id $tverID -type 'series' ; continue }
				'Season' { Get-LinkFromID -id $tverID -type 'season' ; continue }
				'Talent' { Get-LinkFromID -id $tverID -type 'talent' ; continue }
				'Special Main' { Get-LinkFromID -id $tverID -type 'specialMain' ; continue }
				'Special Detail' { Get-LinkFromID -id $tverID -type 'specialDetail' ; continue }
			}
			$linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result 
		}
		$linkTypes = @('episodeLinks', 'seasonLinks', 'seriesLinks', 'specialLinks')
		foreach ($linkType in $linkTypes) { if ($linkCollection.$linkType) { $linkCollection.$linkType = $linkCollection.$linkType | Sort-Object -Unique } }
	}
	return $linkCollection
	Remove-Variable -Name tverIDs, tverIDType, linkCollection, tverID, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVerIDの整理
#----------------------------------------------------------------------
function Update-LinkCollection {
	Param (
		[PSCustomObject]$linkCollection,
		[PSCustomObject]$result
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($result.episodeLinks) { $linkCollection.episodeLinks = [System.Collections.Generic.List[string]](& { $linkCollection.episodeLinks ; $result.episodeLinks }) }
	if ($result.talentLinks) { $linkCollection.talentLinks = [System.Collections.Generic.List[string]](& { $linkCollection.talentLinks ; $result.talentLinks }) }
	if ($result.seasonLinks) { $linkCollection.seasonLinks = [System.Collections.Generic.List[string]](& { $linkCollection.seasonLinks ; $result.seasonLinks }) }
	if ($result.seriesLinks) { $linkCollection.seriesLinks = [System.Collections.Generic.List[string]](& { $linkCollection.seriesLinks ; $result.seriesLinks }) }
	if ($result.specialMainLinks) { $linkCollection.specialMainLinks = [System.Collections.Generic.List[string]](& { $linkCollection.specialMainLinks ; $result.specialMainLinks }) }
	if ($result.specialLinks) { $linkCollection.specialLinks = [System.Collections.Generic.List[string]](& { $linkCollection.specialLinks ; $result.specialLinks }) }
	return $linkCollection
	Remove-Variable -Name linkTypes, linkType, linkCollection, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# IDまたはキーワードによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromID {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$id,
		[Parameter(Mandatory = $false)][ValidateSet('series', 'season', 'talent', 'specialMain', 'specialDetail', 'tag', 'new', 'ranking', 'keyword')][string]$type
	)
	Write-Debug ($MyInvocation.MyCommand.Name)

	# ベースURLをタイプに応じて設定
	$baseURL = switch ($type) {
		'series' { "https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/$id" ; continue }
		'season' { "https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/$id" ; continue }
		'talent' { "https://platform-api.tver.jp/service/api/v1/callTalentEpisode/$id" ; continue }
		'specialMain' { "https://platform-api.tver.jp/service/api/v1/callSpecialContents/$id"; $type = 'specialmain' ; continue }
		'specialDetail' { "https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/$id"; $type = 'specialdetail' ; continue }
		'tag' { "https://platform-api.tver.jp/service/api/v1/callTagSearch/$id" ; continue }
		'new' { "https://platform-api.tver.jp/service/api/v1/callNewerDetail/$id"; $type = 'new' ; continue }
		'ranking' { if ($id -eq 'all') { 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' } else { "https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/$id" }; $type = 'ranking' ; continue }
		'keyword' { 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'; $keyword = $id ; continue }
		default { Write-Warning '無効なタイプが指定されました。' }
	}

	# 検索結果の取得
	$tverIDs = ProcessSearchResults -baseURL $baseURL -Type $type -Keyword $keyword
	return $tverIDs
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTopPage {
	[CmdletBinding()]
	[OutputType([System.Collections.Generic.List[string]])]
	Param ()
	Write-Debug ('Dev - {0}' -f $MyInvocation.MyCommand.Name)
	$linkCollection = [PSCustomObject]@{
		episodeLinks     = [System.Collections.Generic.List[string]]::new()
		seriesLinks      = [System.Collections.Generic.List[string]]::new()
		seasonLinks      = [System.Collections.Generic.List[string]]::new()
		talentLinks      = [System.Collections.Generic.List[string]]::new()
		specialMainLinks = [System.Collections.Generic.List[string]]::new()
		specialLinks     = [System.Collections.Generic.List[string]]::new()
	}
	$callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $callSearchBaseURL, $script:platformUID, $script:platformToken)
	try { $searchResults = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning 'トップページを取得できませんでした' ; return $linkCollection }
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
			{ $_ -in @('banner', 'resume', 'favorite') ; continue } {}
			default { Write-Warning "⚠️ 未知のコンポーネントタイプです。 - $($component.Type)" }
		}
	}
	return $linkCollection
	Remove-Variable -Name linkCollection, callSearchBaseURL, callSearchURL, searchResults, component, contents, content -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSiteMap {
	[CmdletBinding()]
	[OutputType([System.Collections.Generic.List[string]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$linkCollection = [PSCustomObject]@{
		episodeLinks     = [System.Collections.Generic.List[string]]::new()
		seriesLinks      = [System.Collections.Generic.List[string]]::new()
		seasonLinks      = [System.Collections.Generic.List[string]]::new()
		talentLinks      = [System.Collections.Generic.List[string]]::new()
		specialMainLinks = [System.Collections.Generic.List[string]]::new()
		specialLinks     = [System.Collections.Generic.List[string]]::new()
	}
	$callSearchURL = 'https://tver.jp/sitemap.xml'
	try { $searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning 'サイトマップを取得できませんでした' ; return $linkCollection }
	$searchResults = $searchResultsRaw.urlset.url.loc | Sort-Object -Unique
	foreach ($url in $searchResults) {
		try {
			$url = $url.Replace('https://tver.jp/', '') -split '/'
			$tverID = @{
				type = $url[0]
				id   = $url[1]
			}
		} catch { $tverID = @{ type = $null ; id = $null } }
		if ($tverID.id) {
			switch ($tverID.type) {
				'episodes' { $linkCollection.episodeLinks.Add('https://tver.jp/episodes/{0}' -f $tverID.id) ; continue }
				'series' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverID.type, $tverID.id)
						$linkCollection.seriesLinks.Add($tverID.id)
					}
					continue
				}
				'ranking' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromID -id $tverID.id -type 'ranking'
						$linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result
					}
					continue
				}
				'specials' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromID -id $tverID.id -type 'specialMain'
						$linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result
					}
					continue
				}
				{ $_ -in @('info', 'live', 'mypage') } { continue }
				default { if (!$script:sitemapParseEpisodeOnly) { Write-Warning ('⚠️ 未知のパターンです。 - {0}/{1}' -f $tverID.type, $tverID.id) } }
			}
		}
	}
	return $linkCollection
	Remove-Variable -Name linkCollection, callSearchURL, searchResultsRaw, searchResults, url, tverID, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#マイページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromMyPage {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$page)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$baseURLPrefix = if ($script:myMemberSID) { 'https://member-api.tver.jp' ; $loginRequired = $true } else { 'https://platform-api.tver.jp' ; $loginRequired = $false }
	switch ($page) {
		'fav' { $baseURL = ('{0}/service/api/v2/callMylistDetail/{1}' -f $baseURLPrefix, (ConvertTo-UnixTime (Get-Date))) ; $requireData = 'mylist' ; continue }
		'later' { $baseURL = ('{0}/service/api/v2/callMyLater' -f $baseURLPrefix) ; $requireData = 'later' ; continue }
		'resume' { $baseURL = ('{0}/service/api/v2/callMyResume' -f $baseURLPrefix) ; $requireData = 'resume' ; continue }
		'favorite' { $baseURL = ('{0}/service/api/v2/callMyFavorite' -f $baseURLPrefix) ; $requireData = 'mylist' ; continue }
		default { Write-Warning "⚠️ 未知のパターンです。 - mypage/$page" }
	}
	$tverIDs = ProcessSearchResults -baseURL $baseURL -Type 'mypage' -RequireData $requireData -LoginRequired $loginRequired
	return $tverIDs
	Remove-Variable -Name page, baseURL, requireData, tverIDs -ErrorAction SilentlyContinue
}
