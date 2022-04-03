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
	$local:tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create?note=Creating session'
	$local:requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded' ;
		'Origin'       = 'https://tver.jp' ;
		'Referer'      = 'https://tver.jp/' ;
	}
	$local:requestBody = 'device_type=pc'
	$local:tokenResponse = Invoke-RestMethod `
		-Uri $local:tverTokenURL `
		-Method 'POST' `
		-Headers $local:requestHeader `
		-Body $local:requestBody
	$script:platformUID = $local:tokenResponse.result.platform_uid
	$script:platformToken = $local:tokenResponse.result.platform_token
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてビデオ検索
#----------------------------------------------------------------------
function getVideoLinkFromFreeKeyword ($local:keywordName) {
	$local:tverSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/'
	$local:requestHeader = @{
		'x-tver-platform-type' = 'web' ;
		'Origin'               = 'https://tver.jp' ;
		'Referer'              = 'https://tver.jp/' ;
	}
	$local:tverSearchURL = $local:tverSearchBaseURL + `
		'callSearch?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken + `
		'&keyword=' + $local:keywordName
	$local:searchResultsRaw = (Invoke-RestMethod `
			-Uri $local:tverSearchURL `
			-Method 'GET' `
			-Headers $local:requestHeader)
	$local:videoLinks = @()
	$local:searchResults = $local:searchResultsRaw.result.contents
	$local:resultCount = $local:searchResults.length
	for ($i = 0; $i -lt $local:resultCount; $i++) {
		if ($local:searchResults[$i].type -eq 'episode') {
			$local:videoLinks += '/episodes/' + $local:searchResults[$i].content.id
		} else {
			$local:videoLinks += '/' + $local:searchResults[$i].type + $local:searchResults[$i].content.id
		}
	}
	return $local:videoLinks
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
	#	$response.result.series.content.title
	#	$response.result.episode.content.seriesTitle
	$script:videoTitle = $(getSpecialCharacterReplaced ( `
				getNarrowChars ($local:response.result.series.content.title) `
		)).trim()
	$script:videoSeriesID = $local:response.result.series.content.id
	$script:videoSeriesPageURL = 'https://tver.jp/series/' + $local:response.result.series.content.id

	#----------------------------------------------------------------------
	#シーズン
	#Season Name
	#	$response.result.season.content.title
	$script:videoSeason = $(getSpecialCharacterReplaced ( `
				getNarrowChars ($local:response.result.season.content.title) `
		)).trim()
	$script:videoSeasonID = $local:response.result.season.content.id

	#----------------------------------------------------------------------
	#エピソード
	#Episode Name
	#$response.result.episode.content.title
	$script:videoSubtitle = $(getSpecialCharacterReplaced ( `
				getNarrowChars ($local:response.result.episode.content.title) `
		)).trim()
	$script:videoEpisodeID = $local:response.result.episode.content.id

	#----------------------------------------------------------------------
	#放送局
	#Media
	#	$response.result.episode.content.broadcasterName
	$script:mediaName = $(getSpecialCharacterReplaced ( `
				getNarrowChars ($local:response.result.episode.content.broadcasterName) `
		)).trim()
	$script:providerName = $(getSpecialCharacterReplaced ( `
				getNarrowChars ($local:response.result.episode.content.productionProviderName) `
		)).trim()

	#----------------------------------------------------------------------
	#番組説明
	$script:descriptionText = $(getNarrowChars ($local:videoInfo.description). `
			Replace('&amp;', '&')).trim()

	#----------------------------------------------------------------------
	#放送日
	#BroadcastDate
	#	$response.result.episode.content.broadcastDateLabel
	$local:broadcastYMD = $null
	$script:broadcastDate = $(getNarrowChars ($local:videoInfo.broadcastDateLabel).`
			Replace('ほか', '').`
			Replace('放送分', '放送')).`
		trim()
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
function saveGenrePage {
	$local:keywordFile = $($keywordName + '.html') -replace '(\?|\!|>|<|:|\\|/|\|)', '-'
	$local:keywordFile = $(Join-Path $global:debugDir (getFileNameWithoutInvalidChars $local:keywordFile))
	$local:webClient = New-Object System.Net.WebClient
	$local:webClient.Encoding = [System.Text.Encoding]::UTF8
	$local:webClient.DownloadFile($keywordName, $local:keywordFile)
}

#----------------------------------------------------------------------
#ダウンロード対象外番組リストの読み込み
#----------------------------------------------------------------------
function getIgnoreList {
	#ダウンロード対象外番組リストの読み込み
	try {
		$local:ignoreTitles = (Get-Content $global:ignoreFilePath -Encoding UTF8 | `
					Where-Object { !($_ -match '^\s*$') } | `
					Where-Object { !($_ -match '^;.*$') }) `
			-as [string[]]
	} catch { Write-Host 'ダウンロード対象外リストの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }
	return $local:ignoreTitles
}

