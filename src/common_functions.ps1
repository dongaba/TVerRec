###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		共通関数スクリプト
#
#	Copyright (c) 2022 dongaba
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
#ytdlpの最新化確認
#----------------------------------------------------------------------
function checkLatestYtdlp {
	if ($PSVersionTable.PSEdition -eq 'Desktop') { 
		. $(Convert-Path (Join-Path $currentDir '.\update_ytdl-patched_5.ps1'))
	} else { 
		. $(Convert-Path (Join-Path $currentDir '.\update_ytdl-patched.ps1'))
	}
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $currentDir '.\update_ffmpeg_5.ps1'))
	} else { 
		. $(Convert-Path (Join-Path $currentDir '.\update_ffmpeg.ps1'))
	}
}

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	if (Test-Path $global:downloadBaseDir -PathType Container) {}
	else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $global:ffmpegPath -PathType Leaf) {}
	else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $global:ytdlpPath -PathType Leaf) {}
	else { Write-Error 'yt-dlpが存在しません。終了します。' ; exit 1 }
	if (Test-Path $global:confFile -PathType Leaf) {}
	else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $global:keywordFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $global:ignoreFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $global:listFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit 1 }
}

#----------------------------------------------------------------------
#GEO IPの確認
#----------------------------------------------------------------------
function checkGeoIP {
	try {
		if ((Invoke-RestMethod -Uri 'http://ip-api.com/json/').countryCode -ne 'JP') {
			Invoke-RestMethod -Uri ( 
				'http://ip-api.com/json/' + (Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content
			)
			Write-Host '日本のIPアドレスからしか接続できません。VPN接続してください。' -ForegroundColor Green
			exit 1
		}
	} catch { Write-Host 'Geo IPのチェックに失敗しました' }
}

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function getTimeStamp {
	$local:timeStamp = Get-Date -UFormat '%Y-%m-%d %H:%M:%S' 
	return $local:timeStamp
}

#----------------------------------------------------------------------
#30日以上前に処理したものはリストから削除
#----------------------------------------------------------------------
function purgeDB {
	try {
		#ロックファイルをロック
		while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:purgedList = ((Import-Csv $global:listFilePath -Encoding UTF8).Where({ $_.downloadDate -gt $(Get-Date).AddDays(-30) }))
		$local:purgedList `
		| Export-Csv $global:listFilePath -NoTypeInformation -Encoding UTF8
	} catch { Write-Host 'リストのクリーンアップに失敗しました' -ForegroundColor Green
	} finally { $null = fileUnlock ($global:lockFilePath) }
}

#----------------------------------------------------------------------
#リストの重複削除
#----------------------------------------------------------------------
function uniqueDB {
	$local:processedList = $null
	$local:ignoredList = $null
	#無視されたもの
	try {
		#ロックファイルをロック
		while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}

		#ファイル操作
		#無視されたもの
		$local:ignoredList = ((Import-Csv $global:listFilePath -Encoding UTF8).Where({ $_.videoPath -eq '-- IGNORED --' }))

		#無視されなかったものの重複削除。ファイル名で1つしかないもの残す
		$local:processedList = (Import-Csv $global:listFilePath -Encoding UTF8 `
			| Group-Object -Property 'videoPath' `
			| Where-Object count -EQ 1 `
			| Select-Object -ExpandProperty group)

		#無視されたものと無視されなかったものを結合し出力
		if ($null -eq $local:processedList -and $null -eq $local:ignoredList) { 
			return
		} elseif ($null -ne $local:processedList -and $null -eq $local:ignoredList) { 
			$local:mergedList = $local:processedList
		} elseif ($null -eq $processedList -and $null -ne $ignoredList) { 
			$local:mergedList = $local:ignoredList 
		} else { $local:mergedList = $local:processedList + $local:ignoredList }
		$local:fileStatus = checkFileStatus $global:listFilePath
		Write-Host "Status of $global:listFilePath is $local:fileStatus"
		$mergedList `
		| Sort-Object -Property downloadDate `
		| Export-Csv $global:listFilePath -NoTypeInformation -Encoding UTF8

	} catch { Write-Host 'リストの更新に失敗しました' -ForegroundColor Green
	} finally { $null = fileUnlock ($global:lockFilePath) }
}

