###################################################################################
#
#		TVerRec固有関数スクリプト
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
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#region 環境

#----------------------------------------------------------------------
#GUID取得
#----------------------------------------------------------------------
$progressPreference = 'SilentlyContinue'

switch ($true) {
	$IsWindows {
		$osDetails = Get-CimInstance -Class Win32_OperatingSystem
		$script:os = $osDetails.Caption
		$script:kernel = $osDetails.Version
		$script:arch = $Env:PROCESSOR_ARCHITECTURE.ToLower()
		$script:guid = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
		break
	}
	$IsLinux {
		$script:os = if (Test-Path '/etc/os-release') { (& grep 'PRETTY_NAME' /etc/os-release).Replace('PRETTY_NAME=', '').Replace('"', '') } else { (& uname -n) }
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = if (Test-Path '/etc/machine-id') { (Get-Content /etc/machine-id) } else { [guid]::NewGuid() }
		break
	}
	$IsMacOS {
		$script:os = (& sw_vers -productName)
		$script:kernel = [String][System.Environment]::OSVersion.Version
		$script:arch = (& uname -m | tr '[:upper:]' '[:lower:]')
		$script:guid = if (Test-Path '/etc/machine-id') { (Get-Content /etc/machine-id) } else { [guid]::NewGuid() }
		break
	}
	default {
		$script:os = [String][System.Environment]::OSVersion
		$script:kernel = ''
		$script:arch = ''
		$script:guid = ''
		break
	}
}

$script:locale = (Get-Culture).Name
$script:tz = [String][TimeZoneInfo]::Local.BaseUtcOffset

