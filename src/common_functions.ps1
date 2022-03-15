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
#設定で指定したファイル・フォルダの存在チェック
#----------------------------------------------------------------------
function checkRequiredFile { 
	if (Test-Path $downloadBasePath -PathType Container) {} else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ffmpegPath -PathType Leaf) {} else { Write-Error 'ffmpegが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ytdlpPath -PathType Leaf) {} else { Write-Error 'yt-dlpが存在しません。終了します。' ; exit 1 }
	if (Test-Path $confFile -PathType Leaf) {} else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit 1 }
	if (Test-Path $keywordFile -PathType Leaf) {} else { Write-Error 'ダウンロード対象ジャンルリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $ignoreFile -PathType Leaf) {} else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit 1 }
	if (Test-Path $listFile -PathType Leaf) {} else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit 1 }
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
	if ($iswin -eq $true) {
		#Windowsの場合はDirect Xのバージョンを取得
		$dxdiagFile = $(Join-Path $downloadBasePath 'dxdiag.txt')
		try {
			#ffmpegからデコーダー一覧を取得
			$process = New-Object System.Diagnostics.Process
			$process.StartInfo.FileName = 'dxdiag.exe'
			$process.StartInfo.Arguments = "/t $dxdiagFile"
			$process.StartInfo.UseShellExecute = $False
			$process.Start() | Out-Null
			$process.WaitForExit()

			$result = Select-String -Path $dxdiagFile -Pattern 'DDI Version'
			$ddiVersion = [int]$($result[0].Line.Substring($result[0].Line.Length - 2, 2).trim())

		} catch { $ddiVersion = 0 } finally { $process.Dispose() } 

		try { Remove-Item $dxdiagFile } catch {}

		#DDIのバージョンによりデコードオプションを設定
		if ($ddiVersion -gt 10 ) {
			$ffmpegDecodeOption = $ffmpegDecodeD3D11VA		#Direct3D 11 : for Windows
		} elseif ($ddiVersion -gt 8 ) {
			$ffmpegDecodeOption = $ffmpegDecodeDXVA2		#Direct3D 9 : for Windows
		} else {
			$ffmpegDecodeOption = ''
		}

	} elseif ($IsLinux -eq $true) {
		#Linuxの場合はRaspberry Piのデコードオプションを設定
		$result = Select-String -Path '/proc/cpuinfo' -Pattern 'Raspberry Pi 4'
		if ($null -ne $result) {
			$ffmpegDecodeOption = $ffmpegDecodeRpi4			#Raspberry Pi 4
		} else {
			$result = Select-String -Path '/proc/cpuinfo' -Pattern 'Raspberry Pi 3'
			if ($null -ne $result) {
				$ffmpegDecodeOption = $ffmpegDecodeRpi3			#Raspberry Pi 3
			} else {
				$ffmpegDecodeOption = ''
			}
		}
	} else {
		#WindowsでもLinuxでもない場合
		$ffmpegDecodeOption = ''
	}

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
			$process.StartInfo.Arguments = '-decoders'
			$process.StartInfo.UseShellExecute = $False
			$process.StartInfo.RedirectStandardOutput = $True
			$process.Start() | Out-Null
			$process.WaitForExit()
			$stdout = $process.StandardOutput.ReadToEnd()

			#サポートしているデコーダーをチェック
			if ( $stdout.IndexOf('h264_qsv') -gt 0 ) {
				$ffmpegDecodeOption = $ffmpegDecodeQSV			#QSV : for Intel CPUs
			} else {
				$ffmpegDecodeOption = ''						#使えるハードウェアデコーダが不明
			}
		} catch { $ffmpegDecodeOption = '' } finally { $process.Dispose() } 
	}

	return $ffmpegDecodeOption
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
		if ($isWin) { 
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2 
		} else {
			$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
		}
	}
}

#----------------------------------------------------------------------
#yt-dlpプロセスの起動
#----------------------------------------------------------------------
function startYtdlp ($videoPath, $videoPage, $ytdlpPath) {
	$ytdlpArgument = '-f b ' 
	$ytdlpArgument += '--abort-on-error '
	$ytdlpArgument += '--console-title '
	$ytdlpArgument += '--concurrent-fragments 1 '
	$ytdlpArgument += '--no-mtime '
	$ytdlpArgument += '--embed-thumbnail '
	$ytdlpArgument += '--embed-subs '
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
