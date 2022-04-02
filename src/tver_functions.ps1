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
#TVerのAPIを叩いてビデオ検索
#----------------------------------------------------------------------
function getVideoLinkFromFreeKeyword ($keywordName) {
	$tverTokenBaseURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create?note=Creating session'
	$requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded' ;
		'origin'       = 'https://tver.jp' ;
		'referer'      = 'https://tver.jp/' ;
	}
	$requestBody = 'device_type=pc'
	$response = Invoke-RestMethod $tverTokenBaseURL -Method 'POST' -Headers $requestHeader -Body $requestBody


	$tverSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/'
	$requestHeader = @{
		'x-tver-platform-type' = 'web' ;
		'origin'               = 'https://tver.jp' ;
		'referer'              = 'https://tver.jp/' ;
	}
	$tverSearchBaseURL = $tverSearchBaseURL + `
		'callSearch?platform_uid=' + $response.result.platform_uid + `
		'&platform_token=' + $response.result.platform_token + `
		'&keyword=' + $keywordName
	$searchResultsRaw = (Invoke-RestMethod -Uri $tverSearchBaseURL -Method 'GET' -Headers $requestHeader)
	$videoLinks = @()
	$searchResults = $searchResultsRaw.result.contents
	$resultCount = $searchResults.length
	for ($i = 0; $i -lt $resultCount; $i++) {
		$videoLinks += '/' + $searchResults[$i].type + 's/' + $searchResults[$i].content.id
	}

	return $videoLinks
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてビデオ情報取得
#----------------------------------------------------------------------
function getVideoInfoFromVideoID ($videoID) {
	$headerTable = @{
		'origin'  = 'https://tver.jp';
		'referer' = 'https://tver.jp/' 
	}
	$tverApiBaseURL = 'https://statics.tver.jp/content'
	$teverApiVideoURL = $tverApiBaseURL + $videoID.Replace('episodes', 'episode') + '.json?v=5'
	$videoInfo = (Invoke-RestMethod -Headers $headerTable -Uri $teverApiVideoURL -Method 'GET')	#API経由でビデオ情報取得
	return $videoInfo
}

#----------------------------------------------------------------------
#取得したビデオ情報を整形
#----------------------------------------------------------------------
function getBroadcastDateFromVideoInfo ($videoInfo) {
	$broadcastYMD = $null
	$broadcastDate = $(getNarrowChars (
			#$videoInfo.date).Replace('ほか', '').Replace('放送分', '放送')
			$videoInfo.broadcastDateLabel).Replace('ほか', '').Replace('放送分', '放送')
	).trim()
	if ($broadcastDate -match '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		#当年だと仮定して放送日を抽出
		$broadcastYMD = [DateTime]::ParseExact(
			(Get-Date -Format 'yyyy') + $Matches[1].padleft(2, '0') + $Matches[3].padleft(2, '0'), 
			'yyyyMMdd', 
			$null
		)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の動画と判断する(年末の番組を年初にダウンロードするケース)
		if ((Get-Date).AddDays(+1) -lt $broadcastYMD) {
			$broadcastDate = `
			(Get-Date).AddYears(-1).ToString('yyyy') + '年' `
				+ $Matches[1].padleft(2, '0') + $Matches[2] `
				+ $Matches[3].padleft(2, '0') + $Matches[4] `
				+ $Matches[6]
		} else {
			$broadcastDate = `
			(Get-Date).ToString('yyyy') + '年' `
				+ $Matches[1].padleft(2, '0') + $Matches[2] `
				+ $Matches[3].padleft(2, '0') + $Matches[4] `
				+ $Matches[6]
		}
	}
	return $broadcastDate
}

#----------------------------------------------------------------------
#取得したビデオ情報からタイトル情報を取得
#----------------------------------------------------------------------
function getVideoTitleFromVideoInfo ($videoInfo) {
	#return $(getSpecialCharacterReplaced (getNarrowChars ($videoInfo.title))).trim()
	return $(getSpecialCharacterReplaced (getNarrowChars ($videoInfo.share.text).ReplaceLineEndings('').Replace('#TVer', ''))).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報からサブタイトル情報を取得
#----------------------------------------------------------------------
function getVideoSubTitleFromVideoInfo ($videoInfo) {
	#return $(getSpecialCharacterReplaced (getNarrowChars ($videoInfo.subtitle))).trim()
	return $(getSpecialCharacterReplaced (getNarrowChars ($videoInfo.title))).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報から放送局情報を取得
#----------------------------------------------------------------------
function getVideoMediaFromVideoInfo ($videoInfo) {
	#return $(getSpecialCharacterReplaced (getNarrowChars ($videoInfo.media))).trim()
	return $(getSpecialCharacterReplaced (getNarrowChars ($videoInfo.broadcastProviderLabel))).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報から番組説明を取得
#----------------------------------------------------------------------
function getVideoDescriptionFromVideoInfo ($videoInfo) {
	#return $(getNarrowChars ($videoInfo.note.text).Replace('&amp;', '&')).trim()
	return $(getNarrowChars ($videoInfo.description).Replace('&amp;', '&')).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報からLP情報を取得
#----------------------------------------------------------------------
function getVideoSeriesFromVideoInfo ($videoInfo) {
	#return $videoInfo.lp
	return $videoInfo.share.url
}

#----------------------------------------------------------------------
#デバッグ用ジャンルページの保存
#----------------------------------------------------------------------
function saveGenrePage {
	$keywordFile = $($keywordName + '.html') -replace '(\?|\!|>|<|:|\\|/|\|)', '-'
	$keywordFile = $(Join-Path $debugDir (getFileNameWithoutInvalitChars $keywordFile))
	$webClient = New-Object System.Net.WebClient
	$webClient.Encoding = [System.Text.Encoding]::UTF8
	$webClient.DownloadFile($keywordName, $keywordFile)
}

#----------------------------------------------------------------------
#ダウンロード対象外番組リストの読み込み
#----------------------------------------------------------------------
function loadIgnoreList {
	#ダウンロード対象外番組リストの読み込み
	try {
		$ignoreTitles = (Get-Content $ignoreFilePath -Encoding UTF8 | `
					Where-Object { !($_ -match '^\s*$') } | `
					Where-Object { !($_ -match '^;.*$') }) `
			-as [string[]]
	} catch { Write-Host 'ダウンロード対象外リストの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }
	return $ignoreTitles
}

