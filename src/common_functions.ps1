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
function checkLatestTool ($isWin) {
	if ($isWin) {
		if ($PSVersionTable.PSEdition -eq 'Desktop') {
			. '.\update_ffmpeg_5.ps1'				#ffmpegの最新化チェック
			. '.\update_yt-dlp_5.ps1'				#yt-dlpの最新化チェック
		} else {
			. '.\update_ffmpeg.ps1'				#ffmpegの最新化チェック
			. '.\update_yt-dlp.ps1'				#yt-dlpの最新化チェック
		}
	}
}

#----------------------------------------------------------------------
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile { 
	if (Test-Path $downloadBasePath -PathType Container) {} 
	else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ffmpegPath -PathType Leaf) {} 
	else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ytdlpPath -PathType Leaf) {} 
	else { Write-Error 'yt-dlpが存在しません。終了します。' ; exit 1 }
	if (Test-Path $confFile -PathType Leaf) {} 
	else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $keywordFile -PathType Leaf) {} 
	else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ignoreFile -PathType Leaf) {} 
	else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $listFile -PathType Leaf) {} 
	else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit 1 }
}

#----------------------------------------------------------------------
#GEO IPの確認
#----------------------------------------------------------------------
function checkGeoIP () {
	try {
		if ((Invoke-RestMethod -Uri 'http://ip-api.com/json/').countryCode -ne 'JP') {
			Invoke-RestMethod -Uri ('http://ip-api.com/json/' + (Invoke-WebRequest -Uri 'http://ifconfig.me/ip').Content)
			Write-Host '日本のIPアドレスからしか接続できません。VPN接続してください。' -ForegroundColor Red
			exit
		}
	} catch {}
}

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function getTimeStamp {
	$timeStamp = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
	return $timeStamp
}

#----------------------------------------------------------------------
#ffmpegのハードウェアデコードオプションの設定
#----------------------------------------------------------------------
function getFfmpegDecodeOption {
	Write-Host '----------------------------------------------------------------------'
	Write-Host 'ffmpegのデコードオプションを検出しします'
	Write-Host '  もし動画検証がうまく進まない場合は正しく検出されていない可能性があります'
	Write-Host '  その場合、user_setting.conf で $forceSoftwareDecode = $true と'
	Write-Host '  設定することで解決できる場合があります'
	Write-Host '----------------------------------------------------------------------'

	#ffmpegのデコードオプション
	$ffmpegDecodeQSV = '-hwaccel qsv -c:v h264_qsv'							#QSV : for Intel CPUs
	#以下はRaspberryPi用だが実用に耐えないのでコメント
	#$ffmpegDecodeRpi4 = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 16'	#for Raspberry Pi 4
	#$ffmpegDecodeRpi3 = '-c:v h264_omx'										#for Raspberry Pi 3
	#以下は使えるかどうかの判定が難しいのでコメント
	#$ffmpegDecodeD3D11VA = '-hwaccel d3d11va -hwaccel_output_format d3d11'	#Direct3D 11 : for Windows
	#$ffmpegDecodeDXVA2 = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld'	#Direct3D 9 : for Windows
	#以下は検証していないのでコメント
	#$ffmpegDecodeCUDA = '-hwaccel cuda -hwaccel_output_format cuda'			#CUDA : for NVIDIA Graphic Cards

	$ffmpegDecodeOption = ''
	
	#ffmpegのデコードオプションの設定
	if ($forceSoftwareDecode -eq $true ) {
		#ソフトウェアデコードを強制する場合
		$ffmpegDecodeOption = ''
	} elseif ($ffmpegDecodeOption -eq '') {
		#ハードウェアデコード方式が決まっていない場合
		try {
			#ffmpegからデコーダー一覧を取得
			$process = New-Object System.Diagnostics.Process
			$process.StartInfo.FileName = $ffmpegPath
			$process.StartInfo.Arguments = '-decoders -hide_banner'
			$process.StartInfo.UseShellExecute = $False
			$process.StartInfo.RedirectStandardOutput = $True
			$process.Start() | Out-Null
			$stdout = $process.StandardOutput.ReadToEnd()
			$process.WaitForExit()

			#サポートしているデコーダーをチェック
			if ( $stdout.IndexOf('h264_qsv') -gt 0 ) {
				$ffmpegDecodeOption = $ffmpegDecodeQSV			#QSV : for Intel CPUs
			}
		} catch { $ffmpegDecodeOption = '' } finally { $process.Dispose() } 
	}

	return $ffmpegDecodeOption
}

#----------------------------------------------------------------------
#30日以上前に処理したものはリストから削除
#----------------------------------------------------------------------
function purgeDB {
	try {
		$purgedList = (Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.downloadDate -gt $(Get-Date).AddDays(-30) }) 
		$purgedList | Export-Csv $listFile -NoTypeInformation -Encoding UTF8
	} catch { Write-Host 'リストのクリーンアップに失敗しました' }
}