$script:clientEnvs = @{}
try {
	$GeoIPValues = (Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=66846719' -TimeoutSec $script:timeoutSec).psobject.properties
	foreach ($GeoIPValue in $GeoIPValues) { $script:clientEnvs.Add($GeoIPValue.Name, $GeoIPValue.Value) }
} catch {
	Write-Debug ('Failed to check Geo IP')
}
$script:clientEnvs = $script:clientEnvs.GetEnumerator() | Sort-Object -Property key

$progressPreference = 'Continue'

$script:requestHeader = @{
	'x-tver-platform-type' = 'web'
	'Origin'               = 'https://tver.jp'
	'Referer'              = 'https://tver.jp'
}

#----------------------------------------------------------------------
#設定取得
#----------------------------------------------------------------------
function Get-Setting {
	$filePathList = @((Convert-Path (Join-Path $script:confDir 'system_setting.ps1')), (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')))
	$configList = @{}
	foreach ($filePath in $filePathList) {
		$configs = (Select-String $filePath -Pattern '^(\$.+)=(.+)(\s*)$' | ForEach-Object { $_.line })
		foreach ($config in $configs) {
			$configParts = $config -split '='
			$key = $configParts[0].replace('script:', '').trim()
			$value = $configParts[1].split('#')[0].trim()
			if (($key -notlike '*Dir') -and ($key -notlike '*Path') -and ($key -notlike '*PSStyle*') -and ($key -notlike '*Base64')) {
				$configList[$key] = $value
			}
		}
	}
	return $configList.GetEnumerator() | Sort-Object -Property key
}

#----------------------------------------------------------------------
#統計取得
#----------------------------------------------------------------------
function Invoke-StatisticsCheck {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$operation,
		[Parameter(Mandatory = $false, Position = 1)][String]$tverType = 'none',
		[Parameter(Mandatory = $false, Position = 2)][String]$tverID = 'none'
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$progressPreference = 'silentlyContinue'
	$statisticsBase = 'https://hits.sh/github.com/dongaba/TVerRec/'
	try { $null = Invoke-WebRequest `
			-UseBasicParsing `
			-Uri ('{0}{1}.svg' -f $statisticsBase, $operation) `
			-Method 'GET' `
			-TimeoutSec $script:timeoutSec
	} catch { Write-Debug ('Failed to collect count') }
	finally { $progressPreference = 'Continue' }
	if ($operation -eq 'search') { return }

	$clientVars = (Get-Setting)
	$epochTime = [decimal]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000)
	$gaBody = [PSCustomObject]@{
		client_id            = "$script:guid"
		timestamp_micros     = "$epochTime"
		non_personalized_ads = $false
		user_properties      = @{}
		events               = @(
			@{
				name   = "$operation"
				params = @{ Target = "$tverType/$tverID" }
			}
		)
	}
	foreach ($clientEnv in $script:clientEnvs) { $gaBody.user_properties[$clientEnv.Key] = @{value = $clientEnv.Value } }
	foreach ($clientVar in $clientVars) { $gaBody.user_properties[$clientVar.Name] = @{value = $clientVar.Value } }
	$gaBodyJson = $gaBody | ConvertTo-Json -Depth 3
	$gaURL = 'https://www.google-analytics.com/mp/collect'
	$gaKey = 'api_secret=UZ3InfgkTgGiR4FU-in9sw'
	$gaID = 'measurement_id=G-NMSF9L531G'
	$gaHeaders = @{
		'HOST'         = 'www.google-analytics.com'
		'Content-Type' = 'application/json'
	}
	$progressPreference = 'silentlyContinue'
	try { $null = Invoke-RestMethod `
			-Uri ('{0}?{1}&{2}' -f $gaURL, $gaKey, $gaID) `
			-Method 'POST' `
			-Headers $gaHeaders `
			-Body $gaBodyJson `
			-TimeoutSec $script:timeoutSec
	} catch { Write-Debug ('Failed to collect statistics') }
	finally { $progressPreference = 'Continue' }
}

#endregion 環境

#----------------------------------------------------------------------
#TVerRec最新化確認
#----------------------------------------------------------------------
function Invoke-TVerRecUpdateCheck {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$progressPreference = 'silentlyContinue'
	Invoke-StatisticsCheck -Operation 'launch'
	$versionUp = $false

	#TVerRecの最新バージョン取得
	$repo = 'dongaba/TVerRec'
	$releases = ('https://api.github.com/repos/{0}/releases' -f $repo)
	try { $appReleases = (Invoke-RestMethod -Uri $releases -Method 'GET' ) }
	catch { return }

	#GitHub側最新バージョンの整形
	# v1.2.3 → 1.2.3
	$latestVersion = $appReleases[0].Tag_Name.Trim('v', ' ')
	# v1.2.3 beta 4 → 1.2.3
	$latestMajorVersion = $latestVersion.split(' ')[0]

	#ローカル側バージョンの整形
	# v1.2.3 beta 4 → 1.2.3
	$appMajorVersion = $script:appVersion.split(' ')[0]

	#バージョン判定
	$versionUp = switch ($true) {
		{ $latestMajorVersion -gt $appMajorVersion } { $true; break }
		{ ($latestMajorVersion -eq $appMajorVersion) -and ($appMajorVersion -ne $script:appVersion) } { $true; break }
		default { $false }
	}

	$progressPreference = 'Continue'

	#バージョンアップメッセージ
	if ($versionUp) {
		[Console]::ForegroundColor = 'Green'
		Write-Output ('')
		Write-Output ('❗ TVerRecの更新版があるようです。')
		Write-Output ('　Local Version {0}' -f $script:appVersion)
		Write-Output ('　Latest Version {0}' -f $latestVersion)
		Write-Output ('')
		[Console]::ResetColor()

		#変更履歴の表示
		foreach ($appRelease in @($appReleases | Where-Object { $_.Tag_Name.Trim('v', ' ') -gt $appMajorVersion })) {
			[Console]::ForegroundColor = 'Green'
			Write-Output ('----------------------------------------------------------------------')
			Write-Output ('{0}の更新内容' -f $appRelease.tag_name)
			Write-Output ('----------------------------------------------------------------------')
			Write-Output $appRelease.body.Replace('###', '■')
			Write-Output ('')
			[Console]::ResetColor()
		}

		#最新のアップデータを取得
		$latestUpdater = 'https://raw.githubusercontent.com/dongaba/TVerRec/master/src/functions/update_tverrec.ps1'
		Invoke-WebRequest -UseBasicParsing -Uri $latestUpdater -OutFile (Join-Path $script:scriptRoot 'functions//update_tverrec.ps1')
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
#ytdl/ffmpegの最新化確認
#----------------------------------------------------------------------
function Invoke-ToolUpdateCheck {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true)][string]$scriptName,
		[Parameter(Mandatory = $true)][string]$targetName
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$originalPreference = $progressPreference
	$progressPreference = 'silentlyContinue'
	& (Join-Path $scriptRoot ('functions/{0}' -f $scriptName) )
	if (!$?) { Write-Error ("❗ $targetName の更新に失敗しました") ; exit 1 }
	$progressPreference = $originalPreference
}

#----------------------------------------------------------------------
#ファイル・ディレクトリの存在チェック、なければサンプルファイルコピー
#----------------------------------------------------------------------
function Invoke-PathExistenceCheck {
	Param(
		[Parameter(Mandatory = $true)]
		[string]$path,
		[Parameter(Mandatory = $true)]
		[string]$errorMessage,
		[switch]$isFile,
		[string]$sampleFilePath
	)

	$pathType = if ($isFile) { 'Leaf' } else { 'Container' }

	if (!(Test-Path $path -PathType $pathType)) {
		if (!($sampleFilePath -and (Test-Path $sampleFilePath -PathType 'Leaf'))) {
			Write-Error ("❗ $errorMessage 終了します。")
			exit 1
		}
		Copy-Item -LiteralPath $sampleFilePath -Destination $path -Force
	}
}

#----------------------------------------------------------------------
#設定で指定したファイル・ディレクトリの存在チェック
#----------------------------------------------------------------------
function Invoke-RequiredFileCheck {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ($MyInvocation.MyCommand.Name)

	Invoke-PathExistenceCheck -path $script:downloadBaseDir -errorMessage '番組ダウンロード先ディレクトリが存在しません。'
	Invoke-PathExistenceCheck -path $script:downloadWorkDir -errorMessage 'ダウンロード作業ディレクトリが存在しません。'

	if ($script:saveBaseDir -ne '') {
		$script:saveBaseDirArray = $script:saveBaseDir.split(';').Trim()
		foreach ($saveDir in $script:saveBaseDirArray) {
			Invoke-PathExistenceCheck -path $saveDir.Trim() -errorMessage '番組移動先ディレクトリが存在しません。'
		}
	}

	Invoke-PathExistenceCheck -path $script:ytdlPath -isFile -errorMessage 'youtube-dlが存在しません。'
	Invoke-PathExistenceCheck -path $script:ffmpegPath -isFile -errorMessage 'ffmpegが存在しません。'

	if ($script:simplifiedValidation) {
		Invoke-PathExistenceCheck -path $script:ffprobePath -isFile -errorMessage 'ffprobeが存在しません。'
	}

	#ファイルが存在しない場合はサンプルファイルをコピー
	Invoke-PathExistenceCheck -path $script:keywordFilePath -isFile -errorMessage 'ダウンロード対象キーワードファイルが存在しません。' -sampleFilePath $script:keywordFileSamplePath
	Invoke-PathExistenceCheck -path $script:ignoreFilePath -isFile -errorMessage 'ダウンロード対象外番組ファイルが存在しません。' -sampleFilePath $script:ignoreFileSamplePath
	Invoke-PathExistenceCheck -path $script:histFilePath -isFile -errorMessage 'ダウンロード履歴ファイルが存在しません。' -sampleFilePath $script:histFileSamplePath
	Invoke-PathExistenceCheck -path $script:listFilePath -isFile -errorMessage 'ダウンロードリストファイルが存在しません。' -sampleFilePath $script:listFileSamplePath
}


#----------------------------------------------------------------------
#ダウンロード対象キーワードの読み込み
#----------------------------------------------------------------------
function Get-KeywordList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$keywords = @()
	if (Test-Path $script:keywordFilePath -PathType Leaf) {
		try {
			#コメントと空行を除いて抽出
			$keywords = [String[]]((Get-Content $script:keywordFilePath -Encoding UTF8).Where({ $_ -notmatch '^\s*$|^#.*$' }))
		} catch {
			Write-Error ('❗ ダウンロード対象キーワードの読み込みに失敗しました') ; exit 1
		}
	}
	return @($keywords)
}


#----------------------------------------------------------------------
#ダウンロード履歴の読み込み
#----------------------------------------------------------------------
function Get-HistoryFile {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (Test-Path $script:histFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$histFileData = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		} catch { Write-Warning ('❗ ダウンロード履歴の読み込みに失敗しました') ; exit 1 }
		finally { $null = Unlock-File $script:histLockFilePath }
	} else { $histFileData = @() }

	return @($histFileData)
}

#----------------------------------------------------------------------
#ダウンロードリストの読み込み
#----------------------------------------------------------------------
function Get-DownloadList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (Test-Path $script:listFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$listFileData = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
		} catch { Write-Warning ('❗ ダウンロードリストの読み込みに失敗しました') ; exit 1 }
		finally { $null = Unlock-File $script:listLockFilePath }
	} else { $listFileData = @() }

	return @($listFileData)
}

#----------------------------------------------------------------------
#ダウンロードリストからダウンロードリンクの読み込み
#----------------------------------------------------------------------
function Get-LinkFromDownloadList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (Test-Path $script:listFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			#空行とダウンロード対象外を除き、EpisodeIDのみを抽出
			$videoLinks = @((Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_.EpisodeID -cmatch '^#') }) | Select-Object episodeID)
		} catch { Write-Error ('❗ ダウンロードリストの読み込みに失敗しました') ; exit 1 }
		finally { $null = Unlock-File $script:listLockFilePath }
	} else { $videoLinks = @() }

	$videoLinks = $videoLinks.episodeID -replace '^(.+)', 'https://tver.jp/episodes/$1'

	return @($videoLinks)
}

#----------------------------------------------------------------------
#ダウンロード対象外番組の読み込
#----------------------------------------------------------------------
function Get-IgnoreList {
	[OutputType([String[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (Test-Path $script:ignoreFilePath -PathType Leaf) {
		try {
			while ((Lock-File $script:ignoreLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			#コメントと空行を除いて抽出
			$ignoreTitles = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_ -cmatch '^;.*$') }))
		} catch { Write-Error ('❗ ダウンロード対象外の読み込みに失敗しました') ; exit 1 }
		finally { $null = Unlock-File $script:ignoreLockFilePath }
	} else { $ignoreTitles = @() }

	return @($ignoreTitles)
}

#----------------------------------------------------------------------
#ダウンロード対象外番組のソート(使用したものを上に移動)
#----------------------------------------------------------------------
function Update-IgnoreList {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$ignoreTitle
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$ignoreListNew = @()
	$ignoreComment = @()
	$ignoreTarget = @()
	$ignoreElse = @()
	try {
		while ((Lock-File $script:ignoreLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$ignoreLists = @((Get-Content $script:ignoreFilePath -Encoding UTF8).Where( { !($_ -cmatch '^\s*$') }).Where( { !($_ -cmatch '^;;.*$') }))
		$ignoreComment = @(Get-Content $script:ignoreFileSamplePath -Encoding UTF8)
		$ignoreTarget = @($ignoreLists.Where({ $_ -eq $ignoreTitle }) | Sort-Object | Get-Unique)
		$ignoreElse = @($ignoreLists.Where({ $_ -notin $ignoreTitle }))
		$ignoreListNew += $ignoreComment
		$ignoreListNew += $ignoreTarget
		$ignoreListNew += $ignoreElse
		#改行コードLFを強制
		$ignoreListNew | ForEach-Object { ("{0}`n" -f $_) } | Out-File -LiteralPath $script:ignoreFilePath -Encoding UTF8 -NoNewline
		Write-Debug ('ダウンロード対象外リストのソート更新完了')
	} catch { Write-Error ('❗ ダウンロード対象外リストのソートに失敗しました') ; exit 1 }
	finally {
		$null = Unlock-File $script:ignoreLockFilePath
	}
}

#----------------------------------------------------------------------
#URLが既にダウンロード履歴に存在するかチェックし、ダウンロード対象番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryMatchCheck {
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('links')]
		[String[]]$resultLinks
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	#ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-HistoryFile)
	if ($histFileData.Count -eq 0) { $histVideoPages = @() } else { $histVideoPages = @($histFileData.VideoPage) }

	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$histCompResult = @(Compare-Object -IncludeEqual $resultLinks $histVideoPages)
	try { $processedCount = ($histCompResult | Where-Object { $_.SideIndicator -eq '==' }).Count } catch { $processedCount = 0 }
	try { $videoLinks = @(($histCompResult | Where-Object { $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }

	return @($videoLinks, $processedCount)
}

#----------------------------------------------------------------------
#URLが既にダウンロードリストまたはダウンロード履歴に存在するかチェックし、ダウンロード対象番組だけ返す
#----------------------------------------------------------------------
function Invoke-HistoryAndListfileMatchCheck {
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[Alias('links')]
		[String[]]$resultLinks
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	#ダウンロードリストファイルのデータを読み込み
	$local:listFileData = @(Get-DownloadList)
	$local:listVideoPages = @()
	foreach ($local:listFileLine in $local:listFileData) {
		$local:listVideoPages += ('https://tver.jp/episodes/{0}' -f $local:listFileLine.EpisodeID.Replace('#', ''))
	}

	#ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-HistoryFile)
	if ($histFileData.Count -eq 0) { $histVideoPages = @() } else { $histVideoPages = @($histFileData.VideoPage) }

	#ダウンロードリストとダウンロード履歴をマージ
	$local:histVideoPages += $local:listVideoPages

	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$histCompResult = @(Compare-Object -IncludeEqual $resultLinks $histVideoPages)
	try { $processedCount = ($histCompResult | Where-Object { $_.SideIndicator -eq '==' }).Count } catch { $processedCount = 0 }
	try { $videoLinks = @(($histCompResult | Where-Object { $_.SideIndicator -eq '<=' }).InputObject) } catch { $videoLinks = @() }

	return @($videoLinks, $processedCount)
}


#----------------------------------------------------------------------
#youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function Wait-YtdlProcess {
	[OutputType([System.Void])]
	Param ([Int32]$parallelDownloadFileNum)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$psCmd = 'ps'

	$processName = switch ($script:preferredYoutubedl) {
		'yt-dlp' { 'yt-dlp' ; break }
		'ytdl-patched' { 'youtube-dl' ; break }
	}

	#youtube-dlのプロセスが設定値を超えたら一時待機
	while ($true) {
		try {
			$ytdlCount = switch ($true) {
				$IsWindows { [Math]::Round((Get-Process -ErrorAction Ignore -Name 'youtube-dl').Count / 2, [MidpointRounding]::AwayFromZero) ; break }
				$IsLinux { @(Get-Process -ErrorAction Ignore -Name $processName).Count ; break }
				$IsMacOS { (& $psCmd | grep 'youtube-dl' | grep -v grep | grep -c ^).Trim() ; break }
				default { 0 }
			}
		} catch {
			Write-Debug ('ダウンロードプロセスの数を取得できませんでした')
			$ytdlCount = 0
		}

		if ([Int]$ytdlCount -lt [Int]$parallelDownloadFileNum ) { break }

		Write-Host ('ダウンロードが{0}多重に達したので一時待機します。 ({1})' -f $local:parallelDownloadFileNum, (Get-TimeStamp))
		Write-Verbose ('現在のダウンロードプロセス一覧 ({0}個)' -f $local:ytdlCount)
		Start-Sleep -Seconds 60
	}
}


#----------------------------------------------------------------------
#ダウンロード履歴データの作成
#----------------------------------------------------------------------
function Format-HistoryRecord {
	Param($keyword, $videoPageURL, $videoSeriesPageURL, $videoname, $videopath, $validated)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return [pscustomobject]@{
		videoPage       = $videoPageURL
		videoSeriesPage = $videoSeriesPageURL
		genre           = $keyword
		series          = $script:videoSeries
		season          = $script:videoSeason
		title           = $script:videoTitle
		media           = $script:mediaName
		broadcastDate   = $script:broadcastDate
		downloadDate    = Get-TimeStamp
		videoDir        = $script:videoFileDir
		videoName       = $videoname
		videoPath       = $videopath
		videoValidated  = $validated
	}
}

#----------------------------------------------------------------------
#「《」と「》」で挟まれた文字を除去
#----------------------------------------------------------------------
Function Remove-SpecialNote {
	Param($text)

	if ($text -cmatch '(.*)(《.*》)(.*)') {
		return ('{0}{1}' -f $matches[1], $matches[3]).Replace('  ', ' ').Trim()
	} else {
		return $text
	}
}

#----------------------------------------------------------------------
#TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function Invoke-VideoDownload {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$keyword,
		[Parameter(Mandatory = $true, Position = 1)][String]$episodePage,
		[Parameter(Mandatory = $false, Position = 2)][Boolean]$force = $false
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$script:videoName = '' ; $script:videoFilePath = '' ; $videoSeriesPageURL = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = '' ; $script:mediaName = '' ; $script:descriptionText = ''
	$newVideo = $null
	$skipDownload = $false

	$episodeID = $episodePage.Replace('https://tver.jp/episodes/', '')
	#TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	try { Get-VideoInfo $episodeID }
	catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:90') ; continue }

	#ダウンロードファイル情報をセット
	$script:videoName = Set-VideoFileName `
		-Series $script:videoSeries `
		-Season $script:videoSeason `
		-Episode $script:videoEpisode `
		-Title $script:videoTitle `
		-Date $script:broadcastDate

	$script:videoFileDir = Get-FileNameWithoutInvalidChars (Remove-SpecialCharacter ('{0} {1}' -f $script:videoSeries, $script:videoSeason ).Trim(' ', '.'))
	if ($script:sortVideoByMedia) {
		$script:mediaName = Get-FileNameWithoutInvalidChars $script:mediaName
		$script:videoFileDir = (Join-Path $script:downloadBaseDir $script:mediaName | Join-Path -ChildPath $script:videoFileDir)
	} else {
		$script:videoFileDir = (Join-Path $script:downloadBaseDir $script:videoFileDir)
	}
	$script:videoFilePath = Join-Path $script:videoFileDir $script:videoName
	$script:videoFileRelPath = $script:videoFilePath.Replace($script:downloadBaseDir, '').Replace('\', '/')
	$script:videoFileRelPath = $script:videoFileRelPath.Substring(1, ($script:videoFileRelPath.Length - 1))

	#番組情報のコンソール出力
	Show-VideoInfo `
		-Name $script:videoName `
		-Date $script:broadcastDate `
		-Media $script:mediaName `
		-EndTime $script:endTime
	if ($DebugPreference -ne 'SilentlyContinue') {
		Show-VideoDebugInfo `
			-EpisodePage $episodePage `
			-SeriesPage $videoSeriesPageURL `
			-Keyword $keyword `
			-Series $script:videoSeries `
			-Season $script:videoSeason `
			-Episode $script:videoEpisode `
			-Title $script:videoTitle `
			-Path $script:videoFilePath `
			-Time (Get-TimeStamp) `
			-Description $descriptionText
	}

	#番組タイトルが取得できなかった場合はスキップ次の番組へ
	if ($script:videoName -eq '.mp4') { Write-Warning ('❗ 番組タイトルを特定できませんでした。スキップします') ; continue }

	#ここまで来ているということはEpisodeIDでは履歴とマッチしなかったということ
	#考えられる原因は履歴ファイルがクリアされてしまっていること、または、EpisodeIDが変更になったこと
	# 履歴ファイルに存在する	→番組IDが変更になったあるいは、番組名の重複
	# 	検証済	→元々の番組IDとしては問題ないのでSKIP
	# 	検証中	→元々の番組IDとしてはそのうち検証されるのでSKIP
	# 	未検証	→元々の番組IDとしては次回検証されるのでSKIP
	# 履歴ファイルに存在しない
	# 	ファイルが存在する	→検証だけする
	# 	ファイルが存在しない
	# 		無視リストに存在する	→無視
	# 		無視リストに存在しない	→ダウンロード
	#ダウンロード履歴ファイルのデータを読み込み
	$histFileData = @(Get-HistoryFile)
	$histMatch = @($histFileData.Where({ $_.videoPath -eq $script:videoFileRelPath }))
	if (($histMatch.Count -ne 0)) {
		#履歴ファイルに存在する	→スキップして次のファイルに
		Write-Warning ('❗ 同名のファイルがすでに履歴ファイルに存在します。番組IDが変更になった可能性があります。スキップします')
		$newVideo = Format-HistoryRecord $keyword $episodePage $videoSeriesPageURL '-- SKIPPED --' $videoFileRelPath '1'
		$skipDownload = $true
	} elseif ( Test-Path $script:videoFilePath) {
		#履歴ファイルに存在しないが、実ファイルが存在する	→検証だけする
		Write-Warning ('❗ 履歴ファイルに存在しませんが番組ファイルが存在します。整合性検証の対象とします')
		$newVideo = Format-HistoryRecord $keyword $episodePage $videoSeriesPageURL '-- SKIPPED --' $videoFileRelPath '0'
		$skipDownload = $true
	} else {
		#履歴ファイルに存在せず、実ファイルも存在せず、無視リストと合致	→無視する
		$ignoreTitles = @(Get-IgnoreList)
		foreach ($ignoreTitle in $ignoreTitles) {
			if (($script:videoName -like $local:ignoreTitle) `
					-or ($script:videoSeries -like $local:ignoreTitle) `
					-or ($script:videoName -cmatch [Regex]::Escape($local:ignoreTitle)) `
					-or ($script:videoSeries -cmatch [Regex]::Escape($local:ignoreTitle))) {
				Update-IgnoreList $ignoreTitle
				Write-Output ('❗ ダウンロード対象外としたファイルをダウンロード履歴に追加します')
				$newVideo = Format-HistoryRecord $keyword $episodePage $videoSeriesPageURL '-- IGNORED --' '-- IGNORED --' '0'
				$skipDownload = $true
				break
			}
		}
		#履歴ファイルに存在せず、実ファイルも存在せず、無視リストとも合致しない	→ダウンロードする
		if (!$skipDownload) {
			Write-Output ('💡 ダウンロードするファイルをダウンロード履歴に追加します')
			$newVideo = Format-HistoryRecord $keyword $episodePage $videoSeriesPageURL $script:videoName $script:videoFileRelPath '0'
		}
	}

	#ダウンロード履歴CSV書き出し
	try {
		while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$newVideo | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append
		Write-Debug ('ダウンロード履歴を書き込みました')
	} catch { Write-Warning ('❗ ダウンロード履歴を更新できませんでした。スキップします') ; continue }
	finally { $null = Unlock-File $script:histLockFilePath }

	#スキップ対象やダウンロード対象外は飛ばして次のファイルへ
	if (!$force -and $skipDownload) { continue }

	#移動先ディレクトリがなければ作成
	if (-Not (Test-Path $script:videoFileDir -PathType Container)) {
		try { $null = New-Item -ItemType Directory -Path $script:videoFileDir -Force }
		catch { Write-Warning ('❗ 移動先ディレクトリを作成できませんでした') ; continue }
	}
	#youtube-dl起動
	try { Invoke-Ytdl $episodePage }
	catch { Write-Warning ('❗ youtube-dlの起動に失敗しました') }
	#5秒待機
	Start-Sleep -Seconds 5

}

