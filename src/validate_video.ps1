###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画チェック処理スクリプト
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
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	$currentDir = Split-Path $MyInvocation.MyCommand.Path
	Set-Location $currentDir
	$configDir = $(Join-Path $currentDir '..\config')
	$sysFile = $(Join-Path $configDir 'system_setting.conf')
	$confFile = $(Join-Path $configDir 'user_setting.conf')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression

	#外部関数ファイルの読み込み
	. '.\common_functions.ps1'
} catch { Write-Host '設定ファイルの読み込みに失敗しました'; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

#ffmpegのハードウェアデコードオプションの設定
Write-Host '----------------------------------------------------------------------'
Write-Host 'ffmpegのデコードオプションを検出しします'
Write-Host '  もし動画検証がうまく進まない場合は正しく検出されていない可能性があります'
Write-Host '  その場合、user_setting.conf で $forceSoftwareDecode = $true と'
Write-Host '  設定することで解決できる場合があります'
Write-Host '----------------------------------------------------------------------'
$ffmpegDecodeOption = getFfmpegDecodeOption

#30日以上前に処理したものはリストから削除
try {
	$purgedList = (Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.downloadDate -gt $(Get-Date).AddDays(-30) }) 
	$purgedList | Export-Csv $listFile -NoTypeInformation -Encoding UTF8
} catch { Write-Host 'リストのクリーンアップに失敗しました' }

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

#録画リストからビデオチェックが終わっていないものを読み込み
try {
	$videoLists = Import-Csv $listFile -Encoding UTF8 | `
			Where-Object { $_.videoValidated -ne '1' } | `
			Where-Object { $_.videoPath -ne '-- IGNORED --' } | `
			Select-Object 'videoPath'
} catch { Write-Host 'リストの読み込み更新に失敗しました' ; exit 1 }

if ($null -eq $videoLists) {
	Write-Host '----------------------------------------------------------------------'
	Write-Host 'すべてのビデオをチェック済みです'
	Write-Host '----------------------------------------------------------------------'
} else {
	Write-Host '----------------------------------------------------------------------'
	Write-Host '以下のビデオをチェックします'
	Write-Host '----------------------------------------------------------------------'
	$i = 0
	foreach ($videoList in $videoLists.videoPath) {
		$videoPath = $videoList
		$i = $i + 1
		Write-Host "$i 本目: $videoPath"
	}

	$j = 0
	foreach ($videoList in $videoLists.videoPath) {
		$videoPath = $videoList
		$j = $j + 1

		#保存先ディレクトリの存在確認
		if (Test-Path $downloadBasePath -PathType Container) {} else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' ; exit 1 }

		Write-Host "$j/$i 本目をチェック中: $videoPath"

		try {
			#ffmpegで整合性チェック
			$process = New-Object System.Diagnostics.Process
			$process.StartInfo.RedirectStandardError = $true
			$process.StartInfo.UseShellExecute = $false
			$process.StartInfo.WindowStyle = 'Hidden'
			$process.StartInfo.FileName = $ffmpegPath
			$process.StartInfo.Arguments = $ffmpegDecodeOption + ' -v error -i "' + $videoPath + '" -f null - '
			$process.Start() | Out-Null
			$process.WaitForExit()
			$stderr = $process.StandardError.ReadToEnd()

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
}


