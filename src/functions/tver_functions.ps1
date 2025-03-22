###################################################################################
#
#		TVer固有関数スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
# TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function Get-Token () {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$httpHeader = @{
		'Content-Type'     = 'application/x-www-form-urlencoded'
		'Forwarded'        = $script:jpIP
		'Forwarded-For'    = $script:jpIP
		'X-Forwarded'      = $script:jpIP
		'X-Forwarded-For'  = $script:jpIP
		'X-Originating-IP' = $script:jpIP
	}
	$requestBody = 'device_type=pc'
	try {
		$tokenResponse = Invoke-RestMethod -Uri $tverTokenURL -Method 'POST' -Headers $httpHeader -Body $requestBody -TimeoutSec $script:timeoutSec
		$script:platformUID = $tokenResponse.Result.platform_uid
		$script:platformToken = $tokenResponse.Result.platform_token
	} catch { Throw ($script:msg.TokenRetrievalFailed) }
	Remove-Variable -Name tverTokenURL, httpHeader, requestBody, tokenResponse -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function Get-VideoLinksFromKeyword {
	[CmdletBinding()]
	[OutputType([System.Collections.Generic.List[String]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String][Ref]$keyword)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$linkCollection = [PSCustomObject]@{
		episodeLinks     = @{}
		seriesLinks      = New-Object System.Collections.Generic.List[String]
		seasonLinks      = New-Object System.Collections.Generic.List[String]
		talentLinks      = New-Object System.Collections.Generic.List[String]
		specialMainLinks = New-Object System.Collections.Generic.List[String]
		specialLinks     = New-Object System.Collections.Generic.List[String]
	}
	if ($keyword.IndexOf('/') -gt 0) {
		$key = $keyword.split(' ')[0].split("`t")[0].Split('/')[0]
		$tverID = Remove-Comment(($keyword.Replace("$key/", '')).Trim())
	} else { $key = '' ; $tverID = '' }
	if (($keyword -eq 'sitemap') -or ($keyword -eq 'toppage')) { $key = $keyword }
	Invoke-StatisticsCheck -Operation 'search' -TVerType $key -TVerID $tverID
	switch ($key) {
		'episodes' { $linkCollection.episodeLinks[('https://tver.jp/episodes/{0}' -f $tverID)] = 0 ; continue }	# キーワードファイルにあるEpisodeはEndAtが不明なので0を設定
		'series' { $linkCollection.seriesLinks.Add($tverID) ; continue }
		'talents' { $linkCollection.talentLinks.Add($tverID) ; continue }
		'tag' { Get-LinkFromKeyword -id $tverID -linkType 'tag' -LinkCollection ([Ref]$linkCollection) ; continue }
		'ranking' { Get-LinkFromKeyword -id $tverID -linkType 'ranking' -LinkCollection ([Ref]$linkCollection) ; continue }
		'new' { Get-LinkFromKeyword -id $tverID -linkType 'new' -LinkCollection ([Ref]$linkCollection)  ; continue }
		'end' { Get-LinkFromKeyword -id $tverID -linkType 'end' -LinkCollection ([Ref]$linkCollection)  ; continue }
		'mypage' { Get-LinkFromMyPage -Page $tverID -LinkCollection ([Ref]$linkCollection) ; continue }
		'toppage' { Get-LinkFromTopPage ([Ref]$linkCollection) ; continue }
		'sitemap' { Get-LinkFromSiteMap ([Ref]$linkCollection) ; continue }
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
	Remove-Variable -Name keyword, key, tverID, linkTypes, linkType -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# エピソード以外のリンクをためたバッファを順次API呼び出し
#----------------------------------------------------------------------
function Get-LinkFromBuffer {
	[CmdletBinding()]
	[OutputType([Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $false)][Object[]]$tverIDs,
		[Parameter(Mandatory = $true)][ValidateSet('specialMainLinks', 'specialLinks', 'talentLinks', 'seriesLinks', 'seasonLinks')][String]$tverIDType,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][Ref]$linkCollection
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
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$id,
		[Parameter(Mandatory = $false)][ValidateSet('seriesLinks', 'seasonLinks', 'talentLinks', 'specialMainLinks', 'specialLinks', 'tag', 'new', 'end', 'ranking', 'keyword', 'category')][String]$linkType,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][Ref]$linkCollection
	)
	Write-Debug ($MyInvocation.MyCommand.Name)
	$type = ''
	# ベースURLをタイプに応じて設定
	$baseURL = switch ($linkType) {
		'seriesLinks' { ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}' -f $id) ; continue }
		'seasonLinks' { ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $id) ; continue }
		'talentLinks' { ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $id) ; continue }
		'specialMainLinks' { ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $id) ; $type = 'specialmain' ; continue }
		'specialLinks' { ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $id) ; $type = 'specialdetail' ; continue }
		'tag' { ('https://platform-api.tver.jp/service/api/v1/callTagSearch/{0}' -f $id) ; continue }
		'new' { ('https://platform-api.tver.jp/service/api/v1/callNewerDetail/{0}' -f $id) ; $type = 'new' ; continue }
		'end' { ('https://platform-api.tver.jp/service/api/v1/callEnderDetail/{0}' -f $id) ; $type = 'end' ; continue }
		'ranking' {
			if ($id -eq 'all') { 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' }
			else { ('https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/{0}' -f $id) }
			$type = 'ranking' ; continue
		}
		'category' { 'https://platform-api.tver.jp/service/api/v1/callCategoryHome/{0}' -f $id; continue }
		'keyword' { 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'; $keyword = $id ; continue }
		default { Write-Warning $script:msg.InvalidTypeSpecified }
	}
	# 検索結果の取得
	Get-SearchResults -baseURL $baseURL -Type $type -Keyword $keyword -LinkCollection ([Ref]$linkCollection)
	Remove-Variable -Name id, linkType, type, baseURL, keyword -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-SearchResults {
	[CmdletBinding()]
	[OutputType([Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $false)][String]$requireData,
		[Parameter(Mandatory = $false)][Boolean]$loginRequired,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][Ref]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# URLの整形
	$sid = $script:myMemberSID
	if (($script:myPlatformUID) -and ($script:myPlatformToken)) { $uid = $script:myPlatformUID ; $token = $script:myPlatformToken }
	else { $uid = $script:platformUID ; $token = $script:platformToken }
	if ($loginRequired) { $callSearchURL = '{0}?member_sid={1}' -f $baseURL, $sid }						# TVerIDにログインして使う場合
	else { $callSearchURL = '{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $uid, $token }		# TVerIDを匿名で使う場合
	switch ($type) {
		'keyword' { if ($keyword) { $callSearchURL += "&keyword=$keyword" } ; continue }
		'mypage' { if ($requireData) { $callSearchURL += "&require_data=$requireData" } ; continue }
		default {}
	}
	# 取得した値をタイプごとに調整
	try { $searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
	catch {
		if ($_.Exception.Message.Contains('The request was canceled due to the configured HttpClient.Timeout of')) {
			Write-Warning ($script:msg.HttpTimeout) ; return
		} elseif ($_.Exception.Message.Contains('Response status code does not indicate success:')) {
			Write-Warning ($script:msg.HttpBadResponse -f $_.Exception.Message) ; return
		} else { Write-Warning ($script:msg.HttpOtherError -f $_.Exception.Message) ; return }
	}
	# タイプ別に参照先を調整
	$searchResults = switch ($type) {
		'specialmain' { $searchResultsRaw.Result.specialContents ; continue }
		'specialdetail' { $searchResultsRaw.Result.Contents.Content.Contents ; continue }
		'category' { $searchResultsRaw.Result.components.contents ; continue }
		{ $_ -in 'new', 'end', 'ranking' } { $searchResultsRaw.Result.Contents.Contents ; continue }
		default { $searchResultsRaw.Result.Contents }
	}
	# searchResultsを並び替え
	$order = @('specialMain', 'special', 'talent', 'series', 'season', 'episode', 'live', 'banner')
	$sortedSearchResults = $searchResults | Sort-Object { $order.IndexOf($_.Type) }
	# タイプ別に再帰呼び出し
	foreach ($searchResult in $sortedSearchResults) {
		switch ($searchResult.Type) {
			'live' { continue }
			'banner' { continue }
			'episode' { $linkCollection.episodeLinks[('https://tver.jp/episodes/{0}' -f $searchResult.Content.Id)] = $searchResult.Content.EndAt ; continue }
			'season' { $linkCollection.seasonLinks.Add($searchResult.Content.Id) ; continue }
			'series' { $linkCollection.seriesLinks.Add($searchResult.Content.Id) ; continue }
			'talent' { $linkCollection.talentLinks.Add($searchResult.Content.Id) ; continue }
			'special' {
				if ($type -eq 'specialmain') { $linkCollection.specialLinks.Add($searchResult.Content.Id) }
				else { Get-LinkFromKeyword -id $searchResult.Content.Id -linkType 'specialLinks' -LinkCollection ([Ref]$linkCollection) }
				continue
			}
			'specialMain' { $linkCollection.specialMainLinks.Add($searchResult.Content.Id) ; continue }
			default { Write-Warning $script:msg.UnknownContentsType -f $searchResult.Type, $searchResult.Content.Id }
		}
	}
	Remove-Variable -Name baseURL, type, keyword, requireData, loginRequired, sid, uid, token, callSearchURL, searchResultsRaw, searchResults, order, sortedSearchResults, searchResult -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTopPage {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][Ref]$linkCollection)
	Write-Debug ('Dev - {0}' -f $MyInvocation.MyCommand.Name)
	$callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $callSearchBaseURL, $script:platformUID, $script:platformToken)
	try { $searchResults = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning $script:msg.TopPageRetrievalFailed ; return }
	foreach ($component in $searchResults.Result.Components) {
		switch ($component.Type) {
			{ $_ -in @('horizontal', 'richHorizontal', 'ranking', 'talents', 'billboard', 'episodeRanking', 'newer', 'ender', 'talent', 'special', 'specialContent', 'topics', 'spikeRanking', 'seasonEpisode') } {
				$contents = if ($component.Type -eq 'topics') { $component.Contents.Content.Content } else { $component.Contents }
				foreach ($content in $contents) {
					if ($content.Type -eq 'live') { continue }
					switch ($content.Type) {
						'episode' { $linkCollection.episodeLinks[('https://tver.jp/episodes/{0}' -f $content.Content.Id)] = $content.Content.EndAt ; continue }
						'series' { $linkCollection.seriesLinks.Add($content.Content.Id) ; continue }
						'season' { $linkCollection.seasonLinks.Add($content.Content.Id) ; continue }
						'talent' { $linkCollection.talentLinks.Add($content.Content.Id) ; continue }
						'specialMain' { $linkCollection.specialMainLinks.Add($content.Content.Id) ; continue }
						'special' { $linkCollection.specialLinks.Add($content.Content.Id) ; continue }
						default { Write-Warning ($script:msg.UnknownContentsType -f $content.Type, $content.Content.Id) }
					}
				}
				continue
			}
			{ $_ -in @('banner', 'resume', 'favorite') } { continue }
			default { Write-Warning $script:msg.UnknownComponentType -f $component.Type }
		}
	}
	Remove-Variable -Name callSearchBaseURL, callSearchURL, searchResults, component, contents, content -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSiteMap {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][Ref]$linkCollection)
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
			$url = $url.Split('/')
			$tverID = @{ type = $url[0] ; id = $url[1] }
		} catch { $tverID = @{ type = $null ; id = $null } }
		if ($tverID.id) {
			switch ($tverID.type) {
				'episodes' {
					$linkCollection.episodeLinks[('https://tver.jp/episodes/{0}' -f $tverID.id)] = 0	# サイトマップにあるEpisodeはEndAtが不明なので0を設定
					continue
				}
				'series' {
					if (!$script:sitemapParseEpisodeOnly) { $linkCollection.seriesLinks.Add($tverID.id) }
					continue
				}
				'ranking' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ($script:msg.ExtractingEpisodes -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromKeyword -id $tverID.id -linkType 'ranking' -LinkCollection ([Ref]$linkCollection)
					}
					continue
				}
				'specials' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ($script:msg.ExtractingEpisodes -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromKeyword -id $tverID.id -linkType 'specialMainLinks' -LinkCollection ([Ref]$linkCollection)
					}
					continue
				}
				'categories' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ($script:msg.ExtractingEpisodes -f (Get-Date), $tverID.type, $tverID.id)
						Get-LinkFromKeyword -id $tverID.id -linkType 'category' -LinkCollection ([Ref]$linkCollection)
					}
					continue
				}
				{ $_ -in @('info', 'live', 'mypage') } { continue }
				default { if (!$script:sitemapParseEpisodeOnly) { Write-Warning ($script:msg.UnknownContentsType -f $tverID.type, $tverID.id) } }
			}
		}
	}
	Remove-Variable -Name callSearchURL, searchResultsRaw, searchResults, url, tverID -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# マイページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromMyPage {
	[CmdletBinding()]
	[OutputType([Void])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$page,
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][PSCustomObject][Ref]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$baseURLPrefix = if ($script:myMemberSID) { 'https://member-api.tver.jp' ; $loginRequired = $true } else { 'https://platform-api.tver.jp' ; $loginRequired = $false }
	switch ($page) {
		'fav' { $baseURL = ('{0}/service/api/v2/callMylistDetail/{1}' -f $baseURLPrefix, (ConvertTo-UnixTime (Get-Date))) ; $requireData = 'mylist' ; continue }
		'later' { $baseURL = ('{0}/service/api/v2/callMyLater' -f $baseURLPrefix) ; $requireData = $page ; continue }
		'resume' { $baseURL = ('{0}/service/api/v2/callMyResume' -f $baseURLPrefix) ; $requireData = $page ; continue }
		'favorite' { $baseURL = ('{0}/service/api/v2/callMyFavorite' -f $baseURLPrefix) ; $requireData = 'mylist' ; continue }
		default { Write-Warning ($script:msg.UnknownContentsType -f 'mypage', $page) }
	}
	Get-SearchResults -baseURL $baseURL -Type 'mypage' -RequireData $requireData -LoginRequired $loginRequired -LinkCollection ([Ref]$linkCollection)
	Remove-Variable -Name baseURLPrefix, baseURL, requireData, loginRequired -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function Get-VideoInfo {
	Param ([Parameter(Mandatory = $true)][String]$episodeID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#----------------------------------------------------------------------
	# 番組説明以外
	$tverVideoInfoBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$tverVideoInfoURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $tverVideoInfoBaseURL, $episodeID, $script:platformUID, $script:platformToken)
	try { $response = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning ($script:msg.HttpOtherError -f $_.Exception.Message) ; return }
	# シリーズ
	#	Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
	#	Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
	#	3.2.2からEpisode.Content.SeriesTitleを採用することとする。
	#	理由は、Series.Content.Titleだとファイル名が冗長になることがあることと、複数シーズン配信時に最新シーズン名になってしまうことがあるため。
	$videoSeries = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Episode.Content.SeriesTitle))).Trim()
	$videoSeriesID = $response.Result.Series.Content.Id
	$videoSeriesPageURL = ('https://tver.jp/series/{0}' -f $response.Result.Series.Content.Id)
	# シーズン
	$videoSeason = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Season.Content.Title))).Trim()
	$videoSeasonID = $response.Result.Season.Content.Id
	# エピソード
	$episodeName = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Episode.Content.Title))).Trim()
	$videoEpisodeID = $response.Result.Episode.Content.Id
	$videoEpisodePageURL = ('https://tver.jp/episodes/{0}' -f $videoEpisodeID)
	# 放送局
	$mediaName = (Get-NarrowChars ($response.Result.Episode.Content.BroadcasterName)).Trim()
	$providerName = (Get-NarrowChars ($response.Result.Episode.Content.ProductionProviderName)).Trim()
	# 放送日
	$broadcastDate = (($response.Result.Episode.Content.BroadcastDateLabel).Replace('ほか', '').Replace('放送分', '放送').Replace('配信分', '配信')).Trim()
	# 配信終了日時
	$endTime = (ConvertFrom-UnixTime ($response.Result.Episode.Content.EndAt)).AddHours(9)
	#----------------------------------------------------------------------
	# 番組説明
	try {
		$versionNum = $response.Result.Episode.Content.version
		$tverVideoInfoBaseURL = 'https://statics.tver.jp/content/episode/'
		$tverVideoInfoURL = ('{0}{1}.json?v={2}' -f $tverVideoInfoBaseURL, $episodeID, $versionNum)
		$videoInfo = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec
		Write-Debug $videoInfo
		$descriptionText = (Get-NarrowChars ($videoInfo.Description).Replace('&amp;', '&')).Trim()
		$videoEpisodeNum = (Get-NarrowChars ($videoInfo.No)).Trim()
		# Streaks情報取得
		if ($videoInfo.PSObject.Properties.Name -contains 'streaks') {
			$streaksRefID = $videoInfo.streaks.videoRefID
			# $streaksMediaID = $videoInfo.streaks.mediaID
			$streaksProjectID = $videoInfo.streaks.projectID
			# Streaksキー取得
			try {
				$adTemplateJsonURL = ('https://player.tver.jp/player/ad_template.json')
				$ati = (Invoke-RestMethod -Uri $adTemplateJsonURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec).$streaksProjectID.pc
			} catch { Write-Warning ($script:msg.StreaksKeyRetrievalFailed -f $_.Exception.Message) ; return }
			# m3u8 URL取得
			try {
				$streaksInfoBaseURL = 'https://playback.api.streaks.jp/v1/projects/{0}/medias/ref:{1}?ati={2}' -f $streaksProjectID, $streaksRefID, $ati
				$httpHeader = @{
					'Origin'           = 'https://tver.jp'
					'Referer'          = 'https://tver.jp/'
					'Forwarded'        = $script:jpIP
					'Forwarded-For'    = $script:jpIP
					'X-Forwarded'      = $script:jpIP
					'X-Forwarded-For'  = $script:jpIP
					'X-Originating-IP' = $script:jpIP
				}
				$params = @{
					Uri        = $streaksInfoBaseURL
					Method     = 'GET'
					Headers    = $httpHeader
					TimeoutSec = $script:timeoutSec
				}
				if ((Test-Path Variable:Script:proxyUrl) -and ($script:proxyUrl)) { $params.Proxy = $script:proxyUrl }
				if ((Test-Path Variable:Script:proxyCredential) -and ($script:proxyCredential)) { $params.ProxyCredential = $script:proxyCredential }
				$m3u8URL = (Invoke-RestMethod @params).sources.src
				$isStreaks = $true
			} catch { Write-Warning ($script:msg.StreaksM3U8RetrievalFailed -f $_.Exception.Message) ; return }
		} else { $m3u8URL = ''; $isStreaks = $false }
		# Brightcove情報取得
		if ($videoInfo.PSObject.Properties.Name -contains 'video') {
			$accountID = $videoInfo.video.accountID
			$videoRefID = if ($videoInfo.video.PSObject.Properties.Name -contains 'videoRefID') { ('ref%3A{0}' -f $videoInfo.video.videoRefID) } else { $videoInfo.video.videoID }
			$playerID = $videoInfo.video.playerID
			# Brightcoveキー取得
			try {
				$brightcoveJsURL = ('https://players.brightcove.net/{0}/{1}_default/index.min.js' -f $accountID, $playerID)
				$brightcovePk = if ((Invoke-RestMethod -Uri $brightcoveJsURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec) -match 'policyKey:"([a-zA-Z0-9_-]*)"') { $matches[1] }
			} catch { Write-Warning ($script:msg.BrightcoveKeyRetrievalFailed -f $_.Exception.Message) ; return }
			# m3u8とmpd URL取得
			try {
				$brightcoveURL = ('https://edge.api.brightcove.com/playback/v1/accounts/{0}/videos/{1}' -f $accountID, $videoRefID)
				$httpHeader = @{
					'Accept'           = ('application/json;pk={0}' -f $brightcovePk)
					'Forwarded'        = $script:jpIP
					'Forwarded-For'    = $script:jpIP
					'X-Forwarded'      = $script:jpIP
					'X-Forwarded-For'  = $script:jpIP
					'X-Originating-IP' = $script:jpIP
				}
				$response = Invoke-RestMethod -Uri $brightcoveURL -Method 'GET' -Headers $httpHeader -TimeoutSec $script:timeoutSec
				# HLS
				$m3u8URL = $response.sources.where({ $_.src -like 'https://*' }).where({ $_.type -like '*mpeg*' }).where({ $_.ext_x_version -eq 4 })[0].src
				# Dash
				# $mpdURL = $response.sources.where({ $_.src -like 'https://*' }).where({ $_.type -like '*dash*' })[0].src
				$isBrightcove = $true
			} catch { Write-Warning ($script:msg.BrightcoveM3U8RetrievalFailed -f $_.Exception.Message) ; $isBrightcove = $false }
		}
	} catch { Write-Warning ($script:msg.VideoInfoRetrievalFailed -f $_.Exception.Message) ; return }

	# 「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote) { $videoSeason = Remove-SpecialNote $videoSeason ; $episodeName = Remove-SpecialNote $episodeName }
	# シーズン名が本編の場合はシーズン名をクリア
	if ($videoSeason -eq '本編') { $videoSeason = '' }
	# シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($videoSeries -cmatch [RegEx]::Escape($videoSeason)) { $videoSeason = '' }
	# エピソード番号を極力修正
	if ((($videoEpisodeNum -eq 1) -or ($videoEpisodeNum % 10 -eq 0)) -and ($episodeName -imatch '([#|第|Episode|ep|Take|Vol|Part|Chapter|Flight|Karte|Case|Stage|Mystery|Ope|Story|Sign|Trap|Letter|Act]+\.?\s?)(\d+)(.*)')) { $videoEpisodeNum = $matches[2] }
	# エピソード番号が1桁の際は頭0埋めして2桁に
	$videoEpisodeNum = $videoEpisodeNum.PadLeft(2, '0')
	# 放送日を整形
	if ($broadcastDate -cmatch '([0-9]+)(月)([0-9]+)(日)(.+?)(放送|配信)') {
		$currentYear = (Get-Date).Year
		try {
			$parsedBroadcastDate = [DateTime]::ParseExact(('{0}{1}{2}' -f $currentYear, $matches[1].PadLeft(2, '0'), $matches[3].PadLeft(2, '0')), 'yyyyMMdd', $null)
			# 実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する(年末の番組を年初にダウンロードするケース)
			$broadcastYear = $parsedBroadcastDate -gt (Get-Date).AddDays(+1) ? $currentYear - 1 : $currentYear
			$broadcastDate = ('{0}年{1}{2}{3}{4}{5}' -f $broadcastYear, $matches[1].PadLeft(2, '0'), $matches[2], $matches[3].PadLeft(2, '0'), $matches[4], $matches[6])
		} catch {
			# 上記でエラーが出た場合は年が間違っているはず。年が不明なので年無しで整形する
			$broadcastDate = ('{0}{1}{2}{3}{4}' -f $matches[1].PadLeft(2, '0'), $matches[2], $matches[3].PadLeft(2, '0'), $matches[4], $matches[6])
		}
	}
	return [PSCustomObject]@{
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
		# mpdURL          = $mpdURL
		isStreaks       = $isStreaks
		isBrightcove    = $isBrightcove
	}
	Remove-Variable -Name episodeID, tverVideoInfoBaseURL, tverVideoInfoURL, response, videoSeries, videoSeriesID, videoSeriesPageURL, videoSeason, videoSeasonID, episodeName, videoEpisodeID, videoEpisodePageURL, mediaName, providerName, broadcastDate, endTime, versionNum, videoInfo, descriptionText, videoEpisodeNum, streaksRefID, streaksProjectID, ati, brightcoveJsURL, brightcovePk, brightcoveURL, accountID, videoRefID, playerID, httpHeader, response, m3u8URL, isStreaks, isBrightcove -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# Geo IP関連