#----------------------------------------------------------------------
#TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function Update-VideoList {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$keyword,
		[Parameter(Mandatory = $true, Position = 1)][String]$episodePage
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$script:videoName = '' ; $script:videoFilePath = ''
	$script:broadcastDate = '' ; $script:videoSeries = '' ; $script:videoSeason = ''
	$script:videoEpisode = '' ; $script:videoTitle = ''
	$script:mediaName = '' ; $script:descriptionText = ''
	$ignoreWord = ''
	$newVideo = $null
	$ignore = $false ;

	$episodeID = $episodePage.Replace('https://tver.jp/episodes/', '')

	#TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	try { Get-VideoInfo $episodeID }
	catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:91') ; continue }

	#ダウンロード対象外に入っている番組の場合はリスト出力しない
	$ignoreTitles = @(Get-IgnoreList)
	foreach ($ignoreTitle in $ignoreTitles) {
		if ($ignoreTitle -ne '') {
			if ($script:videoSeries -cmatch [Regex]::Escape($ignoreTitle)) {
				$ignoreWord = $ignoreTitle
				Update-IgnoreList $ignoreTitle
				$ignore = $true
				#ダウンロード対象外と合致したものはそれ以上のチェック不要
				break
			} elseif ($script:videoTitle -cmatch [Regex]::Escape($ignoreTitle)) {
				$ignoreWord = $ignoreTitle
				Update-IgnoreList $ignoreTitle
				$ignore = $true
				#ダウンロード対象外と合致したものはそれ以上のチェック不要
				break
			}
		}
	}

	#スキップフラグが立っているかチェック
	if ($ignore) {
		Write-Output ('❗ 番組をコメントアウトした状態でリストファイルに追加します')
		$newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = ('#{0}' -f $episodePage.Replace('https://tver.jp/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $keyword
			ignoreWord    = $ignoreWord
		}
	} else {
		Write-Output ('💡 番組をリストファイルに追加します')
		$newVideo = [pscustomobject]@{
			seriesName    = $script:videoSeries
			seriesID      = $script:videoSeriesID
			seasonName    = $script:videoSeason
			seasonID      = $script:videoSeasonID
			episodeNo     = $script:videoEpisode
			episodeName   = $script:videoTitle
			episodeID     = ('{0}' -f $episodePage.Replace('https://tver.jp/episodes/', ''))
			media         = $script:mediaName
			provider      = $script:providerName
			broadcastDate = $script:broadcastDate
			endTime       = $script:endTime
			keyword       = $keyword
			ignoreWord    = ''
		}
	}

	#ダウンロードリストCSV書き出し
	try {
		while ((Lock-File $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append
		Write-Debug ('ダウンロードリストを書き込みました')
	} catch { Write-Warning ('❗ ダウンロードリストを更新できませんでした。スキップします') ; continue }
	finally { $null = Unlock-File $script:listLockFilePath }
}

#----------------------------------------------------------------------
#TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function Get-VideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][String]$episodeID
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	#----------------------------------------------------------------------
	#番組説明以外
	$tverVideoInfoBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$tverVideoInfoURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $tverVideoInfoBaseURL, $episodeID, $script:platformUID, $script:platformToken)
	$response = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec

	#シリーズ
	#	$response.Result.Series.Content.Title
	#	$response.Result.Episode.Content.SeriesTitle
	#		Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
	#		Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
	#	なのでSeries.Content.TitleとEpisode.Content.SeriesTitleの短い方を採用する
	if ($response.Result.Episode.Content.SeriesTitle.Length -le $response.Result.Series.Content.Title.Length ) {
		$script:videoSeries = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Episode.Content.SeriesTitle))).Trim()
	} else {
		$script:videoSeries = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Series.Content.Title))).Trim()
	}
	$script:videoSeriesID = $response.Result.Series.Content.Id
	#$videoSeriesPageURL = ('https://tver.jp/series/{0}' -f $response.Result.Series.Content.Id)

	#シーズン
	#Season Name
	#	$response.Result.Season.Content.Title
	$script:videoSeason = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Season.Content.Title))).Trim()
	$script:videoSeasonID = $response.Result.Season.Content.Id

	#エピソード
	#	$response.Result.Episode.Content.Title
	$script:videoTitle = (Remove-SpecialCharacter (Get-NarrowChars ($response.Result.Episode.Content.Title))).Trim()
	$script:videoEpisodeID = $response.Result.Episode.Content.Id

	#放送局
	#	$response.Result.Episode.Content.BroadcasterName
	#	$response.Result.Episode.Content.ProductionProviderName
	$script:mediaName = (Get-NarrowChars ($response.Result.Episode.Content.BroadcasterName)).Trim()
	$script:providerName = (Get-NarrowChars ($response.Result.Episode.Content.ProductionProviderName)).Trim()

	#放送日
	#	$response.Result.Episode.Content.BroadcastDateLabel
	$script:broadcastDate = (($response.Result.Episode.Content.BroadcastDateLabel).Replace('ほか', '').Replace('放送分', '放送')).Trim()

	#配信終了日時
	#	$response.Result.Episode.Content.EndAt
	$script:endTime = (ConvertFrom-UnixTime ($response.Result.Episode.Content.EndAt)).AddHours(9)

	#----------------------------------------------------------------------
	#番組説明
	$versionNum = $response.Result.Episode.Content.version
	$tverVideoInfoBaseURL = 'https://statics.tver.jp/content/episode/'
	$tverVideoInfoURL = ('{0}{1}.json?v={2}' -f $tverVideoInfoBaseURL, $episodeID, $versionNum)
	$videoInfo = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$script:descriptionText = (Get-NarrowChars ($videoInfo.Description).Replace('&amp;', '&')).Trim()
	$script:videoEpisode = (Get-NarrowChars ($videoInfo.No)).Trim()

	#----------------------------------------------------------------------
	#各種整形

	#「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote) {
		$script:videoSeries = Remove-SpecialNote $script:videoSeries
		$script:videoSeason = Remove-SpecialNote $script:videoSeason
		$script:videoTitle = Remove-SpecialNote $script:videoTitle
	}

	#シーズン名が本編の場合はシーズン名をクリア
	if ($script:videoSeason -eq '本編') { $script:videoSeason = '' }

	#シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($script:videoSeries -cmatch [Regex]::Escape($script:videoSeason)) { $script:videoSeason = '' }

	#放送日を整形
	if ($script:broadcastDate -cmatch '([0-9]+)(月)([0-9]+)(日)(.+?)(放送)') {
		$currentYear = (Get-Date).Year
		$parsedBroadcastDate = [DateTime]::ParseExact(('{0}{1}{2}' -f $currentYear, $matches[1].padleft(2, '0'), $matches[3].padleft(2, '0')), 'yyyyMMdd', $null)
		#実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する
		#(年末の番組を年初にダウンロードするケース)
		$broadcastYear = $parsedBroadcastDate -lt (Get-Date).AddDays(+1) ? $currentYear - 1 : $currentYear
		$script:broadcastDate = ('{0}年{1}{2}{3}{4}{5}' -f $broadcastYear, $matches[1].padleft(2, '0'), $matches[2], $matches[3].padleft(2, '0'), $matches[4], $matches[6])
	}

}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function Set-VideoFileName {
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$series,
		[Parameter(Mandatory = $false, Position = 1)][String]$season,
		[Parameter(Mandatory = $false, Position = 2)][String]$episode,
		[Parameter(Mandatory = $false, Position = 3)][String]$title,
		[Parameter(Mandatory = $false, Position = 4)][String]$date
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	#ファイル名を生成
	if ($script:addSeriesName) { $videoName = ('{0}{1} ' -f $videoName, $series) }
	if ($script:addSeasonName) { $videoName = ('{0}{1} ' -f $videoName, $season) }
	if ($script:addBrodcastDate) { $videoName = ('{0}{1} ' -f $videoName, $date) }
	if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $episode) }
	$videoName = ('{0}{1}' -f $videoName, $title)

	#ファイル名にできない文字列を除去
	$videoName = (Get-FileNameWithoutInvalidChars $videoName).Replace('  ', ' ').Trim()

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	#youtube-dlの中間ファイル等を考慮して安全目の上限値
	$fileNameLimit = $script:fileNameLengthMax - 25

	if ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
		while ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
			$videoName = $videoName.Substring(0, $videoName.Length - 1)
		}
		$videoName = ('{0}……' -f $videoName)
	}
	$videoName = Get-FileNameWithoutInvalidChars ('{0}.mp4' -f $videoName)

	return $videoName
}

