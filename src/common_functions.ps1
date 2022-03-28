###################################################################################
#  TVerRec : TVerビデオダウンローダ
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
#ツールの最新化確認
#----------------------------------------------------------------------
function checkLatestTool {
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. '.\update_ffmpeg_5.ps1'				#ffmpegの最新化チェック
		. '.\update_yt-dlp_5.ps1'				#yt-dlpの最新化チェック
	} else {
		. '.\update_ffmpeg.ps1'				#ffmpegの最新化チェック
		. '.\update_yt-dlp.ps1'				#yt-dlpの最新化チェック
	}
}

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile {
	if (Test-Path $downloadBaseAbsoluteDir -PathType Container) {}
	else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ffmpegRelativePath -PathType Leaf) {}
	else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ytdlpRelativePath -PathType Leaf) {}
	else { Write-Error 'yt-dlpが存在しません。終了します。' ; exit 1 }
	if (Test-Path $confFile -PathType Leaf) {}
	else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $keywordFileRelativePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ignoreFileRelativePath -PathType Leaf) {}
	else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $listFileRelativePath -PathType Leaf) {}
	else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit 1 }
}

#----------------------------------------------------------------------
#GEO IPの確認
#----------------------------------------------------------------------
function checkGeoIP {
	try {
		if ((Invoke-RestMethod -Uri 'http://ip-api.com/json/').countryCode -ne 'JP') {
			Invoke-RestMethod -Uri ('http://ip-api.com/json/' + (Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content)
			Write-Host '日本のIPアドレスからしか接続できません。VPN接続してください。' -ForegroundColor Green
			exit 1
		}
	} catch {}
}

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function getTimeStamp {
	$processedTime = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
	return $processedTime
}

#----------------------------------------------------------------------
#30日以上前に処理したものはリストから削除
#----------------------------------------------------------------------
function purgeDB {
	try {
		$purgedList = ((Import-Csv $listFileRelativePath -Encoding UTF8).Where({ $_.downloadDate -gt $(Get-Date).AddDays(-30) }))
		$purgedList | Export-Csv $listFileRelativePath -NoTypeInformation -Encoding UTF8
	} catch { Write-Host 'リストのクリーンアップに失敗しました' }
}

#----------------------------------------------------------------------
#リストの重複削除
#----------------------------------------------------------------------
function uniqueDB {
	#無視されたもの
	try {
		$ignoredList = ((Import-Csv $listFileRelativePath -Encoding UTF8).Where({ $_.videoPath -eq '-- IGNORED --' }))
	} catch { Write-Host 'リストの読み込みに失敗しました' }

	#無視されなかったものの重複削除。ファイル名で1つしかないもの残す
	try {
		$processedList = (Import-Csv $listFileRelativePath -Encoding UTF8 | `
					Group-Object -Property 'videoPath' | `
					Where-Object count -EQ 1 | `
					Select-Object -ExpandProperty group)
	} catch { Write-Host 'リストの読み込みに失敗しました' }

	#無視されたものと無視されなかったものを結合し出力
	if ($null -eq $processedList -and $null -eq $ignoredList) {

	} elseif ($null -ne $processedList -and $null -eq $ignoredList) {
		$mergedList = $processedList
	} elseif ($null -eq $processedList -and $null -ne $ignoredList) {
		$mergedList = $ignoredList
	} else {
		$mergedList = $processedList + $ignoredList
	}
	try {
		$mergedList | Sort-Object -Property downloadDate | `
				Export-Csv $listFileRelativePath -NoTypeInformation -Encoding UTF8
	} catch { Write-Host 'リストの更新に失敗しました' }
}

#----------------------------------------------------------------------
#ビデオの整合性チェック
#----------------------------------------------------------------------
function checkVideo ($decodeOption) {
	$errorCount = 0
	$checkFile = '"' + $videoFileAbsolutePath + '"'
	$ffmpegArgs = "$decodeOption "
	$ffmpegArgs += ' -hide_banner -v error -xerror'
	$ffmpegArgs += " -i $checkFile -f null - "

	Write-Debug "ffmpeg起動コマンド:$ffmpegRelativePath $ffmpegArgs"
	try {
		if ($isWin) {
			$proc = Start-Process -FilePath $ffmpegRelativePath `
				-ArgumentList ($ffmpegArgs) `
				-PassThru `
				-WindowStyle $windowShowStyle `
				-RedirectStandardError $ffpmegErrorLogRelativePath `
				-Wait 
		} else {
			$proc = Start-Process -FilePath $ffmpegRelativePath `
				-ArgumentList ($ffmpegArgs) `
				-PassThru `
				-RedirectStandardOutput /dev/null `
				-RedirectStandardError $ffpmegErrorLogRelativePath `
				-Wait 
		}
	} catch {
		Write-Host 'ffmpegを起動できませんでした'
	}

	#ffmpegが正常終了しても、大量エラーが出ることがあるのでエラーをカウント
	try {
		if (Test-Path $ffpmegErrorLogRelativePath) {
			$errorCount = (Get-Content -Path $ffpmegErrorLogRelativePath | `
						Measure-Object -Line).Lines
			Get-Content -Path $ffpmegErrorLogRelativePath -Encoding UTF8 |`
					ForEach-Object { Write-Debug "$_" }
		}
	} catch { Write-Host 'ffmpegエラーの数をカウントできませんでした' }
	try {
		Remove-Item `
			-Path $ffpmegErrorLogRelativePath `
			-Force `
			-ErrorAction SilentlyContinue
	} catch { Write-Host 'ffmpegエラーファイルを削除できませんでした' }

	if ($proc.ExitCode -ne 0 -or $errorCount -gt 30) {
		#終了コードが"0"以外 または エラーが30行以上 は録画リストとファイルを削除
		Write-Host "$videoFileAbsolutePath"
		Write-Host "  exit code: $proc.ExitCode"
		Write-Host "  error count: $errorCount"
		#破損している動画ファイルを録画リストから削除
		try {
			(Select-String -Pattern $videoFileAbsolutePath `
				-Path $listFileRelativePath `
				-Encoding UTF8 `
				-SimpleMatch -NotMatch).Line | `
					Out-File $listFileRelativePath -Encoding UTF8 -Force
		} catch { Write-Host "録画リストの更新に失敗しました: $videoFileAbsolutePath" }
		#破損している動画ファイルを削除
		try {
			Remove-Item `
				-Path $videoFileAbsolutePath `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Write-Host "ファイル削除できませんでした: $videoFileAbsolutePath" }
	} else {
		#終了コードが"0"のときは録画リストにチェック済みフラグを立てる
		try {
			$videoLists = Import-Csv $listFileRelativePath -Encoding UTF8
			#該当のビデオのチェックステータスを"1"に
			$(($videoLists).Where({ $_.videoPath -eq $videoFileAbsolutePath })).videoValidated = '1'
			$videoLists | Export-Csv $listFileRelativePath -NoTypeInformation -Encoding UTF8 -Force
		} catch { Write-Host "録画リストを更新できませんでした: $videoFileAbsolutePath" }
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
function executeYtdlp ($videoFileAbsolutePath, $videoPageURL, $ytdlpRelativePath) {
	$tmpDir = '"temp:' + $downloadWorkAbsoluteDir + '"'
	$saveDir = '"home:' + $videoFileAbsoluteDir + '"'
	$subttlDir = '"subtitle:' + $downloadWorkAbsoluteDir + '"'
	$thumbDir = '"thumbnail:' + $downloadWorkAbsoluteDir + '"'
	$chaptDir = '"chapter:' + $downloadWorkAbsoluteDir + '"'
	$descDir = '"description:' + $downloadWorkAbsoluteDir + '"'
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

	Write-Debug "yt-dlp起動コマンド:$ytdlpRelativePath $ytdlpArgs"
	if ($isWin) {
		try {
			$null = Start-Process -FilePath $ytdlpRelativePath `
				-ArgumentList $ytdlpArgs `
				-PassThru `
				-WindowStyle $windowShowStyle
		} catch { Write-Host 'yt-dlpの起動に失敗しました' }
	} else {
		try {
			$null = Start-Process -FilePath nohup `
				-ArgumentList ($ytdlpRelativePath, $ytdlpArgs) `
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
function showVideoDebugInfo ($videoPageURL, $videoSeriesPageURL, $keywordName, $videoTitleName, $videoSubtitleName, $videoFileAbsolutePath, $processedTime) {
	Write-Debug	"ビデオページ:$videoPageURL"
	Write-Debug	"ビデオLP    :$videoSeriesPageURL"
	Write-Debug "キーワード  :$keywordName"
	Write-Debug "タイトル    :$videoTitleName"
	Write-Debug "サブタイトル:$videoSubtitleName"
	Write-Debug "ファイル    :$videoFileAbsolutePath"
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
function getVideoFileName ($videoTitleName, $videoSubtitleName, $broadcastDate) {
	Write-Verbose 'ビデオファイル名を整形します。'
	if ($videoSubtitleName -eq '') {
		if ($broadcastDate -eq '') {
			$videoName = $videoTitleName
		} else {
			$videoName = $videoTitleName + ' ' + $broadcastDate
		}
	} else {
		$videoName = $videoTitleName + ' ' + $broadcastDate + ' ' + $videoSubtitleName
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
		#		Get-ChildItem `
		#			-Path $Path `
		#			-Recurse `
		#			-Force `
		#			-File `
		#			-Include $Conditions `
		#			-Name | `
		#				ForEach-Object { Remove-Item $_.FullName }

		$delTargets = Get-ChildItem `
			-Path $Path `
			-Recurse `
			-Force `
			-File `
			-Include $Conditions `
			-Name
		foreach ($delTarget in $delTargets) {
			Remove-Item $delTarget -Force -ErrorAction SilentlyContinue
		}

	} catch { Write-Host '削除できないファイルがありました' }
}


