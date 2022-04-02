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
		$currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$currentDir = Convert-Path .
	}
	Set-Location $currentDir
	$confDir = $(Join-Path $currentDir '..\conf')
	$sysFile = $(Join-Path $confDir 'system_setting.conf')
	$confFile = $(Join-Path $confDir 'user_setting.conf')
	$devDir = $(Join-Path $currentDir '..\dev')
	$devConfFile = $(Join-Path $devDir 'dev_setting.conf')
	$devFunctionFile = $(Join-Path $devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile -Encoding UTF8 | `
			Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile -Encoding UTF8 | `
			Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $devConfFile) {
		Get-Content $devConfFile -Encoding UTF8 | `
				Where-Object { $_ -notmatch '^\s*$' } | `
				Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
				Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. '.\common_functions_5.ps1'
		. '.\tver_functions_5.ps1'
		if (Test-Path $devFunctionFile) { 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  PowerShell Coreではありません                         ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	} else {
		. '.\common_functions.ps1'
		. '.\tver_functions.ps1'
		if (Test-Path $devFunctionFile) { 
			. $devFunctionFile 
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
	while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
		Write-Host 'ファイルのロック解除待ち中です'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$videoLists = Import-Csv $listFilePath -Encoding UTF8 | `
			Where-Object { $_.videoValidated -eq '0' } | `
			Where-Object { $_.videoPath -ne '-- IGNORED --' } | `
			Select-Object 'videoPath'
} catch { Write-Host 'リストの読み込みに失敗しました' -ForegroundColor Green
} finally { $null = fileUnlock ($lockFilePath) }


if ($null -eq $videoLists) {
	Write-Host '----------------------------------------------------------------------'
	Write-Host 'すべてのビデオをチェック済みです'
	Write-Host '----------------------------------------------------------------------'
} else {
	Write-Host '----------------------------------------------------------------------'
	Write-Host '以下のビデオをチェックします'
	Write-Host '----------------------------------------------------------------------'

	#----------------------------------------------------------------------
	$i = 0
	foreach ($videoList in $videoLists.videoPath) {
		$videoFileRelativePath = $videoList
		$i = $i + 1
		Write-Host "$i 本目: $videoFileRelativePath"
	}
	#----------------------------------------------------------------------

	#ffmpegのデコードオプションの設定
	if ($forceSoftwareDecodeFlag -eq $true ) {
		#ソフトウェアデコードを強制する場合
		$decodeOption = ''
	} else {
		if ($ffmpegDecodeOption -ne '') {
			Write-Host '----------------------------------------------------------------------'
			Write-Host 'ffmpegのデコードオプションが設定されてます'
			Write-Host 'もし動画検証がうまく進まない場合は、以下のどちらかをお試しください'
			Write-Host '  ・ user_setting.conf でデコードオプションを変更する'
			Write-Host '  ・ user_setting.conf で $forceSoftwareDecodeFlag = $true と設定する'
			Write-Host '----------------------------------------------------------------------'
		}
		$decodeOption = $ffmpegDecodeOption
	}

	$totalStartTime = Get-Date 

	$completionPercent = 0
	Write-Progress `
		-Id 1 `
		-Activity '動画のチェック中' `
		-PercentComplete $completionPercent `
		-Status '残り時間計算中'

	#----------------------------------------------------------------------
	$j = 0
	foreach ($videoList in $videoLists.videoPath) {
		$videoFileRelativePath = $videoList

		$secondsElapsed = (Get-Date) - $totalStartTime
		$secondsRemaining = -1
		if ($j -ne 0) {
			$completionPercent = $($( $j / $i ) * 100)
			$secondsRemaining = ($secondsElapsed.TotalSeconds / $j) * ($i - $j)
		}
		$j = $j + 1

		#保存先ディレクトリの存在確認
		if (Test-Path $downloadBaseDir -PathType Container) {}
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' -ForegroundColor Green ; exit 1 }

		Write-Progress `
			-Id 1 `
			-Activity "$($j)/$($i)" `
			-PercentComplete $completionPercent `
			-Status "$videoFileRelativePath" `
			-SecondsRemaining $secondsRemaining

		Write-Host "$($videoFileRelativePath)をチェックします"
		checkVideo $decodeOption		#ビデオの整合性チェック

	}
	#----------------------------------------------------------------------

}

#録画リストからビデオチェックが終わっていないものを読み込み
Write-Host '==========================================================================='
Write-Host '録画リストからチェックが終わっていないビデオのステータスを変更します'
Write-Host '==========================================================================='
try {
	#ロックファイルをロック
	while ($(fileLock ($lockFilePath)).fileLocked -ne $true) { 
		Write-Host 'ファイルのロック解除待ち中です'
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$videoLists = Import-Csv $listFilePath -Encoding UTF8
	foreach ($uncheckedVido in $(($videoLists).Where({ $_.videoValidated -eq 2 }))) {
		$uncheckedVido.videoValidated = '0'
	}
	$videoLists | Export-Csv $listFilePath -NoTypeInformation -Encoding UTF8
} catch { Write-Host 'リストの更新に失敗しました' -ForegroundColor Green
} finally { $null = fileUnlock ($lockFilePath) }
