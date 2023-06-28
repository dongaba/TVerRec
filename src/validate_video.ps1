###################################################################################
#
#		番組整合性チェック処理スクリプト
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
#----------------------------------------------------------------------
#初期化
try {
	if ($script:myInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$script:scriptRoot = Split-Path -Parent -Path $script:myInvocation.MyCommand.Definition
	} else { $script:scriptRoot = Convert-Path . }
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '../conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '../dev')
} catch { Write-Error '❗ カレントディレクトリの設定に失敗しました' ; exit 1 }
try {
	. $(Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))
	if ($? -eq $false) { exit 1 }
} catch { Write-Error '❗ 関数の読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	. $(Convert-Path $(Join-Path $script:confDir './system_setting.ps1'))
	if ( Test-Path $(Join-Path $script:confDir './user_setting.ps1') ) {
		. $(Convert-Path $(Join-Path $script:confDir './user_setting.ps1'))
	}
} catch { Write-Error '❗ 設定ファイルの読み込みに失敗しました' ; exit 1 }

#設定で指定したファイル・ディレクトリの存在チェック
checkRequiredFile

#======================================================================
#ダウンロード履歴ファイルのクリーンアップ
Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロード履歴の不整合レコードを削除します'
Write-Output '----------------------------------------------------------------------'

#進捗表示
showProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理1/5 - 破損レコードを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#ダウンロード履歴の破損レコード削除
cleanDB
Write-Output ''

Write-Output '----------------------------------------------------------------------'
Write-Output '30日以上前に処理したものはダウンロード履歴から削除します'
Write-Output '----------------------------------------------------------------------'

#進捗表示
showProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理2/5 - 30日以上前のダウンロード履歴を削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#30日以上前に処理したものはダウンロード履歴から削除
purgeDB -RetentionPeriod 30
Write-Output ''

Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロード履歴の重複レコードを削除します'
Write-Output '----------------------------------------------------------------------'

#進捗表示
showProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理3/5 - ダウンロード履歴の重複レコードを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#ダウンロード履歴の重複削除
uniqueDB
Write-Output ''

if ($script:disableValidation -eq $true) {
	Write-Warning '💡 ダウンロードファイルの整合性検証が無効化されているので、検証せずに終了します'
	exit
}

