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

	if (Test-Path $chromeUserDataPath -PathType Container) {} else { Write-Error 'ChromeのUserDataフォルダが存在しません。終了します。' ; exit }
	if (Test-Path $downloadBasePath -PathType Container) {} else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit }
	if (Test-Path $ffmpegPath -PathType Leaf) {} else { Write-Error 'ffmpeg.exeが存在しません。終了します。' ; exit }
	if (Test-Path $ytdlpPath -PathType Leaf) {} else { Write-Error 'yt-dlp.exeが存在しません。終了します。' ; exit }
	if (Test-Path $iniFile -PathType Leaf) {} else { Write-Error 'ユーザ設定ファイルが存在しません。終了します。' ; exit }
	if (Test-Path $keywordFile -PathType Leaf) {} else { Write-Error 'ダウンロード対象ジャンリリストが存在しません。終了します。' ; exit }
	if (Test-Path $ignoreFile -PathType Leaf) {} else { Write-Error 'ダウンロード対象外ビデオリストが存在しません。終了します。' ; exit }
	if (Test-Path $listFile -PathType Leaf) {} else { Write-Error 'ダウンロードリストが存在しません。終了します。' ; exit }

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
		$ytdlpCount = 0
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
	$ytdlpArgument += '--no-part '
	$ytdlpArgument += '--concurrent-fragments 1 '
	$ytdlpArgument += '--no-mtime '
	$ytdlpArgument += '--embed-thumbnail '
	$ytdlpArgument += '--embed-metadata '
	$ytdlpArgument += '--embed-subs '
	$ytdlpArgument += '--no-force-overwrites '
	$ytdlpArgument += '-o ' + ' "' + $videoPath + '" '
	$ytdlpArgument += $videoPage 
	Write-Debug "yt-dlp起動コマンド:$ytdlpPath $ytdlpArgument"
	$null = Start-Process -FilePath ($ytdlpPath) -ArgumentList $ytdlpArgument -PassThru -WindowStyle Minimize		#Minimize or Hidden
}

#----------------------------------------------------------------------
#ファイル名・フォルダ名に禁止文字の削除
#----------------------------------------------------------------------
Function removeInvalidFileNameChars {
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

	Param([string]$Text)		#変換元テキストを引数に指定

	# 正規表現のパターン
	$regexAlphaNumeric = '[０-９Ａ-Ｚａ-ｚ＃＄％＆－＿／［］｛｝（）＜＞　]+'

	# MatchEvaluatorデリゲート
	$matchEvaluator = { param([Match]$match) [strings]::StrConv($match, [VbStrConv]::Narrow, 0x0411) }

	# regexクラスのReplaceメソッドを使用。第2引数にMatchEvaluatorデリゲートを指定
	$result = [regex]::Replace($Text, $regexAlphaNumeric, $matchEvaluator)
	return $result
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
	if ($videoName.length -gt 120) { $videoName = $videoName.Substring(0, 120) + '……' }
	$videoName = $videoName + '.mp4'
	$videoName = removeInvalidFileNameChars (conv2Narrow $videoName)		#windowsでファイル名にできない文字列を除去
	return $videoName
}