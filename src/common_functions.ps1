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
#ytdlの最新化確認
#----------------------------------------------------------------------
function checkLatestYtdl {
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $scriptRoot '.\update_ytdl-patched_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $scriptRoot '.\update_ytdl-patched.ps1'))
	}
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $scriptRoot '.\update_ffmpeg_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $scriptRoot '.\update_ffmpeg.ps1'))
	}
}

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	if (Test-Path $script:downloadBaseDir -PathType Container) {}
	else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ffmpegPath -PathType Leaf) {}
	else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ytdlPath -PathType Leaf) {}
	else { Write-Error 'youtube-dlが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:confFile -PathType Leaf) {}
	else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:keywordFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ignoreFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:listFilePath -PathType Leaf) {}
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
			Write-ColorOutput '日本のIPアドレスからしか接続できません。VPN接続してください。' Green
			exit 1
		}
	} catch { Write-ColorOutput 'Geo IPのチェックに失敗しました' Green }
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
		while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
			Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:purgedList = ((Import-Csv $script:listFilePath -Encoding UTF8).Where({ $_.downloadDate -gt $(Get-Date).AddDays(-30) }))
		$local:purgedList `
		| Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8
	} catch { Write-ColorOutput 'リストのクリーンアップに失敗しました' Green
	} finally { $null = fileUnlock ($script:lockFilePath) }
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
		while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
			Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
			Start-Sleep -Seconds 1
		}

		#ファイル操作
		#無視されたもの
		$local:ignoredList = ((Import-Csv $script:listFilePath -Encoding UTF8).Where({ $_.videoPath -eq '-- IGNORED --' }))

		#無視されなかったものの重複削除。ファイル名で1つしかないもの残す
		$local:processedList = (Import-Csv $script:listFilePath -Encoding UTF8 `
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
		$mergedList `
		| Sort-Object -Property downloadDate `
		| Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8

	} catch { Write-ColorOutput 'リストの更新に失敗しました' Green
	} finally { $null = fileUnlock ($script:lockFilePath) }
}