#----------------------------------------------------------------------
#番組情報表示
#----------------------------------------------------------------------
function Show-VideoInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$name,
		[Parameter(Mandatory = $false, Position = 1)][String]$date,
		[Parameter(Mandatory = $false, Position = 2)][String]$media,
		[Parameter(Mandatory = $false, Position = 3)][String]$endTime
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	Write-Output ('　番組名:　 {0}' -f $name.Replace('.mp4', ''))
	Write-Output ('　放送日:　 {0}' -f $date)
	Write-Output ('　テレビ局: {0}' -f $media)
	Write-Output ('　配信終了: {0}' -f $endTime)
}
#----------------------------------------------------------------------
#番組情報デバッグ表示
#----------------------------------------------------------------------
function Show-VideoDebugInfo {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$episodePage,
		[Parameter(Mandatory = $false, Position = 1)][String]$seriesPage,
		[Parameter(Mandatory = $false, Position = 2)][String]$keyword,
		[Parameter(Mandatory = $false, Position = 3)][String]$series,
		[Parameter(Mandatory = $false, Position = 4)][String]$season,
		[Parameter(Mandatory = $false, Position = 5)][String]$episode,
		[Parameter(Mandatory = $false, Position = 6)][String]$title,
		[Parameter(Mandatory = $false, Position = 7)][String]$path,
		[Parameter(Mandatory = $false, Position = 8)][String]$time,
		[Parameter(Mandatory = $false, Position = 9)][String]$description
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	Write-Debug ('番組エピソードページ: {0}' -f $episodePage)
	Write-Debug ('番組シリーズページ: {0}' -f $seriesPage)
	Write-Debug ('キーワード: {0}' -f $keyword)
	Write-Debug ('シリーズ: {0}' -f $series)
	Write-Debug ('シーズン: {0}' -f $season)
	Write-Debug ('エピソード: {0}' -f $episode)
	Write-Debug ('タイトル: {0}' -f $title)
	Write-Debug ('ファイル: {0}' -f $path)
	Write-Debug ('取得日付: {0}' -f $time)
	Write-Debug ('番組説明: {0}' -f $description)
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動
#----------------------------------------------------------------------
function Invoke-Ytdl {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$url
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	Invoke-StatisticsCheck -Operation 'download'

	$tmpDir = ('temp:{0}' -f $script:downloadWorkDir)
	$saveDir = ('home:{0}' -f $script:videoFileDir)
	$subttlDir = ('subtitle:{0}' -f $script:downloadWorkDir)
	$thumbDir = ('thumbnail:{0}' -f $script:downloadWorkDir)
	$chaptDir = ('chapter:{0}' -f $script:downloadWorkDir)
	$descDir = ('description:{0}' -f $script:downloadWorkDir)
	$saveFile = ('{0}' -f $script:videoName)
	$ytdlArgs = (' {0}' -f $script:ytdlBaseArgs)
	$ytdlArgs += (' {0} {1}' -f '--concurrent-fragments', $script:parallelDownloadNumPerFile)
	if (($script:rateLimit -ne 0) -or ($script:rateLimit -ne '')) {
		$ytdlArgs += (' {0} {1}M' -f '--limit-rate', [Int][Math]::Ceiling([Int]$script:rateLimit / [Int]$script:parallelDownloadNumPerFile / 8))
	}
	if ($script:embedSubtitle) { $ytdlArgs += (' {0}' -f '--sub-langs all --convert-subs srt --embed-subs') }
	if ($script:embedMetatag) { $ytdlArgs += (' {0}' -f '--embed-metadata') }
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $saveDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $tmpDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $subttlDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $thumbDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $chaptDir)
	$ytdlArgs += (' {0} "{1}"' -f '--paths', $descDir)
	$ytdlArgs += (' {0} "{1}"' -f '--ffmpeg-location', $script:ffmpegPath)
	$ytdlArgs += (' {0} "{1}"' -f '--output', $saveFile)
	$ytdlArgs += (' {0} {1}' -f '--add-header', $script:ytdlAcceptLang)
	$ytdlArgs += (' {0}' -f $script:ytdlOption)
	$ytdlArgs += (' {0}' -f $url)

	if ($IsWindows) {
		try {
			Write-Debug ('youtube-dl起動コマンド: {0}{1}' -f $script:ytdlPath, $ytdlArgs)
			$null = Start-Process `
				-FilePath $script:ytdlPath `
				-ArgumentList $ytdlArgs `
				-PassThru `
				-WindowStyle $script:windowShowStyle
		} catch { Write-Error ('❗ youtube-dlの起動に失敗しました') ; return }
	} else {
		Write-Debug ('youtube-dl起動コマンド: nohup {0}{1}' -f $script:ytdlPath, $ytdlArgs)
		try {
			$null = Start-Process `
				-FilePath nohup `
				-ArgumentList ($script:ytdlPath, $ytdlArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError /dev/zero
		} catch { Write-Error ('❗ youtube-dlの起動に失敗しました') ; return }
	}
}

#----------------------------------------------------------------------
#youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function Wait-DownloadCompletion () {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$psCmd = 'ps'

	switch ($script:preferredYoutubedl) {
		'yt-dlp' { $processName = 'yt-dlp' ; break }
		'ytdl-patched' { $processName = 'youtube-dl' ; break }
	}

	try {
		switch ($true) {
			$IsWindows { $ytdlCount = [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero ) ; break }
			$IsLinux { $ytdlCount = @(Get-Process -ErrorAction Ignore -Name $processName).Count ; break }
			$IsMacOS { $ytdlCount = (& $psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; break }
			default { $ytdlCount = 0 ; break }
		}
	} catch { $ytdlCount = 0 }

	while ($ytdlCount -ne 0) {
		try {
			Write-Verbose ('現在のダウンロードプロセス一覧 ({0}個)' -f $ytdlCount)
			Start-Sleep -Seconds 60
			switch ($true) {
				$IsWindows { $ytdlCount = [Int][Math]::Round((Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, [MidpointRounding]::AwayFromZero ) ; break }
				$IsLinux { $ytdlCount = @(Get-Process -ErrorAction Ignore -Name $processName).Count ; break }
				$IsMacOS { $ytdlCount = (& $psCmd | grep youtube-dl | grep -v grep | grep -c ^).Trim() ; break }
				default { $ytdlCount = 0 ; break }
			}
		} catch { $ytdlCount = 0 }
	}
}

#----------------------------------------------------------------------
#ダウンロード履歴の不整合を解消
#----------------------------------------------------------------------
function Optimize-HistoryFile {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$histData0 = @()
	$histData1 = @()
	$histData2 = @()
	$mergedHistData = @()

	try {
		while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }

		#videoValidatedが空白でないもの
		$histData = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ $null -ne $_.videoValidated }))
		$histData0 = @(($histData).Where({ $_.videoValidated -eq '0' }))
		$histData1 = @(($histData).Where({ $_.videoValidated -eq '1' }))
		$histData2 = @(($histData).Where({ $_.videoValidated -eq '2' }))

		$mergedHistData += $histData0
		$mergedHistData += $histData1
		$mergedHistData += $histData2
		$mergedHistData | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8

	} catch { Write-Warning ('❗ ダウンロード履歴の更新に失敗しました') }
	finally { $null = Unlock-File $script:histLockFilePath }
}

