###################################################################################
#  tverrec : TVerビデオダウンローダ
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
#yt-dlpプロセスの確認と待機
#----------------------------------------------------------------------
function getYtdlpProcessList ($parallelDownloadNum) {
	#ffmpegのプロセスが設定値を超えたら一時待機
	try {
		$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count
	} catch {
		$ytdlpCount = 0			#プロセス数が取れなくてもとりあえず先に進む
	}

	$ytdlpCount = $ytdlpCount / 2
	Write-Verbose "現在のダウンロードプロセス一覧  ( $ytdlpCount 個 )"

	while ($ytdlpCount -ge $parallelDownloadNum) {
		Write-Host "ダウンロードが $parallelDownloadNum 多重に達したので一時待機します。 ( $(getTimeStamp) )" -ForegroundColor DarkGray
		Start-Sleep -Seconds 60			#1分待機
		$ytdlpCount = (Get-Process -ErrorAction Ignore -Name yt-dlp).Count / 2
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
		#$null = Start-Process -FilePath ($ytdlpPath) -ArgumentList $ytdlpArgument -PassThru -RedirectStandardOutput Out-Null -NoNewWindow
	} else { 
		$null = Start-Process -FilePath ($ytdlpPath) -ArgumentList $ytdlpArgument -PassThru -RedirectStandardOutput /dev/null -NoNewWindow
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
	$zenSimbol = '＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥”'
	$hanSimbol = '@#$%^&*-+_/[]{}()<> \"'

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
	$fileNameLimit = 220		#yt-dlpの中間ファイル等を考慮して安全目の上限値
	$videoNameByte = [System.Text.Encoding]::UTF8.GetByteCount($videoName)

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
#文字列をバイト数で切り出す
#----------------------------------------------------------------------
function getSubStringBytes([String]$Text, [int]$StartIndex = 0, [int]$Length = 0) {
	$enc = [System.Text.Encoding]::UTF8
	$bytes = $enc.GetBytes($Text)
	return $enc.GetString($bytes, $StartIndex, $Length)
}