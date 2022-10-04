###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画チェック処理スクリプト
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

	#----------------------------------------------------------------------
	#設定ファイル読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:sysFile = $(Join-Path $script:confDir 'system_setting_5.ps1')
		. $script:sysFile
		if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
			$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting_5.ps1'))
			. $script:confFile
		}
	} else {
		$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
		. $script:sysFile
		if ( Test-Path $(Join-Path $script:confDir 'user_setting.ps1') ) {
			$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
			. $script:confFile
		}
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\common_functions.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '..\src\functions\tver_functions.ps1'))
	}

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons_5.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting_5.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '開発ファイル用共通関数ファイルを読み込みました' -FgColor 'White' -BgColor 'DarkGreen'
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '開発ファイル用設定ファイルを読み込みました' -FgColor 'White' -BgColor 'DarkGreen'
		}
	} else {
		$script:devFunctionFile = $(Join-Path $script:devDir 'dev_funcitons.ps1')
		$script:devConfFile = $(Join-Path $script:devDir 'dev_setting.ps1')
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '開発ファイル用共通関数ファイルを読み込みました' -FgColor 'White' -BgColor 'DarkGreen'
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '開発ファイル用設定ファイルを読み込みました' -FgColor 'White' -BgColor 'DarkGreen'
		}
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#======================================================================
#動作環境チェック
checkLatestFfmpeg					#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック

#======================================================================
#リストファイルのクリーンアップ
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '30日以上前に処理したものはリストから削除します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput ''
#進捗表示
ShowProgressToast `
	-Text1 '動画のチェック中' `
	-Text2 '　処理1/4 - 30日以上前のリストを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
purgeDB -RetentionPeriod 30				#30日以上前に処理したものはリストから削除

Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '重複レコードを削除します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput ''
#進捗表示
ShowProgressToast `
	-Text1 '動画のチェック中' `
	-Text2 '　処理2/4 - 重複レコードを削除' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
uniqueDB							#リストの重複削除

if ($script:disableValidation -eq $true) {
	Write-ColorOutput '動画ファイルのチェックが無効化されているので、検証せずに終了します'
	exit 0
}

#======================================================================
#録画リストからビデオチェックが終わっていないものを読み込み
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput 'チェックが終わっていないビデオをチェックします'
Write-ColorOutput '----------------------------------------------------------------------'
try {
	#ロックファイルをロック
	while ($(fileLock $script:lockFilePath).fileLocked -ne $true) {
		Write-ColorOutput 'ファイルのロック解除待ち中です' -FgColor 'DarkGray'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoLists = (
		Import-Csv $script:listFilePath -Encoding UTF8 `
		| Where-Object { $_.videoValidated -eq '0' } `
		| Where-Object { $_.videoPath -ne '-- IGNORED --' } `
		| Select-Object 'videoPath'
	)
} catch { Write-ColorOutput 'リストの読み込みに失敗しました' -FgColor 'Green'
} finally { $null = fileUnlock $script:lockFilePath }


if ($null -eq $local:videoLists) {
	#チェックする動画なし
	Write-ColorOutput '　すべてのビデオをチェック済みです' -FgColor 'DarkGray'
} else {
	#動画ファイルをチェック
	$local:validateTotal = 0
	$local:validateTotal = $local:videoLists.Length

	#ffmpegのデコードオプションの設定
	if ($script:forceSoftwareDecodeFlag -eq $true ) {
		$local:decodeOption = ''
	} else {
		if ($script:ffmpegDecodeOption -ne '') {
			Write-ColorOutput '----------------------------------------------------------------------' -FgColor 'Green'
			Write-ColorOutput 'ffmpegのデコードオプションが設定されてます                            ' -FgColor 'Green'
			Write-ColorOutput 'もし動画検証がうまく進まない場合は、以下のどちらかをお試しください    ' -FgColor 'Green'
			Write-ColorOutput '　・ user_setting.ps1 でデコードオプションを変更する                  ' -FgColor 'Green'
			Write-ColorOutput '　・ user_setting.ps1 で $script:forceSoftwareDecodeFlag = $true と設定する' -FgColor 'Green'
			Write-ColorOutput '----------------------------------------------------------------------' -FgColor 'Green'
		}
		$local:decodeOption = $script:ffmpegDecodeOption
	}

	#進捗表示
	ShowProgressToast `
		-Text1 '動画のチェック中' `
		-Text2 '　処理3/4 - 動画を検証' `
		-WorkDetail '残り時間計算中' `
		-Tag $script:appName `
		-Group 'Validate' `
		-Duration 'long' `
		-Silent $false


	#----------------------------------------------------------------------
	$local:totalStartTime = Get-Date
	$local:validateNum = 0
	foreach ($local:videoList in $local:videoLists.videoPath) {
		$local:videoFileRelativePath = $local:videoList

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
		UpdateProgessToast `
			-Title $local:videoFileRelativePath `
			-Rate $local:progressRatio `
			-LeftText $local:validateNum/$local:validateTotal `
			-RrightText "残り時間 $local:minRemaining" `
			-Tag $script:appName `
			-Group 'Validate'

		#処理
		if (Test-Path $script:downloadBaseDir -PathType Container) { }
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' -FgColor 'Green' ; exit 1 }

		Write-ColorOutput "$($local:validateNum)/$($local:validateTotal) - $($local:videoFileRelativePath)"
		checkVideo `
			-DecodeOption $local:decodeOption `
			-Path $local:videoFileRelativePath		#ビデオの整合性チェック
		
		Start-Sleep -Seconds 1
	}
	#----------------------------------------------------------------------

}

#======================================================================
#録画リストからビデオチェックが終わっていないもののステータスを初期化
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput '録画リストからチェックが終わっていないビデオのステータスを変更します'
Write-ColorOutput '----------------------------------------------------------------------'
Write-ColorOutput ''
#進捗表示
ShowProgressToast `
	-Text1 '動画のチェック中' `
	-Text2 '　処理4/4 - 未検証の動画のステータスを変更' `
	-WorkDetail '' `
	-Tag $script:appName `
	-Group 'Validate' `
	-Duration 'long' `
	-Silent $false

#処理
try {
	#ロックファイルをロック
	while ($(fileLock $script:lockFilePath).fileLocked -ne $true) {
		Write-ColorOutput 'ファイルのロック解除待ち中です' -FgColor 'DarkGray'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoLists = Import-Csv $script:listFilePath -Encoding UTF8
	foreach ($local:uncheckedVido in $(($local:videoLists).Where({ $_.videoValidated -eq 2 }))) {
		$local:uncheckedVido.videoValidated = '0'
	}
	$local:videoLists | Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8
} catch { Write-ColorOutput 'リストの更新に失敗しました' -FgColor 'Green'
} finally { $null = fileUnlock $script:lockFilePath }

#進捗表示
UpdateProgessToast `
	-Title '動画のチェック' `
	-Rate '1' `
	-LeftText '' `
	-RrightText '完了' `
	-Tag $script:appName `
	-Group 'Validate'
