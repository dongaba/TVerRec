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
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$keyword)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$linkCollection = [PSCustomObject]@{
		episodeLinks     = [System.Collections.Generic.List[string]]::new()
		seriesLinks      = [System.Collections.Generic.List[string]]::new()
		seasonLinks      = [System.Collections.Generic.List[string]]::new()
		talentLinks      = [System.Collections.Generic.List[string]]::new()
		specialMainLinks = [System.Collections.Generic.List[string]]::new()
		specialLinks     = [System.Collections.Generic.List[string]]::new()
	}
	$key = $keyword.split(' ')[0].split("`t")[0].Split('/')[0]
	$tverID = Remove-Comment(($keyword.Replace("$key/", '')).Trim())
	if ($key -eq $tverID) { $key = 'episodes' }
	if (($tverID -eq 'sitemap') -or ($tverID -eq 'toppage')) { $key = $tverID }
	Invoke-StatisticsCheck -Operation 'search' -TVerType $key -TVerID $tverID
	switch ($key) {
		'series' { $linkCollection.seriesLinks.Add($tverID) ; continue }
		'talents' { $linkCollection.talentLinks.Add($tverID) ; continue }
		'tag' { $result = Get-LinkFromTag $tverID ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
		'new' { $result = Get-LinkFromNew $tverID ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
		'ranking' { $result = Get-LinkFromRanking $tverID ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
		'toppage' { $result = Get-LinkFromTopPage ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
		'sitemap' { $result = Get-LinkFromSiteMap ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
		'mypage' { $result = Get-LinkFromMyPage $tverID ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
		'episodes' { $linkCollection.episodeLinks.Add(('https://tver.jp/{0}/{1}' -f $key, $tverID)) ; continue }
		default { $result = Get-LinkFromFreeKeyword $keyword ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result }
	}
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
		[Parameter(Mandatory = $false)][String]$requireData
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
	$uid = $script:platformUID
	$token = $script:platformToken
	if ($sid) {
		# TVerIDにログインして使う場合
		$callSearchURL = '{0}?member_sid={1}' -f $baseURL, $sid
	} else {
		# TVerIDを匿名で使う場合
		if ($requireData -and $script:myPlatformUID -ne '' -and $script:myPlatformToken -ne '') {
			$uid = $script:myPlatformUID
			$token = $script:myPlatformToken
		}
		$callSearchURL = '{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $uid, $token
	}
	switch ($type) {
		'keyword' { if ($keyword) { $callSearchURL += "&keyword=$keyword" } }
		'mypage' { if ($requireData) { $callSearchURL += "&require_data=$requireData" } }
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
					else { $episodeLinks = & { $episodeLinks ; (Get-LinkFromSpecialDetailID $searchResult.Content.Id) } }
					continue
				}
				'specialMain' { $specialMainLinks.Add($searchResult.Content.Id) ; continue }
				default { $episodeLinks = & { $episodeLinks ; ('https://tver.jp/{0}/{1}' -f $searchResult.Type, $searchResult.Content.Id) } }
			}
		}
	} catch {
		if ($_.Exception.Message.Contains('The request was canceled due to the configured HttpClient.Timeout of')) {
			Write-Warning ('⚠️ HTTP接続がタイムアウトしました。スキップして次のリンクを処理します。')
			Write-Warning ('　　{0}, {1}, {2}' -f $type, $keyword, $requireData)
		} elseif ($_.Exception.Message.Contains('Response status code does not indicate success:')) {
			Write-Warning ('⚠️ HTTP接続が失敗しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message.Replace('Response status code does not indicate success:', ''))
			Write-Warning ('　　{0}, {1}, {2}' -f $type, $keyword, $requireData)
		} else {
			Write-Warning ('⚠️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message)
			Write-Warning ('　　{0}, {1}, {2}' -f $type, $keyword, $requireData)
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
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSeriesID {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seriesID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}' -f $seriesID)
	return $tverIDs
	Remove-Variable -Name seriesID, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSeasonID {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seasonID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $seasonID)
	return $tverIDs
	Remove-Variable -Name seasonID, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTalentID {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$talentID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $talentID)
	return $tverIDs
	Remove-Variable -Name talentID, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SpecialMainIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSpecialMainID {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialMainID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $specialMainID) -Type 'specialmain'
	return $tverIDs
	Remove-Variable -Name specialMainID, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SpecialDetailIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSpecialDetailID {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialDetailID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $specialDetailID) -Type 'specialdetail'
	return $tverIDs
	Remove-Variable -Name specialDetailID, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTag {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$tagID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callTagSearch/{0}' -f $tagID))
	return $tverIDs
	Remove-Variable -Name tagID, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromNew {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$genre)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callNewerDetail/{0}' -f $genre) -Type 'new')
	return $tverIDs
	Remove-Variable -Name genre, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromRanking {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$genre)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($genre -eq 'all') { $tverIDs = ProcessSearchResults -baseURL 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' -Type 'ranking' }
	else { $tverIDs = ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/{0}' -f $genre) -Type 'ranking' }
	return $tverIDs
	Remove-Variable -Name genre, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function Get-LinkFromFreeKeyword {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$keyword)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverIDs = ProcessSearchResults -baseURL 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch' -Type 'keyword' -Keyword $keyword
	return $tverIDs
	Remove-Variable -Name keyword, tverIDs -ErrorAction SilentlyContinue
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
						default { Write-Warning ('⚠️ 未知のパターンです。 - {0}/{1}' -f $content.Type, $content.Content.Id) }
					}
				}
				continue
			}
			{ $_ -in @('banner', 'resume', 'favorite') ; continue } {}
			default { Write-Warning "⚠️ 未知のパターンです。 - $($component.Type)" }
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
			$url = $url.Replace('https://tver.jp/', '')
			$url = $url -split '/'
			$tverID = @{ type = $url[0] ; id = $url[1] }
		} catch { $tverID = @{ type = $null ; id = $null } }
		if ($tverID.id) {
			switch ( $tverID.type) {
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
						$result = Get-LinkFromRanking($tverID.id)
						$linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result
					}
					continue
				}
				'specials' {
					if (!$script:sitemapParseEpisodeOnly) {
						Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverID.type, $tverID.id)
						$result = Get-LinkFromSpecialMainID($tverID.id)
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
	$baseURLPrefix = if ($script:myMemberSID) { 'https://member-api.tver.jp' } else { 'https://platform-api.tver.jp' }
	switch ($page) {
		'fav' { $baseURL = ('{0}/service/api/v2/callMylistDetail/{1}' -f $baseURLPrefix, (ConvertTo-UnixTime (Get-Date))) ; $requireData = 'mylist' ; continue }
		'later' { $baseURL = ('{0}/service/api/v2/callMyLater' -f $baseURLPrefix) ; $requireData = 'later' ; continue }
		'resume' { $baseURL = ('{0}/service/api/v2/callMyResume' -f $baseURLPrefix) ; $requireData = 'resume' ; continue }
		'favorite' { $baseURL = ('{0}/service/api/v2/callMyFavorite' -f $baseURLPrefix) ; $requireData = 'mylist' ; continue }
		default { Write-Warning "⚠️ 未知のパターンです。 - mypage/$page" }
	}
	$tverIDs = ProcessSearchResults -baseURL $baseURL -Type 'mypage' -RequireData $requireData
	return $tverIDs
	Remove-Variable -Name page, baseURL, requireData, tverIDs -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVerIDの整理
#----------------------------------------------------------------------
function Update-LinkCollection {
	param (
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
	Remove-Variable -Name linkCollection, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#エピソード以外のリンクをためたバッファを順次API呼び出し
#----------------------------------------------------------------------
function Convert-Buffer {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
	param(
		[Parameter(Mandatory = $false)][Object[]]$tverIDs,
		[Parameter(Mandatory = $true)][ValidateSet('Special Main', 'Special Detail', 'Talent', 'Season', 'Series')][string]$tverIDType,
		[Parameter(Mandatory = $true)][OutputType([PSCustomObject])]$linkCollection
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($tverIDs) {
		foreach ($tverID in ($tverIDs | Sort-Object -Unique)) {
			Write-Information ('{0} - {1} {2} からEpisodeを抽出中...' -f (Get-Date), $tverIDType, $tverID)
			switch ($tverIDType) {
				'Special Main' { $result = Get-LinkFromSpecialMainID($tverID) ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
				'Special Detail' { $result = Get-LinkFromSpecialDetailID($tverID) ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
				'Talent' { $result = Get-LinkFromTalentID($tverID) ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
				'Series' { $result = Get-LinkFromSeriesID($tverID) ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
				'Season' { $result = Get-LinkFromSeasonID($tverID) ; $linkCollection = Update-LinkCollection -linkCollection $linkCollection -result $result ; continue }
			}
		}
		if ($linkCollection.episodeLinks) { $linkCollection.episodeLinks = $linkCollection.episodeLinks | Sort-Object -Unique }
		if ($linkCollection.seasonLinks) { $linkCollection.seasonLinks = $linkCollection.seasonLinks | Sort-Object -Unique }
		if ($linkCollection.seriesLinks) { $linkCollection.seriesLinks = $linkCollection.seriesLinks | Sort-Object -Unique }
		if ($linkCollection.specialLinks) { $linkCollection.specialLinks = $linkCollection.specialLinks | Sort-Object -Unique }
	}
	return $linkCollection
	Remove-Variable -Name tverIDs, tverIDType, linkCollection, tverID, result -ErrorAction SilentlyContinue
}
