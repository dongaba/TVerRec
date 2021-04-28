###################################################################################
#  tverrec : TVerビデオダウンローダ
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

using namespace Microsoft.VisualBasic
using namespace System.Text.RegularExpressions

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#Set-StrictMode -Off
Set-StrictMode -Version Latest
$currentDir = Split-Path $MyInvocation.MyCommand.Path
Set-Location $currentDir
$configDir = $(Join-Path $currentDir '..\config')
$sysFile = $(Join-Path $configDir 'system_setting.ini')
$iniFile = $(Join-Path $configDir 'user_setting.ini')

#----------------------------------------------------------------------
#外部設定ファイル読み込み
Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
		Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
		Invoke-Expression
Get-Content $iniFile | Where-Object { $_ -notmatch '^\s*$' } | `
		Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
		Invoke-Expression

#----------------------------------------------------------------------
#必要モジュールの読み込み
Add-Type -AssemblyName Microsoft.VisualBasic

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Get-ChildItem $saveBasePath -Recurse -File -Include *.mp4 |`
		ForEach-Object { 

		$pinfo = New-Object System.Diagnostics.ProcessStartInfo
		$pinfo.RedirectStandardOutput = $true
		$pinfo.RedirectStandardError = $true
		$pinfo.UseShellExecute = $false
		#$pinfo.WindowStyle = 'Hidden'

		$pinfo.FileName = $ffmpegPath
		$pinfo.Arguments = ' -v error -i "' + $_ + '" -f null - '
		Write-Debug "ffmpeg起動コマンド:$ffmpegPath $ffmpegArgument"

		$p = New-Object System.Diagnostics.Process
		$p.StartInfo = $pinfo
		$p.Start() | Out-Null
		$p.WaitForExit()

		$stdout = $p.StandardOutput.ReadToEnd()
		$stderr = $p.StandardError.ReadToEnd()

		if ( $stdout -ne '' ) {
			Write-Host "stdout: $stdout"
		}
		if ( $stderr -ne '' ) {
			Write-Host "stderr: $stderr"
		}
		Write-Host 'exit code: ' $p.ExitCode

	}

#$ffmpegArgument = ' -v error -i "' + $_ + '" -f null - >> v:\check.log 2>&1'
#Write-Debug "ffmpeg起動コマンド:$ffmpegPath $ffmpegArgument"
#Start-Process -FilePath ($ffmpegPath) -ArgumentList $ffmpegArgument -PassThru -Wait