#----------------------------------------------------------------------
#リストの重複削除
#----------------------------------------------------------------------
function uniqueDB {
	#無視されたもの
	try {
		$ignoredList = (Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoPath -eq '-- IGNORED --' } ) 
	} catch { Write-Host 'リストの読み込みに失敗しました' }

	#無視されなかったものの重複削除。ファイル名で1つしかないもの残す
	try {
		$processedList = Import-Csv $listFile -Encoding UTF8 | `
				Group-Object -Property 'videoPath' | `
				Where-Object count -EQ 1 | `
				Select-Object -ExpandProperty group
	} catch { Write-Host 'リストの読み込みに失敗しました' }

	#無視されたものと無視されなかったものを結合し出力
	$mergedList = $processedList + $ignoredList
	try {
		$mergedList | Sort-Object -Property downloadDate | `
				Export-Csv $listFile -NoTypeInformation -Encoding UTF8
	} catch { Write-Host 'リストの更新に失敗しました' }
}

#----------------------------------------------------------------------
#ビデオの整合性チェック
#----------------------------------------------------------------------
function checkVideo ($ffmpegDecodeOption) {
	try { 
		#ffmpegで整合性チェック
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo.RedirectStandardError = $true
		$process.StartInfo.UseShellExecute = $false
		$process.StartInfo.WindowStyle = 'Hidden'
		$process.StartInfo.FileName = $ffmpegPath
		$process.StartInfo.Arguments = $ffmpegDecodeOption + ' -v error -i "' + $videoPath + '" -f null - '
		$process.Start() | Out-Null
		$stderr = $process.StandardError.ReadToEnd()
		$process.WaitForExit()

		if ( $process.ExitCode -ne 0 ) {
			#終了コードが"0"以外は録画リストとファイルを削除
			Write-Host "stderr: $stderr"
			Write-Host 'exit code: ' $process.ExitCode
			try {
				#破損している動画ファイルを録画リストから削除
					(Select-String -Pattern $videoPath -Path $listFile -Encoding utf8 -SimpleMatch -NotMatch).Line `
				| Out-File $listFile -Encoding utf8 -Force
				#破損している動画ファイルを削除
				Remove-Item $videoPath
			} catch { Write-Host "ファイル削除できませんでした: $videoPath" }
		} else {
			#終了コードが"0"のときは録画リストにチェック済みフラグを立てる
			try {
				$videoLists = Import-Csv $listFile -Encoding UTF8
				#該当のビデオのチェックステータスを"1"に
				$($videoLists | Where-Object { $_.videoPath -eq $videoPath }).videoValidated = '1'
				$videoLists | Export-Csv $listFile -NoTypeInformation -Encoding UTF8 -Force
			} catch { Write-Host "録画リストを更新できませんでした: $videoPath" }
		}
	} catch {
		Write-Host 'ffmpegの実行に失敗しました' 
	} finally {
		$process.Dispose() 
	} 
}

#----------------------------------------------------------------------
#yt-dlpプロセスの確認と待機
#----------------------------------------------------------------------
function getYtdlpProcessList ($parallelDownloadNum) {
	#yt-dlpのプロセスが設定値を超えたら一時待機
	try {
		if ($isWin) { 
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2 
		} else {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		}
	} catch {
		$ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	Write-Verbose "現在のダウンロードプロセス一覧 ( $ytdlpCount 個 )"

	while ($ytdlpCount -ge $parallelDownloadNum) {
		Write-Host "ダウンロードが $parallelDownloadNum 多重に達したので一時待機します。 ( $(getTimeStamp) )"
		Start-Sleep -Seconds 60			#1分待機
		try {
			if ($isWin) { 
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2 
			} else {
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
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
		} else {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		}
	} catch {
		$ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	while ($ytdlpCount -ne 0) {
		try {
			Write-Verbose "現在のダウンロードプロセス一覧 ( $ytdlpCount 個 )"
			Start-Sleep -Seconds 60			#1分待機
			if ($isWin) { 
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2 
			} else {
				$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
			}
		} catch {
			$ytdlpCount = 0
		}
	}
}

#----------------------------------------------------------------------
#yt-dlpプロセスの起動
#----------------------------------------------------------------------
function startYtdlp ($videoPath, $videoPage, $ytdlpPath) {
	#$ffmpegHwAccel = '-hwaccel auto'
	$ytdlpArgument = '-f b ' 
	$ytdlpArgument += '--abort-on-error '
	$ytdlpArgument += '--console-title '
	$ytdlpArgument += '--concurrent-fragments 1 '
	$ytdlpArgument += '--no-mtime '
	$ytdlpArgument += '--embed-thumbnail '
	$ytdlpArgument += '--embed-subs '
	#$ytdlpArgument += '--postprocessor-args "' + $ffmpegHwAccel + '"'
	$ytdlpArgument += '-o ' + ' "' + $videoPath + '" '
	$ytdlpArgument += $videoPage 
	Write-Debug "yt-dlp起動コマンド:$ytdlpPath $ytdlpArgument"
	if ($isWin) { 
		$null = Start-Process -FilePath ($ytdlpPath) -ArgumentList $ytdlpArgument -PassThru -WindowStyle $windowStyle
	} else { 
		$null = Start-Process -FilePath ($ytdlpPath) -ArgumentList $ytdlpArgument -PassThru -RedirectStandardOutput /dev/null
	}
}

#----------------------------------------------------------------------
#ビデオ情報表示
#----------------------------------------------------------------------
function writeVideoInfo ($videoName, $broadcastDate, $media, $description ) {
	Write-Host "ビデオ名    :$videoName"
	Write-Host "放送日      :$broadcastDate"
	Write-Host "テレビ局    :$media"
	Write-Host "ビデオ説明  :$description"
}
#----------------------------------------------------------------------
#ビデオ情報デバッグ表示
#----------------------------------------------------------------------
function writeVideoDebugInfo ($videoPage, $videoPageLP, $genre, $title, $subtitle, $videoPath, $timeStamp ) {
	Write-Debug	"ビデオページ:$videoPage"
	Write-Debug	"ビデオLP    :$videoPageLP"
	Write-Debug "ジャンル    :$genre"
	Write-Debug "タイトル    :$title"
	Write-Debug "サブタイトル:$subtitle"
	Write-Debug "ファイル    :$videoPath"
	Write-Debug "取得日付    :$timeStamp"
}

#----------------------------------------------------------------------
#ファイル名・フォルダ名に禁止文字の削除
#----------------------------------------------------------------------
function removeInvalidFileNameChars {
	param(
		[Parameter(Mandatory = $true,
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
#全角→半角(英数のみ)
#----------------------------------------------------------------------
function conv2Narrow {

	Param([string]$text)		#変換元テキストを引数に指定

	$dakuZenKana = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボ'
	$dakuHanKana = 'ｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾊﾋﾌﾍﾎ'
	$hanDakuZenKana = 'パピプペポ'
	$handakuHanKana = 'ﾊﾋﾌﾍﾎ'
	$zenKana = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン゛゜ァィゥェォャュョッ'
	$hanKana = 'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝﾞﾟｧｨｩｪｫｬｭｮｯ'
	$zenNum = '０１２３４５６７８９'
	$hanNum = '0123456789'
	$zenAlpha = 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
	$hanAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
	$zenSimbol = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥”；：'
	$hanSimbol = '@#$%^&*-+_/[]{}()<> \";:'

	for ($i = 0; $i -lt $dakuZenKana.Length; $i++) {
		$text = $text.Replace($dakuHanKana[$i] + 'ﾞ', $dakuZenKana[$i])
	}
	for ($i = 0; $i -lt $hanDakuZenKana.Length; $i++) {
		$text = $text.Replace($handakuHanKana[$i] + 'ﾟ', $hanDakuZenKana[$i])
	}
	for ($i = 0; $i -lt $zenKana.Length; $i++) {
		$text = $text.Replace($hanKana[$i], $zenKana[$i])
	}
	for ($i = 0; $i -lt $hanNum.Length; $i++) {
		$text = $text.Replace($zenNum[$i], $hanNum[$i])
	}
	for ($i = 0; $i -lt $hanAlpha.Length; $i++) {
		$text = $text.Replace($zenAlpha[$i], $hanAlpha[$i])
	}
	for ($i = 0; $i -lt $hanSimbol.Length; $i++) {
		$text = $text.Replace($zenSimbol[$i], $hanSimbol[$i])
	}
	return $text

}

#----------------------------------------------------------------------
#保存ファイル名を設定
#----------------------------------------------------------------------
function setVideoName ($title, $subtitle, $broadcastDate) {
	Write-Verbose 'ビデオファイル名を整形します。'
	if ($subtitle -eq '') {
		if ($broadcastDate -eq '') {
			$videoName = $title
		} else {
			$videoName = $title + ' ' + $broadcastDate 
		}
	} else {
		$videoName = $title + ' ' + $broadcastDate + ' ' + $subtitle
	}
	$videoName = removeInvalidFileNameChars (conv2Narrow $videoName)		#ファイル名にできない文字列を除去

	#SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング
	$videoNameTemp = ''
	$fileNameLimit = $fileNameMax - 25					#yt-dlpの中間ファイル等を考慮して安全目の上限値
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
