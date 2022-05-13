###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		共通関数スクリプト
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
#ytdlの最新化確認
#----------------------------------------------------------------------
function checkLatestYtdl {
	$progressPreference = 'silentlyContinue'
	if ($script:disableUpdateYoutubedl -eq $false) {
		if ($PSVersionTable.PSEdition -eq 'Desktop') {
			. $(Convert-Path (Join-Path $scriptRoot '.\functions\update_ytdl-patched_5.ps1'))
		} else {
			. $(Convert-Path (Join-Path $scriptRoot '.\functions\update_ytdl-patched.ps1'))
		}
		if ($? -eq $false) { Write-Error 'youtube-dlの更新に失敗しました' ; exit 1 }
	} else { }
	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	$progressPreference = 'silentlyContinue'
	if ($script:disableUpdateFfmpeg -eq $false) {
		if ($PSVersionTable.PSEdition -eq 'Desktop') {
			. $(Convert-Path (Join-Path $scriptRoot '.\functions\update_ffmpeg_5.ps1'))
		} else {
			. $(Convert-Path (Join-Path $scriptRoot '.\functions\update_ffmpeg.ps1'))
		}
		if ($? -eq $false) { Write-Error 'ffmpegの更新に失敗しました' ; exit 1 }
	} else { }
	$progressPreference = 'Continue'
}

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	if (Test-Path $script:downloadBaseDir -PathType Container) { }
	else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ffmpegPath -PathType Leaf) { }
	else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ffprobePath -PathType Leaf) { }
	elseif ($script:simplifiedValidation -eq $true) { Write-Error 'ffprobeが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ytdlPath -PathType Leaf) { }
	else { Write-Error 'youtube-dlが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:confFile -PathType Leaf) { }
	else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:keywordFilePath -PathType Leaf) { }
	else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:ignoreFilePath -PathType Leaf) { }
	else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $script:listFilePath -PathType Leaf) { }
	else { Copy-Item -Path $script:listFileBlankPath -Destination $script:listFilePath -Force }
	if (Test-Path $script:listFilePath -PathType Leaf) { }
	else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit 1 }
}

#----------------------------------------------------------------------
#GEO IPの確認
#----------------------------------------------------------------------
function checkGeoIP {
	try {
		if ((Invoke-RestMethod -Uri 'https://ipapi.co/json/').country_code -ne 'JP') {
			Invoke-RestMethod -Uri 'https://ipapi.co/json/'
			Write-ColorOutput '日本のIPアドレスからしか接続できません。VPN接続を検討してください。' Green
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
		$local:purgedList = ((Import-Csv $script:listFilePath -Encoding UTF8).Where({ [DateTime]$_.downloadDate -gt $(Get-Date).AddDays(-30) }))
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
		collectStat 'validate'
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

	if ($script:simplifiedValidation -eq $true) {
		#ffprobeを使った簡易検査
		$local:ffprobeArgs = ' -hide_banner -v error -err_detect explode' `
			+ " -i $local:checkFile "

		Write-Debug "ffprobe起動コマンド:$script:ffprobePath $local:ffprobeArgs"
		try {
			if ($script:isWin) {
				$local:proc = Start-Process -FilePath $script:ffprobePath `
					-ArgumentList ($local:ffprobeArgs) `
					-PassThru `
					-WindowStyle $script:windowShowStyle `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			} else {
				$local:proc = Start-Process -FilePath $script:ffprobePath `
					-ArgumentList ($local:ffprobeArgs) `
					-PassThru `
					-RedirectStandardOutput /dev/null `
					-RedirectStandardError $script:ffpmegErrorLogPath `
					-Wait
			}
		} catch { Write-Error 'ffprobeを起動できませんでした' ; return }
	} else {
		#ffmpegeを使った完全検査
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
	}

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
			$local:ytdlCount = [Math]::Round( `
				(Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, `
					[MidpointRounding]::AwayFromZero `
			)
		} elseif ($IsLinux) {
			$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count
		} elseif ($IsMacOS) {
			$local:psCmd = 'ps'
			$local:ytdlCount = (& $local:psCmd | & grep youtube-dl | grep -v grep | grep -c ^).Trim()
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
				$local:ytdlCount = [Math]::Round( `
					(Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, `
						[MidpointRounding]::AwayFromZero `
				)
			} elseif ($IsLinux) {
				$local:ytdlCount = (& Get-Process -ErrorAction Ignore -Name youtube-dl).Count
			} elseif ($IsMacOS) {
				$local:ytdlCount = (& $local:psCmd | & grep youtube-dl | grep -v grep | grep -c ^).Trim()
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
			$local:ytdlCount = [Math]::Round( `
				(Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, `
					[MidpointRounding]::AwayFromZero `
			)
		} elseif ($IsLinux) {
			$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count
		} elseif ($IsMacOS) {
			$local:psCmd = 'ps'
			$local:ytdlCount = (& $local:psCmd | & grep youtube-dl | grep -v grep | grep -c ^).Trim()
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
				$local:ytdlCount = [Math]::Round( `
					(Get-Process -ErrorAction Ignore -Name youtube-dl).Count / 2, `
						[MidpointRounding]::AwayFromZero `
				)
			} elseif ($IsLinux) {
				$local:ytdlCount = (Get-Process -ErrorAction Ignore -Name youtube-dl).Count
			} elseif ($IsMacOS) {
				$local:ytdlCount = (& $local:psCmd | & grep youtube-dl | grep -v grep | grep -c ^).Trim()
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
	collectStat 'download'

	$local:tmpDir = '"temp:' + $script:downloadWorkDir + '"'
	$local:saveDir = '"home:' + $script:videoFileDir + '"'
	$local:subttlDir = '"subtitle:' + $script:downloadWorkDir + '"'
	$local:thumbDir = '"thumbnail:' + $script:downloadWorkDir + '"'
	$local:chaptDir = '"chapter:' + $script:downloadWorkDir + '"'
	$local:descDir = '"description:' + $script:downloadWorkDir + '"'
	$local:saveFile = '"' + $script:videoName + '"'

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
			ValueFromPipeline = $false,
			ValueFromPipelineByPropertyName = $false)]
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
	if ($local:videoName.Contains('.mp4') -eq $false) {
		Write-Error '動画ファイル名の設定がおかしいです'
	}
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