#----------------------------------------------------------------------
#30日以上前に処理したものはダウンロード履歴から削除
#----------------------------------------------------------------------
function Limit-HistoryFile {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true, Position = 0)][Int32]$retentionPeriod
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	try {
		while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$purgedHist = @((Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8).Where({ [DateTime]::ParseExact($_.downloadDate, 'yyyy-MM-dd HH:mm:ss', $null) -gt (Get-Date).AddDays(-1 * [Int32]$retentionPeriod) }))
		$purgedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
	} catch { Write-Warning ('❗ ダウンロード履歴のクリーンアップに失敗しました') }
	finally { $null = Unlock-File $script:histLockFilePath }
}

#----------------------------------------------------------------------
#ダウンロード履歴の重複削除
#----------------------------------------------------------------------
function Repair-HistoryFile {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$uniquedHist = @()

	try {
		while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }

		#videoPageで1つしかないもの残し、ダウンロード日時でソート
		$uniquedHist = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8 | Group-Object -Property 'videoPage' | Where-Object count -EQ 1 | Select-Object -ExpandProperty group | Sort-Object -Property downloadDate)
		$uniquedHist | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8

	} catch { Write-Warning ('❗ ダウンロード履歴の更新に失敗しました') }
	finally { $null = Unlock-File $script:histLockFilePath }
}