#----------------------------------------------------------------------
#ビデオの整合性チェック
#----------------------------------------------------------------------
function checkVideo ($local:decodeOption, $local:videoFileRelativePath) {
	$local:errorCount = 0
	$local:checkStatus = 0
	$local:videoFilePath = Join-Path $global:downloadBaseDir $local:videoFileRelativePath
	try { $null = New-Item $global:ffpmegErrorLogPath -Type File -Force }
	catch { return }
	
	#これからチェックする動画のステータスをチェック
	try {
		#ロックファイルをロック
		while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:videoLists = Import-Csv $global:listFilePath -Encoding UTF8
		$local:checkStatus = $(($local:videoLists).Where({ $_.videoPath -eq $local:videoFileRelativePath })).videoValidated
	} catch { 
		Write-Host "チェックステータスを取得できませんでした: $local:videoFileRelativePath" -ForegroundColor Green
		return 
	} finally { $null = fileUnlock ($global:lockFilePath) }

	#0:未チェック、1:チェック済み、2:チェック中
	if ($local:checkStatus -eq 2 ) { Write-Host '  └他プロセスでチェック中です'; return } 
	elseif ($local:checkStatus -eq 1 ) { Write-Host '  └他プロセスでチェック済です'; return } 
	else {
		#該当のビデオのチェックステータスを"2"にして後続のチェックを実行
		try {
			$(($local:videoLists).Where({ $_.videoPath -eq $local:videoFileRelativePath })).videoValidated = '2'
		} catch { 
			Write-Host "該当のレコードが見つかりませんでした: $local:videoFileRelativePath" -ForegroundColor Green
			return 
		}
		try {
			#ロックファイルをロック
			while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:videoLists `
			| Export-Csv $global:listFilePath -NoTypeInformation -Encoding UTF8
		} catch {
			Write-Host "録画リストを更新できませんでした: $local:videoFileRelativePath" -ForegroundColor Green
			return
		} finally { $null = fileUnlock ($global:lockFilePath) }
	}

	$local:checkFile = '"' + $local:videoFilePath + '"'
	$local:ffmpegArgs = "$local:decodeOption " `
		+ ' -hide_banner -v error -xerror' `
		+ " -i $local:checkFile -f null - "

	Write-Debug "ffmpeg起動コマンド:$global:ffmpegPath $local:ffmpegArgs"
	try {
		if ($global:isWin) {
			$local:proc = Start-Process -FilePath $global:ffmpegPath `
				-ArgumentList ($local:ffmpegArgs) `
				-PassThru `
				-WindowStyle $global:windowShowStyle `
				-RedirectStandardError $global:ffpmegErrorLogPath `
				-Wait 
		} else {
			$local:proc = Start-Process -FilePath $global:ffmpegPath `
				-ArgumentList ($local:ffmpegArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError $global:ffpmegErrorLogPath `
				-Wait 
		}
	} catch {
		Write-Host 'ffmpegを起動できませんでした' -ForegroundColor Green
	}

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $global:ffpmegErrorLogPath) {
			$local:errorCount = (Get-Content -LiteralPath $global:ffpmegErrorLogPath `
				| Measure-Object -Line).Lines
			Get-Content -LiteralPath $global:ffpmegErrorLogPath -Encoding UTF8 `
			| ForEach-Object { Write-Debug "$_" }
		}
	} catch { Write-Host 'ffmpegエラーの数をカウントできませんでした' -ForegroundColor Green }

	#エラーをカウントしたらファイルを削除
	try {
		if (Test-Path $global:ffpmegErrorLogPath) {
			Remove-Item `
				-LiteralPath $global:ffpmegErrorLogPath `
				-Force -ErrorAction SilentlyContinue
		}
	} catch {}

	if ($local:proc.ExitCode -ne 0 -or $local:errorCount -gt 30) {
		#終了コードが"0"以外 または エラーが30行以上 は録画リストとファイルを削除
		Write-Host "$local:videoFileRelativePath"
		Write-Host "  exit code: $($local:proc.ExitCode)    error count: $local:errorCount"

		#破損している動画ファイルを録画リストから削除
		try {
			#ロックファイルをロック
			while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			(Select-String `
				-Pattern $local:videoFileRelativePath `
				-LiteralPath $global:listFilePath `
				-Encoding UTF8 -SimpleMatch -NotMatch).Line `
			| Out-File $global:listFilePath -Encoding UTF8
		} catch { Write-Host "録画リストの更新に失敗しました: $local:videoFileRelativePath" -ForegroundColor Green
		} finally { $null = fileUnlock ($global:lockFilePath) }

		#破損している動画ファイルを削除
		try {
			Remove-Item `
				-LiteralPath $local:videoFilePath `
				-Force -ErrorAction SilentlyContinue
		} catch { Write-Host "ファイル削除できませんでした: $local:videoFilePath" -ForegroundColor Green }
	} else {
		#終了コードが"0"のときは録画リストにチェック済みフラグを立てる
		try {
			#ロックファイルをロック
			while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:videoLists = Import-Csv $global:listFilePath -Encoding UTF8
			#該当のビデオのチェックステータスを"1"に
			$(($local:videoLists).Where({ $_.videoPath -eq $local:videoFileRelativePath })).videoValidated = '1'
			$local:videoLists `
			| Export-Csv $global:listFilePath -NoTypeInformation -Encoding UTF8
		} catch { Write-Host "録画リストを更新できませんでした: $local:videoFileRelativePath" -ForegroundColor Green
		} finally { $null = fileUnlock ($global:lockFilePath) }
	}

}

#----------------------------------------------------------------------
#yt-dlpプロセスの確認と待機
#----------------------------------------------------------------------
function waitTillYtdlpProcessGetFewer ($local:parallelDownloadFileNum) {
	#yt-dlpのプロセスが設定値を超えたら一時待機
	try {
		if ($global:isWin) {
			$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name youtube-dl-red).Count / 2
		} elseif ($IsLinux) {
			$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		} elseif ($IsMacOS) {
			$local:psCmd = 'ps'
			$local:ytdlpCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
		} else {
			$local:ytdlpCount = 0
		}
	} catch {
		$local:ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlpCount 個)"

	while ([int]$local:ytdlpCount -ge [int]$local:parallelDownloadFileNum) {
		Write-Host "ダウンロードが $local:parallelDownloadFileNum 多重に達したので一時待機します。 ($(getTimeStamp))"
		Start-Sleep -Seconds 60			#1分待機
		try {
			if ($global:isWin) {
				$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name youtube-dl-red).Count / 2
			} elseif ($IsLinux) {
				$local:ytdlpCount = (& Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			} elseif ($IsMacOS) {
				$local:ytdlpCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
			} else {
				$local:ytdlpCount = 0
			}
		} catch {
			$local:ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
		}
	}
}

#----------------------------------------------------------------------
#yt-dlpのプロセスが終わるまで待機
#----------------------------------------------------------------------
function waitTillYtdlpProcessIsZero () {
	try {
		if ($global:isWin) {
			$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name youtube-dl-red).Count / 2		
  } elseif ($IsLinux) {
			$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		} elseif ($IsMacOS) {
			$local:psCmd = 'ps'
			$local:ytdlpCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
		} else {
			$local:ytdlpCount = 0
		}
	} catch {
		$local:ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	while ($local:ytdlpCount -ne 0) {
		try {
			Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlpCount 個)"
			Start-Sleep -Seconds 60			#1分待機
			if ($global:isWin) {
				$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name youtube-dl-red).Count / 2
			} elseif ($IsLinux) {
				$local:ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			} elseif ($IsMacOS) {
				$local:ytdlpCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
			} else {
				$local:ytdlpCount = 0
			}
		} catch {
			$local:ytdlpCount = 0
		}
	}
}

#----------------------------------------------------------------------
#yt-dlpプロセスの起動
#----------------------------------------------------------------------
function executeYtdlp ($local:videoPageURL) {
	$local:tmpDir = '"temp:' + $global:downloadWorkDir + '"'
	$local:saveDir = '"home:' + $global:videoFileDir + '"'
	$local:subttlDir = '"subtitle:' + $global:downloadWorkDir + '"'
	$local:thumbDir = '"thumbnail:' + $global:downloadWorkDir + '"'
	$local:chaptDir = '"chapter:' + $global:downloadWorkDir + '"'
	$local:descDir = '"description:' + $global:downloadWorkDir + '"'
	$local:saveFile = '"' + $videoName + '"'

	$local:ytdlpArgs = '--format mp4 --console-title --no-mtime'
	$local:ytdlpArgs += ' --retries 10 --fragment-retries 10'
	$local:ytdlpArgs += ' --abort-on-unavailable-fragment'
	$local:ytdlpArgs += ' --no-keep-fragments'
	$local:ytdlpArgs += ' --windows-filenames'
	$local:ytdlpArgs += ' --xattr-set-filesize'
	$local:ytdlpArgs += ' --newline --print-traffic'
	$local:ytdlpArgs += " --concurrent-fragments $global:parallelDownloadNumPerFile"
	$local:ytdlpArgs += ' --embed-thumbnail --embed-subs'
	$local:ytdlpArgs += ' --embed-metadata --embed-chapters'
	$local:ytdlpArgs += " --paths $local:saveDir --paths $local:tmpDir"
	$local:ytdlpArgs += " --paths $local:subttlDir --paths $local:thumbDir"
	$local:ytdlpArgs += " --paths $local:chaptDir --paths $local:descDir"
	$local:ytdlpArgs += " -o $local:saveFile $local:videoPageURL"

	if ($global:isWin) {
		try {
			Write-Debug "yt-dlp起動コマンド:$global:ytdlpPath $local:ytdlpArgs"
			$null = Start-Process -FilePath $global:ytdlpPath `
				-ArgumentList $local:ytdlpArgs `
				-PassThru `
				-WindowStyle $global:windowShowStyle
		} catch { Write-Host 'yt-dlpの起動に失敗しました' -ForegroundColor Green }
	} else {
		Write-Debug "y起動コマンド:nohup $global:ytdlpPath $local:ytdlpArgs"
		try {
			$null = Start-Process -FilePath nohup `
				-ArgumentList ($global:ytdlpPath, $local:ytdlpArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null
		} catch { Write-Host 'yt-dlpの起動に失敗しました' -ForegroundColor Green }
	}
}

#----------------------------------------------------------------------
#ビデオ情報表示
#----------------------------------------------------------------------
function showVideoInfo ($local:videoName, $local:broadcastDate, $local:mediaName, $local:descriptionText) {
	Write-Host "ビデオ名    :$local:videoName"
	Write-Host "放送日      :$local:broadcastDate"
	Write-Host "テレビ局    :$local:mediaName"
	Write-Host "ビデオ説明  :$local:descriptionText"
}
#----------------------------------------------------------------------
#ビデオ情報デバッグ表示
#----------------------------------------------------------------------
function showVideoDebugInfo ($local:videoPageURL, $local:videoSeriesPageURL, $local:keywordName, $local:videoSeries, $local:videoSeason, $local:videoTitle, $local:videoFilePath, $local:processedTime) {
	Write-Debug	"ビデオエピソードページ:$local:videoPageURL"
	Write-Debug	"ビデオシリーズページ  :$local:videoSeriesPageURL"
	Write-Debug "キーワード            :$local:keywordName"
	Write-Debug "シリーズ              :$local:videoSeries"
	Write-Debug "シーズン              :$local:videoSeason"
	Write-Debug "サブタイトル          :$local:videoTitle"
	Write-Debug "ファイル              :$local:videoFilePath"
	Write-Debug "取得日付              :$local:processedTime"
}

#----------------------------------------------------------------------
#ファイル名・フォルダ名に禁止文字の削除
#----------------------------------------------------------------------
function getFileNameWithoutInvalidChars {
	param(
		[Parameter(
			Mandatory = $true,
			Position = 0,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true)]
		[String]$local:Name
	)

	$local:invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
	$local:result = '[{0}]' -f [RegEx]::Escape($local:invalidChars)
	return ($local:Name -replace $local:result)
}

#----------------------------------------------------------------------
#全角→半角
#----------------------------------------------------------------------
function getNarrowChars {

	Param([String]$local:text)		#変換元テキストを引数に指定

	$local:wideKanaDaku = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ'
	$local:narrowKanaDaku = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ'
	$local:narrowWideKanaHanDaku = 'パピプペポ'
	$local:narrowWideKanaHanDaku = 'ﾊﾋﾌﾍﾎ'
	$local:wideKana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン゛゜ァィゥェォャュョッ'
	$local:narrowKana = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝﾞﾟｧｨｩｪｫｬｭｮｯ'
	$local:wideNum = '０１２３４５６７８９'
	$local:narrowNum = '0123456789'
	$local:wideAlpha = 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
	$local:narrowAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
	$local:wideSimbol = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：'
	$local:narrowSimbol = '@#$%^&*-+_/[]{}()<> \\";:'

	for ($i = 0; $i -lt $local:wideKanaDaku.Length; $i++) {
		$local:text = $local:text.Replace($local:narrowKanaDaku[$i] + 'ﾞ', $local:wideKanaDaku[$i])
	}
	for ($i = 0; $i -lt $local:narrowWideKanaHanDaku.Length; $i++) {
		$local:text = $local:text.Replace($local:narrowWideKanaHanDaku[$i] + 'ﾟ', $local:narrowWideKanaHanDaku[$i])
	}
	for ($i = 0; $i -lt $local:wideKana.Length; $i++) {
		$local:text = $local:text.Replace($local:narrowKana[$i], $local:wideKana[$i])
	}
	for ($i = 0; $i -lt $local:narrowNum.Length; $i++) {
		$local:text = $local:text.Replace($local:wideNum[$i], $local:narrowNum[$i])
	}
	for ($i = 0; $i -lt $local:narrowAlpha.Length; $i++) {
		$local:text = $local:text.Replace($local:wideAlpha[$i], $local:narrowAlpha[$i])
	}
	for ($i = 0; $i -lt $local:narrowSimbol.Length; $i++) {
		$local:text = $local:text.Replace($local:wideSimbol[$i], $local:narrowSimbol[$i])
	}
	return $local:text

}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
function getSpecialCharacterReplaced {
	Param([String]$local:text)		#変換元テキストを引数に指定
	$local:text = $local:text.Replace('&amp;', '&')
	$local:text = $local:text.Replace('"', '')
	$local:text = $local:text.Replace('“', '')
	$local:text = $local:text.Replace('”', '')
	$local:text = $local:text.Replace(',', '')
	$local:text = $local:text.Replace('?', '？')
	$local:text = $local:text.Replace('!', '！')
	$local:text = $local:text.Replace('/', '-')
	$local:text = $local:text.Replace('\', '-')
	return $local:text
}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function getVideoFileName ($local:videoSeries, $local:videoSeason, $local:videoTitle, $local:broadcastDate) {
	if ($local:videoTitle -eq '') {
		if ($local:broadcastDate -eq '') {
			$local:videoName = $local:videoSeries + ' ' + $local:videoSeason 
		} else {
			$local:videoName = $local:videoSeries + ' ' + $local:videoSeason + ' ' + $local:broadcastDate
		}
	} else {
		$local:videoName = $local:videoSeries + ' ' + $local:videoSeason + ' ' + $local:broadcastDate + ' ' + $local:videoTitle
	}
	#ファイル名にできない文字列を除去
	$local:videoName = $(getFileNameWithoutInvalidChars (getNarrowChars $local:videoName)).Replace('  ', ' ')

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	$local:videoNameTemp = ''
	$local:fileNameLimit = $global:fileNameLengthMax - 25	#yt-dlpの中間ファイル等を考慮して安全目の上限値
	$local:videoNameByte = [System.Text.Encoding]::UTF8.GetByteCount($local:videoName)

	#ファイル名を1文字ずつ増やしていき、上限に達したら残りは「……」とする
	if ($local:videoNameByte -gt $local:fileNameLimit) {
		for ($i = 1 ; [System.Text.Encoding]::UTF8.GetByteCount($local:videoNameTemp) -lt $local:fileNameLimit ; $i++) {
			$local:videoNameTemp = $local:videoName.Substring(0, $i)
		}
		$local:videoName = $local:videoNameTemp + '……'			#ファイル名省略の印
	}

	$local:videoName = $local:videoName + '.mp4'
	return $local:videoName
}

#----------------------------------------------------------------------
#ダウンロードが中断した際にできたゴミファイルは削除
#----------------------------------------------------------------------
function deleteTrashFiles ($local:Path, $local:Conditions) {
	try {
		Write-Host "$($local:Path)を処理中"
		$local:delTargets = @()
		foreach ($local:filter in $local:Conditions.Split(',').trim()) {
			$local:delTargets += Get-ChildItem -LiteralPath $local:Path `
				-Recurse -File -Filter $local:filter
		}
		if ($null -ne $local:delTargets) {
			foreach ($local:delTarget in $local:delTargets) {
				Write-Host "$($local:delTarget.FullName)を削除します"
				Remove-Item -LiteralPath $local:delTarget.FullName `
					-Force -ErrorAction SilentlyContinue
			}
		} else {
			Write-Host '削除対象はありませんでした'
		}
	} catch { Write-Host '削除できないファイルがありました' -ForegroundColor Green }
}

#----------------------------------------------------------------------
#ファイルのロック
#----------------------------------------------------------------------
function fileLock {
	param (
		[parameter(position = 0, mandatory)][System.IO.FileInfo]$local:Path
	)
	try {
		$local:fileLocked = $false						# initialise variables
		$script:fileInfo = New-Object System.IO.FileInfo $local:Path		# attempt to open file and detect file lock
		$script:fileStream = $script:fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$local:fileLocked = $true						# initialise variables
	} catch {
		$fileLocked = $false		# catch fileStream had falied
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $local:Path
			fileLocked = $local:fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのアンロック
#----------------------------------------------------------------------
function fileUnlock {
	param (
		[parameter(position = 0, mandatory)][System.IO.FileInfo]$local:Path
	)
	try {
		if ($script:fileStream) { $script:fileStream.Close() }		# close stream if not lock
		$local:fileLocked = $false						# initialise variables
	} catch {
		$local:fileLocked = $true		# catch fileStream had falied
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $local:Path
			fileLocked = $local:fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのロック確認
#----------------------------------------------------------------------
function isLocked {
	param (
		[parameter(position = 0, mandatory)][string]$local:isLockedPath
	)
	try {
		$local:isFileLocked = $false						# initialise variables
		$local:isLockedFileInfo = New-Object System.IO.FileInfo $local:isLockedPath		# attempt to open file and detect file lock
		$local:isLockedfileStream = $local:isLockedFileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		if ($local:isLockedfileStream) { $local:isLockedfileStream.Close() }		# close stream if not lock
		$local:isFileLocked = $false						# initialise variables
	} catch {
		$local:isFileLocked = $true		# catch fileStream had falied
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $local:isLockedPath
			fileLocked = $local:isFileLocked
		}
	}
}
