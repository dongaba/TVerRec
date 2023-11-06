###################################################################################
#
#		TVer固有関数スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the MIT License;
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in
#	all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#	THE SOFTWARE.
#
###################################################################################
Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function getToken () {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$local:requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded'
	}
	$local:requestBody = 'device_type=pc'
	try {
		$local:tokenResponse = Invoke-RestMethod `
			-Uri $local:tverTokenURL `
			-Method 'POST' `
			-Headers $local:requestHeader `
			-Body $local:requestBody `
			-TimeoutSec $script:timeoutSec
		$script:platformUID = $local:tokenResponse.Result.platform_uid
		$script:platformToken = $local:tokenResponse.Result.platform_token
	} catch { Write-Warning ('❗ トークン取得エラー、終了します') ; exit 1 }
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function getVideoLinksFromKeyword {
	[OutputType([System.Object[]])]
	Param ([String]$local:keyword)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$script:episodeLinks = [System.Collections.Generic.List[String]]::new()
	$script:seriesLinks = [System.Collections.Generic.List[String]]::new()

	switch ($true) {
		($local:keyword.IndexOf('series/') -eq 0) {
			#番組IDによる番組検索から番組ページのLinkを取得
			$local:seriesID = trimComment($local:keyword).Replace('series/', '').Trim()
			goAnal -Operation 'search' -TVerType 'series' -TVerID $local:seriesID
			try { $script:episodeLinks = getLinkFromSeriesID ($local:seriesID) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:02') ; continue }
			break
		}
		($local:keyword.IndexOf('talents/') -eq 0) {
			#タレントIDによるタレント検索から番組ページのLinkを取得
			$local:talentID = trimComment($local:keyword).Replace('talents/', '').Trim()
			goAnal -Operation 'search' -TVerType 'talent' -TVerID $local:talentID
			try { $script:episodeLinks = getLinkFromTalentID ($local:talentID) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:03') ; continue }
			break
		}
		($local:keyword.IndexOf('tag/') -eq 0) {
			#ジャンルなどのTag情報から番組ページのLinkを取得
			$local:tagID = trimComment($local:keyword).Replace('tag/', '').Trim()
			goAnal -Operation 'search' -TVerType 'tag' -TVerID $local:tagID
			try { $script:episodeLinks = getLinkFromTag ($local:tagID) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:04') ; continue }
			break
		}
		($local:keyword.IndexOf('new/') -eq 0) {
			#新着番組から番組ページのLinkを取得
			$local:genre = trimComment($local:keyword).Replace('new/', '').Trim()
			goAnal -Operation 'search' -TVerType 'new' -TVerID $local:genre
			try { $script:episodeLinks = getLinkFromNew ($local:genre) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:05') ; continue }
			break
		}
		($local:keyword.IndexOf('ranking/') -eq 0) {
			#ランキングによる番組ページのLinkを取得
			$local:genre = trimComment($local:keyword).Replace('ranking/', '').Trim()
			goAnal -Operation 'search' -TVerType 'ranking' -TVerID $local:genre
			try { $script:episodeLinks = getLinkFromRanking ($local:genre) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:06') ; continue }
			break
		}
		($local:keyword.IndexOf('toppage') -eq 0) {
			#トップページから番組ページのLinkを取得
			goAnal -Operation 'search' -TVerType 'toppage'
			try { $script:episodeLinks = getLinkFromTopPage }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:07') ; continue }
			break
		}
		($local:keyword.IndexOf('title/') -eq 0) {
			#番組名による新着検索から番組ページのLinkを取得
			$local:titleName = trimComment($local:keyword).Replace('title/', '').Trim()
			goAnal -Operation 'search' -TVerType 'title' -TVerID $local:titleName
			Write-Warning ('❗ 番組名検索は廃止されました。スキップします Err:08') ; continue
			break
		}
		($local:keyword.IndexOf('sitemap') -eq 0) {
			#サイトマップから番組ページのLinkを取得
			goAnal -Operation 'search' -TVerType 'sitemap'
			try { $script:episodeLinks = getLinkFromSiteMap }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:09') ; continue }
			break
		}
		default {
			#タレント名や番組名などURL形式でない場合APIで検索結果から番組ページのLinkを取得
			goAnal -Operation 'search' -TVerType 'free' -TVerID $local:keyword
			try { $script:episodeLinks = getLinkFromFreeKeyword ($local:keyword) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:10') ; continue }
			break
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSeriesID {
	[OutputType([System.Object[]])]
	Param ([String]$local:seriesID)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:seasonLinks = [System.Collections.Generic.List[String]]::new()
	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/'

	#まずはSeries→Seasonに変換
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:seriesID.Replace('series/', '').Replace('https://tver.jp/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) { $local:seasonLinks.Add($local:searchResult.Content.Id) }

	#次にSeason→Episodeに変換
	foreach ( $local:seasonLink in $local:seasonLinks) { getLinkFromSeasonID ($local:seasonLink) }

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSeasonID {
	[OutputType([System.Object[]])]
	Param ([String]$local:SeasonID)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:SeasonID.Replace('season/', '').Replace('https://tver.jp/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID $local:searchResult.Content.Id
				break
			}
			'series' {
				Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:searchResults[$i].Content.Id)
				getLinkFromSeriesID $local:searchResult.Content.Id
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTalentID {
	[OutputType([System.Object[]])]
	Param ([String]$local:talentID)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callTalentEpisode/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:talentID.Replace('talents/', '').Replace('https://tver.jp/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID $local:searchResult.Content.Id
				break
			}
			'series' {
				Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID $local:searchResult.Content.Id
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#SpecialIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSpecialMainID {
	[OutputType([System.Object[]])]
	Param ([String]$local:specialMainID)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSpecialContents/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:specialMainID, $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.specialContents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
				Write-Output ('　Series {0} をバッファに保存中...' -f $local:searchResult.Content.Id)
				$script:seriesLinks.Add($local:searchResult.Content.Id)
				break
			}
			'special' {
				Write-Output ('　Special Detail {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSpecialDetailID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#SpecialDetailIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSpecialDetailID {
	[OutputType([System.Object[]])]
	Param ([String]$local:specialDetailID)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:specialDetailID, $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Content.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
				Write-Output ('　Series {0} をバッファに保存中...' -f $local:searchResult.Content.Id)
				$script:seriesLinks.Add($local:searchResult.Content.Id)
				break
			}
			'special' {
				#再度Specialが出てきた際は再帰呼び出し
				Write-Output ('　Special Detail {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSpecialDetailID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTag {
	[OutputType([System.Object[]])]
	Param ([String]$local:tagID)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callTagSearch'
	$local:callSearchURL = ('{0}/{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:tagID.Replace('tag/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromNew {
	[OutputType([System.Object[]])]
	Param ([String]$local:genre)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://service-api.tver.jp/api/v1/callNewerDetail'
	$local:callSearchURL = ('{0}/{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:genre.Replace('new/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromRanking {
	[OutputType([System.Object[]])]
	Param ([String]$local:genre)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://service-api.tver.jp/api/v1/callEpisodeRanking'
	if ($local:genre -eq 'all') {
		$local:callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $local:callSearchBaseURL, $script:platformUID, $script:platformToken)
	} else {
		$local:callSearchURL = ('{0}Detail/{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:genre.Replace('ranking/', '').Trim(), $script:platformUID, $script:platformToken )
	}
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id)
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTopPage {
	[OutputType([System.Object[]])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$local:callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $local:callSearchBaseURL, $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Components
	foreach ($local:searchResult in $local:searchResults) {
		if ($local:searchResult.Type -eq 'horizontal' `
				-or $local:searchResult.Type -eq 'ranking' `
				-or $local:searchResult.Type -eq 'talents' `
				-or $local:searchResult.Type -eq 'billboard' `
				-or $local:searchResult.Type -eq 'episodeRanking' `
				-or $local:searchResult.Type -eq 'newer' `
				-or $local:searchResult.Type -eq 'ender' `
				-or $local:searchResult.Type -eq 'talent' `
				-or $local:searchResult.Type -eq 'special') {
			#横スクロール型 or 総合ランキング or 注目タレント or 特集
			foreach ($local:searchResultContent in $local:searchResult.Contents) {
				switch ($local:searchResultContent.Type) {
					'live' { break }
					'episode' {
						$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResultContent.Content.Id)
						break
					}
					'season' {
						Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromSeasonID ($local:searchResultContent.Content.Id)
						break
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Output ('　Series {0} をバッファに保存中...' -f $local:searchResultContent.Content.Id)
						$script:seriesLinks.Add($local:searchResultContent.Content.Id)
						break
					}
					'talent' {
						Write-Output ('　Talent {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromTalentID ($local:searchResultContent.Content.Id)
						break
					}
					'specialMain' {
						Write-Output ('　Special Main {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromSpecialMainID ($local:searchResultContent.Content.Id)
						break
					}
					'special' {
						Write-Output ('　Special Detail {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromSpecialDetailID ($local:searchResultContent.Content.Id)
						break
					}
					default {
						#他にはないと思われるが念のため
						$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResultContent.Type, $local:searchResultContent.Content.Id)
						break
					}
				}
			}
		} elseif ($local:searchResult.Type -eq 'topics') {
			foreach ($local:searchResultContent in $local:searchResult.Contents) {
				switch ($local:searchResultContent.Content.Content.Type) {
					'live' { break }
					'episode' {
						$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResultContent.Content.Content.Content.Id)
						break
					}
					'season' {
						Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Content.Content.Id)
						getLinkFromSeasonID ($local:searchResultContent.Content.Content.Content.Id)
						break
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Output ('　Series {0} をバッファに保存中...' -f $local:searchResultContent.Content.Content.Content.Id)
						$script:seriesLinks.Add(($local:searchResultContent.Content.Content.Content.Id))
						break
					}
					'talent' {
						Write-Output ('　Talent {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Content.Content.Id)
						getLinkFromTalentID ($local:searchResultContent.Content.Content.Content.Id)
						break
					}
					default {
						#他にはないと思われるが念のため
						$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResultContent.Content.Content.Type, $local:searchResultContent.Content.Content.Content.Id)
						break
					}
				}
			}
		} elseif ($local:searchResult.Type -eq 'banner') { #広告	URLは $local:searchResult.Contents.Content.targetURL
		} elseif ($local:searchResult.Type -eq 'resume') { #続きを見る	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} else {}

	}

	#バッファしておいたSeriesの重複を削除しEpisodeを抽出
	$script:seriesLinks = $script:seriesLinks | Sort-Object | Get-Unique
	foreach ($local:seriesID in $script:seriesLinks) {
		Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:seriesID)
		getLinkFromSeriesID ($local:seriesID)
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSiteMap {
	[OutputType([System.Object[]])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:callSearchURL = 'https://tver.jp/sitemap.xml'
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.urlset.url.loc | Sort-Object | Get-Unique

	foreach ($local:searchResult in $local:searchResults) {
		if ($local:searchResult -cmatch '\/episodes\/') { $script:episodeLinks.Add($local:searchResult) }
		elseif ($script:sitemapParseEpisodeOnly -eq $true) { Write-Debug ('Episodeではないためスキップします') }
		else {
			switch ($true) {
				($local:searchResult -cmatch '\/seasons\/') {
					Write-Output ('　{0} からEpisodeを抽出中...' -f $local:searchResult)
					try { getLinkFromSeasonID ($local:searchResult) }
					catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:11') ; continue }
					break
				}
				($local:searchResult -cmatch '\/series\/') {
					Write-Output ('　{0} からEpisodeを抽出中...' -f $local:searchResult)
					try { getLinkFromSeriesID ($local:searchResult) }
					catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:12') ; continue }
					break
				}
				($local:searchResult -eq 'https://tver.jp/') { break }	#トップページ	別のキーワードがあるためため対応予定なし
				($local:searchResult -cmatch '\/info\/') { break }	#お知らせ	番組ページではないため対応予定なし
				($local:searchResult -cmatch '\/live\/') { break }	#追っかけ再生	対応していない
				($local:searchResult -cmatch '\/mypage\/') { break }	#マイページ	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
				($local:searchResult -cmatch '\/program') { break }	#番組表	番組ページではないため対応予定なし
				($local:searchResult -cmatch '\/ranking') { break }	#ランキング	他でカバーできるため対応予定なし
				($local:searchResult -cmatch '\/specials') { break }	#特集	他でカバーできるため対応予定なし
				($local:searchResult -cmatch '\/topics') { break }	#トピック	番組ページではないため対応予定なし
				default { Write-Warning ('❗ 未知のパターンです。 - {0}' -f $local:searchResult) ; break }
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function getLinkFromFreeKeyword {
	[OutputType([System.Object[]])]
	Param ([String]$local:keyword)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.Name)

	$local:tverSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'
	$local:tverSearchURL = ('{0}?platform_uid={1}&platform_token={2}&keyword={3}' -f $local:tverSearchBaseURL, $script:platformUID, $script:platformToken, $local:keyword )
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:tverSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents

	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.Type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Output ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Output ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.Type, $local:searchResult.Content.Id )
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

