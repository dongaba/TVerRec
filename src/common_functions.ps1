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
	if ($PSVersionTable.PSEdition -eq 'Desktop') { . '.\update_yt-dlp_5.ps1' }
	else { . '.\update_yt-dlp.ps1' }
}

#----------------------------------------------------------------------
#ffmpegの最新化確認
#----------------------------------------------------------------------
function checkLatestFfmpeg {
	if ($PSVersionTable.PSEdition -eq 'Desktop') { . '.\update_ffmpeg_5.ps1' }
	else { . '.\update_ffmpeg.ps1' }
}

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	if (Test-Path $downloadBaseDir -PathType Container) {}
	else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ffmpegPath -PathType Leaf) {}
	else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ytdlpPath -PathType Leaf) {}
	else { Write-Error 'yt-dlpが存在しません。終了します。' ; exit 1 }
	if (Test-Path $confFile -PathType Leaf) {}
	else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $keywordFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ignoreFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $listFilePath -PathType Leaf) {}
	else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit 1 }
}

#----------------------------------------------------------------------
#GEO IPの確認
#----------------------------------------------------------------------
function checkGeoIP {
	try {
		if ((Invoke-RestMethod -Uri 'http://ip-api.com/json/').countryCode -ne 'JP') {
			Invoke-RestMethod -Uri ( `
					'http://ip-api.com/json/' `
					+ (Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content
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
	return = Get-Date -UFormat '%Y-%m-%d %H:%M:%S' 
}

#----------------------------------------------------------------------
#30日以上前に処理したものはリストから削除
#----------------------------------------------------------------------
function purgeDB {
	try {
		#ロックファイルをロック
		while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$purgedList = ((Import-Csv $listFilePath -Encoding UTF8).Where({ $_.downloadDate -gt $(Get-Date).AddDays(-30) }))
		$purgedList | Export-Csv $listFilePath -NoTypeInformation -Encoding UTF8
	} catch { Write-Host 'リストのクリーンアップに失敗しました'
	} finally { $null = fileUnlock ($lockFilePath) }
}

#----------------------------------------------------------------------
#リストの重複削除
#----------------------------------------------------------------------
function uniqueDB {
	$processedList = $null
	$ignoredList = $null
	#無視されたもの
	try {
		#ロックファイルをロック
		while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}

		#ファイル操作
		#無視されたもの
		$ignoredList = ((Import-Csv $listFilePath -Encoding UTF8).`
				Where({ $_.videoPath -eq '-- IGNORED --' }))

		#無視されなかったものの重複削除。ファイル名で1つしかないもの残す
		$processedList = (Import-Csv $listFilePath -Encoding UTF8 | `
					Group-Object -Property 'videoPath' | `
					Where-Object count -EQ 1 | `
					Select-Object -ExpandProperty group)

		#無視されたものと無視されなかったものを結合し出力
		if ($null -eq $processedList -and $null -eq $ignoredList) { return } 
		elseif ($null -ne $processedList -and $null -eq $ignoredList) { $mergedList = $processedList }
		elseif ($null -eq $processedList -and $null -ne $ignoredList) { $mergedList = $ignoredList }
		else { $mergedList = $processedList + $ignoredList }
		$fileStatus = checkFileStatus $listFilePath
		Write-Host "Status of $listFilePath is $fileStatus"
		$mergedList | `
				Sort-Object -Property downloadDate | `
				Export-Csv $listFilePath -NoTypeInformation -Encoding UTF8

	} catch { Write-Host 'リストの更新に失敗しました'
	} finally { $null = fileUnlock ($lockFilePath) }
}

#----------------------------------------------------------------------
#ビデオの整合性チェック
#----------------------------------------------------------------------
function checkVideo ($decodeOption) {
	$errorCount = 0
	$checkStatus = 0
	$videoFilePath = Join-Path $downloadBaseDir $videoFileRelativePath
	try { $null = New-Item $ffpmegErrorLogPath -Type File -Force }catch {}
	
	#これからチェックする動画のステータスをチェック
	try {
		#ロックファイルをロック
		while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
			Write-Host 'ファイルのロック解除待ち中です'
			Start-Sleep -Seconds 1
		}
		#ファイル操作
		$videoLists = Import-Csv $listFilePath -Encoding UTF8
		$checkStatus = $(($videoLists).Where({ $_.videoPath -eq $videoFileRelativePath })).videoValidated
	} catch { Write-Host "チェックステータスを取得できませんでした: $videoFileRelativePath"; return 
	} finally { $null = fileUnlock ($lockFilePath) }

	#0:未チェック、1:チェック済み、2:チェック中
	if ($checkStatus -eq 2 ) { Write-Host '  └他プロセスでチェック中です'; return } 
	elseif ($checkStatus -eq 1 ) { Write-Host '  └他プロセスでチェック済です'; return } 
	else {
		#該当のビデオのチェックステータスを"2"にして後続のチェックを実行
		try {
			$(($videoLists).Where({ $_.videoPath -eq $videoFileRelativePath })).videoValidated = '2'
		} catch { Write-Host "該当のレコードが見つかりませんでした: $videoFileRelativePath"; return }
		try {
			#ロックファイルをロック
			while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$videoLists | Export-Csv $listFilePath -NoTypeInformation -Encoding UTF8
		} catch { Write-Host "録画リストを更新できませんでした: $videoFileRelativePath" ; return 
		} finally { $null = fileUnlock ($lockFilePath) }
	}

	$checkFile = '"' + $videoFilePath + '"'
	$ffmpegArgs = "$decodeOption " `
		+ ' -hide_banner -v error -xerror' `
		+ " -i $checkFile -f null - "

	Write-Debug "ffmpeg起動コマンド:$ffmpegPath $ffmpegArgs"
	try {
		if ($isWin) {
			$proc = Start-Process -FilePath $ffmpegPath `
				-ArgumentList ($ffmpegArgs) `
				-PassThru `
				-WindowStyle $windowShowStyle `
				-RedirectStandardError $ffpmegErrorLogPath `
				-Wait 
		} else {
			$proc = Start-Process -FilePath $ffmpegPath `
				-ArgumentList ($ffmpegArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError $ffpmegErrorLogPath `
				-Wait 
		}
	} catch {
		Write-Host 'ffmpegを起動できませんでした'
	}

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $ffpmegErrorLogPath) {
			$errorCount = (Get-Content -Path $ffpmegErrorLogPath | `
						Measure-Object -Line).Lines
			Get-Content -Path $ffpmegErrorLogPath -Encoding UTF8 |`
					ForEach-Object { Write-Debug "$_" }
		}
	} catch { Write-Host 'ffmpegエラーの数をカウントできませんでした' }

	#エラーをカウントしたらファイルを削除
	try {
		if (Test-Path $ffpmegErrorLogPath) {
			Remove-Item `
				-Path $ffpmegErrorLogPath `
				-Force `
				-ErrorAction SilentlyContinue
		}
	} catch {}

	if ($proc.ExitCode -ne 0 -or $errorCount -gt 30) {
		#終了コードが"0"以外 または エラーが30行以上 は録画リストとファイルを削除
		Write-Host "$videoFileRelativePath"
		Write-Host "  exit code: $($proc.ExitCode)    error count: $errorCount"

		#破損している動画ファイルを録画リストから削除
		try {
			#ロックファイルをロック
			while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			(Select-String `
				-Pattern $videoFileRelativePath `
				-Path $listFilePath `
				-Encoding UTF8 `
				-SimpleMatch -NotMatch).Line | `
					Out-File $listFilePath -Encoding UTF8
		} catch { Write-Host "録画リストの更新に失敗しました: $videoFileRelativePath" 
		} finally { $null = fileUnlock ($lockFilePath) }

		#破損している動画ファイルを削除
		try {
			Remove-Item `
				-Path $videoFilePath `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Write-Host "ファイル削除できませんでした: $videoFilePath" }
	} else {
		#終了コードが"0"のときは録画リストにチェック済みフラグを立てる
		try {
			#ロックファイルをロック
			while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
				Write-Host 'ファイルのロック解除待ち中です'
				Start-Sleep -Seconds 1
			}
			#ファイル操作
			$videoLists = Import-Csv $listFilePath -Encoding UTF8
			#該当のビデオのチェックステータスを"1"に
			$(($videoLists).Where({ $_.videoPath -eq $videoFileRelativePath })).videoValidated = '1'
			$videoLists | Export-Csv $listFilePath -NoTypeInformation -Encoding UTF8
		} catch { Write-Host "録画リストを更新できませんでした: $videoFileRelativePath" 
		} finally { $null = fileUnlock ($lockFilePath) }
	}

}

#----------------------------------------------------------------------
#yt-dlpプロセスの確認と待機
#----------------------------------------------------------------------
function waitTillYtdlpProcessGetFewer ($parallelDownloadFileNum) {
	#yt-dlpのプロセスが設定値を超えたら一時待機
	try {
		if ($isWin) {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2
		} elseif ($IsLinux) {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		} elseif ($IsMacOS) {
			$psCmd = 'ps'
			$ytdlpCount = (& $psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
		} else {
			$ytdlpCount = 0
		}
	} catch {
		$ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	Write-Verbose "現在のダウンロードプロセス一覧 ($ytdlpCount 個)"

	while ([int]$ytdlpCount -ge [int]$parallelDownloadFileNum) {
		Write-Host "ダウンロードが $parallelDownloadFileNum 多重に達したので一時待機します。 ($(getTimeStamp))"
		Start-Sleep -Seconds 60			#1分待機
		try {
			if ($isWin) {
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2
			} elseif ($IsLinux) {
				$ytdlpCount = (& Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			} elseif ($IsMacOS) {
				$psCmd = 'ps'
				$ytdlpCount = (& $psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
			} else {
				$ytdlpCount = 0
			}
		} catch {
			$ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
		}
	}
}

#----------------------------------------------------------------------
#yt-dlpのプロセスが終わるまで待機
#----------------------------------------------------------------------
function waitTillYtdlpProcessIsZero ($isWin) {
	try {
		if ($isWin) {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2
		} elseif ($IsLinux) {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		} elseif ($IsMacOS) {
			$psCmd = 'ps'
			$ytdlpCount = (& $psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
		} else {
			$ytdlpCount = 0
		}
	} catch {
		$ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	while ($ytdlpCount -ne 0) {
		try {
			Write-Verbose "現在のダウンロードプロセス一覧 ($ytdlpCount 個)"
			Start-Sleep -Seconds 60			#1分待機
			if ($isWin) {
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2
			} elseif ($IsLinux) {
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			} elseif ($IsMacOS) {
				$psCmd = 'ps'
				$ytdlpCount = (& $psCmd | & grep yt-dlp | grep -v grep | wc -l).trim()
			} else {
				$ytdlpCount = 0
			}
		} catch {
			$ytdlpCount = 0
		}
	}
}

#----------------------------------------------------------------------
#yt-dlpプロセスの起動
#----------------------------------------------------------------------
function executeYtdlp ($videoFilePath, $videoPageURL, $ytdlpPath) {
	$tmpDir = '"temp:' + $downloadWorkDir + '"'
	$saveDir = '"home:' + $videoFileDir + '"'
	$subttlDir = '"subtitle:' + $downloadWorkDir + '"'
	$thumbDir = '"thumbnail:' + $downloadWorkDir + '"'
	$chaptDir = '"chapter:' + $downloadWorkDir + '"'
	$descDir = '"description:' + $downloadWorkDir + '"'
	$saveFile = '"' + $videoName + '"'

	$ytdlpArgs = '--format mp4 --console-title --no-mtime'
	$ytdlpArgs += ' --retries 10 --fragment-retries 10'
	$ytdlpArgs += ' --abort-on-unavailable-fragment'
	$ytdlpArgs += ' --no-keep-fragments'
	$ytdlpArgs += ' --windows-filenames'
	$ytdlpArgs += ' --xattr-set-filesize'
	$ytdlpArgs += ' --newline --print-traffic'
	$ytdlpArgs += " --concurrent-fragments $parallelDownloadNumPerFile"
	$ytdlpArgs += ' --embed-thumbnail --embed-subs'
	$ytdlpArgs += ' --embed-metadata --embed-chapters'
	$ytdlpArgs += " --paths $saveDir --paths $tmpDir"
	$ytdlpArgs += " --paths $subttlDir --paths $thumbDir"
	$ytdlpArgs += " --paths $chaptDir --paths $descDir"
	$ytdlpArgs += " -o $saveFile $videoPageURL"

	if ($isWin) {
		try {
			Write-Debug "yt-dlp起動コマンド:$ytdlpPath $ytdlpArgs"
			$null = Start-Process -FilePath $ytdlpPath `
				-ArgumentList $ytdlpArgs `
				-PassThru `
				-WindowStyle $windowShowStyle
		} catch { Write-Host 'yt-dlpの起動に失敗しました' }
	} else {
		Write-Debug "yt-dlp起動コマンド:nohup $ytdlpPath $ytdlpArgs"
		try {
			$null = Start-Process -FilePath nohup `
				-ArgumentList ($ytdlpPath, $ytdlpArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null
		} catch { Write-Host 'yt-dlpの起動に失敗しました' }
	}
}

#----------------------------------------------------------------------
#ビデオ情報表示
#----------------------------------------------------------------------
function showVideoInfo ($videoName, $broadcastDate, $mediaName, $descriptionText) {
	Write-Host "ビデオ名    :$videoName"
	Write-Host "放送日      :$broadcastDate"
	Write-Host "テレビ局    :$mediaName"
	Write-Host "ビデオ説明  :$descriptionText"
}
#----------------------------------------------------------------------
#ビデオ情報デバッグ表示
#----------------------------------------------------------------------
function showVideoDebugInfo ($videoPageURL, $videoSeriesPageURL, $keywordName, $videoTitle, $videoSubtitle, $videoFilePath, $processedTime) {
	Write-Debug	"ビデオページ:$videoPageURL"
	Write-Debug	"ビデオLP    :$videoSeriesPageURL"
	Write-Debug "キーワード  :$keywordName"
	Write-Debug "タイトル    :$videoTitle"
	Write-Debug "サブタイトル:$videoSubtitle"
	Write-Debug "ファイル    :$videoFilePath"
	Write-Debug "取得日付    :$processedTime"
}

#----------------------------------------------------------------------
#ファイル名・フォルダ名に禁止文字の削除
#----------------------------------------------------------------------
function getFileNameWithoutInvalitChars {
	param(
		[Parameter(
			Mandatory = $true,
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
#全角→半角
#----------------------------------------------------------------------
function getNarrowChars {

	Param([string]$text)		#変換元テキストを引数に指定

	$wideKanaDaku = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ'
	$narrowKanaDaku = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ'
	$narrowWideKanaHanDaku = 'パピプペポ'
	$narrowWideKanaHanDaku = 'ﾊﾋﾌﾍﾎ'
	$wideKana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン゛゜ァィゥェォャュョッ'
	$narrowKana = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝﾞﾟｧｨｩｪｫｬｭｮｯ'
	$wideNum = '０１２３４５６７８９'
	$narrowNum = '0123456789'
	$wideAlpha = 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
	$narrowAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
	$wideSimbol = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：'
	$narrowSimbol = '@#$%^&*-+_/[]{}()<> \\";:'

	for ($i = 0; $i -lt $wideKanaDaku.Length; $i++) {
		$text = $text.Replace($narrowKanaDaku[$i] + 'ﾞ', $wideKanaDaku[$i])
	}
	for ($i = 0; $i -lt $narrowWideKanaHanDaku.Length; $i++) {
		$text = $text.Replace($narrowWideKanaHanDaku[$i] + 'ﾟ', $narrowWideKanaHanDaku[$i])
	}
	for ($i = 0; $i -lt $wideKana.Length; $i++) {
		$text = $text.Replace($narrowKana[$i], $wideKana[$i])
	}
	for ($i = 0; $i -lt $narrowNum.Length; $i++) {
		$text = $text.Replace($wideNum[$i], $narrowNum[$i])
	}
	for ($i = 0; $i -lt $narrowAlpha.Length; $i++) {
		$text = $text.Replace($wideAlpha[$i], $narrowAlpha[$i])
	}
	for ($i = 0; $i -lt $narrowSimbol.Length; $i++) {
		$text = $text.Replace($wideSimbol[$i], $narrowSimbol[$i])
	}
	return $text

}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
function getSpecialCharacterReplaced {
	Param([string]$text)		#変換元テキストを引数に指定
	$text = $text.Replace('&amp;', '&')
	$text = $text.Replace('"', '')
	$text = $text.Replace('“', '')
	$text = $text.Replace('”', '')
	$text = $text.Replace(',', '')
	$text = $text.Replace('?', '？')
	$text = $text.Replace('!', '！')
	$text = $text.Replace('/', '-')
	$text = $text.Replace('\', '-')
	return $text
}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function getVideoFileName ($videoTitle, $videoSubtitle, $broadcastDate) {
	Write-Verbose 'ビデオファイル名を整形します。'
	if ($videoSubtitle -eq '') {
		if ($broadcastDate -eq '') {
			$videoName = $videoTitle
		} else {
			$videoName = $videoTitle + ' ' + $broadcastDate
		}
	} else {
		$videoName = $videoTitle + ' ' + $broadcastDate + ' ' + $videoSubtitle
	}
	$videoName = getFileNameWithoutInvalitChars (getNarrowChars $videoName)		#ファイル名にできない文字列を除去

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	$videoNameTemp = ''
	$fileNameLimit = $fileNameLengthMax - 25					#yt-dlpの中間ファイル等を考慮して安全目の上限値
	$videoNameByte = [System.Text.Encoding]::UTF8.GetByteCount($videoName)

	#ファイル名を1文字ずつ増やしていき、上限に達したら残りは「……」とする
	if ($videoNameByte -gt $fileNameLimit) {
		for ($i = 1 ; [System.Text.Encoding]::UTF8.GetByteCount($videoNameTemp) -lt $fileNameLimit ; $i++) {
			$videoNameTemp = $videoName.Substring(0, $i)
		}
		$videoName = $videoNameTemp + '……'			#ファイル名省略の印
	}

	$videoName = $videoName + '.mp4'
	return $videoName
}

#----------------------------------------------------------------------
#ダウンロードが中断した際にできたゴミファイルは削除
#----------------------------------------------------------------------
function deleteTrashFiles ($Path, $Conditions) {
	try {
		Write-Host "$($Path)を処理中"
		$delTargets = Get-ChildItem `
			-Path $Path `
			-Recurse `
			-File `
			-Name `
			-Include $Conditions
		if ($null -ne $delTargets) {
			Write-Host "$($delTargets)を削除します"
			foreach ($delTarget in $delTargets) {
				Remove-Item `
					-Path $delTarget `
					-Force `
					-ErrorAction SilentlyContinue
			}
		} else {
			Write-Host '削除対象はありませんでした'
		}
	} catch { Write-Host '削除できないファイルがありました' }
}

#----------------------------------------------------------------------
#ファイルのロック
#----------------------------------------------------------------------
function fileLock {
	param (
		[parameter(position = 0, mandatory)][System.IO.FileInfo]$Path
	)
	try {
		$script:fileLocked = $false						# initialise variables
		$script:fileInfo = New-Object System.IO.FileInfo $Path		# attempt to open file and detect file lock
		$script:fileStream = $fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$script:fileLocked = $true						# initialise variables
	} catch {
		$fileLocked = $false		# catch fileStream had falied
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $Path
			fileLocked = $fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのアンロック
#----------------------------------------------------------------------
function fileUnlock {
	param (
		[parameter(position = 0, mandatory)][System.IO.FileInfo]$Path
	)
	try {
		if ($fileStream) { $fileStream.Close() }		# close stream if not lock
		$script:fileLocked = $false						# initialise variables
	} catch {
		$fileLocked = $true		# catch fileStream had falied
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $Path
			fileLocked = $fileLocked
		}
	}
}

#----------------------------------------------------------------------
#ファイルのロック確認
#----------------------------------------------------------------------
function isLocked {
	param (
		[parameter(position = 0, mandatory)][string]$isLockedPath
	)
	try {
		$script:isFileLocked = $false						# initialise variables
		$script:isLockedFileInfo = New-Object System.IO.FileInfo $isLockedPath		# attempt to open file and detect file lock
		$script:isLockedfileStream = $isLockedFileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		if ($isLockedfileStream) { $isLockedfileStream.Close() }		# close stream if not lock
		$script:isFileLocked = $false						# initialise variables
	} catch {
		$isFileLocked = $true		# catch fileStream had falied
	} finally {
		# return result
		[PSCustomObject]@{
			path       = $isLockedPath
			fileLocked = $isFileLocked
		}
	}
}