#----------------------------------------------------------------------
#ダウンロード対象ジャンルリストの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	try {
		$keywordNames = (Get-Content $global:keywordFilePath -Encoding UTF8 | `
					Where-Object { !($_ -match '^\s*$') } | `
					Where-Object { !($_ -match '^#.*$') } | `
					Where-Object { !($_ -match '^;.*$') }) `
			-as [string[]]
	} catch { Write-Host 'ダウンロード対象ジャンルリストの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }
	return $keywordNames
}

#----------------------------------------------------------------------
#キーワードからビデオのリンクへの変換
#----------------------------------------------------------------------
function getVideoLinksFromKeyword ($keywordName) {
	if ( $keywordName.IndexOf('https://tver.jp/') -eq 0) {
		#ジャンルページなどURL形式の場合ビデオページのLinkを取得
		try { $keywordNamePage = Invoke-WebRequest $keywordName } 
		catch { Write-Host 'TVerから情報を取得できませんでした。スキップします'; continue }

		try {
			$videoLinks = ($keywordNamePage.Links | Where-Object { `
					(href -Like '*lp*') `
						-or (href -Like '*corner*') `
						-or (href -Like '*series*') `
						-or (href -Like '*episode*') `
						-or (href -Like '*feature*')`
				} | Select-Object href).href
		} catch {}

		#saveGenrePage						#デバッグ用ジャンルページの保存

	} else {
		#タレント名や番組名などURL形式でない場合APIで検索結果からビデオページのLinkを取得
		try { $videoLinks = getVideoLinkFromFreeKeyword ($keywordName) } 
		catch { Write-Host 'TVerから検索結果を取得できませんでした。スキップします'; continue }
	}
	return $videoLinks
}

