###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		共通関数スクリプト
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
#GEO IPの確認
#----------------------------------------------------------------------
function checkGeoIP () {

	if ((Invoke-RestMethod -Uri 'http://ipinfo.io').Country -ne 'JP') {
		Invoke-RestMethod -Uri ('http://ipinfo.io/' + (Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content)
		Write-Host '日本のIPアドレスからしか接続できません。VPN接続してください。' -ForegroundColor Red
		exit
	}

}

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function getTimeStamp {
	$timeStamp = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
	return $timeStamp
}

#----------------------------------------------------------------------
#ffmpegプロセスの確認と待機
#----------------------------------------------------------------------
function getFfmpegProcessList ($parallelDownloadNum) {
	#ffmpegのプロセスが設定値を超えたら一時待機
	try {
		$ffmpegCount = (Get-Process -ErrorAction Ignore -Name ffmpeg).Count
	} catch {
		$ffmpegCount = 0
	}

	Write-Verbose "現在のダウンロードプロセス一覧  ( $ffmpegCount 個 )"

	while ($ffmpegCount -gt $parallelDownloadNum) {
		Write-Host "ダウンロードが $parallelDownloadNum 多重を超えたので一時待機します。 ( $(getTimeStamp) )" -ForegroundColor DarkGray
		Start-Sleep -Seconds 60			#1分待機
		$ffmpegCount = (Get-Process -ErrorAction Ignore -Name ffmpeg).Count
	}
}

#----------------------------------------------------------------------
#ffmpegプロセスの起動
#----------------------------------------------------------------------
function startFfmpeg ($videoName, $videoPath , $videoURL, $genre, $title, $subtitle, $description, $media, $videoPage, $ffmpegPath) {
	$ffmpegArgument = ' -y -i ' + $videoURL `
		+ ' -vcodec copy -acodec copy' `
		+ ' -movflags faststart ' `
		+ ' -metadata genre="' + $genre + '"' `
		+ ' -metadata title="' + $title + '"' `
		+ ' -metadata show="' + $title + '"' `
		+ ' -metadata subtitle="' + $subtitle + '"' `
		+ ' -metadata description="' + $description + '"' `
		+ ' -metadata copyright="' + $media + '"' `
		+ ' -metadata network="' + $media + '"' `
		+ ' -metadata producer="' + $media + '"' `
		+ ' -metadata URL="' + $videoPage + '"' `
		+ ' -metadata year="' + $(Get-Date -UFormat '%Y') + '"' `
		+ ' -metadata creation_time="' + $(getTimeStamp) + '"'
	$ffmpegArgument = $ffmpegArgument + ' "' + $videoPath + '"'
	Write-Debug "ffmpeg起動コマンド:$ffmpegPath $ffmpegArgument"
	$null = Start-Process -FilePath ($ffmpegPath) -ArgumentList $ffmpegArgument -PassThru -WindowStyle Hidden		#Minimize or Hidden
}

#----------------------------------------------------------------------
#ファイル名・フォルダ名に禁止文字の削除
#----------------------------------------------------------------------
Function removeInvalidFileNameChars {
	param(
		[Parameter(Mandatory = $true,
			Position = 0,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true)]
		[String]$Name
	)

	$invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
	$re = '[{0}]' -f [RegEx]::Escape($invalidChars)
	return ($Name -replace $re)
}

#----------------------------------------------------------------------
#全角→半角(英数のみ)
#----------------------------------------------------------------------
function conv2Narrow {

	Param([string]$Text)		#変換元テキストを引数に指定

	# 正規表現のパターン
	$regexAlphaNumeric = '[０-９Ａ-Ｚａ-ｚ＃＄％＆－／［］｛｝（ ）＜＞　]+'

	# MatchEvaluatorデリゲート
	$matchEvaluator = { param([Match]$match) [strings]::StrConv($match, [VbStrConv]::Narrow, 0x0411) }

	# regexクラスのReplaceメソッドを使用。第2引数にMatchEvaluatorデリゲートを指定
	$result = [regex]::Replace($Text, $regexAlphaNumeric, $matchEvaluator)
	return $result
}


#----------------------------------------------------------------------
#CSVファイル読み込み
#	useage : $val = getValue $filePath $keyName
#----------------------------------------------------------------------
function getValue($filePath, $keyName) {
	$hash = @{}

	# ファイルの存在を確認する
	if ((Test-Path $filePath) -eq $false) {
		Write-Error('CSV file not found : ' + $filePath)
		return ''
	}

	# CSVファイルを読み込んで、ハッシュに変換する
	Import-Csv $filePath -Encoding UTF8 | ForEach-Object { $hash.Add($_.name, $_) }

	# キーが存在しているか確認する
	if ($hash.ContainsKey($keyName) -ne $true) {
		Write-Error('Key not found : ' + $keyName)
		return ''
	}

	# value項目を返す
	return $hash[$keyName].value
}

#----------------------------------------------------------------------
#録画リストの情報の追加
#----------------------------------------------------------------------
function insertVideoDB {

	#録画リストに行追加
	Write-Verbose '録画済みリストに行を追加します。'
	$newVideo = [pscustomobject]@{ 
		videoID       = $videoID ;
		videoPage     = $videoPage ;
		genre         = $genre ;
		title         = $title ;
		subtitle      = $subtitle ;
		media         = $media ;
		broadcastDate = $broadcastDate ;
		downloadDate  = $timeStamp
		videoName     = $videoName ;
		videoPath     = $videoPath ;
	}
	#$newVideo
	Write-Debug 'リストに以下を追加'
	$newVideo
	$newVideo | Format-Table

	Write-Debug 'CSVファイルを上書き出力します'
	$newList = @()
	$newList += $videoLists
	$newList += $newVideo
	$newList | Export-Csv $listFile -NoTypeInformation -Encoding UTF8

	return $newList

}

#----------------------------------------------------------------------
#録画リストの情報を検索
#----------------------------------------------------------------------
function updatetVideoDB {

	#	#存在しない検索
	#	$videoLists = Import-Csv $dbPath -Encoding UTF8 | Where-Object { $_.videoID -eq '/feature/f0072557' }
	#	if ($videoLists -eq $null) { Write-Debug '該当なし' }
	#
	#	#存在する検索
	#	$videoLists = Import-Csv $dbPath -Encoding UTF8 | Where-Object { $_.videoID -eq '/feature/f0072556' }
	#	if ($videoLists -ne $null) { Write-Debug '外灯あり' }
	#
	#	Write-Verbose '録画済みリストの既存レコードを更新します。'
	#	$videoLists | Export-Csv 'db/tverlist.csv' -NoTypeInformation -Encoding UTF8

}

#----------------------------------------------------------------------
#録画リストの情報を削除
#----------------------------------------------------------------------
function deletetVideoDB {

}

#----------------------------------------------------------------------
#録画リストの情報を削除
#----------------------------------------------------------------------
function cleanupVideoDB {

	#	# CSVファイルからvideoIDとvideoNameの組み合わせでの重複を削除
	#	Write-Verbose '録画済みリストの重複レコードを削除します。'
	#	$newVideoLists = $videoLists | Sort-Object -Property videoID,videoName -Unique
	#	foreach ($newVideoList in $newVideoLists)
	#	{
	#		#$videoList.videoID
	#	}
	#
	#	return $videoLists

}

#----------------------------------------------------------------------
#Chrome起動パラメータ設定
#----------------------------------------------------------------------
function setChromeAttributes($chromeUserDataPath, [ref]$chromeOptions, $crxPath) {

	$chromeOptions.value = New-Object OpenQA.Selenium.Chrome.ChromeOptions

	$chromeOptions.value.AddArgument("--user-data-dir=$chromeUserDataPath")			#ユーザプロファイル指定
	$chromeOptions.value.AddArgument('--lang=ja-JP')								#日本語(ヘッドレスにすると英語になってしまうらしい)
	$chromeOptions.value.AddArgument('--window-size=1440,900')						#画面サイズ指定
	$chromeOptions.value.AddArgument('--disable-sync')								#データ同期機能を無効
	$chromeOptions.value.AddArgument('--disable-geolocation')						#Geolocation APIを無効
	$chromeOptions.value.AddArgument('--disable-infobars')							#通知バー無効化
	$chromeOptions.value.AddArgument('--disable-java')								#Javaを無効
	#$chromeOptions.value.AddArgument('--headless')									#Chrome をヘッドレスモードで実行する (拡張機能がある場合は使用できない)
	#$chromeOptions.value.AddArgument('--disable-gpu')								#ヘッドレスの際に暫定的に必要なフラグ
	#$chromeOptions.value.AddArgument('--remote-debugging-port=9222')				#ヘッドレスの際に。使い方わからないけど。。。
	$chromeOptions.value.AddArgument('--dns-prefetch-disable')						#DNSプリフェッチを無効
	$chromeOptions.value.AddArgument('--disable-custom-jumplist')					#Windows 7においてカスタムジャンプリストを無効
	$chromeOptions.value.AddArgument('--disable-desktop-notifications')				#デスクトップ通知を無効
	$chromeOptions.value.AddArgument('--disable-application-cache')					#HTML5のApplication Cacheを無効
	$chromeOptions.value.AddArgument('--disable-remote-fonts')						#リモートWebフォントのサポートを無効
	$chromeOptions.value.AddArgument('--disable-content-prefetch')					#Link prefetchingを無効
	$chromeOptions.value.AddArgument('--disable-logging')							#ログ出力を無効にする
	$chromeOptions.value.AddArgument('--disable-metrics')							#
	$chromeOptions.value.AddArgument('--disable-metrics-reporting')					#
	$chromeOptions.value.AddArgument('--disable-hang-monitor')						#「ページ応答無し」のダイアログの表示を抑制
	$chromeOptions.value.AddArgument('--no-default-browser-check')					#デフォルトブラウザチェックをしない
	$chromeOptions.value.AddArgument('--enable-easy-off-store-extension-install')	#公式以外からの拡張機能のインストールを有効化
	$chromeOptions.value.AddExtensions("$crxPath")									#ビデオURLをクリップボードにコピーする拡張機能
	$chromeOptions.value.AddUserProfilePreference('credentials_enable_service', $false)
	$chromeOptions.value.AddUserProfilePreference('profile.password_manager_enabled', $false)

}

#----------------------------------------------------------------------
#URLをChromeにわたす
#----------------------------------------------------------------------
function openVideo ([ref]$chromeDriver, $videoPage) {
	for ($i = 0; $i -lt 30; $i++) {
		try {
			$chromeDriver.value.url = $videoPage		#ChromeにURLを渡す
			break
		} catch {
			Write-Verbose 'ChromeにURLを渡せませんでした。再試行します。'
		}
		Start-Sleep -Milliseconds 1000
	}
}

#----------------------------------------------------------------------
#ページ読み込み待ち、再生ボタンクリック、クリップボードにビデオURLを入れる
#----------------------------------------------------------------------
function playVideo([ref]$chromeDriver) {
	$videoURL = ''
	#-----------------------------------
	#ページ読み込み待ちループここから
	for ($i = 0; $i -lt 30; $i++) {
		try {
			$element = $chromeDriver.value.FindElementByXpath('/html/body')
			break
		} catch {
			Write-Verbose '読み込み完了していないため再生ボタン押せませんでした。再試行します。'
		}
		Start-Sleep -Milliseconds 1000
	}
	$element.Click() # ; $element.SendKeys($chromeDriver.value.keys.Enter)

	Write-Verbose 'ビデオページを読み込みました。ビデオURLを解析中です。'

	for ($i = 0; $i -lt 30; $i++) {
		#クリップボードにURLがが入ったら抜ける
		$videoURL = Get-Clipboard -Format Text
		$regexURL = '([a-zA-Z]{3,})://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'		#正規表現URLパターン
		if ($videoURL -notmatch $regexURL) {
		} else {
			break		 #ループを抜ける
		}
		Start-Sleep -Milliseconds 1000
	}

	$chromeDriver.value.PageSource > $(Join-Path $debugDir 'last_video.html')

	return $videoURL

	#ページ読み込み待ちループここまで
	#-----------------------------------
}

#----------------------------------------------------------------------
#Chrome終了
#----------------------------------------------------------------------
function stopChrome ([ref]$chromeDriver) {

	$chromeDriver.value.Close()
	$chromeDriver.value.Dispose()
	$chromeDriver.value.Quit()
}
#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function setVideoName ($title, $subtitle, $broadcastDate) {
	if ($subtitle -eq '') {
		if ($broadcastDate -eq '') {
			$videoName = $title + '.mp4'
		} else {
			$videoName = $title + ' ' + $broadcastDate + '.mp4'
		}
	} else {
		$videoName = $title + ' ' + $broadcastDate + ' ' + $subtitle + '.mp4'
	}
	$videoName = removeInvalidFileNameChars (conv2Narrow $videoName)		#windowsでファイル名にできない文字列を除去
	return $videoName
}