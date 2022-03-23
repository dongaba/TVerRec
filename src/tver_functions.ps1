###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		TVer固有関数スクリプト
#
#	Copyright (c) 2021 dongaba
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
function callTVerSearchAPI ($keyword) {
	$tverApiBaseURL = 'https://api.tver.jp/v4'
	$tverApiTokenLink = 'https://tver.jp/api/access_token.php'					#APIトークン取得
	$token = (Invoke-RestMethod -Uri $tverApiTokenLink -Method get).token		#APIトークンセット
	$teverApiSearchURL = $tverApiBaseURL + '/search?catchup=1&keyword=' + $keyword + '&token=' + $token
	$searchResult = (Invoke-RestMethod -Uri $teverApiSearchURL -Method get)		#API経由で検索結果取得
	$videoLinks = $searchResult.data.href
	return $videoLinks
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてビデオ情報取得
#----------------------------------------------------------------------
function callTVerAPI ($videoID) {
	$tverApiBaseURL = 'https://api.tver.jp/v4'
	$tverApiTokenLink = 'https://tver.jp/api/access_token.php'					#APIトークン取得
	$token = (Invoke-RestMethod -Uri $tverApiTokenLink -Method get).token		#APIトークンセット
	$teverApiVideoURL = $tverApiBaseURL + $videoID + '?token=' + $token			#APIのURLをセット
	$videoInfo = (Invoke-RestMethod -Uri $teverApiVideoURL -Method get).main	#API経由でビデオ情報取得
	return $videoInfo
}

#----------------------------------------------------------------------
#取得したビデオ情報を整形
#----------------------------------------------------------------------
function getBroadcastDate ($videoInfo ) {
	$broadcastYMD = $null
	$broadcastDate = $(conv2Narrow ($videoInfo.date).Replace('ほか', '').Replace('放送分', '放送')).trim()
	if ($broadcastDate -match '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		#当年だと仮定して放送日を抽出
		$broadcastYMD = [DateTime]::ParseExact((Get-Date -Format 'yyyy') + $Matches[1].padleft(2, '0') + $Matches[3].padleft(2, '0'), 'yyyyMMdd', $null)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の動画と判断する(年末の番組を年初にダウンロードするケース)
		if ((Get-Date).AddDays(+1) -lt $broadcastYMD) {
			$broadcastDate = (Get-Date).AddYears(-1).ToString('yyyy') + '年' + $Matches[1].padleft(2, '0') + $Matches[2] + $Matches[3].padleft(2, '0') + $Matches[4] + $Matches[6]
		} else {
			$broadcastDate = (Get-Date).ToString('yyyy') + '年' + $Matches[1].padleft(2, '0') + $Matches[2] + $Matches[3].padleft(2, '0') + $Matches[4] + $Matches[6]
		}
	}
	return $broadcastDate
}

#----------------------------------------------------------------------
#取得したビデオ情報からタイトル情報を取得
#----------------------------------------------------------------------
function getVideoTitle ($videoInfo ) {
	return $(conv2Narrow ($videoInfo.title).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace(',', '').Replace('?', '？').Replace('!', '！')).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報からサブタイトル情報を取得
#----------------------------------------------------------------------
function getVideoSubTitle ($videoInfo ) {
	return $(conv2Narrow ($videoInfo.subtitle).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace(',', '').Replace('?', '？').Replace('!', '！')).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報から放送局情報を取得
#----------------------------------------------------------------------
function getVideoMedia ($videoInfo ) {
	return $(conv2Narrow ($videoInfo.media).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace(',', '').Replace('?', '？').Replace('!', '！')).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報から番組説明を取得
#----------------------------------------------------------------------
function getVideoDescription ($videoInfo ) {
	return $(conv2Narrow ($videoInfo.note.text).Replace('&amp;', '&')).trim()
}

#----------------------------------------------------------------------
#取得したビデオ情報からLP情報を取得
#----------------------------------------------------------------------
function getVideoSeries ($videoInfo ) {
	return $videoInfo.lp
}

#----------------------------------------------------------------------
#デバッグ用ジャンルページの保存
#----------------------------------------------------------------------
function saveGenrePage {
	$genreFile = $($genre + '.html') -replace '(\?|\!|>|<|:|\\|/|\|)', '-'
	$genreFile = $(Join-Path $debugDir (removeInvalidFileNameChars $genreFile))
	$webClient = New-Object System.Net.WebClient
	$webClient.Encoding = [System.Text.Encoding]::UTF8
	$webClient.DownloadFile($genre, $genreFile)
}

#----------------------------------------------------------------------
#ダウンロード対象外番組リストの読み込み
#----------------------------------------------------------------------
function loadIgnoreList {
	#ダウンロード対象外番組リストの読み込み
	try {
		$ignoreTitles = (Get-Content $ignoreFile -Encoding UTF8 | `
					Where-Object { !($_ -match '^\s*$') } | `
					Where-Object { !($_ -match '^;.*$') } ) `
			-as [string[]]
	} catch { Write-Host 'ダウンロード対象外リストの読み込みに失敗しました'; exit 1 }
	return $ignoreTitles
}

#----------------------------------------------------------------------
#ダウンロード対象ジャンルリストの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	try {
		$keywords = (Get-Content $keywordFile -Encoding UTF8 | `
					Where-Object { !($_ -match '^\s*$') } | `
					Where-Object { !($_ -match '^#.*$') } | `
					Where-Object { !($_ -match '^;.*$') } ) `
			-as [string[]]
	} catch { Write-Host 'ダウンロード対象ジャンルリストの読み込みに失敗しました'; exit 1 }
	return $keywords
}

#----------------------------------------------------------------------
#キーワードからビデオのリンクへの変換
#----------------------------------------------------------------------
function getVideoLinks {
	if ( $keyword.IndexOf('https://tver.jp/') -eq 0 ) {
		#ジャンルページなどURL形式の場合ビデオページのLinkを取得
		try { $genrePage = Invoke-WebRequest $keyword } catch { Write-Host 'TVerから情報を取得できませんでした。スキップします'; continue }

		$ErrorActionPreference = 'silentlycontinue'
		$videoLinks = ($genrePage.Links | Where-Object href -Like '*corner*' | Select-Object href).href
		$videoLinks += ($genrePage.Links | Where-Object href -Like '*feature*' | Select-Object href).href
		$videoLinks += ($genrePage.Links | Where-Object href -Like '*lp*' | Select-Object href).href
		$ErrorActionPreference = 'continue'

		#saveGenrePage						#デバッグ用ジャンルページの保存

	} else {
		#タレント名や番組名などURL形式でない場合APIで検索結果からビデオページのLinkを取得
		try { $videoLinks = callTVerSearchAPI ($keyword) } catch { Write-Host 'TVerから検索結果を取得できませんでした。スキップします'; continue }
	}
	return $videoLinks
}

#----------------------------------------------------------------------
#TVerビデオダウンロードのメイン処理
#----------------------------------------------------------------------
function downloadTVerVideo ($genre) {

	$videoName = '' ; $videoPath = '' ; $videoPageLP = '' ;
	$broadcastDate = '' ; $title = '' ; $subtitle = '' ; $media = '' ; $description = '' ;
	$videoInfo = $null
	$ignore = $false ; $skip = $false
	$newVideo = $null

	$ignoreTitles = loadIgnoreList		#ダウンロード対象外番組リストの読み込み
	
	#TVerの番組説明の場合はビデオがないのでスキップ
	if ($videoPage -match '/episode/') {
		Write-Host 'ビデオではなくオンエア情報のようです。スキップします'
		continue			#次のビデオへ
	}

	#URLがすでにリストに存在する場合はスキップ
	try {
		$listMatch = Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoPage -eq $videoPage }
	} catch {
		Write-Host 'リストを読み書きできなかったのでスキップしました'
		continue			#次回再度トライするためリストに追加せずに次のビデオへ
	}
	if ( $null -ne $listMatch ) {
		Write-Host '過去に処理したビデオです。スキップします'
		continue			#次のビデオへ
	}

	#TVerのAPIを叩いてビデオ情報取得
	try {
		$videoInfo = callTVerAPI ($videoID)
	} catch {
		Write-Host 'TVerから情報を取得できませんでした。スキップします'
		continue			#次回再度トライするためリストに追加せずに次のビデオへ
	}

	#取得したビデオ情報を整形
	$broadcastDate = getBroadcastDate ($videoInfo)
	$title = getVideoTitle ($videoInfo)
	$subtitle = getVideoSubTitle ($videoInfo)
	$media = getVideoMedia ($videoInfo)
	$description = getVideoDescription ($videoInfo)
	$videoPageLP = getVideoSeries ($videoInfo)

	#ビデオファイル情報をセット
	$videoName = setVideoName $title $subtitle $broadcastDate		#保存ファイル名を設定
	$savePath = $(Join-Path $downloadBasePath (removeInvalidFileNameChars $title))
	$videoPath = $(Join-Path $savePath $videoName)

	#ビデオ情報のコンソール出力
	writeVideoInfo $videoName $broadcastDate $media $description
	writeVideoDebugInfo $videoPage $videoPageLP $genre $title $subtitle $videoPath $(getTimeStamp)

	#ビデオタイトルが取得できなかった場合はスキップ次のビデオへ
	if ($videoName -eq '.mp4') {
		Write-Host 'ビデオタイトルを特定できませんでした。スキップします'
		continue			#次回再度ダウンロードをトライするためリストに追加せずに次のビデオへ
	}

	#ファイルが既に存在する場合はスキップフラグを立ててリストに書き込み処理へ
	if (Test-Path $videoPath) {
		#チェック済みか調べた上で、スキップ判断
		try {
			$listMatch = Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoPath -eq $videoPath } | Where-Object { $_.videoValidated -eq '1' }
		} catch {
			Write-Host 'リストを読み書きできませんでした。スキップします'
			continue			#次回再度トライするためリストに追加せずに次のビデオへ
		}
		#結果が0件ということは未検証のファイルがあるということ
		if ( $null -eq $listMatch ) {
			Write-Host 'すでにダウンロード済みですが未検証のビデオです。リストに追加します'
			$skip = $true
		} else {
			Write-Host 'すでにダウンロード済み・検証済みのビデオです。スキップします'
			continue			#すでに検証済みなのでリストに追加せずに次のビデオへ
		}
	} else {
		#無視リストに入っている番組の場合はスキップフラグを立ててリストに書き込み処理へ
		foreach ($ignoreTitle in $ignoreTitles) {
			if ($(conv2Narrow $title) -eq $(conv2Narrow $ignoreTitle)) {
				$ignore = $true
				Write-Host '無視リストに入っているビデオです。スキップします'
				#break
				continue			#リストの重複削除のため、無視したものはリスト出力せずに次のビデオへ行くことに
			}
		}
	}

	#スキップフラグが立っているかチェック
	if ($ignore -eq $true) {
		#リストに行追加
		Write-Host '無視したファイルをリストに追加します'
		$newVideo = [pscustomobject]@{
			videoPage      = $videoPage ;
			videoPageLP    = $videoPageLP ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = '-- IGNORED --' ;
			videoPath      = '-- IGNORED --' ;
			videoValidated = '0' ;
		}
	} elseif ($skip -eq $true) {
		Write-Host 'スキップした未検証のファイルをリストに追加します'
		$newVideo = [pscustomobject]@{
			videoPage      = $videoPage ;
			videoPageLP    = $videoPageLP ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = '-- SKIPPED --' ;
			videoPath      = $videoPath ;
			videoValidated = '0' ;
		}
	} else {
		#リストに行追加
		Write-Host 'ダウンロードするファイルをリストに追加します'
		$newVideo = [pscustomobject]@{
			videoPage      = $videoPage ;
			videoPageLP    = $videoPageLP ;
			genre          = $genre ;
			title          = $title ;
			subtitle       = $subtitle ;
			media          = $media ;
			broadcastDate  = $broadcastDate ;
			downloadDate   = $(getTimeStamp) ;
			videoName      = $videoName ;
			videoPath      = $videoPath ;
			videoValidated = '0' ;
		}
	}

	try {
		#リストCSV書き出し
		$newVideo | Export-Csv $listFile -NoTypeInformation -Encoding UTF8 -Append -Force
		Write-Debug 'リストを書き込みました'
	} catch {
		Write-Host 'リストを更新できませんでした。でスキップします'
		continue			#次回再度トライするためリストに追加せずに次のビデオへ
	}

	#スキップや無視対象でなければyt-dlp起動
	if (($ignore -eq $true ) -Or ($skip -eq $true)) {
		continue			#スキップや無視対象は飛ばして次のファイルへ
	} else {
		#保存作ディレクトリがなければ作成
		if (-Not (Test-Path $savePath -PathType Container)) {
			try { $null = New-Item -ItemType directory -Path $savePath } catch {}
		}
		#yt-dlp起動
		try { startYtdlp $videoPath $videoPage $ytdlpPath } catch { Write-Host 'yt-dlpの起動に失敗しました' }
		Start-Sleep -Seconds 10			#10秒待機

	}

}

