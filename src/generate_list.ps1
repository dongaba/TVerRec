###################################################################################
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

try { $script:uiMode = [String]$args[0] } catch { $script:uiMode = '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
	$script:devDir = Join-Path $script:scriptRoot '../dev'
} catch { Write-Error ('❗ カレントディレクトリの設定に失敗しました') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error ('❗ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#ダウンロード対象キーワードの読み込み
$local:keywordNames = @(loadKeywordList)
#ダウンロード対象外番組の読み込み
$script:ignoreTitles = loadIgnoreList
getToken

$local:keywordNum = 0
$local:keywordTotal = $local:keywordNames.Count

showProgressToast `
	-Text1 'キーワードから番組リスト作成中' `
	-Text2 'キーワードから番組を抽出しダウンロード' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Duration 'long' `
	-Silent $false `
	-Group 'ListGen'

#======================================================================
#個々のジャンルページチェックここから
$local:totalStartTime = Get-Date
foreach ($local:keywordName in $local:keywordNames) {
	#いろいろ初期化
	$local:videoLink = ''
	$local:processedCount = 0
	$local:videoLinks = [System.Collections.Generic.List[string]]::new()
	$local:keywordName = trimTabSpace ($local:keywordName)

	#ジャンルページチェックタイトルの表示
	Write-Output ('')
	Write-Output ('----------------------------------------------------------------------')
	Write-Output ('{0}' -f $local:keywordName)

	$local:resultLinks = @(getVideoLinksFromKeyword ($local:keywordName))
	$local:keywordName = $local:keywordName.Replace('https://tver.jp/', '')

	#ダウンロードリストファイルのデータを読み込み
	try {
		while ((fileLock $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$script:listFileData = @(Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8)
	} catch { Write-Warning ('❗ ダウンロードリストを読み込めなかったのでスキップしました') ; continue }
	finally { $null = fileUnlock $script:listLockFilePath }

	#ダウンロード履歴ファイルのデータを読み込み
	try {
		while ((fileLock $script:historyLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
		$script:historyFileData = @(Import-Csv -LiteralPath $script:historyFilePath -Encoding UTF8)
	} catch { Write-Warning ('❗ ダウンロード履歴を読み込めなかったのでスキップしました') ; continue }
	finally { $null = fileUnlock $script:historyLockFilePath }

	#----------------------------------------------------------------------
	#EpisodeIDがすでにダウンロードリストに存在する場合は検索結果から除外
	$local:listEpisodeIDs = @($script:listFileData.episodeID)
	$local:listVideoPages = [System.Collections.Generic.List[string]]::new()
	foreach ($local:listEpisodeID in $local:listEpisodeIDs) {
		$local:listVideoPages.Add('https://tver.jp/episodes/{0}' -f $local:listEpisodeID)
	}
	$local:listCompareResult = @(Compare-Object -IncludeEqual $local:resultLinks $local:listVideoPages).where({ $_.SideIndicator -ne '=>' })
	$local:listMatch = @($local:listCompareResult.where({ $_.SideIndicator -eq '==' }))
	$local:listUnmatch = @($local:listCompareResult.where({ $_.SideIndicator -eq '<=' }))
	$local:tempLinks = [System.Collections.Generic.List[string]]::new()
	if ($local:listUnmatch.Count -ne 0) { $local:tempLinks = @($local:listUnmatch.InputObject) }
	if ($local:listMatch.Count -ne 0) { $local:processedCount += $local:listMatch.Count }

	#URLがすでにダウンロード履歴に存在する場合は検索結果から除外
	$local:histVideoPages = $script:historyFileData.VideoPage
	$local:histCompareResult = @(Compare-Object -IncludeEqual $local:tempLinks $local:histVideoPages).where({ $_.SideIndicator -ne '=>' })
	$local:histMatch = @($local:histCompareResult.where({ $_.SideIndicator -eq '==' }))
	$local:histUnmatch = @($local:histCompareResult.where({ $_.SideIndicator -eq '<=' }))
	if ($local:histUnmatch.Count -ne 0) {
		$local:videoLinks = @($local:histUnmatch.InputObject)
		$local:videoTotal = $local:histUnmatch.Count
	}
	if ($local:histMatch.Count -ne 0) { $local:processedCount = $local:histMatch.Count }

	if ($null -eq $local:videoLinks) { $local:videoTotal = 0 }
	else { $local:videoTotal = $local:videoLinks.Count }
	Write-Output ('💡 処理対象{0}本　処理済{1}本' -f $local:videoTotal, $local:processedCount)
	#----------------------------------------------------------------------

	#処理対象番組がない場合は次のキーワード
	if ( $local:videoTotal -eq 0 ) { continue }

	#処理時間の推計
	$local:secElapsed = (Get-Date) - $local:totalStartTime
	$local:secRemaining = -1
	if ($local:keywordNum -ne 0) {
		$local:secRemaining = [Int][Math]::Ceiling(($local:secElapsed.TotalSeconds / $local:keywordNum) * ($local:keywordTotal - $local:keywordNum))
	}
	if ($local:secRemaining -eq -1 -Or $local:secRemaining -eq '' ) { $local:minRemaining = '' }
	else { $local:minRemaining = ('{0}分' -f ([Int][Math]::Ceiling($local:secRemaining / 60))) }
	$local:progressRate1 = [Float]($local:keywordNum / $local:keywordTotal)
	$local:keywordNum += 1

	#進捗更新
	updateProgressToast `
		-Title (trimTabSpace ($local:keywordName)) `
		-Rate $local:progressRate1 `
		-LeftText $local:keywordNum/$local:keywordTotal `
		-RightText $local:minRemaining `
		-Tag $script:appName `
		-Group 'ListGen'

	#----------------------------------------------------------------------
	#個々の番組の情報の取得ここから

	if ($script:enableMultithread -eq $true) {
		#並列化が有効の場合は並列化

		#関数の定義
		$funcGoAnal = ${function:goAnal}.ToString()
		$funcGetVideoInfo = ${function:getVideoInfo}.ToString()
		$funcGetNarrowChars = ${function:getNarrowChars}.ToString()
		$funcFileLock = ${function:fileLock}.ToString()
		$funcFileUnlock = ${function:fileUnlock}.ToString()
		$funcGetSpecialCharacterReplaced = ${function:getSpecialCharacterReplaced}.ToString()
		$funcUnixTimeToDateTime = ${function:unixTimeToDateTime}.ToString()
		$funcSortIgnoreList = ${function:sortIgnoreList}.ToString()
		$funcloadIgnoreList = ${function:loadIgnoreList}.ToString()

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
			${function:loadIgnoreList} = $using:funcloadIgnoreList

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

			$local:i = ([Array]::IndexOf($using:local:videoLinks, $_)) + 1
			$local:total = $using:local:videoLinks.Count
			Write-Output ('　{0}/{1} - {2}' -f $local:i, $local:total, $_)

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
			catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:92') ; continue }

			#ダウンロード対象外に入っている番組の場合はリスト出力しない
			foreach ($ignoreTitle in $using:script:ignoreTitles) {
				if ($ignoreTitle -ne '') {
					if ($script:videoSeries -like ('*{0}*' -f $local:ignoreTitle)) {
						$ignoreWord = $ignoreTitle
						sortIgnoreList $ignoreTitle
						$ignore = $true
						#ダウンロード対象外と合致したものはそれ以上のチェック不要
						break
					} elseif ($script:videoTitle -like ('*{0}*' -f $local:ignoreTitle)) {
						$ignoreWord = $ignoreTitle
						sortIgnoreList $ignoreTitle
						$ignore = $true
						#ダウンロード対象外と合致したものはそれ以上のチェック不要
						break
					}
				}
			}

			#スキップフラグが立っているかチェック
			if ($ignore -eq $true) {
				Write-Output ('❗ {0}/{1} - 番組をコメントアウトした状態でリストファイルに追加します' -f $local:i, $local:total)
				$newVideo = [pscustomobject]@{
					seriesName    = $videoSeries
					seriesID      = $videoSeriesID
					seasonName    = $videoSeason
					seasonID      = $videoSeasonID
					episodeNo     = $videoEpisode
					episodeName   = $videoTitle
					episodeID     = ('#{0}' -f $_.Replace('https://tver.jp/episodes/', ''))
					media         = $mediaName
					provider      = $providerName
					broadcastDate = $broadcastDate
					endTime       = $endTime
					keyword       = $local:keywordName
					ignoreWord    = $ignoreWord
				}
			} else {
				Write-Output ('💡 {0}/{1} - 番組をリストファイルに追加します' -f $local:i, $local:total)
				$newVideo = [pscustomobject]@{
					seriesName    = $videoSeries
					seriesID      = $videoSeriesID
					seasonName    = $videoSeason
					seasonID      = $videoSeasonID
					episodeNo     = $videoEpisode
					episodeName   = $videoTitle
					episodeID     = ('{0}' -f $_.Replace('https://tver.jp/episodes/', ''))
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
				while ((fileLock $script:listLockFilePath).fileLocked -ne $true) { Write-Warning ('ファイルのロック解除待ち中です') ; Start-Sleep -Seconds 1 }
				$newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append
				Write-Debug ('ダウンロードリストを書き込みました')
			} catch { Write-Warning ('❗ ダウンロードリストを更新できませんでした。スキップします') ; continue }
			finally { $null = fileUnlock $script:listLockFilePath }
			$script:listFileData = Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8

		} -ThrottleLimit $script:multithreadNum

	} else {
		#並列化が無効の場合は従来型処理
		$local:i = 0
		$local:total = $local:videoLinks.Count
		foreach ($local:videoLink in $local:videoLinks) {
			$local:i += 1
			Write-Output ('　{0}/{1} - {2}' -f $local:i, $local:total, $local:videoLink)
			#TVer番組ダウンロードのメイン処理
			generateTVerVideoList `
				-Keyword $local:keywordName `
				-Link $local:videoLink
		}
	}

	#----------------------------------------------------------------------

}
#======================================================================

updateProgressToast `
	-Title '' `
	-Rate 1 `
	-LeftText $local:keywordNum/$local:keywordTotal `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'ListGen'

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

Write-Output ('')
Write-Output ('---------------------------------------------------------------------------')
Write-Output ('番組リストファイル出力処理を終了しました。')
Write-Output ('---------------------------------------------------------------------------')
