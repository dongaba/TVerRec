###################################################################################
#
#		TVerRecデバッグコンソールスクリプト
#
###################################################################################
Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

$ErrorActionPreference = 'Stop'					#2エラー時中断
$WarningPreference = 'Continue'					#3警告メッセージ
$VerbosePreference = 'Continue'					#4詳細メッセージ
$DebugPreference = 'Continue'					#5デバッグメッセージ
$InformationPreference = 'Continue'				#6情報メッセージ

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Invoke-RequiredFileCheck
Suspend-Process
Get-Token

# GUI起動を判定
if (!$script:guiMode) { $script:guiMode = $false }

# デバッグモードを設定
$script:debugMode = $true

Start-Sleep -Seconds 1

# 設定内容取得
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 設定内容 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Get-Setting | Format-Table -HideTableHeaders

# IPアドレス関連
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ IPアドレス ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
$script:clientEnvs.GetEnumerator() | Format-Table -HideTableHeaders

# 全変数
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 全変数 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Get-Variable | Format-Table -HideTableHeaders

Write-Output ''
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Output "使い方: 以下のようにURLを指定してコマンドを実行してください。"
Write-Output "　　Invoke-VideoDownload -videoLink 'https://tver.jp/episodes/epXXXXXXXX'"
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Output ''
