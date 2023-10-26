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
Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

#region 環境

#----------------------------------------------------------------------
#GUID取得
#----------------------------------------------------------------------
$progressPreference = 'silentlyContinue'
switch ($true) {
	$IsWindows {
		$script:os = (Get-CimInstance -Class Win32_OperatingSystem).Caption
		$script:kernel = (Get-CimInstance -Class Win32_OperatingSystem).Version
		$script:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
		$script:guid = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
		break
	}
	$IsLinux {
		if ((Test-Path '/etc/os-release')) {
			$script:os = (& grep 'PRETTY_NAME' /etc/os-release).replace('PRETTY_NAME=', '').Replace('"', '')
		} else { $script:os = (& uname -n) }
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = (Get-Content /etc/machine-id)
		if ((Test-Path '/etc/machine-id')) { $script:guid = (Get-Content /etc/machine-id) }
		else { $script:guid = [guid]::NewGuid() }
		break
	}
	$IsMacOS {
		$script:os = (& sw_vers -productName)
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		if ((Test-Path '/etc/machine-id')) { $script:guid = (Get-Content /etc/machine-id) }
		else { $script:guid = [guid]::NewGuid() }
		break
	}
	default {
		$script:os = [String][System.Environment]::OSVersion
		break
	}
}
$script:locale = (Get-Culture).Name
$script:tz = [String][TimeZoneInfo]::Local.BaseUtcOffset
$local:ipapi = ''
$script:clientEnvs = @{}
try {
	$local:ipapi = Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=66846719' -TimeoutSec $script:timeoutSec
	$local:GeoIPValues = $local:ipapi.psobject.properties
	foreach ($local:GeoIPValue in $local:GeoIPValues) { $script:clientEnvs.Add($local:GeoIPValue.Name, $local:GeoIPValue.Value) }
} catch { Write-Debug ('Geo IPのチェックに失敗しました') }
$script:clientEnvs = $script:clientEnvs.GetEnumerator() | Sort-Object -Property key
$progressPreference = 'Continue'

#----------------------------------------------------------------------
#統計取得
#----------------------------------------------------------------------
function goAnal {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Event')]
		[String]$local:event,
		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Type')]
		[String]$local:type,
		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('ID')]
		[String]$local:id
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	if (!($local:type)) { $local:type = '' }
	if (!($local:id)) { $local:id = '' }
	$local:epochTime = [decimal]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000)

	$progressPreference = 'silentlyContinue'
	$local:statisticsBase = 'https://hits.sh/github.com/dongaba/TVerRec/'
	try { $null = Invoke-WebRequest `
			-Uri ('{0}{1}.svg' -f $local:statisticsBase, $local:event) `
			-Method 'GET' `
			-TimeoutSec $script:timeoutSec
	} catch { Write-Debug ('Failed to collect count') }
	finally { $progressPreference = 'Continue' }

	$local:clientVars = (Get-Variable).where({ $_.Name -cmatch '^[a-z].+' }).where({ $null -ne $_.Value }).where({ $_.Name -notlike '*Base64' }).where({ $_.Name -notlike 'ipapi' })
	if ($local:event -eq 'search') { return }
	$local:gaURL = 'https://www.google-analytics.com/mp/collect'
	$local:gaKey = 'api_secret=UZ3InfgkTgGiR4FU-in9sw'
	$local:gaID = 'measurement_id=G-NMSF9L531G'
	$local:gaHeaders = New-Object 'System.Collections.Generic.Dictionary[[String],[String]]'
	$local:gaHeaders.Add('HOST', 'www.google-analytics.com')
	$local:gaHeaders.Add('Content-Type', 'application/json')
	$local:gaBody = ('{{ "client_id" : "{0}", ' -f $script:guid)
	$local:gaBody += ('"timestamp_micros" : "{0}", ' -f $local:epochTime)
	$local:gaBody += ('"non_personalized_ads" : false, ')
	$local:gaBody += ('"user_properties":{ ')
	foreach ($local:clientEnv in $script:clientEnvs) { $local:gaBody += ('"{0}" : {{"value" : "{1}"}}, ' -f $local:clientEnv.Key, $local:clientEnv.Value) }
	foreach ($local:clientVar in $local:clientVars) { $local:gaBody += ('"{0}" : {{"value" : "{1}"}}, ' -f $local:clientVar.Name, $local:clientVar.Value) }
	$local:gaBody = $local:gaBody.Trim(',', ' ')		#delete last comma
	$local:gaBody += ('}, "events" : [ { ')
	$local:gaBody += ('"name" : "{0}", ' -f $local:event)
	$local:gaBody += ('"params" : {')
	$local:gaBody += ('"Type" : "{0}", ' -f $local:type)
	$local:gaBody += ('"ID" : "{0}", ' -f $local:id)
	$local:gaBody += ('"Target" : "{0}/{1}", ' -f $local:type, $local:id)
	foreach ($local:clientEnv in $script:clientEnvs) { $local:gaBody += ('"{0}" : "{1}", ' -f $local:clientEnv.Key, $local:clientEnv.Value) }
	foreach ($local:clientVar in $local:clientVars) { $local:gaBody += ('"{0}" : "{1}", ' -f $local:clientVar.Name, $local:clientVar.Value) }
	$local:gaBody += ('"DisableValidation" : "{0}", ' -f $script:disableValidation)
	$local:gaBody += ('"SortwareDecode" : "{0}", ' -f $script:forceSoftwareDecodeFlag)
	$local:gaBody += ('"DecodeOption" : "{0}", ' -f $script:ffmpegDecodeOption)
	$local:gaBody = $local:gaBody.Trim(',', ' ')		#delete last comma
	$local:gaBody += ('} } ] }')

	$progressPreference = 'silentlyContinue'
	try {
		$null = Invoke-RestMethod `
			-Uri ('{0}?{1}&{2}' -f $local:gaURL, $local:gaKey, $local:gaID) `
			-Method 'POST' `
			-Headers $local:gaHeaders `
			-Body $local:gaBody `
			-TimeoutSec $script:timeoutSec
	} catch { Write-Debug ('Failed to collect statistics') }
	finally { $progressPreference = 'Continue' }

}

#endregion 環境

