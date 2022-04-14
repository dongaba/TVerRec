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
		$script:scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$script:scriptRoot = Convert-Path .
	}
	Set-Location $script:scriptRoot
	$script:confDir = $(Convert-Path $(Join-Path $script:scriptRoot '..\conf'))
	$script:devDir = $(Convert-Path $(Join-Path $script:scriptRoot '..\dev'))

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting_5.ps1'))
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting_5.ps1'))
		. $script:sysFile
		. $script:confFile
	} else {
		$script:sysFile = $(Convert-Path $(Join-Path $script:confDir 'system_setting.ps1'))
		$script:confFile = $(Convert-Path $(Join-Path $script:confDir 'user_setting.ps1'))
		. $script:sysFile
		. $script:confFile
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\common_functions_5.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\tver_functions_5.ps1'))
	} else {
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\common_functions.ps1'))
		. $(Convert-Path (Join-Path $script:scriptRoot '.\functions\tver_functions.ps1'))
	}

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$script:devFunctionFile = $(Convert-Path $(Join-Path $script:devDir 'dev_funcitons_5.ps1'))
		$script:devConfFile = $(Convert-Path $(Join-Path $script:devDir 'dev_setting_5.ps1'))
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '  開発ファイル用共通関数ファイルを読み込みました' white DarkGreen
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '  開発ファイル用設定ファイルを読み込みました' white DarkGreen
		}
	} else {
		$script:devFunctionFile = $(Convert-Path $(Join-Path $script:devDir 'dev_funcitons.ps1'))
		$script:devConfFile = $(Convert-Path $(Join-Path $script:devDir 'dev_setting.ps1'))
		if (Test-Path $script:devFunctionFile) {
			. $script:devFunctionFile
			Write-ColorOutput '  開発ファイル用共通関数ファイルを読み込みました' white DarkGreen
		}
		if (Test-Path $script:devConfFile) {
			. $script:devConfFile
			Write-ColorOutput '  開発ファイル用設定ファイルを読み込みました' white DarkGreen
		}
	}
} catch { Write-Error '設定ファイルの読み込みに失敗しました' ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#----------------------------------------------------------------------
#動作環境チェック
checkLatestFfmpeg					#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック

Write-ColorOutput '==========================================================================='
Write-ColorOutput '30日以上前に処理したものはリストから削除します'
Write-ColorOutput '==========================================================================='
purgeDB								#30日以上前に処理したものはリストから削除

Write-ColorOutput '==========================================================================='
Write-ColorOutput '重複レコードを削除します'
Write-ColorOutput '==========================================================================='
uniqueDB							#リストの重複削除

#録画リストからビデオチェックが終わっていないものを読み込み
Write-ColorOutput '==========================================================================='
Write-ColorOutput '録画リストからチェックが終わっていないビデオを検索します'
Write-ColorOutput '==========================================================================='
try {
	#ロックファイルをロック
	while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
		Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoLists = Import-Csv $script:listFilePath -Encoding UTF8 `
	| Where-Object { $_.videoValidated -eq '0' } `
	| Where-Object { $_.videoPath -ne '-- IGNORED --' } `
	| Select-Object 'videoPath'
} catch { Write-ColorOutput 'リストの読み込みに失敗しました' Green
} finally { $null = fileUnlock ($script:lockFilePath) }


if ($null -eq $local:videoLists) {
	Write-ColorOutput '----------------------------------------------------------------------'
	Write-ColorOutput 'すべてのビデオをチェック済みです'
	Write-ColorOutput '----------------------------------------------------------------------'
} else {
	Write-ColorOutput '----------------------------------------------------------------------'
	Write-ColorOutput '以下のビデオをチェックします'
	Write-ColorOutput '----------------------------------------------------------------------'

	#----------------------------------------------------------------------
	$local:i = 0
	foreach ($local:videoList in $local:videoLists.videoPath) {
		$local:videoFileRelativePath = $local:videoList
		$local:i = $local:i + 1
		Write-ColorOutput "$local:i 本目: $local:videoFileRelativePath"
	}
	#----------------------------------------------------------------------

	#ffmpegのデコードオプションの設定
	if ($script:forceSoftwareDecodeFlag -eq $true ) {
		#ソフトウェアデコードを強制する場合
		$local:decodeOption = ''
	} else {
		if ($script:ffmpegDecodeOption -ne '') {
			Write-ColorOutput '----------------------------------------------------------------------'
			Write-ColorOutput 'ffmpegのデコードオプションが設定されてます'
			Write-ColorOutput 'もし動画検証がうまく進まない場合は、以下のどちらかをお試しください'
			Write-ColorOutput '  ・ user_setting.ps1 でデコードオプションを変更する'
			Write-ColorOutput '  ・ user_setting.ps1 で $script:forceSoftwareDecodeFlag = $true と設定する'
			Write-ColorOutput '----------------------------------------------------------------------'
		}
		$local:decodeOption = $script:ffmpegDecodeOption
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
		if (Test-Path $script:downloadBaseDir -PathType Container) {}
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' Green ; exit 1 }

		Write-Progress `
			-Id 1 `
			-Activity "$($local:j)/$($local:i)" `
			-PercentComplete $local:completionPercent `
			-Status $local:videoFileRelativePath `
			-SecondsRemaining $local:secondsRemaining

		Write-ColorOutput "$($local:videoFileRelativePath)をチェックします"
		checkVideo $local:decodeOption $local:videoFileRelativePath		#ビデオの整合性チェック

	}
	#----------------------------------------------------------------------

}

#録画リストからビデオチェックが終わっていないものを読み込み
Write-ColorOutput '==========================================================================='
Write-ColorOutput '録画リストからチェックが終わっていないビデオのステータスを変更します'
Write-ColorOutput '==========================================================================='
try {
	#ロックファイルをロック
	while ($(fileLock ($script:lockFilePath)).fileLocked -ne $true) {
		Write-ColorOutput 'ファイルのロック解除待ち中です' DarkGray
		Start-Sleep -Seconds 1
	}
	#ファイル操作
	$local:videoLists = Import-Csv $script:listFilePath -Encoding UTF8
	foreach ($local:uncheckedVido in $(($local:videoLists).Where({ $_.videoValidated -eq 2 }))) {
		$local:uncheckedVido.videoValidated = '0'
	}
	$local:videoLists `
	| Export-Csv $script:listFilePath -NoTypeInformation -Encoding UTF8
} catch { Write-ColorOutput 'リストの更新に失敗しました' Green
} finally { $null = fileUnlock ($script:lockFilePath) }