#----------------------------------------------------------------------
#色付きWrite-Output
#----------------------------------------------------------------------
function Write-ColorOutput {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $false, ValueFromPipelinebyPropertyName = $false)][Object] $Object,
		[Parameter(Mandatory = $false, Position = 2, ValueFromPipeline = $false, ValueFromPipelinebyPropertyName = $false)][ConsoleColor] $foregroundColor,
		[Parameter(Mandatory = $false, Position = 3, ValueFromPipeline = $false, ValueFromPipelinebyPropertyName = $false)][ConsoleColor] $backgroundColor
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

#----------------------------------------------------------------------
#Windows Application ID取得
#----------------------------------------------------------------------
function Get-WindowsAppId {
	if ($PSEdition -eq 'Desktop') {
		(Get-StartApps -Name 'PowerShell').where({ $_.Name -eq 'Windows PowerShell' }).AppId
	} elseif ($PSVersionTable.PSVersion -ge [Version]'6.0') {
		Import-Module StartLayout -SkipEditionCheck
		(Get-StartApps -Name 'PowerShell').where({ $_.Name -like 'PowerShell*' })[0].AppId
	} else { '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe' }
}

#----------------------------------------------------------------------
#トースト表示
#----------------------------------------------------------------------
function ShowToast {
	[CmdletBinding()]
	PARAM (
		[Parameter(Mandatory = $true)][String] $local:toastText1,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String] $local:toastText2,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String] $local:toastDuration,
		[Parameter(Mandatory = $false)][Boolean] $local:toastSilent
	)

	if ($script:isWin) {
		if ($local:toastSilent) { $local:toastSoundElement = '<audio silent="true" />' }
		else { $local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
		if (!($local:toastDuration)) { $local:toastDuration = 'short' }
		$local:toastTitle = $script:appName
		$local:toastAttribution = ''
		$local:toastAppLogo = $script:toastAppLogo

		if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
			if ($PSEdition -eq 'Core') {
				#For PowerShell Core v6.x & PowerShell v7+
				Add-Type -Path (Join-Path $script:libDir 'win\core\Microsoft.Windows.SDK.NET.dll')
				Add-Type -Path (Join-Path $script:libDir 'win\core\WinRT.Runtime.dll')
				Add-Type -Path (Join-Path $script:libDir 'win\core\Microsoft.Toolkit.Uwp.Notifications.dll')
			} else {
				#For Windows PowerShell and Windows PowerShell_ISE
				Add-Type -Path (Join-Path $script:libDir 'win\desktop\Microsoft.Toolkit.Uwp.Notifications.dll')
			}
		}

		$local:toastProgressContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$($local:toastDuration)">
	<visual>
		<binding template="ToastGeneric">
			<text>$($local:toastTitle)</text>
			<text>$($local:toastText1)</text>
			<text>$($local:toastText2)</text>
			<image placement="appLogoOverride" hint-crop="circle" src="$($local:toastAppLogo)"/>
			<text placement="attribution">$($local:toastAttribution)</text>
		</binding>
	</visual>
	$local:toastSoundElement
</toast>
"@

		$local:appID = Get-WindowsAppId
		$local:toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
		$local:toastXML.LoadXml($script:toastProgressContent)
		$local:toastBody = New-Object Windows.UI.Notifications.ToastNotification $local:toastXML
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Show($local:toastBody)
	}
}