#----------------------------------------------------------------------
#TVerRec最新化確認
#----------------------------------------------------------------------
function checkLatestTVerRec {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$progressPreference = 'silentlyContinue'
	goAnal -Event 'launch'
	$local:versionUp = $false

	#TVerRecの最新バージョン取得
	$local:repo = 'dongaba/TVerRec'
	$local:releases = ('https://api.github.com/repos/{0}/releases' -f $local:repo)
	try { $local:appReleases = (Invoke-RestMethod -Uri $local:releases -Method 'GET' ) }
	catch { return }

	#GitHub側最新バージョンの整形
	# v1.2.3 → 1.2.3
	$local:latestVersion = $local:appReleases[0].Tag_Name.Trim('v', ' ')
	# v1.2.3 beta 4 → 1.2.3
	$local:latestMajorVersion = $local:latestVersion.split(' ')[0]

	#ローカル側バージョンの整形
	# v1.2.3 beta 4 → 1.2.3
	$local:appMajorVersion = $script:appVersion.split(' ')[0]

	#バージョン判定
	switch ($true) {
		($local:latestMajorVersion -gt $local:appMajorVersion ) {
			#最新バージョンのメジャーバージョンが大きい場合
			$local:versionUp = $true ; break
		}
		($local:latestMajorVersion -eq $local:appMajorVersion ) {
			#マイナーバージョンが設定されている場合
			if ( $local:appMajorVersion -ne $script:appVersion) { $local:versionUp = $true }
			#バージョンが完全に一致する場合
			else { $local:versionUp = $false }
			#ローカルバージョンの方が新しい場合
			break
		}
		default { $local:versionUp = $false ; break }
	}

	$progressPreference = 'Continue'

	#バージョンアップメッセージ
	if ($local:versionUp -eq $true ) {
		[Console]::ForegroundColor = 'Green'
		Write-Output ('')
		Write-Output ('❗ TVerRecの更新版があるようです。')
		Write-Output ('　Local Version {0}' -f $script:appVersion)
		Write-Output ('　Latest Version {0}' -f $local:latestVersion)
		Write-Output ('')
		[Console]::ResetColor()

		#変更履歴の表示
		foreach ($local:appRelease in $local:appReleases) {
			$local:pastVersion = $local:appRelease.Tag_Name.Trim('v', ' ')
			$local:pastReleaseNote = $local:appRelease.body.Replace('###', '■')
			if ($local:pastVersion -ge $local:appMajorVersion ) {
				[Console]::ForegroundColor = 'Green'
				Write-Output ('----------------------------------------------------------------------')
				Write-Output ('{0}の更新内容' -f $local:pastVersion)
				Write-Output ('----------------------------------------------------------------------')
				Write-Output $local:pastReleaseNote
				Write-Output ('')
				[Console]::ResetColor()
			}
		}

		#最新のアップデータを取得
		$local:latestUpdater = 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1'
		Invoke-WebRequest -Uri $local:latestUpdater -OutFile (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1')
		if ($IsWindows) { Unblock-File -LiteralPath (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1') }

		#アップデート実行
		Write-Warning ('TVerRecをアップデートするにはこのウィンドウを閉じ update_tverrec を実行してください。')
		foreach ($i in (1..10)) {
			Write-Progress -Activity ('残り{0}秒...' -f (10 - $i)) -PercentComplete ([Int][Math]::Ceiling((100 * $i) / 10))
			Start-Sleep -Second 1
		}

	}

}

#----------------------------------------------------------------------
#ytdlの最新化確認
#----------------------------------------------------------------------
function checkLatestYtdl {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$progressPreference = 'silentlyContinue'

	if ($script:disableUpdateYoutubedl -eq $false) {
		. (Convert-Path (Join-Path $scriptRoot 'functions/update_youtube-dl.ps1'))
		if ($? -eq $false) { Write-Error ('❗ youtube-dlの更新に失敗しました') ; exit 1 }
	}

	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$progressPreference = 'silentlyContinue'

	if ($script:disableUpdateFfmpeg -eq $false) {
		. (Convert-Path (Join-Path $scriptRoot 'functions/update_ffmpeg.ps1'))
		if ($? -eq $false) { Write-Error ('❗ ffmpegの更新に失敗しました') ; exit 1 }
	}

	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	if (!(Test-Path $script:downloadBaseDir -PathType Container))
	{ Write-Error ('❗ 番組ダウンロード先ディレクトリが存在しません。終了します。') ; exit 1 }
	if (!(Test-Path $script:downloadWorkDir -PathType Container))
	{ Write-Error ('❗ ダウンロード作業ディレクトリが存在しません。終了します。') ; exit 1 }
	if ($script:saveBaseDir -ne '') {
		$script:saveBaseDirArray = @()
		$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim()
		foreach ($saveDir in $script:saveBaseDirArray) {
			if (!(Test-Path $saveDir.Trim() -PathType Container))
			{ Write-Error ('❗ 番組移動先ディレクトリが存在しません。終了します。') ; exit 1 }
		}
	}
	if (!(Test-Path $script:ytdlPath -PathType Leaf))
	{ Write-Error ('❗ youtube-dlが存在しません。終了します。') ; exit 1 }
	if (!(Test-Path $script:ffmpegPath -PathType Leaf))
	{ Write-Error ('❗ ffmpegが存在しません。終了します。') ; exit 1 }
	if ((!(Test-Path $script:ffprobePath -PathType Leaf)) -And ($script:simplifiedValidation -eq $true))
	{ Write-Error ('❗ ffprobeが存在しません。終了します。') ; exit 1 }

	#ファイルが存在しない場合はサンプルファイルをコピー
	if (!(Test-Path $script:keywordFilePath -PathType Leaf)) {
		if (!(Test-Path $script:keywordFileSamplePath -PathType Leaf))
		{ Write-Error ('❗ ダウンロード対象キーワードファイル(サンプル)が存在しません。終了します。') ; exit 1 }
		Copy-Item -LiteralPath $script:keywordFileSamplePath -Destination $script:keywordFilePath -Force
	}
	if (!(Test-Path $script:ignoreFilePath -PathType Leaf)) {
		if (!(Test-Path $script:ignoreFileSamplePath -PathType Leaf))
		{ Write-Error ('❗ ダウンロード対象外番組ファイル(サンプル)が存在しません。終了します。') ; exit 1 }
		Copy-Item -LiteralPath $script:ignoreFileSamplePath -Destination $script:ignoreFilePath -Force
	}
	if (!(Test-Path $script:historyFilePath -PathType Leaf)) {
		if (!(Test-Path $script:historyFileSamplePath -PathType Leaf))
		{ Write-Error ('❗ ダウンロード履歴ファイル(サンプル)が存在しません。終了します。') ; exit 1 }
		Copy-Item -LiteralPath $script:historyFileSamplePath -Destination $script:historyFilePath -Force
	}
	if (!(Test-Path $script:listFilePath -PathType Leaf)) {
		if (!(Test-Path $script:listFileSamplePath -PathType Leaf))
		{ Write-Error ('❗ ダウンロードリストファイル(サンプル)が存在しません。終了します。') ; exit 1 }
		Copy-Item -LiteralPath $script:listFileSamplePath -Destination $script:listFilePath -Force
	}

	#念のためチェック
	if (!(Test-Path $script:keywordFilePath -PathType Leaf))
	{ Write-Error ('❗ ダウンロード対象キーワードファイルが存在しません。終了します。') ; exit 1 }
	if (!(Test-Path $script:ignoreFilePath -PathType Leaf))
	{ Write-Error ('❗ ダウンロード対象外番組ファイルが存在しません。終了します。') ; exit 1 }
	if (!(Test-Path $script:historyFilePath -PathType Leaf))
	{ Write-Error ('❗ ダウンロード履歴ファイルが存在しません。終了します。') ; exit 1 }
	if (!(Test-Path $script:listFilePath -PathType Leaf))
	{ Write-Error ('❗ ダウンロードリストファイルが存在しません。終了します。') ; exit 1 }
}

#----------------------------------------------------------------------
#ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function loadKeywordList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	try {
		#コメントと空行を除いて抽出
		$local:keywordNames = [String[]]((Get-Content $script:keywordFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^#.*$') }))
	} catch { Write-Error ('❗ ダウンロード対象キーワードの読み込みに失敗しました') ; exit 1 }

	return $local:keywordNames
}

#----------------------------------------------------------------------
#ダウンロードリストの読み込み
#----------------------------------------------------------------------
function loadDownloadList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	try {
		while ((fileLock $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		#空行とダウンロード対象外を除き、EpisodeIDのみを抽出
		$local:videoLinks = @((Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_.episodeID -cmatch '^#') }) | Select-Object episodeID)
	} catch { Write-Error ('❗ ダウンロードリストの読み込みに失敗しました') ; exit 1 }
	finally { $null = fileUnlock $script:listLockFilePath }

	return $local:videoLinks
}

#----------------------------------------------------------------------
#ダウンロード対象外番組の読み込(正規表現判定用)
#----------------------------------------------------------------------
function loadIgnoreList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	try {
		while ((fileLock $script:ignoreLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$local:ignoreTitles = @()
		#コメントと空行を除いて抽出
		$local:ignoreTitles = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^;.*$') }))
	} catch { Write-Error ('❗ ダウンロード対象外の読み込みに失敗しました') ; exit 1 }
	finally { $null = fileUnlock $script:ignoreLockFilePath }

	return $local:ignoreTitles
}

#----------------------------------------------------------------------
#ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function sortIgnoreList {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('ignoreTitle')]
		[String]$local:ignoreTitle
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:ignoreListNew = @()
	$local:ignoreComment = @()
	$local:ignoreTarget = @()
	$local:ignoreElse = @()

	try {
		while ((fileLock $script:ignoreLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$local:ignoreLists = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where( { !($_ -cmatch '^\s*$') }).Where( { !($_ -cmatch '^;;.*$') }))
	} catch { Write-Error ('❗ ダウンロード対象外リストの読み込みに失敗しました') ; exit 1 }
	finally { $null = fileUnlock $script:ignoreLockFilePath }

	$local:ignoreComment = (Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
	$local:ignoreTarget = $ignoreLists.Where({ $_ -eq $local:ignoreTitle }) | Sort-Object | Get-Unique
	$local:ignoreElse = $ignoreLists.Where({ $_ -ne $local:ignoreTitle })

	$local:ignoreListNew += $local:ignoreComment
	$local:ignoreListNew += $local:ignoreTarget
	$local:ignoreListNew += $local:ignoreElse

	try {
		while ((fileLock $script:ignoreLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		#改行コードLFを強制
		$local:ignoreListNew | ForEach-Object { ("{0}`n" -f $_) } | Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline
		Write-Debug ('ダウンロード対象外リストのソート更新完了')
	} catch { Write-Error ('❗ ダウンロード対象外リストのソートに失敗しました') ; exit 1 }
	finally {
		$null = fileUnlock $script:ignoreLockFilePath
		#ダウンロード対象外番組の読み込み
		$script:ignoreTitles = loadIgnoreList
	}

}


#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function getToken () {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

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
	Param ([String]$local:keywordName)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$script:requestHeader = @{
		'x-tver-platform-type' = 'web'
		'Origin'               = 'https://tver.jp'
		'Referer'              = 'https://tver.jp'
	}
	$script:episodeLinks = [System.Collections.Generic.List[String]]::new()
	$script:seriesLinks = [System.Collections.Generic.List[String]]::new()

	switch ($true) {
		($local:keywordName.IndexOf('series/') -eq 0) {
			#番組IDによる番組検索から番組ページのLinkを取得
			$local:seriesID = trimComment($local:keywordName).Replace('series/', '').Trim()
			goAnal -Event 'search' -Type 'series' -ID $local:seriesID
			try { $script:episodeLinks = getLinkFromSeriesID ($local:seriesID) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:02') ; continue }
			break
		}
		($local:keywordName.IndexOf('talents/') -eq 0) {
			#タレントIDによるタレント検索から番組ページのLinkを取得
			$local:talentID = trimComment($local:keywordName).Replace('talents/', '').Trim()
			goAnal -Event 'search' -Type 'talent' -ID $local:talentID
			try { $script:episodeLinks = getLinkFromTalentID ($local:talentID) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:03') ; continue }
			break
		}
		($local:keywordName.IndexOf('tag/') -eq 0) {
			#ジャンルなどのTag情報から番組ページのLinkを取得
			$local:tagID = trimComment($local:keywordName).Replace('tag/', '').Trim()
			goAnal -Event 'search' -Type 'tag' -ID $local:tagID
			try { $script:episodeLinks = getLinkFromTag ($local:tagID) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:04') ; continue }
			break
		}
		($local:keywordName.IndexOf('new/') -eq 0) {
			#新着番組から番組ページのLinkを取得
			$local:genre = trimComment($local:keywordName).Replace('new/', '').Trim()
			goAnal -Event 'search' -Type 'new' -ID $local:genre
			try { $script:episodeLinks = getLinkFromNew ($local:genre) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:05') ; continue }
			break
		}
		($local:keywordName.IndexOf('ranking/') -eq 0) {
			#ランキングによる番組ページのLinkを取得
			$local:genre = trimComment($local:keywordName).Replace('ranking/', '').Trim()
			goAnal -Event 'search' -Type 'ranking' -ID $local:genre
			try { $script:episodeLinks = getLinkFromRanking ($local:genre) }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:06') ; continue }
			break
		}
		($local:keywordName.IndexOf('toppage') -eq 0) {
			#トップページから番組ページのLinkを取得
			goAnal -Event 'search' -Type 'toppage'
			try { $script:episodeLinks = getLinkFromTopPage }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:07') ; continue }
			break
		}
		($local:keywordName.IndexOf('title/') -eq 0) {
			#番組名による新着検索から番組ページのLinkを取得
			$local:titleName = trimComment($local:keywordName).Replace('title/', '').Trim()
			goAnal -Event 'search' -Type 'title' -ID $local:titleName
			Write-Warning ('❗ 番組名検索は廃止されました。スキップします Err:08') ; continue
			break
		}
		($local:keywordName.IndexOf('sitemap') -eq 0) {
			#サイトマップから番組ページのLinkを取得
			goAnal -Event 'search' -Type 'sitemap'
			try { $script:episodeLinks = getLinkFromSiteMap }
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:09') ; continue }
			break
		}
		default {
			#タレント名や番組名などURL形式でない場合APIで検索結果から番組ページのLinkを取得
			goAnal -Event 'search' -Type 'free' -ID $local:keywordName
			try { $script:episodeLinks = getLinkFromFreeKeyword ($local:keywordName) }
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:SeasonID.Replace('season/', '').Replace('https://tver.jp/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID $local:searchResult.Content.Id
				break
			}
			'series' {
				Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:searchResults[$i].Content.Id)
				getLinkFromSeriesID $local:searchResult.Content.Id
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callTalentEpisode/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:talentID.Replace('talents/', '').Replace('https://tver.jp/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID $local:searchResult.Content.Id
				break
			}
			'series' {
				Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID $local:searchResult.Content.Id
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSpecialContents/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:specialMainID, $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.specialContents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
				Write-Host ('　Series {0} をバッファに保存中...' -f $local:searchResult.Content.Id)
				$script:seriesLinks.Add($local:searchResult.Content.Id)
				break
			}
			'special' {
				Write-Host ('　Special Detail {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSpecialDetailID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/'
	$local:callSearchURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:specialDetailID, $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Content.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
				Write-Host ('　Series {0} をバッファに保存中...' -f $local:searchResult.Content.Id)
				$script:seriesLinks.Add($local:searchResult.Content.Id)
				break
			}
			'special' {
				#再度Specialが出てきた際は再帰呼び出し
				Write-Host ('　Special Detail {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSpecialDetailID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callTagSearch'
	$local:callSearchURL = ('{0}/{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:tagID.Replace('tag/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://service-api.tver.jp/api/v1/callNewerDetail'
	$local:callSearchURL = ('{0}/{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:genre.Replace('new/', ''), $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://service-api.tver.jp/api/v1/callEpisodeRanking'
	if ($local:genre -eq 'all') {
		$local:callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $local:callSearchBaseURL, $script:platformUID, $script:platformToken)
	} else {
		$local:callSearchURL = ('{0}Detail/{1}?platform_uid={2}&platform_token={3}' -f $local:callSearchBaseURL, $local:genre.Replace('ranking/', '').Trim(), $script:platformUID, $script:platformToken )
	}
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents.Contents
	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$local:callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $local:callSearchBaseURL, $script:platformUID, $script:platformToken)
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Components
	foreach ($local:searchResult in $local:searchResults) {
		if ($local:searchResult.Type -eq 'horizontal' `
				-Or $local:searchResult.Type -eq 'ranking' `
				-Or $local:searchResult.Type -eq 'talents' `
				-Or $local:searchResult.type -eq 'billboard' `
				-Or $local:searchResult.type -eq 'episodeRanking' `
				-Or $local:searchResult.type -eq 'newer' `
				-Or $local:searchResult.type -eq 'ender' `
				-Or $local:searchResult.type -eq 'talent' `
				-Or $local:searchResult.type -eq 'special') {
			#横スクロール型 or 総合ランキング or 注目タレント or 特集
			foreach ($local:searchResultContent in $local:searchResult.Contents) {
				switch ($local:searchResultContent.type) {
					'live' { break }
					'episode' {
						$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResultContent.Content.Id)
						break
					}
					'season' {
						Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromSeasonID ($local:searchResultContent.Content.Id)
						break
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Host ('　Series {0} をバッファに保存中...' -f $local:searchResultContent.Content.Id)
						$script:seriesLinks.Add($local:searchResultContent.Content.Id)
						break
					}
					'talent' {
						Write-Host ('　Talent {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromTalentID ($local:searchResultContent.Content.Id)
						break
					}
					'specialMain' {
						Write-Host ('　Special Main {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromSpecialMainID ($local:searchResultContent.Content.Id)
						break
					}
					'special' {
						Write-Host ('　Special Detail {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Id)
						getLinkFromSpecialDetailID ($local:searchResultContent.Content.Id)
						break
					}
					default {
						#他にはないと思われるが念のため
						$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResultContent.type, $local:searchResultContent.Content.Id)
						break
					}
				}
			}
		} elseif ($local:searchResult.type -eq 'topics') {
			foreach ($local:searchResultContent in $local:searchResult.Contents) {
				switch ($local:searchResultContent.Content.Content.type) {
					'live' { break }
					'episode' {
						$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResultContent.Content.Content.Content.Id)
						break
					}
					'season' {
						Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Content.Content.Id)
						getLinkFromSeasonID ($local:searchResultContent.Content.Content.Content.Id)
						break
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Host ('　Series {0} をバッファに保存中...' -f $local:searchResultContent.Content.Content.Content.Id)
						$script:seriesLinks.Add(($local:searchResultContent.Content.Content.Content.Id))
						break
					}
					'talent' {
						Write-Host ('　Talent {0} からEpisodeを抽出中...' -f $local:searchResultContent.Content.Content.Content.Id)
						getLinkFromTalentID ($local:searchResultContent.Content.Content.Content.Id)
						break
					}
					default {
						#他にはないと思われるが念のため
						$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResultContent.Content.Content.type, $local:searchResultContent.Content.Content.Content.Id)
						break
					}
				}
			}
		} elseif ($local:searchResult.type -eq 'banner') { #広告	URLは $local:searchResult.contents.content.targetURL
		} elseif ($local:searchResult.type -eq 'resume') { #続きを見る	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} else {}

	}

	#バッファしておいたSeriesの重複を削除しEpisodeを抽出
	$script:seriesLinks = $script:seriesLinks | Sort-Object | Get-Unique
	foreach ($local:seriesID in $script:seriesLinks) {
		Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:seriesID)
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

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:callSearchURL = 'https://tver.jp/sitemap.xml'
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.urlset.url.loc | Sort-Object | Get-Unique

	foreach ($local:searchResult in $local:searchResults) {
		if ($local:searchResult -cmatch '\/episodes\/') { $script:episodeLinks.Add($local:searchResult) }
		elseif ($script:sitemapParseEpisodeOnly -eq $true) { Write-Debug ('Episodeではないためスキップします') }
		else {
			switch ($true) {
				($local:searchResult -cmatch '\/seasons\/') {
					Write-Host ('　{0} からEpisodeを抽出中...' -f $local:searchResult)
					try { getLinkFromSeasonID ($local:searchResult) }
					catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:11') ; continue }
					break
				}
				($local:searchResult -cmatch '\/series\/') {
					Write-Host ('　{0} からEpisodeを抽出中...' -f $local:searchResult)
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
	Param ([String]$local:keywordName)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:tverSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'
	$local:tverSearchURL = ('{0}?platform_uid={1}&platform_token={2}&keyword={3}' -f $local:tverSearchBaseURL, $script:platformUID, $script:platformToken, $local:keywordName )
	$local:searchResultsRaw = Invoke-RestMethod -Uri $local:tverSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$local:searchResults = $local:searchResultsRaw.Result.Contents

	foreach ($local:searchResult in $local:searchResults) {
		switch ($local:searchResult.type) {
			'live' { break }
			'episode' {
				$script:episodeLinks.Add('https://tver.jp/episodes/{0}' -f $local:searchResult.Content.Id)
				break
			}
			'season' {
				Write-Host ('　Season {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeasonID ($local:searchResult.Content.Id)
				break
			}
			'series' {
				Write-Host ('　Series {0} からEpisodeを抽出中...' -f $local:searchResult.Content.Id)
				getLinkFromSeriesID ($local:searchResult.Content.Id)
				break
			}
			default {
				#他にはないと思われるが念のため
				$script:episodeLinks.Add('https://tver.jp/{0}/{1}' -f $local:searchResult.type, $local:searchResult.Content.Id )
				break
			}
		}
	}

	return $script:episodeLinks | Sort-Object | Get-Unique
}

#----------------------------------------------------------------------
#youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function waitTillYtdlProcessGetFewer {
	[OutputType([System.Void])]
	Param ([Int32]$local:parallelDownloadFileNum)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $local:processName = 'yt-dlp' ; break }
		'ytdl-patched' { $local:processName = 'youtube-dl' ; break }
	}

	#youtube-dlのプロセスが設定値を超えたら一時待機
	try {
		switch ($true) {
			$IsWindows { $local:ytdlCount = [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero) ; break }
			$IsLinux { $local:ytdlCount = @(Get-Process -ErrorAction Ignore -Name $local:processName).Count ; break }
			$IsMacOS { $local:ytdlCount = (& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; break }
			default { $local:ytdlCount = 0 ; break }
		}
	} catch { $local:ytdlCount = 0 }			#プロセス数が取れなくてもとりあえず先に進む

	Write-Verbose ('現在のダウンロードプロセス一覧 ({0}個)' -f $local:ytdlCount)
	while ([Int]$local:ytdlCount -ge [Int]$local:parallelDownloadFileNum ) {
		Write-Host ('ダウンロードが{0}多重に達したので一時待機します。 ({1})' -f $local:parallelDownloadFileNum, (getTimeStamp))
		Write-Verbose ('現在のダウンロードプロセス一覧 ({0}個)' -f $local:ytdlCount)
		Start-Sleep -Seconds 60
		try {
			switch ($true) {
				$IsWindows { $local:ytdlCount = [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero) ; break }
				$IsLinux { $local:ytdlCount = @(Get-Process -ErrorAction Ignore -Name $local:processName).Count ; break }
				$IsMacOS { $local:ytdlCount = (& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; break }
				default { $local:ytdlCount = 0 ; break }
			}
		} catch { Write-Debug ('youtube-dlのプロセス数の取得に失敗しました') ; $local:ytdlCount = 0 }
	}
}

#----------------------------------------------------------------------
#TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function downloadTVerVideo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Keyword')]
		[String]$script:keywordName,

		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('URL')]
		[String]$script:videoPageURL,

		[Parameter(Mandatory = $true, Position = 2)]
		[Alias('Link')]
		[String]$script:videoLink,

		[Parameter(Mandatory = $true, Position = 3)]
		[Alias('Single')]
		[String]$script:videoSingle
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = '' ; $script:mediaName = '' ; $script:descriptionText = ''
	$script:newVideo = $null
	$script:ignore = $false
	$script:skipWithValidation = $false ; $script:skipWithoutValidation = $false

	#TVerのAPIを叩いて番組情報取得
	goAnal -Event 'getinfo' -Type 'link' -ID $script:videoLink
	try { getVideoInfo -Link $script:videoLink }
	catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:90') ; continue }

	#ダウンロードファイル情報をセット
	$script:videoName = getVideoFileName `
		-Series $script:videoSeries `
		-Season $script:videoSeason `
		-Episode $script:videoEpisode `
		-Title $script:videoTitle `
		-Date $script:broadcastDate

	$script:videoFileDir = getFileNameWoInvChars (getSpecialCharacterReplaced ('{0} {1}' -f $script:videoSeries, $script:videoSeason ).Trim(' ', '.'))
	if ($script:sortVideoByMedia -eq $true) {
		$script:mediaName = getFileNameWoInvChars $script:mediaName
		$script:videoFileDir = (Join-Path $script:downloadBaseDir $script:mediaName | Join-Path -ChildPath $script:videoFileDir)
	} else {
		$script:videoFileDir = (Join-Path $script:downloadBaseDir $script:videoFileDir)
	}
	$script:videoFilePath = Join-Path $script:videoFileDir $script:videoName
	$script:videoFileRelPath = $script:videoFilePath.Replace($script:downloadBaseDir, '').Replace('\', '/')
	$script:videoFileRelPath = $script:videoFileRelPath.Substring(1, ($script:videoFileRelPath.Length - 1))

	#番組情報のコンソール出力
	showVideoInfo `
		-Name $script:videoName `
		-Date $script:broadcastDate `
		-Media $script:mediaName `
		-EndTime $script:endTime
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
			-Time (getTimeStamp) `
			-Description $descriptionText
	}

	#番組タイトルが取得できなかった場合はスキップ次の番組へ
	if ($script:videoName -eq '.mp4') { Write-Warning ('❗ 番組タイトルを特定できませんでした。スキップします') ; continue }

	$local:historyMatch = $script:historyFileData.Where({ $_.videoName -eq $script:videoName })
	if ($local:historyMatch.Count -ne 0) {
		#ファイル名がすでにダウンロード履歴に存在する場合はスキップフラグを立ててダウンロード履歴に書き込み処理へ
		#リストファイルにチェック済の状態で存在するかチェック
		$local:historyMatch = $script:historyFileData.Where({ $_.videoPath -eq $script:videoFileRelPath }).Where({ $_.videoValidated -eq '1' })
		if ($local:historyMatch.Count -eq 0) { Write-Warning ('❗ すでにダウンロード済ですが未検証の番組です。スキップします') }
		else { Write-Warning ('❗ すでにダウンロード済・検証済の番組です。番組IDが変更になった可能性があります。スキップします') }
		$script:skipWithoutValidation = $true
	} elseif (Test-Path $script:videoFilePath) {
		#ダウンロード履歴にファイル名が存在しないがファイルが既に存在する場合はスキップフラグを立ててダウンロード履歴に書き込み処理へ
		#リストファイルにチェック済の状態で存在するかチェック
		$local:historyMatch = $script:historyFileData.Where({ $_.videoPath -eq $script:videoFileRelPath }).Where({ $_.videoValidated -eq '1' })
		if ($local:historyMatch.Count -eq 0) {
			Write-Warning ('❗ すでにダウンロード済ですが未検証の番組です。ダウンロード履歴に追加します')
			$script:skipWithValidation = $true
		} else { Write-Warning ('❗ すでにダウンロード済・検証済の番組です。スキップします') ; continue }
	} else {
		foreach ($local:ignoreTitle in $script:ignoreTitles) {
			if ($local:ignoreTitle -ne '') {
				#ダウンロード対象外と合致したものはそれ以上のチェック不要
				if (($script:videoName -match [Regex]::Escape($local:ignoreTitle)) -Or ($script:videoSeries -match [Regex]::Escape($local:ignoreTitle))) {
					sortIgnoreList $local:ignoreTitle
					$script:ignore = $true ; break
				}
			}
		}
		Write-Debug ('Ignored: {0}' -f $script:ignore)
	}

	#スキップフラグが立っているかチェック
	switch ($true) {
		($script:ignore -eq $true) {
			Write-Output ('❗ ダウンロード対象外としたファイルをダウンロード履歴に追加します')
			$script:newVideo = [pscustomobject]@{
				videoPage       = $script:videoPageURL
				videoSeriesPage = $script:videoSeriesPageURL
				genre           = $script:keywordName
				series          = $script:videoSeries
				season          = $script:videoSeason
				title           = $script:videoTitle
				media           = $script:mediaName
				broadcastDate   = $script:broadcastDate
				downloadDate    = getTimeStamp
				videoDir        = $script:videoFileDir
				videoName       = '-- IGNORED --'
				videoPath       = '-- IGNORED --'
				videoValidated  = '0'
			}
			break
		}
		($script:skipWithValidation -eq $true) {
			Write-Output ('❗ ダウンロード済の未検証のファイルをダウンロード履歴に追加します')
			$script:newVideo = [pscustomobject]@{
				videoPage       = $script:videoPageURL
				videoSeriesPage = $script:videoSeriesPageURL
				genre           = $script:keywordName
				series          = $script:videoSeries
				season          = $script:videoSeason
				title           = $script:videoTitle
				media           = $script:mediaName
				broadcastDate   = $script:broadcastDate
				downloadDate    = getTimeStamp
				videoDir        = $script:videoFileDir
				videoName       = '-- SKIPPED --'
				videoPath       = $videoFileRelPath
				videoValidated  = '0'
			}
			break
		}
		($script:skipWithoutValidation -eq $true) {
			Write-Output ('❗ 番組IDが変更になった可能性があるダウンロード済の未検証のファイルをダウンロード履歴に追加します')
			$script:newVideo = [pscustomobject]@{
				videoPage       = $script:videoPageURL
				videoSeriesPage = $script:videoSeriesPageURL
				genre           = $script:keywordName
				series          = $script:videoSeries
				season          = $script:videoSeason
				title           = $script:videoTitle
				media           = $script:mediaName
				broadcastDate   = $script:broadcastDate
				downloadDate    = getTimeStamp
				videoDir        = $script:videoFileDir
				videoName       = '-- SKIPPED --'
				videoPath       = $videoFileRelPath
				videoValidated  = '1'
			}
			break
		}
		default {
			Write-Output ('💡 ダウンロードするファイルをダウンロード履歴に追加します')
			$script:newVideo = [pscustomobject]@{
				videoPage       = $script:videoPageURL
				videoSeriesPage = $script:videoSeriesPageURL
				genre           = $script:keywordName
				series          = $script:videoSeries
				season          = $script:videoSeason
				title           = $script:videoTitle
				media           = $script:mediaName
				broadcastDate   = $script:broadcastDate
				downloadDate    = getTimeStamp
				videoDir        = $script:videoFileDir
				videoName       = $script:videoName
				videoPath       = $script:videoFileRelPath
				videoValidated  = '0'
			}
			break
		}
	}

	#ダウンロード履歴CSV書き出し
	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$script:newVideo | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8 -Append
		$script:historyFileData = Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
		Write-Debug ('ダウンロード履歴を書き込みました')
	} catch { Write-Warning ('❗ ダウンロード履歴を更新できませんでした。スキップします') ; continue }
	finally { $null = fileUnlock $script:historyLockFilePath }

	#スキップやダウンロード対象外でなければyoutube-dl起動
	if (($script:videoSingle -eq $false) -And (($script:ignore -eq $true) -Or ($script:skipWithValidation -eq $true) -Or ($script:skipWithoutValidation -eq $true))) {
		#スキップ対象やダウンロード対象外は飛ばして次のファイルへ
		continue
	} else {
		#移動先ディレクトリがなければ作成
		if (-Not (Test-Path $script:videoFileDir -PathType Container)) {
			try { $null = New-Item -ItemType Directory -Path $script:videoFileDir -Force }
			catch { Write-Warning ('❗ 移動先ディレクトリを作成できませんでした') ; continue }
		}
		#youtube-dl起動
		try { executeYtdl $script:videoPageURL }
		catch { Write-Warning ('❗ youtube-dlの起動に失敗しました') }
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
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Keyword')]
		[String]$script:keywordName,
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Link')]
		[String]$script:videoLink
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$script:videoName = '' ; $script:videoFilePath = '' ; $script:videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$local:ignoreWord = ''
	$script:newVideo = $null
	$script:ignore = $false ;

	#TVerのAPIを叩いて番組情報取得
	goAnal -Event 'getinfo' -Type 'link' -ID $script:videoLink
	try { getVideoInfo -Link $script:videoLink }
	catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:91') ; continue }

	#ダウンロード対象外に入っている番組の場合はリスト出力しない
	foreach ($local:ignoreTitle in $script:ignoreTitles) {
		if ($local:ignoreTitle -ne '') {
			if ($script:videoSeries -cmatch [Regex]::Escape($local:ignoreTitle)) {
				$local:ignoreWord = $local:ignoreTitle
				sortIgnoreList $local:ignoreTitle
				$script:ignore = $true
				#ダウンロード対象外と合致したものはそれ以上のチェック不要
				break
			} elseif ($script:videoTitle -cmatch [Regex]::Escape($local:ignoreTitle)) {
				$local:ignoreWord = $local:ignoreTitle
				sortIgnoreList $local:ignoreTitle
				$script:ignore = $true
				#ダウンロード対象外と合致したものはそれ以上のチェック不要
				break
			}
		}
	}

	#スキップフラグが立っているかチェック
	if ($script:ignore -eq $true) {
		Write-Output ('❗ 番組をコメントアウトした状態でリストファイルに追加します')
		$script:newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = ('#{0}' -f $script:videoLink.Replace('https://tver.jp/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $script:keywordName
			ignoreWord    = $local:ignoreWord
		}
	} else {
		Write-Output ('💡 番組をリストファイルに追加します')
		$script:newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = ('{0}' -f $script:videoLink.Replace('https://tver.jp/episodes/', ''))
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
		while ((fileLock $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$script:newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append
		Write-Debug ('ダウンロードリストを書き込みました')
	} catch { Write-Warning ('❗ ダウンロードリストを更新できませんでした。スキップします') ; continue }
	finally { $null = fileUnlock $script:listLockFilePath }
	$script:listFileData = Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8

}

#----------------------------------------------------------------------
#TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function getVideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('Link')]
		[String]$local:videoLink
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:episodeID = $local:videoLink.Replace('https://tver.jp/', '').Replace('https://tver.jp', '').Replace('/episodes/', '').Replace('episodes/', '')

	#----------------------------------------------------------------------
	#番組説明以外
	$local:tverVideoInfoBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$local:requestHeader = @{
		'x-tver-platform-type' = 'web'
	}
	$local:tverVideoInfoURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $local:tverVideoInfoBaseURL, $local:episodeID, $script:platformUID, $script:platformToken)
	$local:response = Invoke-RestMethod -Uri $local:tverVideoInfoURL -Method 'GET' -Headers $local:requestHeader -TimeoutSec $script:timeoutSec

	#シリーズ
	#	$response.Result.Series.Content.Title
	#	$response.Result.Episode.Content.SeriesTitle
	#		Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
	#		Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
	#	なのでSeries.Content.TitleとEpisode.Content.SeriesTitleの短い方を採用する
	if ($local:response.Result.Episode.Content.SeriesTitle.Length -le $local:response.Result.Series.Content.Title.Length ) {
		$script:videoSeries = (getSpecialCharacterReplaced (getNarrowChars ($local:response.Result.Episode.Content.SeriesTitle))).Trim()
	} else {
		$script:videoSeries = (getSpecialCharacterReplaced (getNarrowChars ($local:response.Result.Series.Content.Title))).Trim()
	}
	$script:videoSeriesID = $local:response.Result.Series.Content.Id
	$script:videoSeriesPageURL = ('https://tver.jp/series/{0}' -f $local:response.Result.Series.Content.Id)

	#シーズン
	#Season Name
	#	$response.Result.Season.Content.Title
	$script:videoSeason = (getSpecialCharacterReplaced (getNarrowChars ($local:response.Result.Season.Content.Title))).Trim()
	$script:videoSeasonID = $local:response.Result.Season.Content.Id

	#エピソード
	#	$response.Result.Episode.Content.Title
	$script:videoTitle = (getSpecialCharacterReplaced (getNarrowChars ($local:response.Result.Episode.Content.Title))).Trim()
	$script:videoEpisodeID = $local:response.Result.Episode.Content.Id

	#放送局
	#	$response.Result.Episode.Content.BroadcasterName
	#	$response.Result.Episode.Content.ProductionProviderName
	$script:mediaName = (getNarrowChars ($local:response.Result.Episode.Content.BroadcasterName)).Trim()
	$script:providerName = (getNarrowChars ($local:response.Result.Episode.Content.ProductionProviderName)).Trim()

	#放送日
	#	$response.Result.Episode.Content.BroadcastDateLabel
	$script:broadcastDate = (($response.Result.Episode.Content.BroadcastDateLabel).Replace('ほか', '').Replace('放送分', '放送')).Trim()

	#配信終了日時
	#	$response.Result.Episode.Content.endAt
	$script:endTime = (unixTimeToDateTime ($response.Result.Episode.Content.endAt)).AddHours(9)

	#----------------------------------------------------------------------
	#番組説明
	$local:versionNum = $local:response.result.episode.content.version
	$local:tverVideoInfoBaseURL = 'https://statics.tver.jp/content/episode/'
	$local:requestHeader = @{
		'origin'  = 'https://tver.jp'
		'referer' = 'https://tver.jp'
	}
	$local:tverVideoInfoURL = ('{0}{1}.json?v={2}' -f $local:tverVideoInfoBaseURL, $local:episodeID, $local:versionNum)
	$local:videoInfo = Invoke-RestMethod `
		-Uri $local:tverVideoInfoURL `
		-Method 'GET' `
		-Headers $local:requestHeader `
		-TimeoutSec $script:timeoutSec
	$script:descriptionText = (getNarrowChars ($local:videoInfo.Description).Replace('&amp;', '&')).Trim()
	$script:videoEpisode = (getNarrowChars ($local:videoInfo.No)).Trim()

	#----------------------------------------------------------------------
	#各種整形

	#「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote -eq $true) {
		if ($script:videoSeries -cmatch '(.*)(《.*》)(.*)') { $script:videoSeries = ('{0}{1}' -f $Matches[1], $Matches[3]).Replace('  ', ' ').Trim() }
		if ($script:videoSeason -cmatch '(.*)(《.*》)(.*)') { $script:videoSeason = ('{0}{1}' -f $Matches[1], $Matches[3]).Replace('  ', ' ').Trim() }
		if ($script:videoTitle -cmatch '(.*)(《.*》)(.*)') { $script:videoTitle = ('{0}{1}' -f $Matches[1], $Matches[3]).Replace('  ', ' ').Trim() }
	}

	#シーズン名が本編の場合はシーズン名をクリア
	if ($script:videoSeason -eq '本編') { $script:videoSeason = '' }

	#シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($script:videoSeries -cmatch [Regex]::Escape($script:videoSeason)) { $script:videoSeason = '' }

	#放送日を整形
	$local:broadcastYMD = $null
	if ($script:broadcastDate -cmatch '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		#当年だと仮定して放送日を抽出
		$local:broadcastYMD = [DateTime]::ParseExact(('{0}{1}{2}' -f (Get-Date -Format 'yyyy'), $Matches[1].padleft(2, '0'), $Matches[3].padleft(2, '0')), 'yyyyMMdd', $null)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する
		#(年末の番組を年初にダウンロードするケース)
		if ((Get-Date).AddDays(+1) -lt $local:broadcastYMD) { $script:broadcastDate = ('{0}年' -f (Get-Date).AddYears(-1).ToString('yyyy')) }
		else { $script:broadcastDate = ('{0}年' -f (Get-Date).ToString('yyyy')) }
		$script:broadcastDate = ('{0}{1}{2}{3}{4}{5}' -f $script:broadcastDate, $Matches[1].padleft(2, '0'), $Matches[2], $Matches[3].padleft(2, '0'), $Matches[4], $Matches[6])
	}

}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function getVideoFileName {
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Series')]
		[String]$local:videoSeries,

		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Season')]
		[String]$local:videoSeason,

		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Episode')]
		[String]$local:videoEpisode,

		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('Title')]
		[String]$local:videoTitle,

		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('Date')]
		[String]$local:broadcastDate
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:videoName = ''

	#ファイル名を生成
	if ($script:addSeriesName -eq $true) { $local:videoName = ('{0}{1} ' -f $local:videoName, $local:videoSeries) }
	if ($script:addSeasonName -eq $true) { $local:videoName = ('{0}{1} ' -f $local:videoName, $local:videoSeason) }
	if ($script:addBrodcastDate -eq $true) { $local:videoName = ('{0}{1} ' -f $local:videoName, $local:broadcastDate) }
	if ($script:addEpisodeNumber -eq $true) { $local:videoName = ('{0}Ep{1} ' -f $local:videoName, $local:videoEpisode) }
	$local:videoName = ('{0}{1}' -f $local:videoName, $local:videoTitle)

	#ファイル名にできない文字列を除去
	$local:videoName = (getFileNameWoInvChars $local:videoName).Replace('  ', ' ').Trim()

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	$local:videoNameTemp = ''
	#youtube-dlの中間ファイル等を考慮して安全目の上限値
	$local:fileNameLimit = $script:fileNameLengthMax - 25
	$local:videoNameByte = [System.Text.Encoding]::UTF8.GetByteCount($local:videoName)

	#ファイル名を1文字ずつ増やしていき、上限に達したら残りは「……」とする
	if ($local:videoNameByte -gt $local:fileNameLimit) {
		for ($i = 1 ; [System.Text.Encoding]::UTF8.GetByteCount($local:videoNameTemp) -lt $local:fileNameLimit ; $i++) {
			$local:videoNameTemp = $local:videoName.Substring(0, $i)
		}
		#ファイル名省略の印
		$local:videoName = ('{0}……' -f $local:videoNameTemp)
	}
	$local:videoName = getFileNameWoInvChars ('{0}.mp4' -f $local:videoName)
	if ($local:videoName.Contains('.mp4') -eq $false) { Write-Error ('　ダウンロードファイル名の設定がおかしいです') }

	return $local:videoName
}

#----------------------------------------------------------------------
#番組情報表示
#----------------------------------------------------------------------
function showVideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('Name')]
		[String]$local:videoName,
		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Date')]
		[String]$local:broadcastDate,
		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Media')]
		[String]$local:mediaName,
		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('EndTime')]
		[String]$local:endTime
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	Write-Output ('　番組名:　 {0}' -f $local:videoName.Replace('.mp4', ''))
	Write-Output ('　放送日:　 {0}' -f $local:broadcastDate)
	Write-Output ('　テレビ局: {0}' -f $local:mediaName)
	Write-Output ('　配信終了: {0}' -f $local:endTime)
}
#----------------------------------------------------------------------
#番組情報デバッグ表示
#----------------------------------------------------------------------
function showVideoDebugInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('URL')]
		[String]$local:videoPageURL,
		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('SeriesURL')]
		[String]$local:videoSeriesPageURL,
		[Parameter(Mandatory = $false, Position = 2)]
		[Alias('Keyword')]
		[String]$local:keywordName,
		[Parameter(Mandatory = $false, Position = 3)]
		[Alias('Series')]
		[String]$local:videoSeries,
		[Parameter(Mandatory = $false, Position = 4)]
		[Alias('Season')]
		[String]$local:videoSeason,
		[Parameter(Mandatory = $false, Position = 5)]
		[Alias('Episode')]
		[String]$local:videoEpisode,
		[Parameter(Mandatory = $false, Position = 6)]
		[Alias('Title')]
		[String]$local:videoTitle,
		[Parameter(Mandatory = $false, Position = 7)]
		[Alias('Path')]
		[String]$local:videoFilePath,
		[Parameter(Mandatory = $false, Position = 8)]
		[Alias('Time')]
		[String]$local:processedTime,
		[Parameter(Mandatory = $false, Position = 9)]
		[Alias('Description')]
		[String]$local:descriptionText
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	Write-Debug ('番組エピソードページ: {0}' -f $local:videoPageURL)
	Write-Debug ('番組シリーズページ: {0}' -f $local:videoSeriesPageURL)
	Write-Debug ('キーワード: {0}' -f $local:keywordName)
	Write-Debug ('シリーズ: {0}' -f $local:videoSeries)
	Write-Debug ('シーズン: {0}' -f $local:videoSeason)
	Write-Debug ('エピソード: {0}' -f $local:videoEpisode)
	Write-Debug ('タイトル: {0}' -f $local:videoTitle)
	Write-Debug ('ファイル: {0}' -f $local:videoFilePath)
	Write-Debug ('取得日付: {0}' -f $local:processedTime)
	Write-Debug ('番組説明: {0}' -f $local:descriptionText)
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動
#----------------------------------------------------------------------
function executeYtdl {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('URL')]
		[String]$local:videoPageURL
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	goAnal -Event 'download'

	$local:tmpDir = ('"temp:{0}"' -f $script:downloadWorkDir)
	$local:saveDir = ('"home:{0}"' -f $script:videoFileDir)
	$local:subttlDir = ('"subtitle:{0}"' -f $script:downloadWorkDir)
	$local:thumbDir = ('"thumbnail:{0}"' -f $script:downloadWorkDir)
	$local:chaptDir = ('"chapter:{0}"' -f $script:downloadWorkDir)
	$local:descDir = ('"description:{0}"' -f $script:downloadWorkDir)
	$local:saveFile = ('"{0}"' -f $script:videoName)
	$local:ytdlArgs = (' {0}' -f $script:ytdlBaseArgs)
	$local:ytdlArgs += (' {0} {1}' -f '--concurrent-fragments', $script:parallelDownloadNumPerFile)
	$local:ytdlArgs += (' {0} {1}M' -f '--limit-rate', [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8))
	if ($script:embedSubtitle -eq $true) { $local:ytdlArgs += (' {0}' -f '--sub-langs all --convert-subs srt --embed-subs') }
	if ($script:embedMetatag -eq $true) { $local:ytdlArgs += (' {0}' -f '--embed-metadata') }
	$local:ytdlArgs += (' {0} {1}' -f '--paths', $local:saveDir)
	$local:ytdlArgs += (' {0} {1}' -f '--paths', $local:tmpDir)
	$local:ytdlArgs += (' {0} {1}' -f '--paths', $local:subttlDir)
	$local:ytdlArgs += (' {0} {1}' -f '--paths', $local:thumbDir)
	$local:ytdlArgs += (' {0} {1}' -f '--paths', $local:chaptDir)
	$local:ytdlArgs += (' {0} {1}' -f '--paths', $local:descDir)
	$local:ytdlArgs += (' {0} {1}' -f '--ffmpeg-location', $script:ffmpegPath)
	$local:ytdlArgs += (' {0} {1}' -f '--output', $local:saveFile)
	$local:ytdlArgs += (' {0}' -f $script:ytdlOption)
	$local:ytdlArgs += (' {0}' -f $local:videoPageURL)

	if ($IsWindows) {
		try {
			Write-Debug ('youtube-dl起動コマンド: {0}{1}' -f $script:ytdlPath, $local:ytdlArgs)
			$null = Start-Process `
				-FilePath $script:ytdlPath `
				-ArgumentList $local:ytdlArgs `
				-PassThru `
				-WindowStyle $script:windowShowStyle
		} catch { Write-Error ('❗ youtube-dlの起動に失敗しました') ; return }
	} else {
		Write-Debug ('youtube-dl起動コマンド: nohup {0}{1}' -f $script:ytdlPath, $local:ytdlArgs)
		try {
			$null = Start-Process `
				-FilePath nohup `
				-ArgumentList ($script:ytdlPath, $local:ytdlArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError /dev/zero
		} catch { Write-Error ('❗ youtube-dlの起動に失敗しました') ; return }
	}
}

#----------------------------------------------------------------------
#youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function waitTillYtdlProcessIsZero () {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $local:processName = 'yt-dlp' ; break }
		'ytdl-patched' { $local:processName = 'youtube-dl' ; break }
	}

	try {
		switch ($true) {
			$IsWindows { $local:ytdlCount = [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero ) ; break }
			$IsLinux { $local:ytdlCount = @(Get-Process -ErrorAction Ignore -Name $local:processName).Count ; break }
			$IsMacOS { $local:ytdlCount = (& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; break }
			default { $local:ytdlCount = 0 ; break }
		}
	} catch { $local:ytdlCount = 0 }

	while ($local:ytdlCount -ne 0) {
		try {
			Write-Verbose ('現在のダウンロードプロセス一覧 ({0}個)' -f $local:ytdlCount)
			Start-Sleep -Seconds 60
			switch ($true) {
				$IsWindows { $local:ytdlCount = [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero ) ; break }
				$IsLinux { $local:ytdlCount = @(Get-Process -ErrorAction Ignore -Name $local:processName).Count ; break }
				$IsMacOS { $local:ytdlCount = (& $local:psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; break }
				default { $local:ytdlCount = 0 ; break }
			}
		} catch { $local:ytdlCount = 0 }
	}
}

#----------------------------------------------------------------------
#ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function cleanDB {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:historyData0 = @()
	$local:historyData1 = @()
	$local:historyData2 = @()
	$local:mergedHistoryData = @()

	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }

		#videoValidatedが空白でないもの
		$local:historyData = ((Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8).Where({ $null -ne $_.videoValidated }))
		$local:historyData0 = (($local:historyData).Where({ $_.videoValidated -eq '0' }))
		$local:historyData1 = (($local:historyData).Where({ $_.videoValidated -eq '1' }))
		$local:historyData2 = (($local:historyData).Where({ $_.videoValidated -eq '2' }))

		$local:mergedHistoryData += $local:historyData0
		$local:mergedHistoryData += $local:historyData1
		$local:mergedHistoryData += $local:historyData2
		$local:mergedHistoryData | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8

	} catch { Write-Warning ('❗ ダウンロード履歴の更新に失敗しました') }
	finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#30日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function purgeDB {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('RetentionPeriod')]
		[Int32]$local:retentionPeriod
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$local:purgedHist = ((Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8).Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * [Int32]$local:retentionPeriod) }))
		$local:purgedHist | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
	} catch { Write-Warning ('❗ ダウンロード履歴のクリーンアップに失敗しました') }
	finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function uniqueDB {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:uniquedHist = @()

	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }

		#videoPageで1つしかないもの残し、ダウンロード日時でソート
		$local:uniquedHist = Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8 `
		| Group-Object -Property 'videoPage' `
		| Where-Object count -EQ 1 `
		| Select-Object -ExpandProperty group `
		| Sort-Object -Property downloadDate

		$local:uniquedHist | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8

	} catch { Write-Warning ('❗ ダウンロード履歴の更新に失敗しました') }
	finally { $null = fileUnlock $script:historyLockFilePath }
}

