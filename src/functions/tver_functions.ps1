###################################################################################
#
#		TVer固有関数スクリプト
#
###################################################################################
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

$script:requestHeader = @{
	'x-tver-platform-type' = 'web'
	'Origin'               = 'https://tver.jp'
	'Referer'              = 'https://tver.jp'
}

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function Get-Token () {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded'
	}
	$requestBody = 'device_type=pc'
	try {
		$tokenResponse = Invoke-RestMethod `
			-Uri $tverTokenURL `
			-Method 'POST' `
			-Headers $requestHeader `
			-Body $requestBody `
			-TimeoutSec $script:timeoutSec
		$script:platformUID = $tokenResponse.Result.platform_uid
		$script:platformToken = $tokenResponse.Result.platform_token
	} catch { Write-Error ('❌️ トークン取得エラー、終了します') ; exit 1 }

	Remove-Variable -Name tverTokenURL, requestHeader, requestBody, tokenResponse -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function Get-VideoLinksFromKeyword {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$keyword)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$episodeLinks = @()
	$key = $keyword.split(' ')[0].split("`t")[0].Split('/')[0]
	$tverID = Remove-Comment(($keyword.Replace("$key/", '')).Trim())
	Invoke-StatisticsCheck -Operation 'search' -TVerType $key -TVerID $tverID
	switch ($key) {
		'series' { $episodeLinks = @(Get-LinkFromSeriesID $tverID) ; continue }
		'talents' { $episodeLinks = @(Get-LinkFromTalentID $tverID) ; continue }
		'tag' { $episodeLinks = @(Get-LinkFromTag $tverID) ; continue }
		'new' { $episodeLinks = @(Get-LinkFromNew $tverID) ; continue }
		'ranking' { $episodeLinks = @(Get-LinkFromRanking $tverID) ; continue }
		'toppage' { $episodeLinks = @(Get-LinkFromTopPage) ; continue }
		'sitemap' { $episodeLinks = @(Get-LinkFromSiteMap) ; continue }
		default { $episodeLinks = @(Get-LinkFromFreeKeyword $keyword) }
	}

	return $episodeLinks | Sort-Object -Unique

	Remove-Variable -Name keyword, episodeLinks, key, tverID -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function ProcessSearchResults {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$epLinks = @()

	#URLの整形
	if ($type -eq 'keyword') { $callSearchURL = ('{0}?platform_uid={1}&platform_token={2}&keyword={3}' -f $baseURL, $script:platformUID, $script:platformToken, $keyword) }
	else { $callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $script:platformUID, $script:platformToken) }

	#取得した値をタイプごとに調整
	$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	if ($type -in @('new', 'ranking')) { $searchResults = $searchResultsRaw.Result.Contents.Contents }
	elseif ($type -eq 'specialmain') { $searchResults = $searchResultsRaw.Result.specialContents }
	elseif ($type -eq 'specialdetail') { $searchResults = $searchResultsRaw.Result.Contents.Content.Contents }
	else { $searchResults = $searchResultsRaw.Result.Contents }

	#タイプ別に再帰呼び出し
	foreach ($searchResult in $searchResults) {
		switch ($searchResult.Type) {
			'live' { continue }
			'episode' {
				$epLinks += ('https://tver.jp/episodes/{0}' -f $searchResult.Content.Id)
				continue
			}
			'series' {
				Write-Verbose ('　Series {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
				$epLinks += Get-LinkFromSeriesID $searchResult.Content.Id
				continue
			}
			'season' {
				Write-Verbose ('　Season {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
				$epLinks += Get-LinkFromSeasonID $searchResult.Content.Id
				continue
			}
			'special' {
				Write-Verbose ('　Special Detail {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
				$epLinks += Get-LinkFromSpecialDetailID $searchResult.Content.Id
				continue
			}
			default { $epLinks += ('https://tver.jp/{0}/{1}' -f $searchResult.Type, $searchResult.Content.Id) }
		}
	}

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name baseURL, type, keyword, epLinks, callSearchURL, searchResultsRaw, searchResults, searchResult -ErrorAction SilentlyContinue

}

#----------------------------------------------------------------------
#各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function ProcessSearchResultsForTopPage {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$epLinks = @()

	#URLの整形
	if ($type -eq 'keyword') { $callSearchURL = ('{0}?platform_uid={1}&platform_token={2}&keyword={3}' -f $baseURL, $script:platformUID, $script:platformToken, $keyword) }
	else { $callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $script:platformUID, $script:platformToken) }

	try {
		#取得した値をタイプごとに調整
		$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
		if ($type -in @('new', 'ranking')) { $searchResults = $searchResultsRaw.Result.Contents.Contents }
		elseif ($type -eq 'specialmain') { $searchResults = $searchResultsRaw.Result.specialContents }
		elseif ($type -eq 'specialdetail') { $searchResults = $searchResultsRaw.Result.Contents.Content.Contents }
		else { $searchResults = $searchResultsRaw.Result.Contents }

		#タイプ別に再帰呼び出し
		foreach ($searchResult in $searchResults) {
			switch ($searchResult.Type) {
				'live' { continue }
				'episode' {
					$epLinks += ('https://tver.jp/episodes/{0}' -f $searchResult.Content.Id)
					continue
				}
				'series' {
					Write-Verbose ('　Series {0} をバッファに保存中...' -f $searchResult.Content.Id)
					$seriesLinks += ($searchResult.Content.Id)
					continue
				}
				'season' {
					Write-Verbose ('　Season {0} をバッファに保存中...' -f $searchResult.Content.Id)
					$seasonLinks += ($searchResult.Content.Id)
					continue
				}
				'special' {
					Write-Verbose ('　Special Detail {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
					$epLinks += Get-LinkFromSpecialDetailIDForTopPage $searchResult.Content.Id
					continue
				}
				default { $epLinks += ('https://tver.jp/{0}/{1}' -f $searchResult.Type, $searchResult.Content.Id) }
			}
		}
	} catch { Write-Error ('❌️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) }

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name baseURL, type, keyword, epLinks, callSearchURL, searchResultsRaw, searchResults, searchResult, seriesLinks, seasonLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSeriesID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seriesID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}' -f $seriesID))

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name seriesID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSeasonID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seasonID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $seasonID))

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name seasonID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得(TopPage用)
#----------------------------------------------------------------------
function Get-LinkFromSeasonIDForTopPage {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seasonID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResultsForTopPage -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $seasonID))

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name seasonID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTalentID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$talentID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $talentID))

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name talentID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得(TopPage用)
#----------------------------------------------------------------------
function Get-LinkFromTalentIDForTopPage {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$talentID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResultsForTopPage -baseURL ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $talentID))

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name talentID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SpecialIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSpecialMainID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialMainID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $specialMainID) -Type 'specialmain')

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name specialMainID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SpecialIDによる特集ページのLinkを取得(TopPage用)
#----------------------------------------------------------------------
function Get-LinkFromSpecialMainIDForTopPage {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialMainID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResultsForTopPage -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $specialMainID) -Type 'specialmain')

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name specialMainID, epLinks -ErrorAction SilentlyContinue
}