#======================================================================
#ダウンロード履歴から番組チェックが終わっていないものを読み込み
Write-Output '----------------------------------------------------------------------'
Write-Output '整合性検証が終わっていない番組を検証します'
Write-Output '----------------------------------------------------------------------'
try {
	#ロックファイルをロック
	while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
	{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
	#ファイル操作
	$local:videoHists = (
		Import-Csv `
			-Path $script:historyFilePath `
			-Encoding UTF8 `
		| Where-Object { $_.videoValidated -eq '0' } `
		| Where-Object { $_.videoPath -ne '-- IGNORED --' } `
		| Select-Object 'videoPage', 'videoPath', 'videoValidated'
	)
} catch { Write-Warning '❗ ダウンロード履歴の読み込みに失敗しました'
} finally { $null = fileUnlock $script:historyLockFilePath }


if ($null -eq $local:videoHists) {
	#チェックする番組なし
	Write-Output '　すべての番組を検証済です'
	Write-Output ''
} else {
	#ダウンロードファイルをチェック
	$local:validateTotal = 0
	$local:validateTotal = $local:videoHists.Length

	#ffmpegのデコードオプションの設定
	if ($script:forceSoftwareDecodeFlag -eq $true ) { $local:decodeOption = '' }
	else {
		if ($script:ffmpegDecodeOption -ne '') {
			Write-Output '---------------------------------------------------------------------------'
			Write-Output '💡 ffmpegのデコードオプションが設定されてます                                 '
			Write-Output "　・$($script:ffmpegDecodeOption)                                          "
			Write-Output '💡 もし整合性検証がうまく進まない場合は、以下のどちらかをお試しください       '
			Write-Output '　・user_setting.ps1 でデコードオプションを変更する                        '
			Write-Output '　・user_setting.ps1 で $script:forceSoftwareDecodeFlag = $true と設定する '
			Write-Output '---------------------------------------------------------------------------'
		}
		$local:decodeOption = $script:ffmpegDecodeOption
	}

	#進捗表示
	showProgressToast `
		-Text1 'ダウンロードファイルの整合性検証中' `
		-Text2 '　処理4/5 - ファイルを検証' `
		-WorkDetail '残り時間計算中' `
		-Tag $script:appName `
		-Group 'Validate' `
		-Duration 'long' `
		-Silent $false


	#----------------------------------------------------------------------
	$local:totalStartTime = Get-Date
	$local:validateNum = 0
	foreach ($local:videoHist in $local:videoHists.videoPath) {
		$local:videoFileRelPath = $local:videoHist

		#処理時間の推計
		$local:secElapsed = (Get-Date) - $local:totalStartTime
		$local:secRemaining = -1
		if ($local:validateNum -ne 0) {
			$local:secRemaining = ($local:secElapsed.TotalSeconds / $local:validateNum) * ($local:validateTotal - $local:validateNum)
			$local:minRemaining = "$([String]([math]::Ceiling($local:secRemaining / 60)))分"
			$local:progressRatio = $($local:validateNum / $local:validateTotal)
		} else {
			$local:minRemaining = '計算中...'
			$local:progressRatio = 0
		}
		$local:validateNum = $local:validateNum + 1

		#進捗表示
		updateProgressToast `
			-Title $local:videoFileRelPath `
			-Rate $local:progressRatio `
			-LeftText $local:validateNum/$local:validateTotal `
			-RightText "残り時間 $local:minRemaining" `
			-Tag $script:appName `
			-Group 'Validate'

		#処理
		if (Test-Path $script:downloadBaseDir -PathType Container) {}
		else { Write-Error '❗ 番組ダウンロード先ディレクトリにアクセスできません。終了します。' ; exit 1 }

		Write-Output "$($local:validateNum)/$($local:validateTotal) - $($local:videoFileRelPath)"
		#番組の整合性チェック
		checkVideo `
			-DecodeOption $local:decodeOption `
			-Path $local:videoFileRelPath

		Start-Sleep -Seconds 1
	}
	#----------------------------------------------------------------------

}

#======================================================================
#ダウンロード履歴から整合性検証が終わっていないもののステータスを初期化
Write-Output '----------------------------------------------------------------------'
Write-Output 'ダウンロード履歴から検証が終わっていない番組のステータスを変更します'
Write-Output '----------------------------------------------------------------------'
Write-Output ''
#進捗表示
showProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理5/5 - 未検証のファイルのステータスを変更' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
try {
	#ロックファイルをロック
	while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true)
	{ Write-Warning 'ファイルのロック解除待ち中です'; Start-Sleep -Seconds 1 }
	#ファイル操作
	$local:videoHists = `
		Import-Csv `
		-Path $script:historyFilePath `
		-Encoding UTF8
	foreach ($local:uncheckedVido in $(($local:videoHists).`
				Where({ $_.videoValidated -eq 2 }))) {
		$local:uncheckedVido.videoValidated = '0'
	}
	$local:videoHists | Export-Csv `
		-Path $script:historyFilePath `
		-NoTypeInformation `
		-Encoding UTF8
} catch { Write-Warning '❗ ダウンロード履歴の更新に失敗しました'
} finally { $null = fileUnlock $script:historyLockFilePath }

#進捗表示
updateProgressToast `
	-Title 'ダウンロードファイルの整合性検証' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Validate'

Write-Output '---------------------------------------------------------------------------'
Write-Output '番組整合性チェック処理を終了しました。                                           '
Write-Output '---------------------------------------------------------------------------'
