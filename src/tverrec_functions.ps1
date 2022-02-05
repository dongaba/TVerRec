###################################################################################
#  tverrec : TVerビデオダウンローダ
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
#デバッグ用ジャンルページの保存
#----------------------------------------------------------------------
function saveGenrePage {
	$genreFile = $($genre + '.html') -replace '(\?|\!|>|<|:|\\|/|\|)', '-'
	$genreFile = $(Join-Path $debugDir (removeInvalidFileNameChars $genreFile))
	$webClient = New-Object System.Net.WebClient
	$webClient.Encoding = [System.Text.Encoding]::UTF8
	$webClient.DownloadFile($genreLink, $genreFile)
}

#----------------------------------------------------------------------
#ビデオタイトル取得
#----------------------------------------------------------------------
function getVideoTitle ([ref]$chromeDriver) {
	Write-Verbose 'ビデオタイトルを解析中です。'
	if ( $chromeDriver.value.PageSource -match 'id="program_title" type="hidden" value="(.+?)">') {
		$title = $Matches[1].Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！')
		$title = $title.Replace('｜民放公式テレビポータル「TVer（ティーバー）」 - 無料でビデオ見放題', '').trim()
	} elseif ($chromeDriver.value.PageSource -match '<h2>(.+?)</h2>') {
		$title = $Matches[1].Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！')
		$title = $title.Replace('｜民放公式テレビポータル「TVer（ティーバー）」 - 無料でビデオ見放題', '').trim()
	} else {
		$title = ''
	}
	if ($title.length -gt 70) { $title = $title.Substring(0, 70) + '……' }
	return (conv2Narrow $title)
}

#----------------------------------------------------------------------
#ビデオサブタイトル取得
#----------------------------------------------------------------------
function getVideoSubtitle ([ref]$chromeDriver) {
	Write-Verbose 'ビデオサブタイトルを解析中です。'
	if ( $chromeDriver.value.PageSource -match 'id="program_subtitle" type="hidden" value="(.+?)">') {
		$subtitle = $Matches[1].Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！').trim()
	} elseif ( $chromeDriver.value.PageSource -match '<p class="video-subtitle">(.+?)</p>') {
		$subtitle = $Matches[1].Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！').trim()
	} else {
		$subtitle = ''
	}
	if ($subtitle.length -gt 70) { $subtitle = $subtitle.Substring(0, 70) + '……' }
	return (conv2Narrow $subtitle)
}

#----------------------------------------------------------------------
#テレビ局取得
#----------------------------------------------------------------------
function getVideoMedia ([ref]$chromeDriver) {
	Write-Verbose 'テレビ局名を解析中です。'
	if ( $chromeDriver.value.PageSource -match 'id="media" type="hidden" value="(.+?)">') {
		$media = $Matches[1].Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').trim()
	} else {
		$media = ''
	}
	return (conv2Narrow $media)
}

#----------------------------------------------------------------------
#放送日
#----------------------------------------------------------------------
function getVideoBroadcastDate ([ref]$chromeDriver) {
	Write-Verbose '放送日を解析中です。'
	if ( $chromeDriver.value.PageSource -match ' class="tv">(.+?)(　| )(.+?)</span>' ) {
		$broadcastDate = $Matches[3].Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '')
		$broadcastDate = $broadcastDate.Replace('ほか　', '').Replace('分', '').trim()
		if ($broadcastDate -match '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
			$broadcastYMD = [DateTime]::ParseExact((Get-Date -Format 'yyyy') + $Matches[1].padleft(2, '0') + $Matches[3].padleft(2, '0'), 'yyyyMMdd', $null)
			if ((Get-Date).AddDays(+1) -lt $broadcastYMD) {
				$broadcastDate = (Get-Date).AddYears(-1).ToString('yyyy') + '年' + $Matches[1].padleft(2, '0') + $Matches[2] + $Matches[3].padleft(2, '0') + $Matches[4] + $Matches[5] + $Matches[6] 
			} else {
				$broadcastDate = (Get-Date).ToString('yyyy') + '年' + $Matches[1].padleft(2, '0') + $Matches[2] + $Matches[3].padleft(2, '0') + $Matches[4] + $Matches[5] + $Matches[6] 
			}
		} 
	} else {
		$broadcastDate = ''
	}
	return (conv2Narrow $broadcastDate)
}

#----------------------------------------------------------------------
#説明取得
#----------------------------------------------------------------------
function getVideoDescription ([ref]$chromeDriver) {
	Write-Verbose '番組説明を解析中です。'
	try {
		$description = $chromeDriver.value.FindElementByClassName('description').Text
		$description = $description.Replace('&amp;', '&').trim()
	} catch {
		$description = ''
	}
	return (conv2Narrow $description)
}

#----------------------------------------------------------------------
#ビデオ情報表示
#----------------------------------------------------------------------
function writeVideoInfo ($videoName, $broadcastDate, $media, $description ) {
	Write-Host "ビデオ名    :$videoName"
	Write-Host "放送日      :$broadcastDate"
	Write-Host "テレビ局    :$media"
	Write-Host "ビデオ説明  :$description"
}
#----------------------------------------------------------------------
#ビデオ情報デバッグ表示
#----------------------------------------------------------------------
function writeVideoDebugInfo ($videoPage, $genre, $title, $subtitle, $videoPath, $timeStamp, $videoURL ) {
	Write-Debug	"ビデオページ:$videoPage"
	Write-Debug "ジャンル    :$genre"
	Write-Debug "タイトル    :$title"
	Write-Debug "サブタイトル:$subtitle"
	Write-Debug "ファイル    :$videoPath"
	Write-Debug "取得日付    :$timeStamp"
	Write-Debug "ビデオURL   :$videoURL"
}


#----------------------------------------------------------------------
#録画リストの情報の取得
#----------------------------------------------------------------------
function selectVideoDB {

	#録画リストCSV読み込み
	Write-Debug '録画済みリストを読み込みます。'
	$videoLists = Import-Csv $listFile -Encoding UTF8
	$videoLists | Format-Table

	#CSV内容表示
	#$videoLists[0].videoID				#1件目のvideIDを表示
	#$videoLists						#全件を表示(オブジェクト形式)
	#$videoLists | Format-Table			#全件を表示(表形式)
	#$videoLists | ogv					#全件を表示(GUI形式)

	return $videoLists

}
