###################################################################################
#  tverrec : TVerビデオダウンローダ
#		TVer固有関数スクリプト
###################################################################################

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile { 

	if (Test-Path $chromeUserDataPath -PathType Container) {} else { Write-Error 'ChromeのUserDataフォルダが存在しません。終了します。' ; exit }
	if (Test-Path $saveBasePath -PathType Container) {} else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit }
	if (Test-Path $ffmpegPath -PathType Leaf) {} else { Write-Error 'ffmpeg.exeが存在しません。終了します。' ; exit }
	if (Test-Path $crxPath -PathType Leaf) {} else { Write-Error 'tver.crxが存在しません。終了します。' ; exit }
	if (Test-Path $adbPath -PathType Leaf) {} else { Write-Error 'TVerEnqueteDisabler.crxが存在しません。終了します。' Red ; exit }
	if (Test-Path $webDriverPath -PathType Leaf) {} else { Write-Error 'WebDriver.dllが存在しません。終了します。' ; exit }
	if (Test-Path $webDriverSupportPath -PathType Leaf) {} else { Write-Error 'WebDriver.Support.dllが存在しません。終了します。' ; exit }
	if (Test-Path $seleniumPath -PathType Leaf) {} else { Write-Error 'Selenium.WebDriverBackedSelenium.dllが存在しません。終了します。' ; exit }
	if (Test-Path $iniFile -PathType Leaf) {} else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit }
	if (Test-Path $keywordFile -PathType Leaf) {} else { Write-Error 'ダウンロード対象ジャンリリストが存在しません。終了します。' ; exit }
	if (Test-Path $ignoreFile -PathType Leaf) {} else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit }
	if (Test-Path $listFile -PathType Leaf) {} else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit }

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

#----------------------------------------------------------------------
#ビデオタイトル取得
#----------------------------------------------------------------------
function getVideoTitle ([ref]$chromeDriver) {
	if ( $chromeDriver.value.PageSource -match 'id="program_title" type="hidden" value="(.+?)"') {
		$title = $Matches[1].Replace('&amp;', '&').Replace('｜民放公式テレビポータル「TVer（ティーバー）」 - 無料でビデオ見放題', '').trim()
	} else {
		$title = ''
	}
	return (conv2Narrow $title)
}

#----------------------------------------------------------------------
#ビデオサブタイトル取得
#----------------------------------------------------------------------
function getVideoSubtitle ([ref]$chromeDriver) {
	if ( $chromeDriver.value.PageSource -match 'id="program_subtitle" type="hidden" value="(.+?)"') {
		$subtitle = $Matches[1].Replace('&amp;', '&').trim()
	} else {
		$subtitle = ''
	}
	return (conv2Narrow $subtitle)
}

#----------------------------------------------------------------------
#テレビ局取得
#----------------------------------------------------------------------
function getVideoMedia ([ref]$chromeDriver) {
	if ( $chromeDriver.value.PageSource -match 'id="media" type="hidden" value="(.+?)"') {
		$media = $Matches[1].Replace('&amp;', '&').trim()
	} else {
		$media = ''
	}
	return (conv2Narrow $media)
}

#----------------------------------------------------------------------
#放送日
#----------------------------------------------------------------------
function getVideoBroadcastDate ([ref]$chromeDriver) {
	if ( $chromeDriver.value.PageSource -match ' class="tv">(.+?)(　| )(.+?)</span>' ) {
		$broadcastDate = $Matches[3].Replace('&amp;', '&').Replace('ほか　', '').Replace('分', '').trim()
	} else {
		$broadcastDate = ''
	}
	return (conv2Narrow $broadcastDate)
}

#----------------------------------------------------------------------
#説明取得
#----------------------------------------------------------------------
function getVideoDescription ([ref]$chromeDriver) {
	$description = $chromeDriver.value.FindElementByClassName('description').Text
	$description = $description.Replace('&amp;', '&').trim()
	return (conv2Narrow $description)
}

#----------------------------------------------------------------------
#説明取得
#----------------------------------------------------------------------
function writeVideoInfo ($videoName, $broadcastDate, $media, $description ) {
	Write-Host "ビデオ名    :$videoName"
	Write-Host "放送日      :$broadcastDate"
	Write-Host "テレビ局    :$media"
	Write-Host "ビデオ説明  :$description"
}
#----------------------------------------------------------------------
#説明取得
#----------------------------------------------------------------------
function writeVideoDebugInfo ($videoID, $videoPage, $genre, $title, $subtitle, $videoPath, $timeStamp, $videoURL ) {
	Write-Debug	"ビデオID    :$videoID"
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