#----------------------------------------------------------------------
#SpecialDetailIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSpecialDetailID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialDetailID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $specialDetailID) -Type 'specialdetail')

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name specialDetailID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#SpecialDetailIDによる特集ページのLinkを取得(TopPage用)
#----------------------------------------------------------------------
function Get-LinkFromSpecialDetailIDForTopPage {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialDetailID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResultsForTopPage -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $specialDetailID) -Type 'specialdetail')

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name specialDetailID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTag {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$tagID)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callTagSearch/{0}' -f $tagID))

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name tagID, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromNew {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$genre)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callNewerDetail/{0}' -f $genre) -Type 'new')

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name genre, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromRanking {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$genre)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($genre -eq 'all') { $epLinks = @(ProcessSearchResults -baseURL 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' -Type 'ranking') }
	else { $epLinks = @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/{0}' -f $genre) -Type 'ranking') }

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name genre, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function Get-LinkFromFreeKeyword {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$keyword)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$epLinks = @(ProcessSearchResults -baseURL 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch' -Type 'keyword' -Keyword $keyword)

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name keyword, epLinks -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTopPage {
	[OutputType([System.Collections.ArrayList[]])]
	Param ()

	Write-Debug ('Dev - {0}' -f $MyInvocation.MyCommand.Name)

	$epLinks = @()
	$seriesLinks = @()
	$seasonLinks = @()
	$talentLinks = @()
	$specialMainLinks = @()
	$specialDetailLinks = @()

	$callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $callSearchBaseURL, $script:platformUID, $script:platformToken)
	$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$searchResults = $searchResultsRaw.Result.Components

	foreach ($searchResult in $searchResults) {
		if ($searchResult.Type -in @('horizontal', 'ranking', 'talents', 'billboard', 'episodeRanking', 'newer', 'ender', 'talent', 'special', 'specialContent') ) {
			#横スクロール型 or 総合ランキング or 注目タレント or 特集
			foreach ($searchResultContent in $searchResult.Contents) {
				switch ($searchResultContent.Type) {
					'live' { continue }
					'episode' {
						$epLinks += ('https://tver.jp/episodes/{0}' -f $searchResultContent.Content.Id)
						continue
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Verbose ('　Series {0} をバッファに保存中...' -f $searchResultContent.Content.Id)
						$seriesLinks += ($searchResultContent.Content.Id)
						continue
					}
					'season' {
						Write-Verbose ('　Season をバッファに保存中...' -f $searchResultContent.Content.Id)
						$seasonLinks += ($searchResultContent.Content.Id)
						continue
					}
					'talent' {
						Write-Verbose ('　Talent をバッファに保存中...' -f $searchResultContent.Content.Id)
						$talentLinks += ($searchResultContent.Content.Id)
						continue
					}
					'specialMain' {
						Write-Verbose ('　Special Main {0} をバッファに保存中...' -f $searchResultContent.Content.Id)
						$specialMainLinks += ($searchResultContent.Content.Id)
						continue
					}
					'special' {
						Write-Verbose ('　Special Detail {0} をバッファに保存中...' -f $searchResultContent.Content.Id)
						$specialDetailLinks += ($searchResultContent.Content.Id)
						continue
					}
					default { $epLinks += ('https://tver.jp/{0}/{1}' -f $searchResultContent.Type, $searchResultContent.Content.Id) }
				}
			}

		} elseif ($searchResult.Type -eq 'topics') {
			foreach ($searchResultContent in $searchResult.Contents) {
				switch ($searchResultContent.Content.Content.Type) {
					'live' { continue }
					'episode' {
						$epLinks += ('https://tver.jp/episodes/{0}' -f $searchResultContent.Content.Content.Content.Id)
						continue
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Verbose ('　Series {0} をバッファに保存中...' -f $searchResultContent.Content.Content.Content.Id)
						$seriesLinks += ($searchResultContent.Content.Content.Content.Id)
						continue
					}
					'season' {
						Write-Verbose ('　Season {0} をバッファに保存中...' -f $searchResultContent.Content.Content.Content.Id)
						$seasonLinks += ($searchResultContent.Content.Content.Content.Id)
						continue
					}
					'talent' {
						Write-Verbose ('　Talent {0} をバッファに保存中...' -f $searchResultContent.Content.Content.Content.Id)
						$talentLinks += ($searchResultContent.Content.Content.Content.Id)
						continue
					}
					default { $epLinks += ('https://tver.jp/{0}/{1}' -f $searchResultContent.Content.Content.Type, $searchResultContent.Content.Content.Content.Id) }
				}
			}
		} elseif ($searchResult.Type -eq 'banner') { #広告	URLは $searchResult.Contents.Content.targetURL
		} elseif ($searchResult.Type -eq 'resume') { #続きを見る	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} elseif ($searchResult.Type -eq 'favorite') { #お気に入り	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} else { Write-Warning ('⚠️ 未知のパターンです。 - {0}' -f $searchResult.Type) }
	}

	#バッファしておいたSpecialMainの重複を削除しEpisodeを抽出
	$specialMainLinks = $specialMainLinks | Sort-Object -Unique
	foreach ($specialMainID in $specialMainLinks) {
		Write-Verbose ('Special Main {0} からEpisodeを抽出中...' -f $specialMainID)
		$epLinks += Get-LinkFromSpecialMainIDForTopPage ($specialMainID)
	}

	#バッファしておいたSpecialDetailの重複を削除しEpisodeを抽出
	$specialDetailLinks = $specialDetailLinks | Sort-Object -Unique
	foreach ($specialDetailID in $specialDetailLinks) {
		Write-Verbose ('Special Detail {0} からEpisodeを抽出中...' -f $specialDetailID)
		$epLinks += Get-LinkFromSpecialDetailIDForTopPage ($specialDetailID)
	}

	#バッファしておいたTalentの重複を削除しEpisodeを抽出
	$talentLinks = $talentLinks | Sort-Object -Unique
	foreach ($talentID in $talentLinks) {
		Write-Verbose ('Talent {0} からEpisodeを抽出中...' -f $talentID)
		$epLinks += Get-LinkFromTalentIDForTopPage ($talentID)
	}

	#バッファしておいたSeasonの重複を削除しEpisodeを抽出
	$seasonLinks = $seasonLinks | Sort-Object -Unique
	foreach ($seasonID in $seasonLinks) {
		Write-Verbose ('Season {0} からEpisodeを抽出中...' -f $seasonID)
		$epLinks += Get-LinkFromSpecialDetailIDForTopPage ($seasonID)
	}

	#バッファしておいたSeriesの重複を削除しEpisodeを抽出
	$seriesLinks = $seriesLinks | Sort-Object -Unique
	foreach ($seriesID in $seriesLinks) {
		Write-Verbose ('　Series {0} からEpisodeを抽出中...' -f $seriesID)
		$epLinks += Get-LinkFromSeriesID ($seriesID)
	}

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name epLinks, seriesLinks, seasonLinks, talentLinks, specialMainLinks, specialDetailLinks, callSearchBaseURL, callSearchURL, searchResultsRaw, searchResults, searchResult -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
#サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSiteMap {
	[OutputType([System.Object[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$epLinks = @()

	$callSearchURL = 'https://tver.jp/sitemap.xml'
	$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$searchResults = $searchResultsRaw.urlset.url.loc | Sort-Object -Unique

	foreach ($searchResult in $searchResults) {
		if ($searchResult -cmatch '\/episodes\/') { $epLinks += ($searchResult) }
	}

	if (!$script:sitemapParseEpisodeOnly) {
		if ($script:enableMultithread) {
			Write-Debug ('Multithread Processing Enabled')
			#並列化が有効の場合は並列化
			if (Test-Path $script:sitemaptFilePath) { $null = Clear-Content $script:sitemaptFilePath }
			else { $null = New-Item $script:sitemaptFilePath }
			$searchResults | ForEach-Object -Parallel {
				if ($_ -cmatch '\/series\/') {
					$links = @()
					try {
						$seriesID = $_.Replace('https://tver.jp/series/', '')
						Write-Verbose ('　Series {0} からEpisodeを抽出中...' -f $seriesID)
						$callSearchURL = ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}?platform_uid={1}&platform_token={2}' -f $seriesID, $using:script:platformUID, $using:script:platformToken)
						$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $using:script:requestHeader -TimeoutSec $using:script:timeoutSec
						$searchResults = $searchResultsRaw.Result.Contents
						if ($searchResults) {
							foreach ($searchResult in $searchResults) {
								$seasonID = $searchResult.Content.Id
								Write-Verbose ('　Season {0} からEpisodeを抽出中...' -f $seasonID)
								$searchURL = ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}?platform_uid={1}&platform_token={2}' -f $seasonID, $using:script:platformUID, $using:script:platformToken)
								$resultsRaw = Invoke-RestMethod -Uri $searchURL -Method 'GET' -Headers $using:script:requestHeader -TimeoutSec $using:script:timeoutSec
								$results = $resultsRaw.Result.Contents.Content.Id
								foreach ($result in $results) {
									if ($result -cmatch '^ep') { $links += ('https://tver.jp/episodes/{0}' -f $result) }
								}
							}
						}
					} catch { Write-Warning ('⚠️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) }
					$links | Out-File -Encoding UTF8 -Append -FilePath $using:script:sitemaptFilePath
				}
			} -ThrottleLimit $script:multithreadNum
			$epLinks += @(Get-Content -Path $script:sitemaptFilePath -Encoding UTF8)
			$null = Remove-Item $script:sitemaptFilePath
		} else {
			#並列化が無効の場合は従来型処理
			foreach ($searchResult in $searchResults) {
				if ($searchResult -cmatch '\/series\/') {
					Write-Verbose ('　{0} からEpisodeを抽出中...' -f $searchResult)
					try { $epLinks += @(Get-LinkFromSeriesID $searchResult.Replace('https://tver.jp/series/', '')) }
					catch { Write-Warning ('⚠️ エラーが発生しました。スキップして次のリンクを処理します。 - {0}' -f $_.Exception.Message) }
				}
			}
		}
	}

	return $epLinks | Sort-Object -Unique

	Remove-Variable -Name epLinks, callSearchURL, searchResultsRaw, searchResults, searchResult, seriesID, seasonID, resultsRaw, results, result, links -ErrorAction SilentlyContinue
}
