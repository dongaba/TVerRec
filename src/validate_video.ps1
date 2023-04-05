###################################################################################
#  TVerRec : TVerダウンローダ
#
#		番組チェック処理スクリプト
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
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$script:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
		$script:scriptName = Split-Path -Leaf -Path $MyInvocation.MyCommand.Definition
	} else {
		$script:scriptRoot = Convert-Path .
	}
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '..\conf'))
	$script:devDir = $(Join-Path $script:scriptRoot '..\dev')
} catch { Write-Error 'ディレクトリ設定に失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#設定ファイル読み込み
try {
	$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
	. $script:sysFile
	if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:confFile
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
try {
	. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions.ps1'))
	. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions.ps1'))
} catch { Write-Error '外部関数ファイルの読み込みに失敗しました' ; exit 1 }

#----------------------------------------------------------------------
#開発環境用に設定上書き
try {
	$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
	$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
	if (Test-Path $script:devFunctionFile) {
		. $script:devFunctionFile
		Write-ColorOutput '開発ファイル用共通関数ファイルを読み込みました' -FgColor 'Yellow'
	}
	if (Test-Path $script:devConfFile) {
		. $script:devConfFile
		Write-ColorOutput '開発ファイル用設定ファイルを読み込みました' -FgColor 'Yellow'
	}
} catch { Write-Error '開発用設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#動作環境チェック
checkLatestFfmpeg					#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック

#======================================================================
#ダウンロード履歴ファイルのクリーンアップ
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput 'ダウンロード履歴の不整合レコードを削除します'
Write-ColorOutput '----------------------------------------------------------------------'

#進捗表示
ShowProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理1/5 - 破損レコードを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
cleanDB							#ダウンロード履歴の破損レコード削除
Write-ColorOutput ''

Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '30日以上前に処理したものはダウンロード履歴から削除します'
Write-ColorOutput '----------------------------------------------------------------------'

#進捗表示
ShowProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理2/5 - 30日以上前のダウンロード履歴を削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
purgeDB -RetentionPeriod 30				#30日以上前に処理したものはダウンロード履歴から削除
Write-ColorOutput ''

Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput 'ダウンロード履歴の重複レコードを削除します'
Write-ColorOutput '----------------------------------------------------------------------'

#進捗表示
ShowProgressToast `
	-Text1 'ダウンロードファイルの整合性検証中' `
	-Text2 '　処理3/5 - ダウンロード履歴の重複レコードを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
uniqueDB							#ダウンロード履歴の重複削除
Write-ColorOutput ''

if ($script:disableValidation -eq $true) {
	Write-ColorOutput 'ダウンロードファイルの整合性検証が無効化されているので、検証せずに終了します'
	exit 0
}

#======================================================================
#ダウンロード履歴から番組チェックが終わっていないものを読み込み
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '整合性検証が終わっていない番組を検証します'
Write-ColorOutput '----------------------------------------------------------------------'
try {
	#ロックファイルをロック
	while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
		Write-ColorOutput 'ファイルのロック解除待ち中です' -FgColor 'Gray'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoHists = (
		Import-Csv $script:historyFilePath -Encoding UTF8 `
		| Where-Object { $_.videoValidated -eq '0' } `
		| Where-Object { $_.videoPath -ne '-- IGNORED --' } `
		| Select-Object 'videoPath'
	)
} catch {
 Write-ColorOutput 'ダウンロード履歴の読み込みに失敗しました' -FgColor 'Green'
} finally { $null = fileUnlock $script:historyLockFilePath }


if ($null -eq $local:videoHists) {
	#チェックする番組なし
	Write-ColorOutput '　すべての番組を検証済です' -FgColor 'Gray'
	Write-ColorOutput ''
} else {
	#ダウンロードファイルをチェック
	$local:validateTotal = 0
	$local:validateTotal = $local:videoHists.Length

	#ffmpegのデコードオプションの設定
	if ($script:forceSoftwareDecodeFlag -eq $true ) {
		$local:decodeOption = ''
	} else {
		if ($script:ffmpegDecodeOption -ne '') {
			Write-ColorOutput '---------------------------------------------------------------------------' -FgColor 'Green'
			Write-ColorOutput 'ffmpegのデコードオプションが設定されてます                                 ' -FgColor 'Green'
			Write-ColorOutput "　・$($script:ffmpegDecodeOption)                                          " -FgColor 'Green'
			Write-ColorOutput 'もし整合性検証がうまく進まない場合は、以下のどちらかをお試しください       ' -FgColor 'Green'
			Write-ColorOutput '　・user_setting.ps1 でデコードオプションを変更する                        ' -FgColor 'Green'
			Write-ColorOutput '　・user_setting.ps1 で $script:forceSoftwareDecodeFlag = $true と設定する ' -FgColor 'Green'
			Write-ColorOutput '---------------------------------------------------------------------------' -FgColor 'Green'
		}
		$local:decodeOption = $script:ffmpegDecodeOption
	}

	#進捗表示
	ShowProgressToast `
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
		$local:videoFileRelativePath = $local:videoHist

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
		UpdateProgressToast `
			-Title $local:videoFileRelativePath `
			-Rate $local:progressRatio `
			-LeftText $local:validateNum/$local:validateTotal `
			-RightText "残り時間 $local:minRemaining" `
			-Tag $script:appName `
			-Group 'Validate'

		#処理
		if (Test-Path $script:downloadBaseDir -PathType Container) { }
		else { Write-Error '番組ダウンロード先フォルダにアクセスできません。終了します。' -FgColor 'Green' ; exit 1 }

		Write-ColorOutput "$($local:validateNum)/$($local:validateTotal) - $($local:videoFileRelativePath)" -NoNewLine $true
		checkVideo `
			-DecodeOption $local:decodeOption `
			-Path $local:videoFileRelativePath		#番組の整合性チェック

		Start-Sleep -Seconds 1
	}
	#----------------------------------------------------------------------

}

#======================================================================
#ダウンロード履歴から整合性検証が終わっていないもののステータスを初期化
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput 'ダウンロード履歴から検証が終わっていない番組のステータスを変更します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput ''
#進捗表示
ShowProgressToast `
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
	while ($(fileLock $script:historyLockFilePath).fileLocked -ne $true) {
		Write-ColorOutput 'ファイルのロック解除待ち中です' -FgColor 'Gray'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoHists = Import-Csv $script:historyFilePath -Encoding UTF8
	foreach ($local:uncheckedVido in $(($local:videoHists).Where({ $_.videoValidated -eq 2 }))) {
		$local:uncheckedVido.videoValidated = '0'
	}
	$local:videoHists | Export-Csv $script:historyFilePath -NoTypeInformation -Encoding UTF8
} catch {
 Write-ColorOutput 'ダウンロード履歴の更新に失敗しました' -FgColor 'Green'
} finally { $null = fileUnlock $script:historyLockFilePath }

#進捗表示
UpdateProgressToast `
	-Title 'ダウンロードファイルの整合性検証' `
	-Rate '1' `
	-LeftText '' `
	-RightText '完了' `
	-Tag $script:appName `
	-Group 'Validate'