#----------------------------------------------------------------------
#番組の整合性チェック
#----------------------------------------------------------------------
function Invoke-ValidityCheck {
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false, Position = 0)][String]$decodeOption,
		[Parameter(Mandatory = $false, Position = 1)][String]$path
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$errorCount = 0
	$checkStatus = 0
	$videoFilePath = Join-Path (Convert-Path $script:downloadBaseDir) $path
	try { $null = New-Item -Path $script:ffpmegErrorLogPath -ItemType File -Force }
	catch { Write-Warning ('❗ ffmpegエラーファイルを初期化できませんでした') ; return }

	#これからチェックする番組のステータスをチェック
	try {
		while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
		$checkStatus = ($videoHists.Where({ $_.videoPath -eq $path })).videoValidated
		switch ($checkStatus) {
			#0:未チェック、1:チェック済、2:チェック中
			'0' {
				$videoHists.Where({ $_.videoPath -eq $path }).Where({ $_.videoValidated = '2' })
				$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
				break
			}
			'1' { Write-Warning ('💡 他プロセスでチェック済です') ; return ; break }
			'2' { Write-Warning ('💡 他プロセスでチェック中です') ; return ; break }
			default { Write-Warning ('❗ 既にダウンロード履歴から削除されたようです: {0}' -f $path) ; return ; break }
		}
	} catch { Write-Warning ('❗ ダウンロード履歴を更新できませんでした: {0}' -f $path) ; return }
	finally { $null = Unlock-File $script:histLockFilePath }

	Invoke-StatisticsCheck -Operation 'validate'

	if ($script:simplifiedValidation) {
		#ffprobeを使った簡易検査
		$ffprobeArgs = (' -hide_banner -v error -err_detect explode -i "{0}"' -f $videoFilePath)
		Write-Debug ('ffprobe起動コマンド: {0}{1}' -f $script:ffprobePath, $ffprobeArgs)
		try {
			if ($IsWindows) {
				$proc = Start-Process `
					-FilePath $script:ffprobePath `
					-ArgumentList ($ffprobeArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$proc = Start-Process `
					-FilePath $script:ffprobePath `
					-ArgumentList ($ffprobeArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			}
		} catch { Write-Error ('❗ ffprobeを起動できませんでした') ; return }
	} else {
		#ffmpegeを使った完全検査
		$ffmpegArgs = (' -hide_banner -v error -xerror {0} -i "{1}" -f null - ' -f $decodeOption, $videoFilePath)
		Write-Debug ('ffmpeg起動コマンド: {0}{1}' -f $script:ffmpegPath, $ffmpegArgs)
		try {
			if ($IsWindows) {
				$proc = Start-Process `
					-FilePath $script:ffmpegPath `
					-ArgumentList ($ffmpegArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$proc = Start-Process `
					-FilePath $script:ffmpegPath `
					-ArgumentList ($ffmpegArgs) `
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
			$errorCount = (Get-Content -LiteralPath $script:ffpmegErrorLogPath | Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffpmegErrorLogPath -Encoding UTF8 | ForEach-Object { Write-Debug $_ }
		}
	} catch { Write-Warning ('❗ ffmpegエラーの数をカウントできませんでした') ; $errorCount = 9999999 }

	#エラーをカウントしたらファイルを削除
	try { if (Test-Path $script:ffpmegErrorLogPath) { Remove-Item -LiteralPath $script:ffpmegErrorLogPath -Force -ErrorAction SilentlyContinue } }
	catch { Write-Warning ('❗ ffmpegエラーファイルを削除できませんでした') }

	if ($proc.ExitCode -ne 0 -or $errorCount -gt 30) {

		#終了コードが0以外 または エラーが一定以上 はダウンロード履歴とファイルを削除
		Write-Warning ('❗ チェックNGでした')
		Write-Warning ('　Exit Code: {0} Error Count: {1}' -f $proc.ExitCode, $errorCount)
		$script:validationFailed = $true

		#破損しているダウンロードファイルをダウンロード履歴から削除
		try {
			while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			#該当の番組のレコードを削除
			$videoHists = @($videoHists.Where({ $_.videoPath -ne $path }))
			$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		} catch { Write-Warning ('❗ ダウンロード履歴の更新に失敗しました: {0}' -f $path) }
		finally { $null = Unlock-File $script:histLockFilePath }

		#破損しているダウンロードファイルを削除
		try { Remove-Item -LiteralPath $videoFilePath -Force -ErrorAction SilentlyContinue }
		catch { Write-Warning ('❗ ファイル削除できませんでした: {0}' -f $videoFilePath) }

	} else {

		#終了コードが0のときはダウンロード履歴にチェック済フラグを立てる
		Write-Output ('　✔️')
		try {
			while ((Lock-File $script:histLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
			$videoHists = @(Import-Csv -LiteralPath $script:histFilePath -Encoding UTF8)
			#該当の番組のチェックステータスを1に
			$videoHists.Where({ $_.videoPath -eq $path }).Where({ $_.videoValidated = '1' })
			$videoHists | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8
		} catch { Write-Warning ('❗ ダウンロード履歴を更新できませんでした: {0}' -f $path) }
		finally { $null = Unlock-File $script:histLockFilePath }

	}

}