#----------------------------------------------------------------------
#TVerビデオダウンロードのメイン処理
#----------------------------------------------------------------------
function downloadTVerVideo ($local:keywordName, $local:videoPageURL, $local:videoLink) {

	$script:platformUID = '' ; $script:platformToken = ''
	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoTitle = '' ; $script:videoSeason = '' ; $script:videoSubtitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$script:videoInfo = $null ;
	$local:newVideo = $null
	$script:ignore = $false ; $script:skip = $false

	$script:ignoreTitles = getIgnoreList		#ダウンロード対象外番組リストの読み込み
	
	#URLがすでにリストに存在する場合はスキップ
	try {
		#ロックファイルをロック
		while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:listMatch = Import-Csv $global:listFilePath -Encoding UTF8 | `
				Where-Object { $_.videoPage -eq $local:videoPageURL }
	} catch { Write-Host 'リストを読み書きできなかったのでスキップしました' -ForegroundColor Green ; continue 
	} finally { $null = fileUnlock ($global:lockFilePath) }

	if ( $null -ne $local:listMatch) { Write-Host '過去に処理したビデオです。スキップします'; continue }

	#TVerのAPIを叩いてビデオ情報取得
	try {
		getToken
		getVideoInfo ($local:videoLink)
	} catch {
		Write-Host 'TVerから情報を取得できませんでした。スキップします'
		continue			#次回再度トライするためリストに追加せずに次のビデオへ
	}

	#ビデオファイル情報をセット
	$script:videoName = getVideoFileName $script:videoTitle $script:videoSeason $script:videoSubtitle $script:broadcastDate
	$script:videoFileDir = getNarrowChars $($script:videoTitle + ' ' + $script:videoSeason).trim()
	$script:videoFileDir = $(Join-Path $global:downloadBaseDir (getFileNameWithoutInvalidChars $script:videoFileDir))
	$script:videoFilePath = $(Join-Path $script:videoFileDir $script:videoName)
	$script:videoFileRelativePath = $script:videoFilePath.Replace($global:downloadBaseDir, '').Replace('\', '/')
	$script:videoFileRelativePath = $script:videoFileRelativePath.Substring(1, $($script:videoFileRelativePath.Length - 1))

	#ビデオ情報のコンソール出力
	showVideoInfo $script:videoName $script:broadcastDate $script:mediaName $descriptionText
	showVideoDebugInfo $local:videoPageURL $script:videoSeriesPageURL $local:keywordName $script:videoTitle $script:videoSeason $script:videoSubtitle $script:videoFilePath $(getTimeStamp)

	#ビデオタイトルが取得できなかった場合はスキップ次のビデオへ
	if ($script:videoName -eq '.mp4') {
		Write-Host 'ビデオタイトルを特定できませんでした。スキップします'
		continue			#次回再度ダウンロードをトライするためリストに追加せずに次のビデオへ
	}

	#ファイルが既に存在する場合はスキップフラグを立ててリストに書き込み処理へ
	if (Test-Path $script:videoFilePath) {

		#チェック済みか調べた上で、スキップ判断
		try {
			#ロックファイルをロック
			while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:listMatch = Import-Csv $global:listFilePath -Encoding UTF8 | `
					Where-Object { $_.videoPath -eq $script:videoFilePath } | `
					Where-Object { $_.videoValidated -eq '1' }
		} catch { Write-Host 'リストを読み書きできませんでした。スキップします' -ForegroundColor Green ; continue 
		} finally { $null = fileUnlock ($global:lockFilePath) }

		#結果が0件ということは未検証のファイルがあるということ
		if ( $null -eq $local:listMatch) {
			Write-Host 'すでにダウンロード済みですが未検証のビデオです。リストに追加します'
			$script:skip = $true
		} else { Write-Host 'すでにダウンロード済み・検証済みのビデオです。スキップします'; continue }

	} else {

		#無視リストに入っている番組の場合はスキップフラグを立ててリスト書き込み処理へ
		foreach ($local:ignoreTitle in $script:ignoreTitles) {
			if ($(getNarrowChars $script:videoTitle) -match $(getNarrowChars $local:ignoreTitle)) {
				$script:ignore = $true
				Write-Host '無視リストに入っているビデオです。スキップします'
				continue			#リストの重複削除のため、無視したものはリスト出力せずに次のビデオへ行くことに
			}
		}

	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Write-Host '無視したファイルをリストに追加します'
		$local:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL ;
			videoSeriesPage = $script:videoSeriesPageURL ;
			genre           = $local:keywordName ;
			title           = $script:videoTitle ;
			subtitle        = $script:videoSubtitle ;
			media           = $script:mediaName ;
			broadcastDate   = $script:broadcastDate ;
			downloadDate    = $(getTimeStamp) ;
			videoName       = '-- IGNORED --' ;
			videoPath       = '-- IGNORED --' ;
			videoValidated  = '0' ;
		}
	} elseif ($script:skip -eq $true) {
		Write-Host 'スキップした未検証のファイルをリストに追加します'
		$local:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL ;
			videoSeriesPage = $script:videoSeriesPageURL ;
			genre           = $local:keywordName ;
			title           = $script:videoTitle ;
			subtitle        = $script:videoSubtitle ;
			media           = $script:mediaName ;
			broadcastDate   = $script:broadcastDate ;
			downloadDate    = $(getTimeStamp) ;
			videoName       = '-- SKIPPED --' ;
			videoPath       = $videoFileRelativePath ;
			videoValidated  = '0' ;
		}
	} else {
		Write-Host 'ダウンロードするファイルをリストに追加します'
		$local:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL ;
			videoSeriesPage = $script:videoSeriesPageURL ;
			genre           = $local:keywordName ;
			title           = $script:videoTitle ;
			subtitle        = $script:videoSubtitle ;
			media           = $script:mediaName ;
			broadcastDate   = $script:broadcastDate ;
			downloadDate    = $(getTimeStamp) ;
			videoName       = $script:videoName ;
			videoPath       = $script:videoFileRelativePath ;
			videoValidated  = '0' ;
		}
	}

	#リストCSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:newVideo | Export-Csv $global:listFilePath -NoTypeInformation -Encoding UTF8 -Append
		Write-Debug 'リストを書き込みました'
	} catch { Write-Host 'リストを更新できませんでした。でスキップします' -ForegroundColor Green ; continue 
	} finally { $null = fileUnlock ($global:lockFilePath) }

	#スキップや無視対象でなければyt-dlp起動
	if (($script:ignore -eq $true) -Or ($script:skip -eq $true)) {
		continue			#スキップや無視対象は飛ばして次のファイルへ
	} else {
		#保存作ディレクトリがなければ作成
		if (-Not (Test-Path $script:videoFileDir -PathType Container)) {
			try { $null = New-Item -ItemType directory -Path $script:videoFileDir } catch {}
		}
		#yt-dlp起動
		try { executeYtdlp $script:videoPageURL } 
		catch { Write-Host 'yt-dlpの起動に失敗しました' -ForegroundColor Green }
		Start-Sleep -Seconds 5			#10秒待機

	}

}

