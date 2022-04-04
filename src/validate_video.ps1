###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画チェック処理スクリプト
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$global:currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$global:currentDir = Convert-Path .
	}
	Set-Location $global:currentDir
	$global:confDir = $(Join-Path $global:currentDir '..\conf')
	$global:sysFile = $(Join-Path $global:confDir 'system_setting.conf')
	$global:confFile = $(Join-Path $global:confDir 'user_setting.conf')
	$global:devDir = $(Join-Path $global:currentDir '..\dev')
	$global:devConfFile = $(Join-Path $global:devDir 'dev_setting.conf')
	$global:devFunctionFile = $(Join-Path $global:devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $global:sysFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression
	Get-Content $global:confFile -Encoding UTF8 `
	| Where-Object { $_ -notmatch '^\s*$' } `
	| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
	| Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $global:devConfFile) {
		Get-Content $global:devConfFile -Encoding UTF8 `
		| Where-Object { $_ -notmatch '^\s*$' } `
		| Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } `
		| Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $currentDir '.\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $currentDir '.\tver_functions_5.ps1'))
		if (Test-Path $global:devFunctionFile) { 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  PowerShell Coreではありません                         ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	} else {
		. $(Convert-Path (Join-Path $currentDir '.\common_functions.ps1'))
		. $(Convert-Path (Join-Path $currentDir '.\tver_functions.ps1'))
		if (Test-Path $global:devFunctionFile) { 
			. $global:devFunctionFile 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  開発ファイルを読み込みました                          ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#----------------------------------------------------------------------
#動作環境チェック
checkLatestFfmpeg					#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック

Write-Host '==========================================================================='
Write-Host '30日以上前に処理したものはリストから削除します'
Write-Host '==========================================================================='
purgeDB								#30日以上前に処理したものはリストから削除

Write-Host '==========================================================================='
Write-Host '重複レコードを削除します'
Write-Host '==========================================================================='
uniqueDB							#リストの重複削除

#録画リストからビデオチェックが終わっていないものを読み込み
Write-Host '==========================================================================='
Write-Host '録画リストからチェックが終わっていないビデオを検索します'
Write-Host '==========================================================================='
try {
	#ロックファイルをロック
	while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
		Write-Host 'ファイルのロック解除待ち中です'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoLists = Import-Csv $global:listFilePath -Encoding UTF8 `
	| Where-Object { $_.videoValidated -eq '0' } `
	| Where-Object { $_.videoPath -ne '-- IGNORED --' } `
	| Select-Object 'videoPath'
} catch { Write-Host 'リストの読み込みに失敗しました' -ForegroundColor Green
} finally { $null = fileUnlock ($global:lockFilePath) }


if ($null -eq $local:videoLists) {
	Write-Host '----------------------------------------------------------------------'
	Write-Host 'すべてのビデオをチェック済みです'
	Write-Host '----------------------------------------------------------------------'
} else {
	Write-Host '----------------------------------------------------------------------'
	Write-Host '以下のビデオをチェックします'
	Write-Host '----------------------------------------------------------------------'

	#----------------------------------------------------------------------
	$local:i = 0
	foreach ($local:videoList in $local:videoLists.videoPath) {
		$local:videoFileRelativePath = $local:videoList
		$local:i = $local:i + 1
		Write-Host "$local:i 本目: $local:videoFileRelativePath"
	}
	#----------------------------------------------------------------------

	#ffmpegのデコードオプションの設定
	if ($global:forceSoftwareDecodeFlag -eq $true ) {
		#ソフトウェアデコードを強制する場合
		$local:decodeOption = ''
	} else {
		if ($global:ffmpegDecodeOption -ne '') {
			Write-Host '----------------------------------------------------------------------'
			Write-Host 'ffmpegのデコードオプションが設定されてます'
			Write-Host 'もし動画検証がうまく進まない場合は、以下のどちらかをお試しください'
			Write-Host '  ・ user_setting.conf でデコードオプションを変更する'
			Write-Host '  ・ user_setting.conf で $global:forceSoftwareDecodeFlag = $true と設定する'
			Write-Host '----------------------------------------------------------------------'
		}
		$local:decodeOption = $global:ffmpegDecodeOption
	}

	$local:totalStartTime = Get-Date 

	$local:completionPercent = 0
	Write-Progress `
		-Id 1 `
		-Activity '動画のチェック中' `
		-PercentComplete $local:completionPercent `
		-Status '残り時間計算中'

	#----------------------------------------------------------------------
	$local:j = 0
	foreach ($local:videoList in $local:videoLists.videoPath) {
		$local:videoFileRelativePath = $local:videoList

		$local:secondsElapsed = (Get-Date) - $local:totalStartTime
		$local:secondsRemaining = -1
		if ($j -ne 0) {
			$local:completionPercent = $($( $j / $i ) * 100)
			$local:secondsRemaining = ($local:secondsElapsed.TotalSeconds / $local:j) * ($local:i - $local:j)
		}
		$local:j = $local:j + 1

		#保存先ディレクトリの存在確認
		if (Test-Path $global:downloadBaseDir -PathType Container) {}
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' -ForegroundColor Green ; exit 1 }

		Write-Progress `
			-Id 1 `
			-Activity "$($local:j)/$($local:i)" `
			-PercentComplete $local:completionPercent `
			-Status $local:videoFileRelativePath `
			-SecondsRemaining $local:secondsRemaining

		Write-Host "$($local:videoFileRelativePath)をチェックします"
		checkVideo $local:decodeOption $local:videoFileRelativePath		#ビデオの整合性チェック

	}
	#----------------------------------------------------------------------

}

#録画リストからビデオチェックが終わっていないものを読み込み
Write-Host '==========================================================================='
Write-Host '録画リストからチェックが終わっていないビデオのステータスを変更します'
Write-Host '==========================================================================='
try {
	#ロックファイルをロック
	while ($(fileLock ($global:lockFilePath)).fileLocked -ne $true) { 
		Write-Host 'ファイルのロック解除待ち中です'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoLists = Import-Csv $global:listFilePath -Encoding UTF8
	foreach ($local:uncheckedVido in $(($local:videoLists).Where({ $_.videoValidated -eq 2 }))) {
		$local:uncheckedVido.videoValidated = '0'
	}
	$local:videoLists `
	| Export-Csv $global:listFilePath -NoTypeInformation -Encoding UTF8
} catch { Write-Host 'リストの更新に失敗しました' -ForegroundColor Green
} finally { $null = fileUnlock ($global:lockFilePath) }