#----------------------------------------------------------------------
function Get-JpIP {
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# 日本に割り当てられているIPアドレスレンジの取得
	$allCIDR = Import-Csv $script:jpIPList
	Do {
		# ランダムなIPアドレスの取得
		$randomCIDR = $allCIDR | Get-Random
		$startIPArray = [System.Net.IPAddress]::Parse($randomCIDR[0].start).GetAddressBytes()
		[Array]::Reverse($startIPArray) ; $startIPInt = [BitConverter]::ToUInt32($startIPArray, 0)
		$endIPArray = [System.Net.IPAddress]::Parse($randomCIDR[0].end).GetAddressBytes()
		[Array]::Reverse($endIPArray) ; $endIPInt = [BitConverter]::ToUInt32($endIPArray, 0)
		$randomIPInt = $startIPInt + [UInt32](Get-Random -Maximum ($endIPInt - $startIPInt - 1)) + 1	# CIDR範囲の先頭と末尾を除く
		$randomIPArray = [System.BitConverter]::GetBytes($randomIPInt)
		[Array]::Reverse($randomIPArray) ; $jpIP = [System.Net.IPAddress]::new($randomIPArray).ToString()
		try { $check = Invoke-RestMethod -Uri ('http://ip-api.com/json/{0}?fields=16785410' -f $jpIP) -TimeoutSec $script:timeoutSec }
		catch { $check.CountryCode = '' ; $check.hosting = $true }
	} While (($check.CountryCode -ne 'JP') -or ($check.hosting) )
	return $jpIP
	Remove-Variable -Name allCIDR, randomCIDR, startIPArray, startIPInt, endIPArray, endIPInt, randomIPInt, randomIPArray, check -ErrorAction SilentlyContinue
}
