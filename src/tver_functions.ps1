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
	$webClient.DownloadFile($genreLink, $genreFile)
}

