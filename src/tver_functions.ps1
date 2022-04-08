###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		TVer固有関数スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
#
###################################################################################

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function getToken () {
	$local:tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$local:requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded' ;
	}
	$local:requestBody = 'device_type=pc'
	$local:tokenResponse = Invoke-RestMethod `
		-Uri $local:tverTokenURL `
		-Method 'POST' `
		-Headers $local:requestHeader `
		-Body $local:requestBody
	$script:platformUID = $local:tokenResponse.Result.platform_uid
	$script:platformToken = $local:tokenResponse.Result.platform_token
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索からビデオページのLinkを取得
#----------------------------------------------------------------------
function getVideoLinkFromTalentID ($local:talentID) {
	$local:callTalentEpisodeBaseURL = 'https://platform-api.tver.jp/service/api/v1/callTalentEpisode/'
	$local:callTalentEpisodeURL = $local:callTalentEpisodeBaseURL + `
		$local:talentID + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:callTalentEpisodeURL `
			-Method 'GET' `
			-Headers $script:requestHeader)
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		if ($local:searchResults[$i].type -eq 'episode') {
			$script:videoLinks += '/episodes/' + $local:searchResults[$i].Content.Id
		} else {}		#通常はepisode以外返ってこないはずなので無視
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索からビデオページのLinkを取得
#----------------------------------------------------------------------
function getVideoLinkFromSeasonID ($local:SeasonID) {
	$local:callSeasonEpisodeBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/'
	$local:callSeasonEpisodeURL = $local:callSeasonEpisodeBaseURL + `
		$local:SeasonID + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:callSeasonEpisodeURL `
			-Method 'GET' `
			-Headers $script:requestHeader)
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		if ($local:searchResults[$i].type -eq 'episode') {
			$script:videoLinks += '/episodes/' + $local:searchResults[$i].Content.Id
		} else {}		#通常はepisode以外返ってこないはずなので無視
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#SeriesIDによる番組検索からビデオページのLinkを取得
#----------------------------------------------------------------------
function getVideoLinkFromSeriesID ($local:seriesID) {
	$local:seasonLinks = @()
	$local:callSeriesSeasonBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/'
	#まずはSeries→Seasonに変換
	$local:callSeriesSeasonURL = $local:callSeriesSeasonBaseURL + `
		$local:seriesID + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:callSeriesSeasonURL `
			-Method 'GET' `
			-Headers $script:requestHeader)
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		$local:seasonLinks += $local:searchResults[$i].Content.Id
	}
	#次にSeason→Episodeに変換
	foreach ( $local:seasonLink in $local:seasonLinks) {
		$script:videoLinks += getVideoLinkFromSeasonID ($local:seasonLink)
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#ジャンルIDなどによる新着検索からビデオページのLinkを取得
#----------------------------------------------------------------------
function getVideoLinkFromGenreID ($local:tagID) {
	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSearch'
	$local:callSearchURL = $local:callSearchBaseURL + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:callSearchURL `
			-Method 'GET' `
			-Headers $script:requestHeader)
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		if ($local:searchResults[$i].Tags.Id.Contains($local:tagID) -eq $true) {
			#指定したジャンルと一致する場合
			if ($local:searchResults[$i].type -eq 'episode') {
				$script:videoLinks += '/episodes/' + $local:searchResults[$i].Content.Id
			} elseif ($local:searchResults[$i].type -eq 'season') {
				$script:videoLinks += getVideoLinkFromSeasonID ($local:seasonLink)
			} elseif ($local:searchResults[$i].type -eq 'series') {
				$script:videoLinks += getVideoLinkFromSeriesID ($local:seasonLink)
			} else {
				#他にはないと思われるが念のため
				$script:videoLinks += '/' + $local:searchResults[$i].type + '/' + $local:searchResults[$i].Content.Id
			}
		}
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#番組名による新着検索からビデオページのLinkを取得
#----------------------------------------------------------------------
function getVideoLinkFromTitle ($local:titleName) {
	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSearch'
	$local:callSearchURL = $local:callSearchBaseURL + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
		
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:callSearchURL `
			-Method 'GET' `
			-Headers $script:requestHeader)
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		if ($(getFileNameWithoutInvalidChars (
					getSpecialCharacterReplaced (
						getNarrowChars ($local:searchResults[$i].Content.SeriesTitle)
					))).Trim().Replace('  ', ' ').Contains($local:titleName) -eq $true) {
			#指定したジャンルと一致する場合
			if ($local:searchResults[$i].type -eq 'episode') {
				$script:videoLinks += '/episodes/' + $local:searchResults[$i].Content.Id
			} elseif ($local:searchResults[$i].type -eq 'season') {
				$script:videoLinks += getVideoLinkFromSeasonID ($local:seasonLink)
			} elseif ($local:searchResults[$i].type -eq 'series') {
				$script:videoLinks += getVideoLinkFromSeriesID ($local:seasonLink)
			} else {
				#他にはないと思われるが念のため
				$script:videoLinks += '/' + $local:searchResults[$i].type + '/' + $local:searchResults[$i].Content.Id
			}
		}
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function getVideoLinkFromFreeKeyword ($local:keywordName) {
	$local:tverSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/'
	$local:tverSearchURL = $local:tverSearchBaseURL + `
		'callSearch?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken + `
		'&keyword=' + $local:keywordName
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:tverSearchURL `
			-Method 'GET' `
			-Headers $script:requestHeader)
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		if ($local:searchResults[$i].type -eq 'episode') {
			$script:videoLinks += '/episodes/' + $local:searchResults[$i].Content.Id
		} elseif ($local:searchResults[$i].type -eq 'season') {
			$script:videoLinks += getVideoLinkFromSeasonID ($local:seasonLink)
		} elseif ($local:searchResults[$i].type -eq 'series') {
			$script:videoLinks += getVideoLinkFromSeriesID ($local:seasonLink)
		} else {
			#他にはないと思われるが念のため
			$script:videoLinks += '/' + $local:searchResults[$i].type + '/' + $local:searchResults[$i].Content.Id
		}
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてビデオ情報取得
#----------------------------------------------------------------------
function getVideoInfo ($local:videoLink) {

	$local:episodeID = $local:videoLink.Replace('/episodes/', '')
	
	#----------------------------------------------------------------------
	#VideoInfo
	$local:tverVideoInfoBaseURL = 'https://statics.tver.jp/content/episode/'
	$local:requestHeader = @{
		'origin'  = 'https://tver.jp';
		'referer' = 'https://tver.jp/'
	}
	$local:tverVideoInfoURL = $local:tverVideoInfoBaseURL + $local:episodeID + '.json?v=5'
	$local:videoInfo = (Invoke-RestMethod `
			-Uri $local:tverVideoInfoURL `
			-Method 'GET' `
			-Headers $local:requestHeader)

	#----------------------------------------------------------------------
	#Token & UID
	$local:tverVideoInfoBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$local:requestHeader = @{
		'x-tver-platform-type' = 'web' ;
	}
	$local:tverVideoInfoURL = $local:tverVideoInfoBaseURL + $local:episodeID + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:response = Invoke-RestMethod `
		-Uri $local:tverVideoInfoURL `
		-Method 'GET' `
		-Headers $local:requestHeader


	#----------------------------------------------------------------------
	#シリーズ
	#Series Name
	#	$response.Result.Series.Content.Title
	#	$response.Result.Episode.Content.SeriesTitle
	$script:videoSeries = $(getSpecialCharacterReplaced (
			getNarrowChars ($local:response.Result.Series.Content.Title)
		)).Trim()
	$script:videoSeriesID = $local:response.Result.Series.Content.Id
	$script:videoSeriesPageURL = 'https://tver.jp/series/' + `
		$local:response.Result.Series.Content.Id

	#----------------------------------------------------------------------
	#シーズン
	#Season Name
	#	$response.Result.Season.Content.Title
	$script:videoSeason = $(getSpecialCharacterReplaced (
			getNarrowChars ($local:response.Result.Season.Content.Title)
		)).Trim()
	$script:videoSeasonID = $local:response.Result.Season.Content.Id

	#----------------------------------------------------------------------
	#エピソード
	#Episode Name
	#$response.Result.Episode.Content.Title
	$script:videoTitle = $(getSpecialCharacterReplaced (
			getNarrowChars ($local:response.Result.Episode.Content.Title)
		)).Trim()
	$script:videoEpisodeID = $local:response.Result.Episode.Content.Id

	#----------------------------------------------------------------------
	#放送局
	#Media
	#	$response.Result.Episode.Content.BroadcasterName
	$script:mediaName = $(getSpecialCharacterReplaced (
			getNarrowChars ($local:response.Result.Episode.Content.BroadcasterName)
		)).Trim()
	$script:providerName = $(getSpecialCharacterReplaced (
			getNarrowChars ($local:response.Result.Episode.Content.ProductionProviderName)
		)).Trim()

	#----------------------------------------------------------------------
	#番組説明
	$script:descriptionText = $(getNarrowChars ($local:videoInfo.Description).Replace('&amp;', '&')).Trim()

	#----------------------------------------------------------------------
	#放送日
	#BroadcastDate
	#	$response.Result.Episode.Content.BroadcastDateLabel
	$local:broadcastYMD = $null
	$script:broadcastDate = $(getNarrowChars ($local:videoInfo.BroadcastDateLabel).Replace('ほか', '').Replace('放送分', '放送')).Trim()
	if ($script:broadcastDate -match '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		#当年だと仮定して放送日を抽出
		$local:broadcastYMD = [DateTime]::ParseExact(
			(Get-Date -Format 'yyyy') + $Matches[1].padleft(2, '0') + $Matches[3].padleft(2, '0'),
			'yyyyMMdd',
			$null
		)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の動画と判断する
		#(年末の番組を年初にダウンロードするケース)
		if ((Get-Date).AddDays(+1) -lt $local:broadcastYMD) {
			$script:broadcastDate = `
			(Get-Date).AddYears(-1).ToString('yyyy') + '年' `
				+ $Matches[1].padleft(2, '0') + $Matches[2] `
				+ $Matches[3].padleft(2, '0') + $Matches[4] `
				+ $Matches[6]
		} else {
			$script:broadcastDate = `
			(Get-Date).ToString('yyyy') + '年' `
				+ $Matches[1].padleft(2, '0') + $Matches[2] `
				+ $Matches[3].padleft(2, '0') + $Matches[4] `
				+ $Matches[6]
		}
	}

}

#----------------------------------------------------------------------
#デバッグ用ジャンルページの保存
#----------------------------------------------------------------------
function saveGenrePage ($script:KeywordName) {
	$local:keywordFile = $($script:keywordName + '.html') -replace '(\?|\!|>|<|:|\\|/|\|)', '-'
	$local:keywordFile = $(Join-Path $script:debugDir (getFileNameWithoutInvalidChars $local:keywordFile))
	$local:webClient = New-Object System.Net.WebClient
	$local:webClient.Encoding = [System.Text.Encoding]::UTF8
	$local:webClient.DownloadFile($script:keywordName, $local:keywordFile)
}

#----------------------------------------------------------------------
#ダウンロード対象外番組リストの読み込み
#----------------------------------------------------------------------
function getIgnoreList {
	#ダウンロード対象外番組リストの読み込み
	try {
		$local:ignoreTitles = (Get-Content $script:ignoreFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `
			| Where-Object { !($_ -match '^;.*$') }) `
			-as [string[]]
	} catch { Write-Error 'ダウンロード対象外リストの読み込みに失敗しました' ; exit 1 }
	return $local:ignoreTitles
}

#----------------------------------------------------------------------
#ダウンロード対象ジャンルリストの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	try {
		$local:keywordNames = (Get-Content $script:keywordFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `
			| Where-Object { !($_ -match '^#.*$') }) `
			-as [string[]]
	} catch { Write-Error 'ダウンロード対象ジャンルリストの読み込みに失敗しました' ; exit 1 }
	return $local:keywordNames
}

#----------------------------------------------------------------------
#キーワードからビデオのリンクへの変換
#----------------------------------------------------------------------
function getVideoLinksFromKeyword ($local:keywordName) {
	getToken
	$script:requestHeader = @{
		'x-tver-platform-type' = 'web' ;
		'Origin'               = 'https://tver.jp' ;
		'Referer'              = 'https://tver.jp/' ;
	}
	$script:videoLinks = @()
	if ( $local:keywordName.IndexOf('https://tver.jp/') -eq 0) {
		#URL形式の場合ビデオページのLinkを取得
		try { $local:keywordNamePage = Invoke-WebRequest $local:keywordName }
		catch { Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'; continue }
		try {
			$script:videoLinks = ($local:keywordNamePage.Links `
				| Where-Object { `
					(href -Like '*lp*') `
						-or (href -Like '*corner*') `
						-or (href -Like '*series*') `
						-or (href -Like '*episode*') `
						-or (href -Like '*feature*')`
				} `
				| Select-Object href).href
		} catch { Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'; continue }
		#saveGenrePage $script:keywordName						#デバッグ用ジャンルページの保存
	} elseif ($local:keywordName.IndexOf('talents/') -eq 0) {
		#タレントIDによるタレント検索からビデオページのLinkを取得
		$local:talentID = removeCommentsFromKeyword($local:keywordName).Replace('talents/', '').Trim()
		try { $script:videoLinks = getVideoLinkFromTalentID ($local:talentID) }
		catch { Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'; continue }
	} elseif ($local:keywordName.IndexOf('series/') -eq 0) {
		#番組IDによる番組検索からビデオページのLinkを取得
		$local:seriesID = removeCommentsFromKeyword($local:keywordName).Replace('series/', '').Trim()
		try { $script:videoLinks = getVideoLinkFromSeriesID ($local:seriesID) }
		catch { Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'; continue }
	} elseif ($local:keywordName.IndexOf('id/') -eq 0) {
		#ジャンルIDなどによる新着検索からビデオページのLinkを取得
		$local:tagID = removeCommentsFromKeyword($local:keywordName).Replace('id/', '').Trim()
		try { $script:videoLinks = getVideoLinkFromGenreID ($local:tagID) }
		catch { Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'; continue }
	} elseif ($local:keywordName.IndexOf('title/') -eq 0) {
		#番組名による新着検索からビデオページのLinkを取得
		$local:titleName = removeCommentsFromKeyword($local:keywordName).Replace('title/', '').Trim()
		try { $script:videoLinks = getVideoLinkFromTitle ($local:titleName) }
		catch { Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'; continue }
	} else {
		#タレント名や番組名などURL形式でない場合APIで検索結果からビデオページのLinkを取得
		try { $script:videoLinks = getVideoLinkFromFreeKeyword ($local:keywordName) }
		catch { Write-ColorOutput 'TVerから検索結果を取得できませんでした。スキップします'; continue }
	}
	return $script:videoLinks
}

#----------------------------------------------------------------------
#TVerビデオダウンロードのメイン処理
#----------------------------------------------------------------------
function downloadTVerVideo ($script:keywordName, $script:videoPageURL, $script:videoLink) {

	$script:platformUID = '' ; $script:platformToken = ''
	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$script:videoInfo = $null ;
	$script:newVideo = $null
	$script:ignore = $false ; $script:skip = $false

	$script:ignoreTitles = getIgnoreList		#ダウンロード対象外番組リストの読み込み
	
	#URLがすでにリストに存在する場合はスキップ
	try {
		#ロックファイルをロック
		while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
			Write-ColorOutput 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:listMatch = Import-Csv $script:listFilePath -Encoding UTF8 `
		| Where-Object { $_.videoPage -eq $script:videoPageURL }
	} catch { Write-ColorOutput 'リストを読み書きできなかったのでスキップしました' Green ; continue
	} finally { $null = fileUnlock ($script:lockFilePath) }

	if ( $null -ne $local:listMatch) { Write-ColorOutput '過去に処理したビデオです。スキップします'; continue }

	#TVerのAPIを叩いてビデオ情報取得
	try {
		getToken
		getVideoInfo ($script:videoLink)
	} catch {
		Write-ColorOutput 'TVerから情報を取得できませんでした。スキップします'
		continue			#次回再度トライするためリストに追加せずに次のビデオへ
	}

	#ビデオファイル情報をセット
	$script:videoName = getVideoFileName $script:videoSeries $script:videoSeason $script:videoTitle $script:broadcastDate
	$script:videoFileDir = getNarrowChars $($script:videoSeries + ' ' + $script:videoSeason).Trim()
	$script:videoFileDir = $(Join-Path $script:downloadBaseDir (getFileNameWithoutInvalidChars $script:videoFileDir))
	$script:videoFilePath = $(Join-Path $script:videoFileDir $script:videoName)
	$script:videoFileRelativePath = $script:videoFilePath.Replace($script:downloadBaseDir, '').Replace('\', '/')
	$script:videoFileRelativePath = $script:videoFileRelativePath.Substring(1, $($script:videoFileRelativePath.Length - 1))

	#ビデオ情報のコンソール出力
	showVideoInfo $script:videoName $script:broadcastDate $script:mediaName $descriptionText
	showVideoDebugInfo $script:videoPageURL $script:videoSeriesPageURL $script:keywordName $script:videoSeries $script:videoSeason $script:videoTitle $script:videoFilePath $(getTimeStamp)

	#ビデオタイトルが取得できなかった場合はスキップ次のビデオへ
	if ($script:videoName -eq '.mp4') {
		Write-ColorOutput 'ビデオタイトルを特定できませんでした。スキップします'
		continue			#次回再度ダウンロードをトライするためリストに追加せずに次のビデオへ
	}

	#ファイルが既に存在する場合はスキップフラグを立ててリストに書き込み処理へ
	if (Test-Path $script:videoFilePath) {

		#チェック済みか調べた上で、スキップ判断
		try {
			#ロックファイルをロック
			while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
				Write-ColorOutput 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:listMatch = Import-Csv $script:listFilePath -Encoding UTF8 `
			| Where-Object { $_.videoPath -eq $script:videoFilePath } `
			| Where-Object { $_.videoValidated -eq '1' }
		} catch { Write-ColorOutput 'リストを読み書きできませんでした。スキップします' Green ; continue
		} finally { $null = fileUnlock ($script:lockFilePath) }

		#結果が0件ということは未検証のファイルがあるということ
		if ( $null -eq $local:listMatch) {
			Write-ColorOutput 'すでにダウンロード済みですが未検証のビデオです。リストに追加します'
			$script:skip = $true
		} else { Write-ColorOutput 'すでにダウンロード済み・検証済みのビデオです。スキップします'; continue }

	} else {

		#無視リストに入っている番組の場合はスキップフラグを立ててリスト書き込み処理へ
		foreach ($script:ignoreTitle in $script:ignoreTitles) {
			if ($(getNarrowChars $script:videoSeries) -match $(getNarrowChars $script:ignoreTitle)) {
				$script:ignore = $true
				Write-ColorOutput '無視リストに入っているビデオです。スキップします'
				continue			#リストの重複削除のため、無視したものはリスト出力せずに次のビデオへ行くことに
			}
		}

	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Write-ColorOutput '無視したファイルをリストに追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL ;
			videoSeriesPage = $script:videoSeriesPageURL ;
			genre           = $script:keywordName ;
			series          = $script:videoSeries ;
			season          = $script:videoSeason ;
			title           = $script:videoTitle ;
			media           = $script:mediaName ;
			broadcastDate   = $script:broadcastDate ;
			downloadDate    = $(getTimeStamp) ;
			videoDir        = $script:videoFileDir ;
			videoName       = '-- IGNORED --' ;
			videoPath       = '-- IGNORED --' ;
			videoValidated  = '0' ;
		}
	} elseif ($script:skip -eq $true) {
		Write-ColorOutput 'スキップした未検証のファイルをリストに追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL ;
			videoSeriesPage = $script:videoSeriesPageURL ;
			genre           = $script:keywordName ;
			series          = $script:videoSeries ;
			season          = $script:videoSeason ;
			title           = $script:videoTitle ;
			media           = $script:mediaName ;
			broadcastDate   = $script:broadcastDate ;
			downloadDate    = $(getTimeStamp) ;
			videoDir        = $script:videoFileDir ;
			videoName       = '-- SKIPPED --' ;
			videoPath       = $videoFileRelativePath ;
			videoValidated  = '0' ;
		}
	} else {
		Write-ColorOutput 'ダウンロードするファイルをリストに追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL ;
			videoSeriesPage = $script:videoSeriesPageURL ;
			genre           = $script:keywordName ;
			series          = $script:videoSeries ;
			season          = $script:videoSeason ;
			title           = $script:videoTitle ;
			media           = $script:mediaName ;
			broadcastDate   = $script:broadcastDate ;
			downloadDate    = $(getTimeStamp) ;
			videoDir        = $script:videoFileDir ;
			videoName       = $script:videoName ;
			videoPath       = $script:videoFileRelativePath ;
			videoValidated  = '0' ;
		}
	}

	#リストCSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
			Write-ColorOutput 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$script:newVideo | Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8 -Append
		Write-Debug 'リストを書き込みました'
	} catch { Write-ColorOutput 'リストを更新できませんでした。でスキップします' Green ; continue
	} finally { $null = fileUnlock ($script:lockFilePath) }

	#スキップや無視対象でなければyoutube-dl起動
	if (($script:ignore -eq $true) -Or ($script:skip -eq $true)) {
		continue			#スキップや無視対象は飛ばして次のファイルへ
	} else {
		#保存作ディレクトリがなければ作成
		if (-Not (Test-Path $script:videoFileDir -PathType Container)) {
			try { $null = New-Item -ItemType directory -Path $script:videoFileDir } catch {}
		}
		#youtube-dl起動
		try { executeYtdl $script:videoPageURL }
		catch { Write-ColorOutput 'youtube-dlの起動に失敗しました' Green }
		Start-Sleep -Seconds 5			#5秒待機

	}

}