#----------------------------------------------------------------------
#ダウンロード対象ジャンルリストの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	try {
		$keywordNames = (Get-Content $keywordFilePath -Encoding UTF8 | `
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
			$videoLinks = ($keywordNamePage.Links | Where-Object href -Like '*lp*' | Select-Object href).href
			$videoLinks += ($keywordNamePage.Links | Where-Object href -Like '*corner*' | Select-Object href).href
			$videoLinks += ($keywordNamePage.Links | Where-Object href -Like '*series*' | Select-Object href).href
			$videoLinks += ($keywordNamePage.Links | Where-Object href -Like '*episode*' | Select-Object href).href
			$videoLinks += ($keywordNamePage.Links | Where-Object href -Like '*feature*' | Select-Object href).href
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
function downloadTVerVideo ($keywordName) {

	$videoName = '' ; $videoFilePath = '' ; $videoSeriesPageURL = ''
	$broadcastDate = '' ; $videoTitle = '' ; $videoSubtitle = ''
	$mediaName = '' ; $descriptionText = ''
	$videoInfo = $null ; $newVideo = $null
	$ignore = $false ; $skip = $false

	$ignoreTitles = loadIgnoreList		#ダウンロード対象外番組リストの読み込み
	
	#URLがすでにリストに存在する場合はスキップ
	try {
		#ロックファイルをロック
		while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$listMatch = Import-Csv $listFilePath -Encoding UTF8 | `
				Where-Object { $_.videoPage -eq $videoPageURL }
	} catch { Write-Host 'リストを読み書きできなかったのでスキップしました' -ForegroundColor Green ; continue 
	} finally { $null = fileUnlock ($lockFilePath) }

	if ( $null -ne $listMatch) { Write-Host '過去に処理したビデオです。スキップします'; continue }

	#TVerのAPIを叩いてビデオ情報取得
	try {
		$videoInfo = getVideoInfoFromVideoID ($videoID)
	} catch {
		Write-Host 'TVerから情報を取得できませんでした。スキップします'
		continue			#次回再度トライするためリストに追加せずに次のビデオへ
	}

	#取得したビデオ情報を整形
	$broadcastDate = getBroadcastDateFromVideoInfo ($videoInfo)
	$videoTitle = getVideoTitleFromVideoInfo ($videoInfo)
	$videoSubtitle = getVideoSubTitleFromVideoInfo ($videoInfo)
	$mediaName = getVideoMediaFromVideoInfo ($videoInfo)
	$descriptionText = getVideoDescriptionFromVideoInfo ($videoInfo)
	$videoSeriesPageURL = getVideoSeriesFromVideoInfo ($videoInfo)

	#ビデオファイル情報をセット
	$videoName = getVideoFileName $videoTitle $videoSubtitle $broadcastDate
	$videoFileDir = $(Join-Path $downloadBaseDir (getFileNameWithoutInvalitChars $videoTitle))
	$videoFilePath = $(Join-Path $videoFileDir $videoName)
	$videoFileRelativePath = $videoFilePath.Replace($downloadBaseDir, '').Replace('\', '/')
	$videoFileRelativePath = $videoFileRelativePath.Substring(1, $($videoFileRelativePath.Length - 1))

	#ビデオ情報のコンソール出力
	showVideoInfo $videoName $broadcastDate $mediaName $descriptionText
	showVideoDebugInfo $videoPageURL $videoSeriesPageURL $keywordName $videoTitle $videoSubtitle $videoFilePath $(getTimeStamp)

	#ビデオタイトルが取得できなかった場合はスキップ次のビデオへ
	if ($videoName -eq '.mp4') {
		Write-Host 'ビデオタイトルを特定できませんでした。スキップします'
		continue			#次回再度ダウンロードをトライするためリストに追加せずに次のビデオへ
	}

	#ファイルが既に存在する場合はスキップフラグを立ててリストに書き込み処理へ
	if (Test-Path $videoFilePath) {

		#チェック済みか調べた上で、スキップ判断
		try {
			#ロックファイルをロック
			while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$listMatch = Import-Csv $listFilePath -Encoding UTF8 | `
					Where-Object { $_.videoPath -eq $videoFilePath } | `
					Where-Object { $_.videoValidated -eq '1' }
		} catch { Write-Host 'リストを読み書きできませんでした。スキップします' -ForegroundColor Green ; continue 
		} finally { $null = fileUnlock ($lockFilePath) }

		#結果が0件ということは未検証のファイルがあるということ
		if ( $null -eq $listMatch) {
			Write-Host 'すでにダウンロード済みですが未検証のビデオです。リストに追加します'
			$skip = $true
		} else { Write-Host 'すでにダウンロード済み・検証済みのビデオです。スキップします'; continue }

	} else {

		#無視リストに入っている番組の場合はスキップフラグを立ててリスト書き込み処理へ
		foreach ($ignoreTitle in $ignoreTitles) {
			if ($(getNarrowChars $videoTitle) -match $(getNarrowChars $ignoreTitle)) {
				$ignore = $true
				Write-Host '無視リストに入っているビデオです。スキップします'
				continue			#リストの重複削除のため、無視したものはリスト出力せずに次のビデオへ行くことに
			}
		}

	}

	#スキップフラグが立っているかチェック
	if ($ignore -eq $true) {
		Write-Host '無視したファイルをリストに追加します'
		$newVideo = [pscustomobject]@{
			videoPage      = $videoPageURL ;
			videoPageLP    = $videoSeriesPageURL ;
			genre          = $keywordName ;
			title          = $videoTitle ;
			subtitle       = $videoSubtitle ;
			media          = $mediaName ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = '-- IGNORED --' ;
			videoPath      = '-- IGNORED --' ;
			videoValidated = '0' ;
		}
	} elseif ($skip -eq $true) {
		Write-Host 'スキップした未検証のファイルをリストに追加します'
		$newVideo = [pscustomobject]@{
			videoPage      = $videoPageURL ;
			videoPageLP    = $videoSeriesPageURL ;
			genre          = $keywordName ;
			title          = $videoTitle ;
			subtitle       = $videoSubtitle ;
			media          = $mediaName ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = '-- SKIPPED --' ;
			videoPath      = $videoFileRelativePath ;
			videoValidated = '0' ;
		}
	} else {
		Write-Host 'ダウンロードするファイルをリストに追加します'
		$newVideo = [pscustomobject]@{
			videoPage      = $videoPageURL ;
			videoPageLP    = $videoSeriesPageURL ;
			genre          = $keywordName ;
			title          = $videoTitle ;
			subtitle       = $videoSubtitle ;
			media          = $mediaName ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = $videoName ;
			videoPath      = $videoFileRelativePath ;
			videoValidated = '0' ;
		}
	}

	#リストCSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$newVideo | Export-Csv $listFilePath -NoTypeInformation -Encoding UTF8 -Append
		Write-Debug 'リストを書き込みました'
	} catch { Write-Host 'リストを更新できませんでした。でスキップします' -ForegroundColor Green ; continue 
	} finally { $null = fileUnlock ($lockFilePath) }

	#スキップや無視対象でなければyt-dlp起動
	if (($ignore -eq $true) -Or ($skip -eq $true)) {
		continue			#スキップや無視対象は飛ばして次のファイルへ
	} else {
		#保存作ディレクトリがなければ作成
		if (-Not (Test-Path $videoFileDir -PathType Container)) {
			try { $null = New-Item -ItemType directory -Path $videoFileDir } catch {}
		}
		#yt-dlp起動
		try { executeYtdlp $videoFilePath $videoPageURL $ytdlpPath } 
		catch { Write-Host 'yt-dlpの起動に失敗しました' -ForegroundColor Green }
		Start-Sleep -Seconds 5			#10秒待機

	}

}

