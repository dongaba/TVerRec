###################################################################################
#  TVerRec : TVerダウンローダ
#
#		番組リストファイル出力処理スクリプト
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$script:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else { $script:scriptRoot = Convert-Path . }
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '../conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '../dev')
} catch { Write-Error 'ディレクトリ設定に失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
	. $script:sysFile
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:confFile
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/tver_functions.ps1'))
} catch { Write-Error '外部関数ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Write-Warning '開発ファイル用共通関数ファイルを読み込みました'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Write-Warning '開発ファイル用設定ファイルを読み込みました'
	}
} catch { Write-Error '開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
[Console]::ForegroundColor = 'Cyan'
Write-Output ''
Write-Output '==========================================================================='
Write-Output '                                                                           '
Write-Output '        ████████ ██    ██ ███████ ██████  ██████  ███████  ██████          '
Write-Output '           ██    ██    ██ ██      ██   ██ ██   ██ ██      ██               '
Write-Output '           ██    ██    ██ █████   ██████  ██████  █████   ██               '
Write-Output '           ██     ██  ██  ██      ██   ██ ██   ██ ██      ██               '
Write-Output '           ██      ████   ███████ ██   ██ ██   ██ ███████  ██████          '
Write-Output '                                                                           '
Write-Output "        $script:appName : TVerダウンローダ                                 "
Write-Output "                             番組リスト生成 version. $script:appVersion    "
Write-Output '                                                                           '
Write-Output '==========================================================================='
Write-Output ''
[Console]::ResetColor()

#----------------------------------------------------------------------
#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#ダウンロード対象キーワードの読み込み
$local:keywordNames = loadKeywordList
#ダウンロード対象外番組の読み込み
$script:ignoreRegExTitles = getRegExIgnoreList
getToken

#キーワードの番号
$local:keywordNum = 0
if ($script:keywordNames -is [Array]) {
	#トータルキーワード数
	$local:keywordTotal = $script:keywordNames.Length
} else { $local:keywordTotal = 1 }

#進捗表示
showProgressToast `
	-Text1 'キーワードから番組リスト作成中' `
	-Text2 'キーワードから番組を抽出しダウンロード' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'ListGen' `
	-Duration 'long' `
	-Silent $false

#======================================================================
#個々のジャンルページチェックここから
$local:totalStartTime = Get-Date
foreach ($local:keywordName in $local:keywordNames) {
	#いろいろ初期化
	$local:videoLink = ''
	$local:videoLinks = @()
	$local:searchResultCount = 0

	#ジャンルページチェックタイトルの表示
	Write-Output ''
	Write-Output '----------------------------------------------------------------------'
	Write-Output "$(trimTabSpace ($local:keywordName))"
	Write-Output '----------------------------------------------------------------------'

	#処理
	$local:resultLinks = getVideoLinksFromKeyword ($local:keywordName)
	$local:keywordName = $local:keywordName.Replace('https://tver.jp/', '')

	#ダウンロードリストファイルのデータを読み込み
	try {
		#ロックファイルをロック
		while ($(fileLock $script:listLockFilePath).fileLocked -ne $true)
		{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
		#ファイル操作
		$script:listFileData = `
			Import-Csv `
			-Path $script:listFilePath `
			-Encoding UTF8
	} catch { Write-Warning 'ダウンロードリストを読み込めなかったのでスキップしました'; continue
	} finally { $null = fileUnlock $script:listLockFilePath }

	#URLがすでにダウンロードリストに存在する場合は検索結果から除外
	foreach ($local:resultLink in $local:resultLinks) {
		$local:listMatch = $script:listFileData `
		| Where-Object { $_.episodeID -like "*$($local:resultLink.Replace('https://tver.jp/episodes/', ''))" }
		if ($null -eq $local:listMatch) { $local:videoLinks += $local:resultLink }
		else { $local:searchResultCount = $local:searchResultCount + 1; continue }
	}

	#ジャンル内の処理中の番組の番号
	#$local:videoNum = 0
	#ダウンロード対象のトータル番組数
	if ($null -eq $local:videoLinks) { $local:videoTotal = 0 }
	else { $local:videoTotal = $local:videoLinks.Length }
	Write-Output "　ダウンロード対象$($local:videoTotal)本 処理済$($local:searchResultCount)本"

	#処理時間の推計
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining = -1
	if ($local:keywordNum -ne 0) {
		$local:secRemaining = `
		($local:secElapsed.TotalSeconds / $local:keywordNum) `
			* ($local:keywordTotal - $local:keywordNum)
	}
	if ($local:secRemaining -eq -1 -Or $local:secRemaining -eq '' ) { $local:minRemaining = '計算中...' }
	else { $local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分" }
	$local:progressRatio1 = $($local:keywordNum / $local:keywordTotal)
	#$local:progressRatio2 = 0

	#キーワード数のインクリメント
	$local:keywordNum = $local:keywordNum + 1

	#進捗更新
	updateProgressToast `
		-Title $(trimTabSpace ($local:keywordName)) `
		-Rate $local:progressRatio1 `
		-LeftText $local:keywordNum/$local:keywordTotal `
		-RightText $local:minRemaining `
		-Tag $script:appName `
		-Group 'ListGen'

	#----------------------------------------------------------------------
	#個々の番組の情報の取得ここから

	#複数あるときは並列化して極力高速化
	if ($local:videoTotal -gt 1) {

		#関数の定義
		$funcGoAnal = ${function:goAnal}.ToString()
		$funcGetVideoInfo = ${function:getVideoInfo}.ToString()
		$funcGetNarrowChars = ${function:getNarrowChars}.ToString()
		$funcFileLock = ${function:fileLock}.ToString()
		$funcFileUnlock = ${function:fileUnlock}.ToString()
		$funcGetSpecialCharacterReplaced = ${function:getSpecialCharacterReplaced}.ToString()
		$funcUnixTimeToDateTime = ${function:unixTimeToDateTime}.ToString()
		$funcSortIgnoreList = ${function:sortIgnoreList}.ToString()
		$funcGetRegExIgnoreList = ${function:getRegExIgnoreList}.ToString()

		$local:videoLinks | ForEach-Object -Parallel {
			#関数の取り込み
			${function:goAnal} = $using:funcGoAnal
			${function:getVideoInfo} = $using:funcGetVideoInfo
			${function:getNarrowChars} = $using:funcGetNarrowChars
			${function:fileLock} = $using:funcFileLock
			${function:fileUnlock} = $using:funcFileUnlock
			${function:getSpecialCharacterReplaced} = $using:funcGetSpecialCharacterReplaced
			${function:unixTimeToDateTime} = $using:funcUnixTimeToDateTime
			${function:sortIgnoreList} = $using:funcSortIgnoreList
			${function:getRegExIgnoreList} = $using:funcGetRegExIgnoreList

			#変数の置き換え
			$script:timeoutSec = $using:script:timeoutSec
			$script:guid = $using:script:guid
			$script:clientEnv = $using:script:clientEnv
			$script:disableValidation = $using:script:disableValidation
			$script:forceSoftwareDecodeFlag = $using:script:forceSoftwareDecodeFlag
			$script:ffmpegDecodeOption = $using:script:ffmpegDecodeOption
			$script:platformUID = $using:script:platformUID
			$script:platformToken = $using:script:platformToken
			$script:listLockFilePath = $using:script:listLockFilePath
			$script:listFilePath = $using:script:listFilePath
			$script:listFileData = $using:script:listFileData
			$script:ignoreLockFilePath = $using:script:ignoreLockFilePath
			$script:ignoreFileSamplePath = $using:script:ignoreFileSamplePath
			$script:ignoreFilePath = $using:script:ignoreFilePath

			$local:i = $([Array]::IndexOf($using:local:videoLinks, $_)) + 1
			$local:total = $using:local:videoLinks.Count
			#処理
			Write-Output "$($local:i)/$($local:total) - $($_)"

			#TVer番組ダウンロードのメイン処理
			$broadcastDate = '' ; $videoSeries = '' ; $videoSeason = ''
			$videoEpisode = '' ; $videoTitle = ''
			$mediaName = ''
			$ignoreWord = ''
			$newVideo = $null
			$ignore = $false

			#TVerのAPIを叩いて番組情報取得
			goAnal -Event 'getinfo' -Type 'link' -ID $_
			try { getVideoInfo -Link $_ }
			catch { Write-Warning '情報取得エラー。スキップします Err:10'; continue }

			#ダウンロード対象外に入っている番組の場合はリスト出力しない
			foreach ($ignoreRegexTitle in $using:script:ignoreRegexTitles) {

				if ($(getNarrowChars $script:videoSeries) -match $(getNarrowChars $ignoreRegexTitle)) {
					$ignoreWord = $ignoreRegexTitle
					sortIgnoreList $ignoreRegexTitle
					$ignore = $true
					#ダウンロード対象外と合致したものはそれ以上のチェック不要
					break
				} elseif ($(getNarrowChars $script:videoTitle) -match $(getNarrowChars $ignoreRegexTitle)) {
					$ignoreWord = $ignoreRegexTitle
					sortIgnoreList $ignoreRegexTitle
					$ignore = $true
					#ダウンロード対象外と合致したものはそれ以上のチェック不要
					break
				}
			}

			#スキップフラグが立っているかチェック
			if ($ignore -eq $true) {
				Write-Output "　$($local:i)/$($local:total) - 番組をコメントアウトした状態でリストファイルに追加します"
				$newVideo = [pscustomobject]@{
					seriesName    = $videoSeries
					seriesID      = $videoSeriesID
					seasonName    = $videoSeason
					seasonID      = $videoSeasonID
					episodeNo     = $videoEpisode
					episodeName   = $videoTitle
					episodeID     = '#' + $_.Replace('https://tver.jp/episodes/', '')
					media         = $mediaName
					provider      = $providerName
					broadcastDate = $broadcastDate
					endTime       = $endTime
					keyword       = $local:keywordName
					ignoreWord    = $ignoreWord
				}
			} else {
				Write-Output "　$($local:i)/$($local:total) - 番組をリストファイルに追加します"
				$newVideo = [pscustomobject]@{
					seriesName    = $videoSeries
					seriesID      = $videoSeriesID
					seasonName    = $videoSeason
					seasonID      = $videoSeasonID
					episodeNo     = $videoEpisode
					episodeName   = $videoTitle
					episodeID     = $_.Replace('https://tver.jp/episodes/', '')
					media         = $mediaName
					provider      = $providerName
					broadcastDate = $broadcastDate
					endTime       = $endTime
					keyword       = $keywordName
					ignoreWord    = ''
				}
			}

			#ダウンロードリストCSV書き出し
			try {
				#ロックファイルをロック
				while ($(fileLock $script:listLockFilePath).fileLocked -ne $true)
				{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
				#ファイル操作
				$newVideo | Export-Csv `
					-Path $script:listFilePath `
					-NoTypeInformation `
					-Encoding UTF8 `
					-Append
				Write-Debug 'ダウンロードリストを書き込みました'
			} catch { Write-Warning 'ダウンロードリストを更新できませんでした。スキップします'; continue
			} finally { $null = fileUnlock $script:listLockFilePath }
			$script:listFileData = `
				Import-Csv `
				-Path $script:listFilePath `
				-Encoding UTF8

		} -ThrottleLimit $script:multithreadNum

	} else {

		foreach ($local:videoLink in $local:videoLinks) {
			Write-Output "$($([Array]::IndexOf($local:videoLinks, $local:videoLink)) + 1 )/$($local:videoLinks.Count) - $($local:videoLink)"
			#TVer番組ダウンロードのメイン処理
			generateTVerVideoList `
				-Keyword $local:keywordName `
				-Link $local:videoLink
		}

	}

	#----------------------------------------------------------------------

}
#======================================================================

#進捗表示
updateProgressToast `
	-Title '' `
	-Rate 1 `
	-LeftText $local:keywordNum/$local:keywordTotal `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'ListGen'

#youtube-dlのプロセスが終わるまで待機
Write-Output 'ダウンロードの終了を待機しています'
waitTillYtdlProcessIsZero

Write-Output '---------------------------------------------------------------------------'
Write-Output '処理を終了しました。                                                       '
Write-Output '---------------------------------------------------------------------------'