#----------------------------------------------------------------------
#ビデオの整合性チェック
#----------------------------------------------------------------------
function checkVideo ($local:decodeOption, $local:videoFileRelativePath) {
	$local:errorCount = 0
	$local:checkStatus = 0
	$local:videoFilePath = Join-Path $script:downloadBaseDir $local:videoFileRelativePath
	try { $null = New-Item $script:ffpmegErrorLogPath -Type File -Force }
	catch { Write-ColorOutput 'ffmpegエラーファイルを初期化できませんでした' Green ; return }
	
	#これからチェックする動画のステータスをチェック
	try {
		#ロックファイルをロック
		while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
			Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$local:videoLists = Import-Csv $script:listFilePath -Encoding UTF8
		$local:checkStatus = $(($local:videoLists).Where({ $_.videoPath -eq $local:videoFileRelativePath })).videoValidated
	} catch {
		Write-ColorOutput "チェックステータスを取得できませんでした: $local:videoFileRelativePath" Green
		return
	} finally { $null = fileUnlock ($script:lockFilePath) }

	#0:未チェック、1:チェック済み、2:チェック中
	if ($local:checkStatus -eq 2 ) { Write-ColorOutput '  └他プロセスでチェック中です' DarkGray ; return }
	elseif ($local:checkStatus -eq 1 ) { Write-ColorOutput '  └他プロセスでチェック済です' DarkGray ; return }
	else {
		#該当のビデオのチェックステータスを"2"にして後続のチェックを実行
		try {
			$(($local:videoLists).Where({ $_.videoPath -eq $local:videoFileRelativePath })).videoValidated = '2'
		} catch {
			Write-ColorOutput "該当のレコードが見つかりませんでした: $local:videoFileRelativePath" Green
			return
		}
		try {
			#ロックファイルをロック
			while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
				Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:videoLists `
			| Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8
		} catch {
			Write-ColorOutput "録画リストを更新できませんでした: $local:videoFileRelativePath" Green
			return
		} finally { $null = fileUnlock ($script:lockFilePath) }
	}

	$local:checkFile = '"' + $local:videoFilePath + '"'
	$local:ffmpegArgs = "$local:decodeOption " `
		+ ' -hide_banner -v error -xerror' `
		+ " -i $local:checkFile -f null - "

	Write-Debug "ffmpeg起動コマンド:$script:ffmpegPath $local:ffmpegArgs"
	try {
		if ($script:isWin) {
			$local:proc = Start-Process -FilePath $script:ffmpegPath `
				-ArgumentList ($local:ffmpegArgs) `
				-PassThru `
				-WindowStyle $script:windowShowStyle `
				-RedirectStandardError $script:ffpmegErrorLogPath `
				-Wait
		} else {
			$local:proc = Start-Process -FilePath $script:ffmpegPath `
				-ArgumentList ($local:ffmpegArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError $script:ffpmegErrorLogPath `
				-Wait
		}
	} catch { Write-Error 'ffmpegを起動できませんでした' ; return }

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			$local:errorCount = (Get-Content -LiteralPath $script:ffpmegErrorLogPath `
				| Measure-Object -Line).Lines
			Get-Content -LiteralPath $script:ffpmegErrorLogPath -Encoding UTF8 `
			| ForEach-Object { Write-Debug "$_" }
		}
	} catch { Write-ColorOutput 'ffmpegエラーの数をカウントできませんでした' Green ; $local:errorCount = 9999999 }

	#エラーをカウントしたらファイルを削除
	try {
		if (Test-Path $script:ffpmegErrorLogPath) {
			Remove-Item `
				-LiteralPath $script:ffpmegErrorLogPath `
				-Force -ErrorAction SilentlyContinue
		}
	} catch { Write-ColorOutput 'ffmpegエラーファイルを削除できませんでした' Green }

	if ($local:proc.ExitCode -ne 0 -or $local:errorCount -gt 30) {
		#終了コードが"0"以外 または エラーが30行以上 は録画リストとファイルを削除
		Write-ColorOutput "$local:videoFileRelativePath"
		Write-ColorOutput "  exit code: $($local:proc.ExitCode)    error count: $local:errorCount" Green

		#破損している動画ファイルを録画リストから削除
		try {
			#ロックファイルをロック
			while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
				Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			(Select-String `
				-Pattern $local:videoFileRelativePath `
				-LiteralPath $script:listFilePath `
				-Encoding UTF8 -SimpleMatch -NotMatch).Line `
			| Out-File $script:listFilePath -Encoding UTF8
		} catch { Write-ColorOutput "録画リストの更新に失敗しました: $local:videoFileRelativePath" Green
		} finally { $null = fileUnlock ($script:lockFilePath) }

		#破損している動画ファイルを削除
		try {
			Remove-Item `
				-LiteralPath $local:videoFilePath `
				-Force -ErrorAction SilentlyContinue
		} catch { Write-ColorOutput "ファイル削除できませんでした: $local:videoFilePath" Green }
	} else {
		#終了コードが"0"のときは録画リストにチェック済みフラグを立てる
		try {
			#ロックファイルをロック
			while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
				Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$local:videoLists = Import-Csv $script:listFilePath -Encoding UTF8
			#該当のビデオのチェックステータスを"1"に
			$(($local:videoLists).Where({ $_.videoPath -eq $local:videoFileRelativePath })).videoValidated = '1'
			$local:videoLists `
			| Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8
		} catch { Write-ColorOutput "録画リストを更新できませんでした: $local:videoFileRelativePath" Green
		} finally { $null = fileUnlock ($script:lockFilePath) }
	}

}

#----------------------------------------------------------------------
#youtube-dlプロセスの確認と待機
#----------------------------------------------------------------------
function waitTillYtdlProcessGetFewer ($local:parallelDownloadFileNum) {
	#youtube-dlのプロセスが設定値を超えたら一時待機
	try {
		if ($script:isWin) {
			$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2
		} elseif ($IsLinux) {
			$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		} elseif ($IsMacOS) {
			$local:psCmd = 'ps'
			$local:ytdlCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).Trim()
		} else {
			$local:ytdlCount = 0
		}
	} catch {
		$local:ytdlCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)"

	while ([int]$local:ytdlCount -ge [int]$local:parallelDownloadFileNum) {
		Write-ColorOutput "ダウンロードが $local:parallelDownloadFileNum 多重に達したので一時待機します。 ($(getTimeStamp))" DarkGray
		Start-Sleep -Seconds 60			#1分待機
		try {
			if ($script:isWin) {
				$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2
			} elseif ($IsLinux) {
				$local:ytdlCount = (& Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			} elseif ($IsMacOS) {
				$local:ytdlCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).Trim()
			} else {
				$local:ytdlCount = 0
			}
		} catch {
			$local:ytdlCount = 0			#プロセス数が取れなくてもとりあえず先に進む
		}
	}
}

#----------------------------------------------------------------------
#youtube-dlのプロセスが終わるまで待機
#----------------------------------------------------------------------
function waitTillYtdlProcessIsZero () {
	try {
		if ($script:isWin) {
			$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2		
  } elseif ($IsLinux) {
			$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		} elseif ($IsMacOS) {
			$local:psCmd = 'ps'
			$local:ytdlCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).Trim()
		} else {
			$local:ytdlCount = 0
		}
	} catch {
		$local:ytdlCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	while ($local:ytdlCount -ne 0) {
		try {
			Write-Verbose "現在のダウンロードプロセス一覧 ($local:ytdlCount 個)" DarkGray
			Start-Sleep -Seconds 60			#1分待機
			if ($script:isWin) {
				$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2
			} elseif ($IsLinux) {
				$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			} elseif ($IsMacOS) {
				$local:ytdlCount = (& $local:psCmd | & grep yt-dlp | grep -v grep | wc -l).Trim()
			} else {
				$local:ytdlCount = 0
			}
		} catch {
			$local:ytdlCount = 0
		}
	}
}

#----------------------------------------------------------------------
#youtube-dlプロセスの起動
#----------------------------------------------------------------------
function executeYtdl ($local:videoPageURL) {
	$local:tmpDir = '"temp:' + $script:downloadWorkDir + '"'
	$local:saveDir = '"home:' + $script:videoFileDir + '"'
	$local:subttlDir = '"subtitle:' + $script:downloadWorkDir + '"'
	$local:thumbDir = '"thumbnail:' + $script:downloadWorkDir + '"'
	$local:chaptDir = '"chapter:' + $script:downloadWorkDir + '"'
	$local:descDir = '"description:' + $script:downloadWorkDir + '"'
	$local:saveFile = '"' + $videoName + '"'

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
	$local:ytdlArgs += ' --xattr-set-filesize'
	$local:ytdlArgs += ' --newline'
	$local:ytdlArgs += ' --print-traffic'
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
	$local:ytdlArgs += " -o $local:saveFile"
	$local:ytdlArgs += " $local:videoPageURL"

	if ($script:isWin) {
		try {
			Write-Debug "youtube-dl起動コマンド:$script:ytdlPath $local:ytdlArgs"
			$null = Start-Process -FilePath $script:ytdlPath `
				-ArgumentList $local:ytdlArgs `
				-PassThru `
				-WindowStyle $script:windowShowStyle
		} catch { Write-Error 'youtube-dlの起動に失敗しました' ; return }
	} else {
		Write-Debug "y起動コマンド:nohup $script:ytdlPath $local:ytdlArgs"
		try {
			$null = Start-Process -FilePath nohup `
				-ArgumentList ($script:ytdlPath, $local:ytdlArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null
		} catch { Write-Error 'youtube-dlの起動に失敗しました' ; return }
	}
}

#----------------------------------------------------------------------
#ビデオ情報表示
#----------------------------------------------------------------------
function showVideoInfo ($local:videoName, $local:broadcastDate, $local:mediaName, $local:descriptionText) {
	Write-ColorOutput "ビデオ名    :$local:videoName" DarkGray
	Write-ColorOutput "放送日      :$local:broadcastDate" DarkGray
	Write-ColorOutput "テレビ局    :$local:mediaName" DarkGray
	Write-ColorOutput "ビデオ説明  :$local:descriptionText" DarkGray
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
#タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
function trimTabSpace ($local:text) {
	return $local:text.Replace("`t", ' ').Replace('  ', ' ')
}

#----------------------------------------------------------------------
#キーワードの後にあるコメントを削除しキーワードのみ抽出
#----------------------------------------------------------------------
function removeCommentsFromKeyword ($local:keyword) {
	return $local:keyword.Split("`t")[0].Split(' ')[0].Split('#')[0]
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
	$local:fileNameLimit = $script:fileNameLengthMax - 25	#youtube-dlの中間ファイル等を考慮して安全目の上限値
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
		Write-ColorOutput "$($local:Path)を処理中"
		$local:delTargets = @()
		foreach ($local:filter in $local:Conditions.Split(',').Trim()) {
			$local:delTargets += Get-ChildItem -LiteralPath $local:Path `
				-Recurse -File -Filter $local:filter
		}
		if ($null -ne $local:delTargets) {
			foreach ($local:delTarget in $local:delTargets) {
				Write-ColorOutput "$($local:delTarget.FullName)を削除します"
				Remove-Item -LiteralPath $local:delTarget.FullName `
					-Force -ErrorAction SilentlyContinue
			}
		} else { Write-ColorOutput '削除対象はありませんでした' DarkGray }
	} catch { Write-ColorOutput '削除できないファイルがありました' Green }
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

function Write-ColorOutput {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $False, Position = 1, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)][Object] $Object,
		[Parameter(Mandatory = $False, Position = 2, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)][ConsoleColor] $foregroundColor,
		[Parameter(Mandatory = $False, Position = 3, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)][ConsoleColor] $backgroundColor
	)

	# Save previous colors
	$prevForegroundColor = $host.UI.RawUI.ForegroundColor
	$prevBackgroundColor = $host.UI.RawUI.BackgroundColor

	# Set colors if available
	if ($BackgroundColor -ne $null) { $host.UI.RawUI.BackgroundColor = $backgroundColor }
	if ($ForegroundColor -ne $null) { $host.UI.RawUI.ForegroundColor = $foregroundColor }

	# Always write (if we want just a NewLine)
	if ($null -eq $Object) { $Object = '' }

	Write-Output $Object

	# Restore previous colors
	$host.UI.RawUI.ForegroundColor = $prevForegroundColor
	$host.UI.RawUI.BackgroundColor = $prevBackgroundColor
}