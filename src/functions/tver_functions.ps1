###################################################################################
#  TVerRec : TVerダウンローダ
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

#----------------------------------------------------------------------
#TVerRec最新化確認
#----------------------------------------------------------------------
function checkLatestTVerRec {
	[OutputType([System.Void])]
	Param ()

	$progressPreference = 'silentlyContinue'
	goAnal -Event 'launch'
	$local:versionUp = $false

	#TVerRecの最新バージョン取得
	$local:repo = 'dongaba/TVerRec'
	$local:releases = "https://api.github.com/repos/$($local:repo)/releases"
	try {
		$local:appReleases = (Invoke-RestMethod `
				-Uri $local:releases `
				-Method Get `
		)[0]
	} catch { return }

	#GitHub側最新バージョンの整形
	# v1.2.3 → 1.2.3
	$local:latestVersion = $($local:appReleases)[0].Tag_Name.Trim('v', ' ')
	# v1.2.3 beta 4 → 1.2.3
	$local:latestMajorVersion = $local:latestVersion.split(' ')[0]

	#ローカル側バージョンの整形
	# v1.2.3 beta 4 → 1.2.3
	$local:appMajorVersion = $script:appVersion.split(' ')[0]

	#バージョン判定
	if ($local:latestMajorVersion -gt $local:appMajorVersion ) {
		#最新バージョンのメジャーバージョンが大きい場合
		$local:versionUp = $true
	} elseif ($local:latestMajorVersion -eq $local:appMajorVersion ) {
		if ( $local:appMajorVersion -ne $script:appVersion) {
			#マイナーバージョンが設定されている場合
			$local:versionUp = $true
		} else {
			#バージョンが完全に一致する場合
			$local:versionUp = $false
		}
	} else {
		#ローカルバージョンの方が新しい場合
		$local:versionUp = $false
	}

	$progressPreference = 'Continue'

	#バージョンアップメッセージ
	if ($local:versionUp -eq $true ) {
		Out-Msg 'TVerRecの更新版があるようです。' -Fg 'Green'
		Out-Msg '' -Fg 'Green'
		Out-Msg "　Current Version $script:appVersion " -Fg 'Green'
		Out-Msg "　Latest Version  $local:latestVersion" -Fg 'Green'
		Out-Msg '' -Fg 'Green'

		#変更履歴の表示
		for ($i = 0; $i -lt $local:appReleases.Length; $i++) {
			if ($local:appReleases[$i].Tag_Name.Trim('v', ' ') -ge $local:appMajorVersion ) {
				Out-Msg '----------------------------------------------------------------------' -Fg 'Green'
				Out-Msg "$($local:appReleases[$i].Tag_Name.Trim('v', ' ')) の更新内容" -Fg 'Green'
				Out-Msg '----------------------------------------------------------------------' -Fg 'Green'
				Out-Msg $local:appReleases[$i].body.Replace('###', '■') -Fg 'Green'
				Out-Msg '' -Fg 'Green'
			}
		}

		#アップデート実行
		Write-Output '60秒後にTVerRecをアップデートします。中止したい場合は Ctrl+C で中断してください'
		for ($i = 60; $i -gt 0; $i--) {
			Write-Output "  $i"
			Start-Sleep 1
		}
		. $(Join-Path $script:scriptRoot '/functions/update_tverrec.ps1')

		#再起動のため強制終了 ; exit 1

	}

}

#----------------------------------------------------------------------
#ytdlの最新化確認
#----------------------------------------------------------------------
function checkLatestYtdl {
	[OutputType([System.Void])]
	Param ()

	$progressPreference = 'silentlyContinue'

	if ($script:disableUpdateYoutubedl -eq $false) {
		if ($script:preferredYoutubedl -eq 'yt-dlp') {
			. $(Convert-Path (Join-Path $scriptRoot './functions/update_yt-dlp.ps1'))
		} elseif ($script:preferredYoutubedl -eq 'ytdl-patched') {
			. $(Convert-Path (Join-Path $scriptRoot './functions/update_ytdl-patched.ps1'))
		} else {
			Write-Error 'youtube-dlの取得元の指定が無効です' ; exit 1
		}
		if ($? -eq $false) { Write-Error 'youtube-dlの更新に失敗しました' ; exit 1 }
	} else { }

	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	[OutputType([System.Void])]
	Param ()

	$progressPreference = 'silentlyContinue'

	if ($script:disableUpdateFfmpeg -eq $false) {
		. $(Convert-Path (Join-Path $scriptRoot './functions/update_ffmpeg.ps1'))
		if ($? -eq $false) { Write-Error 'ffmpegの更新に失敗しました' ; exit 1 }
	} else { }

	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	[OutputType([System.Void])]
	Param ()

	if (!(Test-Path $script:downloadBaseDir -PathType Container)) {
		Write-Error '番組ダウンロード先ディレクトリが存在しません。終了します。' ; exit 1
	}
	if (!(Test-Path $script:downloadWorkDir -PathType Container)) {
		Write-Error 'ダウンロード作業ディレクトリが存在しません。終了します。' ; exit 1
	}
	if (!(Test-Path $script:ytdlPath -PathType Leaf)) {
		Write-Error 'youtube-dlが存在しません。終了します。' ; exit 1
	}
	if (!(Test-Path $script:ffmpegPath -PathType Leaf)) {
		Write-Error 'ffmpegが存在しません。終了します。' ; exit 1
	}
	if ((!(Test-Path $script:ffprobePath -PathType Leaf)) `
			-And ($script:simplifiedValidation -eq $true)) {
		Write-Error 'ffprobeが存在しません。終了します。' ; exit 1
	}

	#過去のバージョンで使用していたファイルを削除、または移行
	#tver.lockをhistory.lockに移行(v2.6.5→v2.6.6)
	if (Test-Path $(Join-Path $script:dbDir 'tver.lock') -PathType Leaf) {
		Move-Item `
			-Path $(Join-Path $script:dbDir 'tver.lock') `
			-Destination $script:historyLockFilePath `
			-Force
	}
	#tver.sample.csvをhistory.sample.csvに移行(v2.6.5→v2.6.6)
	if (Test-Path $(Join-Path $script:dbDir 'tver.sample.csv') -PathType Leaf) {
		Move-Item `
			-Path $(Join-Path $script:dbDir 'tver.sample.csv') `
			-Destination $script:historyFilePath `
			-Force
	}
	#tver.csvをhistory.csvに移行(v2.6.5→v2.6.6)
	if (Test-Path $(Join-Path $script:dbDir 'tver.csv') -PathType Leaf) {
		Rename-Item `
			-Path $(Join-Path $script:dbDir 'tver.csv') `
			-NewName history.csv `
			-Force
	}

	#ファイルが存在しない場合はサンプルファイルをコピー
	if (!(Test-Path $script:keywordFilePath -PathType Leaf)) {
		if (!(Test-Path $script:keywordFileSamplePath -PathType Leaf)) {
			Write-Error 'ダウンロード対象キーワードファイル(サンプル)が存在しません。終了します。' ; exit 1
		}
		Copy-Item `
			-Path $script:keywordFileSamplePath `
			-Destination $script:keywordFilePath `
			-Force
	}
	if (!(Test-Path $script:ignoreFilePath -PathType Leaf)) {
		if (!(Test-Path $script:ignoreFileSamplePath -PathType Leaf)) {
			Write-Error 'ダウンロード対象外番組ファイル(サンプル)が存在しません。終了します。' ; exit 1
		}
		Copy-Item `
			-Path $script:ignoreFileSamplePath `
			-Destination $script:ignoreFilePath `
			-Force
	}
	if (!(Test-Path $script:historyFilePath -PathType Leaf)) {
		if (!(Test-Path $script:historyFileSamplePath -PathType Leaf)) {
			Write-Error 'ダウンロード履歴ファイル(サンプル)が存在しません。終了します。' ; exit 1
		}
		Copy-Item `
			-Path $script:historyFileSamplePath `
			-Destination $script:historyFilePath `
			-Force
	}
	if (!(Test-Path $script:listFilePath -PathType Leaf)) {
		if (!(Test-Path $script:listFileSamplePath -PathType Leaf)) {
			Write-Error 'ダウンロードリストファイル(サンプル)が存在しません。終了します。' ; exit 1
		}
		Copy-Item `
			-Path $script:listFileSamplePath `
			-Destination $script:listFilePath `
			-Force
	}

	#念のためチェック
	if (!(Test-Path $script:keywordFilePath -PathType Leaf)) {
		Write-Error 'ダウンロード対象キーワードファイルが存在しません。終了します。' ; exit 1
	}
	if (!(Test-Path $script:ignoreFilePath -PathType Leaf)) {
		Write-Error 'ダウンロード対象外番組ファイルが存在しません。終了します。' ; exit 1
	}
	if (!(Test-Path $script:historyFilePath -PathType Leaf)) {
		Write-Error 'ダウンロード履歴ファイルが存在しません。終了します。' ; exit 1
	}
	if (!(Test-Path $script:listFilePath -PathType Leaf)) {
		Write-Error 'ダウンロードリストファイルが存在しません。終了します。' ; exit 1
	}
}

#----------------------------------------------------------------------
#ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	[OutputType([String[]])]
	Param ()

	try {
		$local:keywordNames = `
			[String[]](Get-Content $script:keywordFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `	#空行を除く
			| Where-Object { !($_ -match '^#.*$') })	#コメント行を除く
	} catch {
		Out-Msg 'ダウンロード対象キーワードの読み込みに失敗しました' -Fg 'Green' ; exit 1
	}

	return $local:keywordNames
}

#----------------------------------------------------------------------
#ダウンロードリストの読み込み
#----------------------------------------------------------------------
function loadDownloadList {
	[OutputType([String[]])]
	Param ()

	try {
		#ロックファイルをロック
		while ($(fileLock $script:listLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:videoLinks = `
			Import-Csv `
			-Path $script:listFilePath `
			-Encoding UTF8 `
		| Select-Object episodeID `						#EpisodeIDのみ抽出
		| Where-Object { !($_ -match '^\s*$') } `		#空行を除く
		| Where-Object { !($_.episodeID -match '^#') }	#ダウンロード対象外を除く
	} catch {
		Out-Msg 'ダウンロードリストの読み込みに失敗しました' -Fg 'Green' ; exit 1
	} finally {
		$null = fileUnlock $script:listLockFilePath
	}

	return $local:videoLinks
}

#----------------------------------------------------------------------
#ダウンロード対象外番組の読み込み
#----------------------------------------------------------------------
function getIgnoreList {
	[OutputType([String[]])]
	Param ()

	try {
		$local:ignoreTitles = `
			[String[]](Get-Content $script:ignoreFilePath -Encoding UTF8 `
			| Where-Object { !($_ -match '^\s*$') } `		#空行を除く
			| Where-Object { !($_ -match '^;.*$') })		#コメント行を除く
	} catch {
		Out-Msg 'ダウンロード対象外の読み込みに失敗しました' -Fg 'Green' ; exit 1
	}

	return $local:ignoreTitles
}

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function getToken () {
	[OutputType([System.Void])]
	Param ()

	$local:tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$local:requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded'
	}
	$local:requestBody = 'device_type=pc'
	$local:tokenResponse = `
		Invoke-RestMethod `
		-Uri $local:tverTokenURL `
		-Method 'POST' `
		-Headers $local:requestHeader `
		-Body $local:requestBody `
		-TimeoutSec $script:timeoutSec
	$script:platformUID = $local:tokenResponse.Result.platform_uid
	$script:platformToken = $local:tokenResponse.Result.platform_token
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function getVideoLinksFromKeyword {
	[OutputType([System.Object[]])]
	Param ([String]$local:keywordName)

	$script:requestHeader = @{
		'x-tver-platform-type' = 'web'
		'Origin'               = 'https://tver.jp'
		'Referer'              = 'https://tver.jp'
	}
	$script:tverLinks = @()
	if ( $local:keywordName.IndexOf('https://tver.jp') -eq 0) {
		#URL形式の場合番組ページのLinkを取得
		try { $local:keywordNamePage = Invoke-WebRequest `
				-Uri $local:keywordName `
				-TimeoutSec $script:timeoutSec
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:00' -Fg 'Green'
			continue
		}
		try {
			$script:tverLinks = (
				$local:keywordNamePage.Links `
				| Where-Object { `
					(href -Like '*lp*') `
						-Or (href -Like '*corner*') `
						-Or (href -Like '*series*') `
						-Or (href -Like '*episode*') `
						-Or (href -Like '*feature*')`
				} `
				| Select-Object href
			).href
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:01' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('series/') -eq 0) {
		#番組IDによる番組検索から番組ページのLinkを取得
		$local:seriesID = trimComment($local:keywordName).Replace('series/', '').Trim()
		goAnal -Event 'search' -Type 'series' -ID $local:seriesID
		try {
			$script:tverLinks = getLinkFromSeriesID ($local:seriesID)
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:02' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('talents/') -eq 0) {
		#タレントIDによるタレント検索から番組ページのLinkを取得
		$local:talentID = trimComment($local:keywordName).Replace('talents/', '').Trim()
		goAnal -Event 'search' -Type 'talent' -ID $local:talentID
		try {
			$script:tverLinks = getLinkFromTalentID ($local:talentID)
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:03' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('tag/') -eq 0) {
		#ジャンルなどのTag情報から番組ページのLinkを取得
		$local:tagID = trimComment($local:keywordName).Replace('tag/', '').Trim()
		goAnal -Event 'search' -Type 'tag' -ID $local:tagID
		try {
			$script:tverLinks = getLinkFromTag ($local:tagID)
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:04' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('new/') -eq 0) {
		#新着番組から番組ページのLinkを取得
		$local:genre = trimComment($local:keywordName).Replace('new/', '').Trim()
		goAnal -Event 'search' -Type 'new' -ID $local:genre
		try {
			$script:tverLinks = getLinkFromNew ($local:genre)
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:05' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('ranking/') -eq 0) {
		#ランキングによる番組ページのLinkを取得
		$local:genre = trimComment($local:keywordName).Replace('ranking/', '').Trim()
		goAnal -Event 'search' -Type 'ranking' -ID $local:genre
		try {
			$script:tverLinks = getLinkFromRanking ($local:genre)
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:06' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('toppage') -eq 0) {
		#トップページから番組ページのLinkを取得
		goAnal -Event 'search' -Type 'toppage'
		try {
			$script:tverLinks = getLinkFromTopPage
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:07' -Fg 'Green'
			continue
		}

	} elseif ($local:keywordName.IndexOf('title/') -eq 0) {
		#番組名による新着検索から番組ページのLinkを取得
		$local:titleName = trimComment($local:keywordName).Replace('title/', '').Trim()
		goAnal -Event 'search' -Type 'title' -ID $local:titleName
		Out-Msg '　番組名検索は廃止されました。スキップします Err:08' -Fg 'Green'
		continue

	} else {
		#タレント名や番組名などURL形式でない場合APIで検索結果から番組ページのLinkを取得
		goAnal -Event 'search' -Type 'free' -ID $local:keywordName
		try {
			$script:tverLinks = getLinkFromFreeKeyword ($local:keywordName)
		} catch {
			Out-Msg '　情報取得エラー。スキップします Err:09' -Fg 'Green'
			continue
		}
	}

	$script:tverLinks = $script:tverLinks | Sort-Object | Get-Unique

	if ($script:tverLinks -is [Array]) {
		for ( $i = 0; $i -lt $script:tverLinks.Length; $i++) {
			$script:tverLinks[$i] = 'https://tver.jp' + $script:tverLinks[$i]
		}
	} elseif ($null -ne $script:tverLinks) {
		$script:tverLinks = 'https://tver.jp' + $script:tverLinks
	}

	return $script:tverLinks
}

#----------------------------------------------------------------------
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSeriesID {
	[OutputType([System.Object[]])]
	Param ([String]$local:seriesID)

	$local:seasonLinks = @()
	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/'

	#まずはSeries→Seasonに変換
	$local:callSearchURL =
	$local:callSearchBaseURL + $local:seriesID `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		$local:seasonLinks += $local:searchResults[$i].Content.Id
	}

	#次にSeason→Episodeに変換
	foreach ( $local:seasonLink in $local:seasonLinks) {
		$script:tverLinks += getLinkFromSeasonID ($local:seasonLink)
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTalentID {
	[OutputType([System.Object[]])]
	Param ([String]$local:talentID)

	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callTalentEpisode/'
	$local:callSearchURL = `
		$local:callSearchBaseURL + $local:talentID `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTag {
	[OutputType([System.Object[]])]
	Param ([String]$local:tagID)

	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callTagSearch'
	$local:callSearchURL = `
		$local:callSearchBaseURL + '/' + $local:tagID `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromNew {
	[OutputType([System.Object[]])]
	Param ([String]$local:genre)

	$local:callSearchBaseURL = `
		'https://service-api.tver.jp/api/v1/callNewerDetail'
	$local:callSearchURL = `
		$local:callSearchBaseURL + '/' + $local:genre `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromRanking {
	[OutputType([System.Object[]])]
	Param ([String]$local:genre)

	$local:callSearchBaseURL = `
		'https://service-api.tver.jp/api/v1/callEpisodeRanking'
	if ($local:genre -eq 'all') {
		$local:callSearchURL = `
			$local:callSearchBaseURL `
			+ '?platform_uid=' + $script:platformUID `
			+ '&platform_token=' + $script:platformToken
	} else {
		$local:callSearchURL = `
			$local:callSearchBaseURL `
			+ 'Detail/' + $local:genre `
			+ '?platform_uid=' + $script:platformUID `
			+ '&platform_token=' + $script:platformToken
	}
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromTopPage {
	[OutputType([System.Object[]])]
	Param ()

	$local:callSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callHome'
	$local:callSearchURL = `
		$local:callSearchBaseURL + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Components
	$local:searchResultCount = $local:searchResults.Length
	for ($i = 0; $i -lt $local:searchResultCount; $i++) {
		if ($local:searchResults[$i].Type -eq 'horizontal' `
				-Or $local:searchResults[$i].Type -eq 'ranking' `
				-Or $local:searchResults[$i].Type -eq 'talents' `
				-Or $local:searchResults[$i].type -eq 'billboard' `
				-Or $local:searchResults[$i].type -eq 'episodeRanking' `
				-Or $local:searchResults[$i].type -eq 'newer' `
				-Or $local:searchResults[$i].type -eq 'ender' `
				-Or $local:searchResults[$i].type -eq 'talent' `
				-Or $local:searchResults[$i].type -eq 'special') {
			#横スクロール型 or 総合ランキング or 注目タレント or 特集
			$local:searchSectionResultCount = $local:searchResults[$i].Contents.Length
			for ($j = 0; $j -lt $local:searchSectionResultCount; $j++) {
				switch ($local:searchResults[$i].contents[$j].type) {
					'episode' {
						$script:tverLinks += `
							'/episodes/' + $local:searchResults[$i].contents[$j].Content.Id
						break
					}
					'season' {
						$script:tverLinks += `
							getLinkFromSeasonID ($local:searchResults[$i].contents[$j].Content.Id)
						break
					}
					'series' {
						$script:tverLinks += `
							getLinkFromSeriesID ($local:searchResults[$i].contents[$j].Content.Id)
						break
					}
					'talent' {
						$script:tverLinks += `
							getLinkFromTalentID ($local:searchResults[$i].contents[$j].Content.Id)
						break
					}
					'live' { break }
					'specialMain' {
						#特集ページ。パース方法不明
						#https://tver.jp/specials/$($local:searchResults[4].contents.content.id)
						#$local:searchResults[4].contents.content.id
						#callSpecialContentsDetailを再帰的に呼び出す必要がありそう
						#https://platform-api.tver.jp/service/api/v1/callSpecialContents/drama-digest?require_data=mylist[special][drama-digest]
						#を呼んで得られたspecialContents>[TypeがSpecialのもの]>contents.content.idを使って、再度以下のように呼び出し。(以下の例ではsum22-latterhal)
						#https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/sum22-latterhalf?sort_key=newer&require_data=mylist, later
						#他にはないと思われるが念のため
						break
					}
					default {
						$script:tverLinks += `
							'/' + $local:searchResults[$i].contents[$j].type `
							+ '/' + $local:searchResults[$i].contents[$j].Content.Id
						break
					}
				}
			}
		} elseif ($local:searchResults[$i].type -eq 'topics') {
			$local:searchSectionResultCount = $local:searchResults[$i].Contents.Length
			for ($j = 0; $j -lt $local:searchSectionResultCount; $j++) {
				$local:searchSectionResultCount = $local:searchResults[$i].Contents.Length
				for ($j = 0; $j -lt $local:searchSectionResultCount; $j++) {
					switch ($local:searchResults[$i].contents[$j].Content.Content.type) {
						'episode' {
							$script:tverLinks += `
								'/episodes/' + $local:searchResults[$i].contents[$j].Content.Content.Content.Id
							break
						}
						'season' {
							$script:tverLinks += `
								getLinkFromSeasonID ($local:searchResults[$i].contents[$j].Content.Content.Content.Id)
							break
						}
						'series' {
							$script:tverLinks += `
								getLinkFromSeriesID ($local:searchResults[$i].contents[$j].Content.Content.Content.Id)
							break
						}
						'talent' {
							$script:tverLinks += `
								getLinkFromTalentID ($local:searchResults[$i].contents[$j].Content.Content.Content.Id)
							break
						}
						'live' { break }
						#他にはないと思われるが念のため
						default {
							$script:tverLinks += `
								'/' + $local:searchResults[$i].contents[$j].type `
								+ '/' + $local:searchResults[$i].contents[$j].Content.Content.Content.Id
							break
						}
					}
				}
			}
		} elseif ($local:searchResults[$i].type -eq 'banner') {
			#広告
			#URLは $($local:searchResults[$i].contents.content.targetURL)
			#$local:searchResults[$i].contents.content.targetURL
		} elseif ($local:searchResults[$i].type -eq 'resume') {
			#続きを見る
			#ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} else {}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function getLinkFromFreeKeyword {
	[OutputType([System.Object[]])]
	Param ([String]$local:keywordName)

	$local:tverSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'
	$local:tverSearchURL = `
		$local:tverSearchBaseURL `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken `
		+ '&keyword=' + $local:keywordName
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:tverSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += '/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function getLinkFromSeasonID {
	[OutputType([System.Object[]])]
	Param ([String]$local:SeasonID)

	$local:tverSearchBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/'
	$local:callSearchURL = `
		$local:tverSearchBaseURL + $local:SeasonID `
		+ '?platform_uid=' + $script:platformUID `
		+ '&platform_token=' + $script:platformToken
	$local:searchResultsRaw = `
		Invoke-RestMethod `
		-Uri $local:callSearchURL `
		-Method 'GET' `
		-Headers $script:requestHeader `
		-TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	for ($i = 0; $i -lt $local:searchResults.Length; $i++) {
		switch ($local:searchResults[$i].type) {
			'episode' {
				$script:tverLinks += `
					'/episodes/' + $local:searchResults[$i].Content.Id
				break
			}
			'season' {
				$script:tverLinks += `
					getLinkFromSeasonID ($local:searchResults[$i].Content.Id)
				break
			}
			'series' {
				$script:tverLinks += `
					getLinkFromSeriesID ($local:searchResults[$i].Content.Id)
				break
			}
			'live' { break }
			#他にはないと思われるが念のため
			default {
				$script:tverLinks += `
					'/' + $local:searchResults[$i].type `
					+ '/' + $local:searchResults[$i].Content.Id
				break
			}
		}
	}
	[System.GC]::Collect()

	return $script:tverLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function waitTillYtdlProcessGetFewer {
	[OutputType([System.Void])]
	Param ([Int32]$local:parallelDownloadFileNum)

	$local:psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $local:processName = 'yt-dlp' ; break }
		'ytdl-patched' { $local:processName = 'youtube-dl' ; break }
	}

	#youtube-dlのプロセスが設定値を超えたら一時待機
	try {
		switch ($true) {
			$IsWindows {
				$local:ytdlCount = `
					[Math]::Round(
					(Get-Process -ErrorAction Ignore -Name youtube-dl).`
						Count / 2, [MidpointRounding]::AwayFromZero
				)
				break
			}
			$IsLinux {
				$local:ytdlCount = `
				@(Get-Process -ErrorAction Ignore -Name $local:processName).Count
				break
			}
			$IsMacOS {
				$local:ytdlCount = `
				(& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
				break
			}
			default { $local:ytdlCount = 0 ; break }
		}
	} catch { $local:ytdlCount = 0 }			#プロセス数が取れなくてもとりあえず先に進む

	Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"

	while ([int]$local:ytdlCount -ge [int]$local:parallelDownloadFileNum ) {
		Out-Msg "ダウンロードが $local:parallelDownloadFileNum 多重に達したので一時待機します。 ($(getTimeStamp))" -Fg 'Gray'
		Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"
		Start-Sleep -Seconds 60			#1分待機
		try {
			switch ($true) {
				$IsWindows {
					$local:ytdlCount = `
						[Math]::Round(
						(Get-Process -ErrorAction Ignore -Name youtube-dl).`
							Count / 2, [MidpointRounding]::AwayFromZero
					)
					break
				}
				$IsLinux {
					$local:ytdlCount = `
					@(Get-Process -ErrorAction Ignore -Name $local:processName).Count
					break
				}
				$IsMacOS {
					$local:ytdlCount = `
					(& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
					break
				}
			}
		} catch {
			$local:ytdlCount = 0
			Write-Debug 'youtube-dlのプロセス数の取得に失敗しました'
		}
	}
}

#----------------------------------------------------------------------
#TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function downloadTVerVideo {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $true,
			Position = 0
		)]
		[Alias('Keyword')]
		[String]$script:keywordName,

		[Parameter(
			Mandatory = $true,
			Position = 1
		)]
		[Alias('URL')]
		[String]$script:videoPageURL,

		[Parameter(
			Mandatory = $true,
			Position = 2
		)]
		[Alias('Link')]
		[String]$script:videoLink
	)

	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$script:newVideo = $null
	$script:ignore = $false ; $script:skip = $false

	#TVerのAPIを叩いて番組情報取得
	goAnal -Event 'getinfo' -Type 'link' -ID $script:videoLink
	try {
		getVideoInfo -Link $script:videoLink
	} catch {
		Out-Msg '　情報取得エラー。スキップします Err:10' -Fg 'Green'
		continue			#次回再度トライするためダウンロード履歴に追加せずに次の番組へ
	}

	#ダウンロードファイル情報をセット
	$script:videoName = getVideoFileName `
		-Series $script:videoSeries `
		-Season $script:videoSeason `
		-Episode $script:videoEpisode `
		-Title $script:videoTitle `
		-Date $script:broadcastDate

	$script:videoFileDir = getSpecialCharacterReplaced (
		getNarrowChars $($script:videoSeries + ' ' + $script:videoSeason)
	).Trim()
	if ($script:sortVideoByMedia -eq $true) {
		$script:videoFileDir = $(
			Join-Path $script:downloadBaseDir $(getFileNameWoInvChars $script:mediaName) `
			| Join-Path -ChildPath $(getFileNameWoInvChars $script:videoFileDir)
		)
	} else {
		$script:videoFileDir = $(
			Join-Path $script:downloadBaseDir $(getFileNameWoInvChars $script:videoFileDir)
		)
	}
	$script:videoFilePath = $(Join-Path $script:videoFileDir $script:videoName)
	$script:videoFileRelPath = $script:videoFilePath.`
		Replace($script:downloadBaseDir, '').`
		Replace('\', '/')
	$script:videoFileRelPath = $script:videoFileRelPath.`
		Substring(1, $($script:videoFileRelPath.Length - 1))

	#番組情報のコンソール出力
	showVideoInfo `
		-Name $script:videoName `
		-Date $script:broadcastDate `
		-Media $script:mediaName `
		-Description $descriptionText
	if ($DebugPreference -ne 'SilentlyContinue') {
		showVideoDebugInfo `
			-URL $script:videoPageURL `
			-SeriesURL $script:videoSeriesPageURL `
			-Keyword $script:keywordName `
			-Series $script:videoSeries `
			-Season $script:videoSeason `
			-Episode $script:videoEpisode `
			-Title $script:videoTitle `
			-Path $script:videoFilePath `
			-Time $(getTimeStamp) `
			-EndTime $script:endTime
	}

	#番組タイトルが取得できなかった場合はスキップ次の番組へ
	if ($script:videoName -eq '.mp4') {
		Out-Msg '　番組タイトルを特定できませんでした。スキップします' -Fg 'Green'
		#次回再度ダウンロードをトライするためダウンロード履歴に追加せずに次の番組へ
		continue
	}

	#ファイルが既に存在する場合はスキップフラグを立ててダウンロード履歴に書き込み処理へ
	if (Test-Path $script:videoFilePath) {

		#リストファイルにチェック済の状態で存在するかチェック
		$local:historyMatch = $script:historyFileData `
		| Where-Object { $_.videoPath -eq $script:videoFileRelPath } `
		| Where-Object { $_.videoValidated -eq '1' }

		#結果が0件ということは未検証のファイルがあるということ
		if ( $null -eq $local:historyMatch) {
			Out-Msg '　すでにダウンロード済ですが未検証の番組です。ダウンロード履歴に追加します' -Fg 'Gray'
			$script:skip = $true
		} else {
			Out-Msg '　すでにダウンロード済・検証済の番組です。スキップします' -Fg 'Gray'
			continue
		}

	} else {

		# $funCheckIfIgnored = ${function:checkIfIgnored}.ToString()
		# $funGetNarrowChars = ${function:getNarrowChars}.ToString()

		# $script:ignoreTitles | ForEach-Object -Parallel {
		# 	${function:checkIfIgnored} = $using:funCheckIfIgnored
		# 	${function:getNarrowChars} = $using:funGetNarrowChars
		# 	$series = $using:script:videoSeries
		# 	$title = $using:script:videoTitle

		# 	Write-Host $_

		# 	checkIfIgnored `
		# 		-ignoreText $_ `
		# 		-seriesTitle "$($series) " `
		# 		-epsodeTitle "$($title) "

		# } -ThrottleLimit 10

		foreach ($local:ignoreTitle in $script:ignoreTitles) {
			$script:ignore = checkIfIgnored `
				-ignoreText $local:ignoreTitle `
				-seriesTitle "$($script:videoSeries) " `
				-epsodeTitle "$($script:videoTitle) "
		}

	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Out-Msg '　ダウンロード対象外としたファイルをダウンロード履歴に追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL
			videoSeriesPage = $script:videoSeriesPageURL
			genre           = $script:keywordName
			series          = $script:videoSeries
			season          = $script:videoSeason
			title           = $script:videoTitle
			media           = $script:mediaName
			broadcastDate   = $script:broadcastDate
			downloadDate    = $(getTimeStamp)
			videoDir        = $script:videoFileDir
			videoName       = '-- IGNORED --'
			videoPath       = '-- IGNORED --'
			videoValidated  = '0'
		}
	} elseif ($script:skip -eq $true) {
		Out-Msg '　スキップした未検証のファイルをダウンロード履歴に追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL
			videoSeriesPage = $script:videoSeriesPageURL
			genre           = $script:keywordName
			series          = $script:videoSeries
			season          = $script:videoSeason
			title           = $script:videoTitle
			media           = $script:mediaName
			broadcastDate   = $script:broadcastDate
			downloadDate    = $(getTimeStamp)
			videoDir        = $script:videoFileDir
			videoName       = '-- SKIPPED --'
			videoPath       = $videoFileRelPath
			videoValidated  = '0'
		}
	} else {
		Out-Msg '　ダウンロードするファイルをダウンロード履歴に追加します'
		$script:newVideo = [pscustomobject]@{
			videoPage       = $script:videoPageURL
			videoSeriesPage = $script:videoSeriesPageURL
			genre           = $script:keywordName
			series          = $script:videoSeries
			season          = $script:videoSeason
			title           = $script:videoTitle
			media           = $script:mediaName
			broadcastDate   = $script:broadcastDate
			downloadDate    = $(getTimeStamp)
			videoDir        = $script:videoFileDir
			videoName       = $script:videoName
			videoPath       = $script:videoFileRelPath
			videoValidated  = '0'
		}
	}

	#ダウンロード履歴CSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$script:newVideo | Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8 `
			-Append
		Write-Debug 'ダウンロード履歴を書き込みました'
	} catch {
		Out-Msg '　ダウンロード履歴を更新できませんでした。スキップします' -Fg 'Green'
		continue
	} finally { $null = fileUnlock $script:historyLockFilePath }
	$script:historyFileData = `
		Import-Csv `
		-Path $script:historyFilePath `
		-Encoding UTF8

	#スキップやダウンロード対象外でなければyoutube-dl起動
	if (($script:ignore -eq $true) -Or ($script:skip -eq $true)) {
		#スキップ対象やダウンロード対象外は飛ばして次のファイルへ
		continue
	} else {
		#保存先ディレクトリがなければ作成
		if (-Not (Test-Path $script:videoFileDir -PathType Container)) {
			try {
				$null = New-Item `
					-ItemType Directory `
					-Path $script:videoFileDir `
					-Force
			} catch { Out-Msg '　保存先ディレクトリを作成できませんでした' -Fg 'Green'
				continue
			}
		}

		#youtube-dl起動
		try { executeYtdl $script:videoPageURL }
		catch { Out-Msg '　youtube-dlの起動に失敗しました' -Fg 'Green' }
		#5秒待機
		Start-Sleep -Seconds 5

	}

}

#----------------------------------------------------------------------
#TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function generateTVerVideoList {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $true,
			Position = 0
		)]
		[Alias('Keyword')]
		[String]$script:keywordName,

		[Parameter(
			Mandatory = $true,
			Position = 1
		)]
		[Alias('Link')]
		[String]$script:videoLink
	)

	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$local:ignoreWord = ''
	$script:newVideo = $null
	$script:ignore = $false ; $script:skip = $false

	#TVerのAPIを叩いて番組情報取得
	goAnal -Event 'getinfo' -Type 'link' -ID $script:videoLink
	try {
		getVideoInfo -Link $script:videoLink
	} catch {
		Out-Msg '　情報取得エラー。スキップします Err:10' -Fg 'Green'
		#次回再度トライするため以降の処理をせずに次の番組へ
		continue
	}

	#ダウンロード対象外に入っている番組の場合はリスト出力しない
	foreach ($local:ignoreTitle in $script:ignoreTitles) {

		#正規表現用のエスケープ
		$local:ignoreTitle = $local:ignoreTitle.Replace('\', '\\')
		$local:ignoreTitle = $local:ignoreTitle.Replace('*', '\*')
		$local:ignoreTitle = $local:ignoreTitle.Replace('+', '\+')
		$local:ignoreTitle = $local:ignoreTitle.Replace('.', '\.')
		$local:ignoreTitle = $local:ignoreTitle.Replace('?', '\?')
		$local:ignoreTitle = $local:ignoreTitle.Replace('{', '\{')
		$local:ignoreTitle = $local:ignoreTitle.Replace('}', '\}')
		$local:ignoreTitle = $local:ignoreTitle.Replace('(', '\(')
		$local:ignoreTitle = $local:ignoreTitle.Replace(')', '\)')
		$local:ignoreTitle = $local:ignoreTitle.Replace('[', '\[')
		$local:ignoreTitle = $local:ignoreTitle.Replace(']', '\]')
		$local:ignoreTitle = $local:ignoreTitle.Replace('^', '\^')
		$local:ignoreTitle = $local:ignoreTitle.Replace('$', '\$')
		$local:ignoreTitle = $local:ignoreTitle.Replace('-', '\-')
		$local:ignoreTitle = $local:ignoreTitle.Replace('|', '\|')
		$local:ignoreTitle = $local:ignoreTitle.Replace('/', '\/')

		if (($(getNarrowChars $script:videoSeries) -match $(getNarrowChars $local:ignoreTitle)) `
				-Or ($(getNarrowChars $script:videoTitle) -match $(getNarrowChars $local:ignoreTitle))) {
			$local:ignoreWord = $local:ignoreTitle
			$script:ignore = $true
			#ダウンロード対象外と合致したものはそれ以上のチェック不要
			break
		}
	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Out-Msg '　番組をコメントアウトした状態でリストファイルに追加します'
		$script:newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = '#' + $($script:videoLink.Replace('/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $script:keywordName
			ignoreWord    = $local:ignoreWord
		}
	} else {
		Out-Msg '　番組をリストファイルに追加します'
		$script:newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = $($script:videoLink.Replace('/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $script:keywordName
			ignoreWord    = ''
		}
	}

	#ダウンロードリストCSV書き出し
	try {
		#ロックファイルをロック
		while ($(fileLock $script:listLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$script:newVideo | Export-Csv `
			-Path $script:listFilePath `
			-NoTypeInformation `
			-Encoding UTF8 `
			-Append
		Write-Debug 'ダウンロードリストを書き込みました'
	} catch {
		Out-Msg '　ダウンロードリストを更新できませんでした。スキップします' -Fg 'Green'
		continue
	} finally { $null = fileUnlock $script:listLockFilePath }
	$script:listFileData = `
		Import-Csv `
		-Path $script:listFilePath `
		-Encoding UTF8

}

#----------------------------------------------------------------------
#TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function getVideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $true,
			Position = 0
		)]
		[Alias('Link')]
		[String]$local:videoLink
	)

	$local:episodeID = $local:videoLink.Replace('/episodes/', '')

	#----------------------------------------------------------------------
	#番組説明以外
	$local:tverVideoInfoBaseURL = `
		'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$local:requestHeader = @{
		'x-tver-platform-type' = 'web'
	}
	$local:tverVideoInfoURL = `
		$local:tverVideoInfoBaseURL + $local:episodeID + `
		'?platform_uid=' + $script:platformUID + `
		'&platform_token=' + $script:platformToken
	$local:response = `
		Invoke-RestMethod `
		-Uri $local:tverVideoInfoURL `
		-Method 'GET' `
		-Headers $local:requestHeader `
		-TimeoutSec $script:timeoutSec

	#シリーズ
	#	$response.Result.Series.Content.Title
	#	$response.Result.Episode.Content.SeriesTitle
	#		Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
	#		Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
	#	なのでSeries.Content.TitleとEpisode.Content.SeriesTitleの短い方を採用する
	if ($local:response.Result.Episode.Content.SeriesTitle.Length `
			-le $local:response.Result.Series.Content.Title.Length ) {
		$script:videoSeries = $(getSpecialCharacterReplaced (getNarrowChars (
					$local:response.Result.Episode.Content.SeriesTitle))).Trim()
	} else {
		$script:videoSeries = $(getSpecialCharacterReplaced (getNarrowChars (
					$local:response.Result.Series.Content.Title))).Trim()
	}
	$script:videoSeriesID = $local:response.Result.Series.Content.Id
	$script:videoSeriesPageURL = `
		'https://tver.jp/series/' + $local:response.Result.Series.Content.Id

	#シーズン
	#Season Name
	#	$response.Result.Season.Content.Title
	$script:videoSeason = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Season.Content.Title))).Trim()
	$script:videoSeasonID = $local:response.Result.Season.Content.Id

	#エピソード
	#	$response.Result.Episode.Content.Title
	$script:videoTitle = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Episode.Content.Title))).Trim()
	$script:videoEpisodeID = $local:response.Result.Episode.Content.Id

	#放送局
	#	$response.Result.Episode.Content.BroadcasterName
	#	$response.Result.Episode.Content.ProductionProviderName
	$script:mediaName = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Episode.Content.BroadcasterName))).Trim()
	$script:providerName = $(getSpecialCharacterReplaced (getNarrowChars (
				$local:response.Result.Episode.Content.ProductionProviderName))).Trim()

	#放送日
	#	$response.Result.Episode.Content.BroadcastDateLabel
	$script:broadcastDate = $(getNarrowChars (
			$response.Result.Episode.Content.BroadcastDateLabel).`
			Replace('ほか', '').Replace('放送分', '放送')).Trim()

	#配信終了日時
	#	$response.Result.Episode.Content.endAt
	$script:endTime = $(getNarrowChars ($response.Result.Episode.Content.endAt)).Trim()
	$script:endTime = $(unixTimeToDateTime ($script:endTime)).AddHours(9)

	#----------------------------------------------------------------------
	#番組説明
	$local:versionNum = $local:response.result.episode.content.version
	$local:tverVideoInfoBaseURL = `
		'https://statics.tver.jp/content/episode/'
	$local:requestHeader = @{
		'origin'  = 'https://tver.jp'
		'referer' = 'https://tver.jp'
	}
	$local:tverVideoInfoURL = `
		$local:tverVideoInfoBaseURL `
		+ $local:episodeID + '.json?v=' + $local:versionNum
	$local:videoInfo = `
		Invoke-RestMethod `
		-Uri $local:tverVideoInfoURL `
		-Method 'GET' `
		-Headers $local:requestHeader `
		-TimeoutSec $script:timeoutSec
	$script:descriptionText = $(getNarrowChars ($local:videoInfo.Description).`
			Replace('&amp;', '&')).Trim()
	$script:videoEpisode = getNarrowChars ($local:videoInfo.No)

	#----------------------------------------------------------------------
	#各種整形

	#「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote -eq $true) {
		if ($script:videoSeries -match '(.*)(《.*》)(.*)') {
			$script:videoSeries = $($Matches[1] + $Matches[3]).`
				Replace('  ', ' ').Trim()
		}
		if ($script:videoSeason -match '(.*)(《.*》)(.*)') {
			$script:videoSeason = $($Matches[1] + $Matches[3]).`
				Replace('  ', ' ').Trim()
		}
		if ($script:videoTitle -match '(.*)(《.*》)(.*)') {
			$script:videoTitle = $($Matches[1] + $Matches[3]).`
				Replace('  ', ' ').Trim()
		}
	}

	#シーズン名が本編の場合はシーズン名をクリア
	if ($script:videoSeason -eq '本編') { $script:videoSeason = '' }

	#シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($script:videoSeries -like $('*' + $script:videoSeason + '*' )) {
		$script:videoSeason = ''
	}

	#放送日を整形
	$local:broadcastYMD = $null
	if ($script:broadcastDate -match '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		#当年だと仮定して放送日を抽出
		$local:broadcastYMD = [DateTime]::ParseExact(
			(Get-Date -Format 'yyyy') `
				+ $Matches[1].padleft(2, '0') `
				+ $Matches[3].padleft(2, '0'), 'yyyyMMdd', $null)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する
		#(年末の番組を年初にダウンロードするケース)
		if ((Get-Date).AddDays(+1) -lt $local:broadcastYMD) {
			$script:broadcastDate = `
			(Get-Date).AddYears(-1).ToString('yyyy') + '年'
		} else {
			$script:broadcastDate = `
			(Get-Date).ToString('yyyy') + '年'
		}
		$script:broadcastDate += `
			$Matches[1].padleft(2, '0') + $Matches[2] `
			+ $Matches[3].padleft(2, '0') + $Matches[4] `
			+ $Matches[6]
	}

}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function getVideoFileName {
	[OutputType([String])]
	Param (
		[Parameter(
			Mandatory = $false,
			Position = 0
		)]
		[Alias('Series')]
		[String]$local:videoSeries,

		[Parameter(
			Mandatory = $false,
			Position = 1
		)]
		[Alias('Season')]
		[String]$local:videoSeason,

		[Parameter(
			Mandatory = $false,
			Position = 2
		)]
		[Alias('Episode')]
		[String]$local:videoEpisode,

		[Parameter(
			Mandatory = $false,
			Position = 3
		)]
		[Alias('Title')]
		[String]$local:videoTitle,

		[Parameter(
			Mandatory = $false,
			Position = 4
		)]
		[Alias('Date')]
		[String]$local:broadcastDate
	)

	#ファイル名を生成
	if ($script:addEpisodeNumber -eq $true) {
		$local:videoName = $local:videoSeries `
			+ ' ' + $local:videoSeason `
			+ ' ' + $local:broadcastDate `
			+ ' Ep' + $local:videoEpisode `
			+ ' ' + $local:videoTitle
	} else {
		$local:videoName = $local:videoSeries `
			+ ' ' + $local:videoSeason `
			+ ' ' + $local:broadcastDate `
			+ ' ' + $local:videoTitle
	}

	#ファイル名にできない文字列を除去
	$local:videoName = $(getFileNameWoInvChars (getSpecialCharacterReplaced (
				getNarrowChars $local:videoName))).Replace('  ', ' ').Trim()

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	$local:videoNameTemp = ''
	#youtube-dlの中間ファイル等を考慮して安全目の上限値
	$local:fileNameLimit = $script:fileNameLengthMax - 25
	$local:videoNameByte = [System.Text.Encoding]::UTF8.GetByteCount($local:videoName)

	#ファイル名を1文字ずつ増やしていき、上限に達したら残りは「……」とする
	if ($local:videoNameByte -gt $local:fileNameLimit) {
		for ($i = 1 ; [System.Text.Encoding]::UTF8.`
				GetByteCount($local:videoNameTemp) -lt $local:fileNameLimit ; $i++) {
			$local:videoNameTemp = $local:videoName.Substring(0, $i)
		}
		#ファイル名省略の印
		$local:videoName = $local:videoNameTemp + '……'
	}

	$local:videoName = $local:videoName + '.mp4'
	if ($local:videoName.Contains('.mp4') -eq $false) {
		Write-Error '　ダウンロードファイル名の設定がおかしいです'
	}

	return $local:videoName
}

#----------------------------------------------------------------------
#番組情報表示
#----------------------------------------------------------------------
function showVideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $false,
			Position = 0
		)]
		[Alias('Name')]
		[String]$local:videoName,

		[Parameter(
			Mandatory = $false,
			Position = 1
		)]
		[Alias('Date')]
		[String]$local:broadcastDate,

		[Parameter(
			Mandatory = $false,
			Position = 2
		)]
		[Alias('Media')]
		[String]$local:mediaName,

		[Parameter(
			Mandatory = $false,
			Position = 3
		)]
		[Alias('Description')]
		[String]$local:descriptionText
	)

	Out-Msg ' '
	Out-Msg "　番組名 :$local:videoName" -Fg 'Gray'
	Out-Msg "　放送日 :$local:broadcastDate" -Fg 'Gray'
	Out-Msg "　テレビ局:$local:mediaName" -Fg 'Gray'
	Out-Msg "　番組説明:$local:descriptionText" -Fg 'Gray'
}
#----------------------------------------------------------------------
#番組情報デバッグ表示
#----------------------------------------------------------------------
function showVideoDebugInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $false,
			Position = 0
		)]
		[Alias('URL')]
		[String]$local:videoPageURL,

		[Parameter(
			Mandatory = $false,
			Position = 1
		)]
		[Alias('SeriesURL')]
		[String]$local:videoSeriesPageURL,

		[Parameter(
			Mandatory = $false,
			Position = 2
		)]
		[Alias('Keyword')]
		[String]$local:keywordName,

		[Parameter(
			Mandatory = $false,
			Position = 3
		)]
		[Alias('Series')]
		[String]$local:videoSeries,

		[Parameter(
			Mandatory = $false,
			Position = 4
		)]
		[Alias('Season')]
		[String]$local:videoSeason,

		[Parameter(
			Mandatory = $false,
			Position = 5
		)]
		[Alias('Episode')]
		[String]$local:videoEpisode,

		[Parameter(
			Mandatory = $false,
			Position = 6
		)]
		[Alias('Title')]
		[String]$local:videoTitle,

		[Parameter(
			Mandatory = $false,
			Position = 7
		)]
		[Alias('Path')]
		[String]$local:videoFilePath,

		[Parameter(
			Mandatory = $false,
			Position = 8
		)]
		[Alias('Time')]
		[String]$local:processedTime,

		[Parameter(
			Mandatory = $false,
			Position = 9
		)]
		[Alias('EndTime')]
		[String]$local:endTime
	)

	Write-Debug	"　番組エピソードページ:$local:videoPageURL"
	Write-Debug	"　番組シリーズページ :$local:videoSeriesPageURL"
	Write-Debug "　キーワード :$local:keywordName"
	Write-Debug "　シリーズ :$local:videoSeries"
	Write-Debug "　シーズン :$local:videoSeason"
	Write-Debug "　エピソード :$local:videoEpisode"
	Write-Debug "　サブタイトル :$local:videoTitle"
	Write-Debug "　ファイル :$local:videoFilePath"
	Write-Debug "　取得日付 :$local:processedTime"
	Write-Debug "　配信終了 :$local:endTime"
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動
#----------------------------------------------------------------------
function executeYtdl {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $false,
			Position = 0
		)]
		[Alias('URL')]
		[String]$local:videoPageURL
	)

	goAnal -Event 'download'

	$local:tmpDir = '"temp:' + $script:downloadWorkDir + '"'
	$local:saveDir = '"home:' + $script:videoFileDir + '"'
	$local:subttlDir = '"subtitle:' + $script:downloadWorkDir + '"'
	$local:thumbDir = '"thumbnail:' + $script:downloadWorkDir + '"'
	$local:chaptDir = '"chapter:' + $script:downloadWorkDir + '"'
	$local:descDir = '"description:' + $script:downloadWorkDir + '"'
	$local:saveFile = '"' + $script:videoName + '"'
	$local:ffmpegPath = '"' + $script:ffmpegPath + '"'

	$local:ytdlArgs = '--format mp4'
	$local:ytdlArgs += ' --console-title'
	$local:ytdlArgs += ' --no-mtime'
	$local:ytdlArgs += ' --retries 10'
	$local:ytdlArgs += ' --fragment-retries 10'
	$local:ytdlArgs += ' --abort-on-unavailable-fragment'
	$local:ytdlArgs += ' --no-keep-fragments'
	$local:ytdlArgs += ' --abort-on-error'
	$local:ytdlArgs += ' --no-continue'
	$local:ytdlArgs += ' --windows-filenames'
	$local:ytdlArgs += ' --newline'
	$local:ytdlArgs += " --concurrent-fragments $script:parallelDownloadNumPerFile"
	$local:ytdlArgs += ' --embed-thumbnail'
	$local:ytdlArgs += ' --embed-subs'
	$local:ytdlArgs += ' --embed-metadata'
	$local:ytdlArgs += ' --embed-chapters'
	$local:ytdlArgs += " --paths $local:saveDir"
	$local:ytdlArgs += " --paths $local:tmpDir"
	$local:ytdlArgs += " --paths $local:subttlDir"
	$local:ytdlArgs += " --paths $local:thumbDir"
	$local:ytdlArgs += " --paths $local:chaptDir"
	$local:ytdlArgs += " --paths $local:descDir"
	$local:ytdlArgs += " --ffmpeg-location $local:ffmpegPath"
	$local:ytdlArgs += " --output $local:saveFile"
	$local:ytdlArgs += " $local:videoPageURL"

	if ($IsWindows) {
		try {
			Write-Debug "youtube-dl起動コマンド:$script:ytdlPath $local:ytdlArgs"
			$null = (
				Start-Process `
					-FilePath $script:ytdlPath `
					-ArgumentList $local:ytdlArgs `
					-PassThru `
					-WindowStyle $script:windowShowStyle
			)
		} catch { Write-Error 'youtube-dlの起動に失敗しました' ; return }
	} else {
		Write-Debug "youtube-dl起動コマンド:nohup $script:ytdlPath $local:ytdlArgs"
		try {
			$null = (
				Start-Process `
					-FilePath nohup `
					-ArgumentList ($script:ytdlPath, $local:ytdlArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError /dev/zero
			)
		} catch { Write-Error '　youtube-dlの起動に失敗しました' ; return }
	}
}

#----------------------------------------------------------------------
#youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function waitTillYtdlProcessIsZero () {
	[OutputType([System.Void])]
	Param ()

	$local:psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $local:processName = 'yt-dlp' ; break }
		'ytdl-patched' { $local:processName = 'youtube-dl' ; break }
	}

	try {
		switch ($true) {
			$IsWindows {
				$local:ytdlCount = `
					[Math]::Round(
					(Get-Process -ErrorAction Ignore -Name youtube-dl).`
						Count / 2, [MidpointRounding]::AwayFromZero )
				break
			}
			$IsLinux {
				$local:ytdlCount = `
				@(Get-Process -ErrorAction Ignore -Name $local:processName).Count
				break
			}
			$IsMacOS {
				$local:ytdlCount = `
				(& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
				break
			}
			default { $local:ytdlCount = 0 ; break }
		}
	} catch {
		$local:ytdlCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	while ($local:ytdlCount -ne 0) {
		try {
			Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"
			Start-Sleep -Seconds 60			#1分待機
			switch ($true) {
				$IsWindows {
					$local:ytdlCount = `
						[Math]::Round(
						(Get-Process -ErrorAction Ignore -Name youtube-dl).`
							Count / 2, [MidpointRounding]::AwayFromZero )
					break
				}
				$IsLinux {
					$local:ytdlCount = `
					@(Get-Process -ErrorAction Ignore -Name $local:processName).Count
					break
				}
				$IsMacOS {
					$local:ytdlCount = `
					(& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim()
					break
				}
				default { $local:ytdlCount = 0 ; break }
			}
		} catch {
			$local:ytdlCount = 0
		}
	}
}

#----------------------------------------------------------------------
#ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function cleanDB {
	[OutputType([System.Void])]
	Param ()

	$local:historyData0 = $null
	$local:historyData1 = $null
	$local:historyData2 = $null
	$local:mergedHist = @()
	#ダウンロード対象外とされたもの
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}

		#ファイル操作
		#videoValidatedが空白でないもの
		$local:historyData = ((Import-Csv -Path $script:historyFilePath -Encoding UTF8).`
				Where({ $null -ne $_.videoValidated }))
		$local:historyData0 = (($local:historyData).Where({ $_.videoValidated -eq '0' }))
		$local:historyData1 = (($local:historyData).Where({ $_.videoValidated -eq '1' }))
		$local:historyData2 = (($local:historyData).Where({ $_.videoValidated -eq '2' }))

		if ($null -ne $local:historyData0) { $local:mergedHist += $local:historyData0 }
		if ($null -ne $local:historyData1) { $local:mergedHist += $local:historyData1 }
		if ($null -ne $local:historyData2) { $local:mergedHist += $local:historyData2 }
		$local:mergedHist | Sort-Object -Property downloadDate `
		| Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8

	} catch {
		Out-Msg '　ダウンロード履歴の更新に失敗しました' -Fg 'Green'
	} finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#30日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function purgeDB {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $true,
			Position = 0
		)]
		[Alias('RetentionPeriod')]
		[Int32]$local:retentionPeriod
	)

	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:purgedHist = ((Import-Csv -Path $script:historyFilePath -Encoding UTF8).`
				Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt $(Get-Date).`
						AddDays(-1 * [Int32]$local:retentionPeriod) }))
		$local:purgedHist | Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8
	} catch {
		Out-Msg '　ダウンロード履歴のクリーンアップに失敗しました' -Fg 'Green'
	} finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function uniqueDB {
	[OutputType([System.Void])]
	Param ()

	$local:processedHist = $null
	$local:ignoredHist = $null
	#ダウンロード対象外とされたもの
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}

		#ファイル操作
		#ダウンロード対象外とされたもの
		$local:ignoredHist = ((Import-Csv -Path $script:historyFilePath -Encoding UTF8).`
				Where({ $_.videoPath -eq '-- IGNORED --' }))

		#ダウンロード対象外とされなかったものの重複削除。ファイル名で1つしかないもの残す
		$local:processedHist = `
			Import-Csv `
			-Path $script:historyFilePath `
			-Encoding UTF8 `
		| Group-Object -Property 'videoPath' `
		| Where-Object count -EQ 1 `
		| Select-Object -ExpandProperty group

		#ダウンロード対象外とされたものとダウンロード対象外とされなかったものを結合し出力
		switch ($local:processedHist) {
			$null {
				switch ($local:ignoredHist) {
					$null { retrun }
					default { $local:mergedHist = $local:ignoredHist; break }
				}; break		#breakがないと無限ループ
			}
			default {
				switch ($local:ignoredHist) {
					$null { $local:mergedHist = $local:processedHist; break }
					default { $local:mergedHist = $local:processedHist + $local:ignoredHist; break }
				}; break		#breakがないと無限ループ
			}
		}

		$local:mergedHist | Sort-Object -Property downloadDate `
		| Export-Csv `
			-Path $script:historyFilePath `
			-NoTypeInformation `
			-Encoding UTF8

	} catch {
		Out-Msg '　ダウンロード履歴の更新に失敗しました' -Fg 'Green'
	} finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#番組の整合性チェック
#----------------------------------------------------------------------
function checkVideo {
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $false,
			Position = 0
		)]
		[Alias('DecodeOption')]
		[String]$local:decodeOption,

		[Parameter(
			Mandatory = $false,
			Position = 1
		)]
		[Alias('Path')]
		[String]$local:videoFileRelPath
	)

	$local:errorCount = 0
	$local:checkStatus = 0
	$local:videoFilePath = Join-Path $script:downloadBaseDir $local:videoFileRelPath
	try {
		$null = New-Item `
			-Path $script:ffpmegErrorLogPath `
			-ItemType File `
			-Force
	} catch { Out-Msg '　ffmpegエラーファイルを初期化できませんでした' -Fg 'Green' ; return }

	#これからチェックする番組のステータスをチェック
	try {
		#ロックファイルをロック
		while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
			Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:videoHists = `
			Import-Csv `
			-Path $script:historyFilePath `
			-Encoding UTF8
		$local:checkStatus = $(($local:videoHists).`
				Where({ $_.videoPath -eq $local:videoFileRelPath })).`
			videoValidated
	} catch {
		Out-Msg "　既にダウンロード履歴から削除されたようです: $local:videoFileRelPath" 'Gray'
		return
	} finally { $null = fileUnlock $script:historyLockFilePath }

	#0:未チェック、1:チェック済、2:チェック中
	if ($local:checkStatus -eq 2 ) {
		Out-Msg '　他プロセスでチェック中です' -Fg 'Gray'
		return
	} elseif ($local:checkStatus -eq 1 ) {
		Out-Msg '　他プロセスでチェック済です' -Fg 'Gray'
		return
	} else {
		#該当の番組のチェックステータスを"2"にして後続のチェックを実行
		try {
			$(($local:videoHists).`
					Where({ $_.videoPath -eq $local:videoFileRelPath })).`
				videoValidated = '2'
		} catch {
			Out-Msg "　該当のレコードが見つかりませんでした: $local:videoFileRelPath" 'Green'
			return
		}
		try {
			#ロックファイルをロック
			while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
				Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:videoHists | Export-Csv `
				-Path $script:historyFilePath `
				-NoTypeInformation `
				-Encoding UTF8
		} catch {
			Out-Msg "　ダウンロード履歴を更新できませんでした: $local:videoFileRelPath" 'Green'
			return
		} finally { $null = fileUnlock $script:historyLockFilePath }
	}

	$local:checkFile = '"' + $local:videoFilePath + '"'
	goAnal -Event 'validate'

	if ($script:simplifiedValidation -eq $true) {
		#ffprobeを使った簡易検査
		$local:ffprobeArgs = ' -hide_banner -v error -err_detect explode' `
			+ " -i $local:checkFile '

		Write-Debug 'ffprobe起動コマンド:$script:ffprobePath $local:ffprobeArgs"
		try {
			if ($IsWindows) {
				$local:proc = (
					Start-Process `
						-FilePath $script:ffprobePath `
						-ArgumentList ($local:ffprobeArgs) `
						-PassThru `
						-WindowStyle $script:windowShowStyle `
						-RedirectStandardError $script:ffpmegErrorLogPath `
						-Wait
				)
			} else {
				$local:proc = (
					Start-Process `
						-FilePath $script:ffprobePath `
						-ArgumentList ($local:ffprobeArgs) `
						-PassThru `
						-RedirectStandardOutput /dev/null `
						-RedirectStandardError $script:ffpmegErrorLogPath `
						-Wait
				)
			}
		} catch { Write-Error '　ffprobeを起動できませんでした' ; return }
	} else {
		#ffmpegeを使った完全検査
		$local:ffmpegArgs = "$local:decodeOption " `
			+ ' -hide_banner -v error -xerror' `
			+ " -i $local:checkFile -f null - "

		Write-Debug "ffmpeg起動コマンド:$script:ffmpegPath $local:ffmpegArgs"
		try {
			if ($IsWindows) {
				$local:proc = (
					Start-Process `
						-FilePath $script:ffmpegPath `
						-ArgumentList ($local:ffmpegArgs) `
						-PassThru `
						-WindowStyle $script:windowShowStyle `
						-RedirectStandardError $script:ffpmegErrorLogPath `
						-Wait
				)
			} else {
				$local:proc = (
					Start-Process `
						-FilePath $script:ffmpegPath `
						-ArgumentList ($local:ffmpegArgs) `
						-PassThru `
						-RedirectStandardOutput /dev/null `
						-RedirectStandardError $script:ffpmegErrorLogPath `
						-Wait
				)
			}
		} catch { Write-Error '　ffmpegを起動できませんでした' ; return }
	}

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			$local:errorCount = (Get-Content -LiteralPath $script:ffpmegErrorLogPath `
				| Measure-Object -Line).Lines
			Get-Content `
				-LiteralPath $script:ffpmegErrorLogPath `
				-Encoding UTF8 `
			| ForEach-Object { Write-Debug $_ }
		}
	} catch {
		Out-Msg '　ffmpegエラーの数をカウントできませんでした' -Fg 'Green'
		$local:errorCount = 9999999
	}

	#エラーをカウントしたらファイルを削除
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			Remove-Item `
				-LiteralPath $script:ffpmegErrorLogPath `
				-Force `
				-ErrorAction SilentlyContinue
		}
	} catch { Out-Msg '　ffmpegエラーファイルを削除できませんでした' -Fg 'Green' }

	if ($local:proc.ExitCode -ne 0 -Or $local:errorCount -gt 30) {
		Out-Msg '　チェックNGでした' -Fg 'Green'

		#終了コードが"0"以外 または エラーが30行以上 はダウンロード履歴とファイルを削除
		Out-Msg "　exit code: $($local:proc.ExitCode) error count: $local:errorCount" 'Green'

		#破損しているダウンロードファイルをダウンロード履歴から削除
		try {
			#ロックファイルをロック
			while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
				Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			(Select-String `
				-Pattern $local:videoFileRelPath `
				-LiteralPath $script:historyFilePath `
				-Encoding UTF8 `
				-SimpleMatch `
				-NotMatch).Line `
			| Out-File $script:historyFilePath -Encoding UTF8
		} catch {
			Out-Msg "　ダウンロード履歴の更新に失敗しました: $local:videoFileRelPath" 'Green'
		} finally { $null = fileUnlock $script:historyLockFilePath }

		#破損しているダウンロードファイルを削除
		try {
			Remove-Item `
				-LiteralPath $local:videoFilePath `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Out-Msg "　ファイル削除できませんでした: $local:videoFilePath" 'Green' }
	} else {
		#終了コードが"0"のときはダウンロード履歴にチェック済フラグを立てる
		Out-Msg '　チェックOKでした' -Fg 'Gray'
		try {
			#ロックファイルをロック
			while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
				Out-Msg '　ファイルのロック解除待ち中です' -Fg 'Gray'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:videoHists = `
				Import-Csv `
				-Path $script:historyFilePath `
				-Encoding UTF8
			#該当の番組のチェックステータスを"1"に
			$(($local:videoHists).`
					Where({ $_.videoPath -eq $local:videoFileRelPath })).`
				videoValidated = '1'
			$local:videoHists | Export-Csv `
				-Path $script:historyFilePath `
				-NoTypeInformation `
				-Encoding UTF8
		} catch {
			Out-Msg "　ダウンロード履歴を更新できませんでした: $local:videoFileRelPath" 'Green'
		} finally { $null = fileUnlock $script:historyLockFilePath }
	}

}

#----------------------------------------------------------------------
#番組が無視されているかチェック
#----------------------------------------------------------------------
function checkIfIgnored {
	[CmdletBinding()]
	#	[OutputType([Boolean])]
	[OutputType([System.Void])]
	Param (
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
			Position = 0
		)]
		[Alias('ignoreText')]
		[String]$local:ignoreTitle,

		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
			Position = 1
		)]
		[Alias('seriesTitle')]
		[String]$local:videoSeries,

		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true,
			Position = 2
		)]
		[Alias('epsodeTitle')]
		[String]$local:videoTitle
	)

	process {

		#正規表現用のエスケープ
		$local:ignoreTitle = $local:ignoreTitle.Replace('\', '\\')
		$local:ignoreTitle = $local:ignoreTitle.Replace('*', '\*')
		$local:ignoreTitle = $local:ignoreTitle.Replace('+', '\+')
		$local:ignoreTitle = $local:ignoreTitle.Replace('.', '\.')
		$local:ignoreTitle = $local:ignoreTitle.Replace('?', '\?')
		$local:ignoreTitle = $local:ignoreTitle.Replace('{', '\{')
		$local:ignoreTitle = $local:ignoreTitle.Replace('}', '\}')
		$local:ignoreTitle = $local:ignoreTitle.Replace('(', '\(')
		$local:ignoreTitle = $local:ignoreTitle.Replace(')', '\)')
		$local:ignoreTitle = $local:ignoreTitle.Replace('[', '\[')
		$local:ignoreTitle = $local:ignoreTitle.Replace(']', '\]')
		$local:ignoreTitle = $local:ignoreTitle.Replace('^', '\^')
		$local:ignoreTitle = $local:ignoreTitle.Replace('$', '\$')
		$local:ignoreTitle = $local:ignoreTitle.Replace('-', '\-')
		$local:ignoreTitle = $local:ignoreTitle.Replace('|', '\|')
		$local:ignoreTitle = $local:ignoreTitle.Replace('/', '\/')

		#ダウンロード対象外と合致したものはそれ以上のチェック不要
		if ($(getNarrowChars $local:videoSeries) -match $(getNarrowChars $local:ignoreTitle)) {
			$script:ignore = $true ; break
		} elseif ($(getNarrowChars $local:videoTitle) -match $(getNarrowChars $local:ignoreTitle)) {
			$script:ignore = $true ; break
		} elseif ($(getNarrowChars $local:videoName) -match $(getNarrowChars $local:ignoreTitle)) {
			$script:ignore = $true ; break
		}

	}
}