#----------------------------------------------------------------------
#番組の整合性チェック
#----------------------------------------------------------------------
function checkVideo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('DecodeOption')]
		[String]$local:decodeOption,
		[Parameter(Mandatory = $false, Position = 1)]
		[Alias('Path')]
		[String]$local:videoFileRelPath
	)

	Write-Debug ('{0}' -f $myInvocation.MyCommand.name)

	$local:errorCount = 0
	$local:checkStatus = 0
	$local:videoFilePath = Join-Path $script:downloadBaseDir $local:videoFileRelPath
	try { $null = New-Item -Path $script:ffpmegErrorLogPath -ItemType File -Force }
	catch { Write-Warning ('❗ ffmpegエラーファイルを初期化できませんでした') ; return }

	#これからチェックする番組のステータスをチェック
	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$local:videoHists = @(Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8)
		$local:checkStatus = ($local:videoHists.Where({ $_.videoPath -eq $local:videoFileRelPath })).videoValidated
		switch ($local:checkStatus) {
			#0:未チェック、1:チェック済、2:チェック中
			'0' {
				$local:videoHists.Where({ $_.videoPath -eq $local:videoFileRelPath }).Where({ $_.videoValidated = '2' })
				$local:videoHists | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
				break
			}
			'1' { Write-Warning ('💡 他プロセスでチェック済です') ; return ; break }
			'2' { Write-Warning ('💡 他プロセスでチェック中です') ; return ; break }
			default { Write-Warning ('❗ 既にダウンロード履歴から削除されたようです: {0}' -f $local:videoFileRelPath) ; return ; break }
		}
	} catch { Write-Warning ('❗ ダウンロード履歴を更新できませんでした: {0}' -f $local:videoFileRelPath) ; return }
	finally { $null = fileUnlock $script:historyLockFilePath }

	$local:checkFile = ('"{0}"' -f $local:videoFilePath)
	goAnal -Event 'validate'

	if ($script:simplifiedValidation -eq $true) {
		#ffprobeを使った簡易検査
		$local:ffprobeArgs = (' -hide_banner -v error -xerror -i {0}' -f $local:checkFile)
		Write-Debug ('ffprobe起動コマンド: {0}{1}' -f $script:ffprobePath, $local:ffprobeArgs)
		try {
			if ($IsWindows) {
				$local:proc = Start-Process `
					-FilePath $script:ffprobePath `
					-ArgumentList ($local:ffprobeArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$local:proc = Start-Process `
					-FilePath $script:ffprobePath `
					-ArgumentList ($local:ffprobeArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			}
		} catch { Write-Error ('❗ ffprobeを起動できませんでした') ; return }
	} else {
		#ffmpegeを使った完全検査
		$local:ffmpegArgs = (' -hide_banner -v error -xerror {0} -i {1} -f null - ' -f $local:decodeOption, $local:checkFile)
		Write-Debug ('ffmpeg起動コマンド: {0}{1}' -f $script:ffmpegPath, $local:ffmpegArgs)
		try {
			if ($IsWindows) {
				$local:proc = Start-Process `
					-FilePath $script:ffmpegPath `
					-ArgumentList ($local:ffmpegArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$local:proc = Start-Process `
					-FilePath $script:ffmpegPath `
					-ArgumentList ($local:ffmpegArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			}
		} catch { Write-Error ('❗ ffmpegを起動できませんでした') ; return }
	}

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			$local:errorCount = (Get-Content -LiteralPath $script:ffpmegErrorLogPath | Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffpmegErrorLogPath -Encoding UTF8 | ForEach-Object { Write-Debug $_ }
		}
	} catch { Write-Warning ('❗ ffmpegエラーの数をカウントできませんでした') ; $local:errorCount = 9999999 }

	#エラーをカウントしたらファイルを削除
	try { if (Test-Path $script:ffpmegErrorLogPath) { Remove-Item -LiteralPath $script:ffpmegErrorLogPath -Force -ErrorAction SilentlyContinue } }
	catch { Write-Warning ('❗ ffmpegエラーファイルを削除できませんでした') }

	if ($local:proc.ExitCode -ne 0 -Or $local:errorCount -gt 30) {

		#終了コードが0以外 または エラーが一定以上 はダウンロード履歴とファイルを削除
		Write-Warning ('❗ チェックNGでした')
		Write-Warning ('　Exit Code: {0} Error Count: {1}' -f $local:proc.ExitCode, $local:errorCount)
		$script:validationFailed = $true

		#破損しているダウンロードファイルをダウンロード履歴から削除
		try {
			while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$local:videoHists = @(Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8)
			#該当の番組のレコードを削除
			$local:videoHists = @($local:videoHists.Where({ $_.videoPath -ne $local:videoFileRelPath }))
			$local:videoHists | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
		} catch { Write-Warning ('❗ ダウンロード履歴の更新に失敗しました: {0}' -f $local:videoFileRelPath) }
		finally { $null = fileUnlock $script:historyLockFilePath }

		#破損しているダウンロードファイルを削除
		try { Remove-Item -LiteralPath $local:videoFilePath -Force -ErrorAction SilentlyContinue }
		catch { Write-Warning ('❗ ファイル削除できませんでした: {0}' -f $local:videoFilePath) }

	} else {

		#終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
		Write-Output ('　✔️')
		try {
			while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$local:videoHists = @(Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8)
			#該当の番組のチェックステータスを1に
			$local:videoHists.Where({ $_.videoPath -eq $local:videoFileRelPath }).Where({ $_.videoValidated = '1' })
			$local:videoHists | Export-Csv -LiteralPath $script:historyFilePath -Encoding UTF8
		} catch { Write-Warning ('❗ ダウンロード履歴を更新できませんでした: {0}' -f $local:videoFileRelPath) }
		finally { $null = fileUnlock $script:historyLockFilePath }

	}

}