#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------
function ShowProgressToast {
	[CmdletBinding()]
	PARAM (
		[Parameter(Mandatory = $true)][String] $local:toastText1,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String] $local:toastText2,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String] $local:toastWorkDetail,
		[Parameter(Mandatory = $true)][String] $local:toastTag,
		[Parameter(Mandatory = $true)][String] $local:toastGroup,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String] $local:toastDuration,
		[Parameter(Mandatory = $false)][Boolean] $local:toastSilent
	)

	if ($script:isWin) {
		if ($local:toastSilent) { $local:toastSoundElement = '<audio silent="true" />' }
		else { $local:toastSoundElement = '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
		if (!($local:toastDuration)) { $local:toastDuration = 'short' }
		$local:toastTitle = $script:appName
		$local:toastAttribution = ''
		$local:toastAppLogo = $script:toastAppLogo

		if (-not ('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type])) {
			if ($PSEdition -eq 'Core') {
				#For PowerShell Core v6.x & PowerShell v7+
				Add-Type -Path (Join-Path $script:libDir 'win\core\Microsoft.Windows.SDK.NET.dll')
				Add-Type -Path (Join-Path $script:libDir 'win\core\WinRT.Runtime.dll')
				Add-Type -Path (Join-Path $script:libDir 'win\core\Microsoft.Toolkit.Uwp.Notifications.dll')
			} else {
				#For Windows PowerShell and Windows PowerShell_ISE
				Add-Type -Path (Join-Path $script:libDir 'win\desktop\Microsoft.Toolkit.Uwp.Notifications.dll')
			}
		}

		$local:toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$($local:toastDuration)">
	<visual>
		<binding template="ToastGeneric">
			<text>$($local:toastTitle)</text>
			<text>$($local:toastText1)</text>
			<text>$($local:toastText2)</text>
			<image placement="appLogoOverride" hint-crop="circle" src="$($local:toastAppLogo)"/>
			<progress value="{progressValue}" title="{progressTitle}" valueStringOverride="{progressValueString}" status="{progressStatus}" />
			<text placement="attribution">$($local:toastAttribution)</text>
		</binding>
	</visual>
	$local:toastSoundElement
</toast>
"@

		$local:appID = Get-WindowsAppId
		$local:toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
		$local:toastXML.LoadXml($local:toastContent)
		$local:toast = New-Object Windows.UI.Notifications.ToastNotification $local:toastXML
		$local:toast.Tag = $local:toastTag
		$local:toast.Group = $local:toastGroup
		$local:toastData = New-Object 'system.collections.generic.dictionary[string,string]'
		$local:toastData.add('progressTitle', $local:toastWorkDetail)
		$local:toastData.add('progressValue', '')
		$local:toastData.add('progressValueString', '')
		$local:toastData.add('progressStatus', '')
		$local:toast.Data = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
		$local:toast.Data.SequenceNumber = 1
		$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Show($local:toast)
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------
function UpdateProgessToast {
	[CmdletBinding()]
	PARAM (
		[Parameter(Mandatory = $true)][String] $local:toastProgressTitle,
		[Parameter(Mandatory = $true)][String] $local:toastProgressRatio,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String] $local:toastLeftText,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String] $local:toastRrightText,
		[Parameter(Mandatory = $true)][String] $local:toastTag,
		[Parameter(Mandatory = $true)][String] $local:toastGroup
	)

	if ($script:isWin) {
		$local:appID = Get-WindowsAppId
		$local:toastData = New-Object 'system.collections.generic.dictionary[string,string]'
		$local:toastData.add('progressTitle', $local:toastProgressTitle)
		$local:toastData.add('progressValue', $local:toastProgressRatio)
		$local:toastData.add('progressValueString', $local:toastRrightText)
		$local:toastData.add('progressStatus', $local:toastLeftText)
		$local:toastProgressData = [Windows.UI.Notifications.NotificationData]::new($local:toastData)
		$local:toastProgressData.SequenceNumber = 2
		[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($local:appID).Update($local:toastProgressData, $local:toastTag , $local:toastGroup)
	}
}