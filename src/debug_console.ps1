###################################################################################
#
#		TVerRecデバッグコンソールスクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのデバッグ用対話型コンソール環境を提供するスクリプト

	.DESCRIPTION
		TVerRecの開発やトラブルシューティングのためのデバッグ環境を提供します。
		以下の機能を提供します：
		1. 詳細なログ出力の有効化
		2. 現在の設定内容の表示
		3. IPアドレス情報の表示
		4. 全変数の表示
		5. 対話型コマンド実行環境

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。
		- 指定なし: 通常モードで実行
		- 'gui': GUIモードで実行
		- その他の値: 通常モードで実行

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります
		- 開発者またはトラブルシューティング担当者向けのスクリプトです

		デバッグ環境の特徴:
		1. ログレベルの設定
		- エラー時中断 (ErrorActionPreference = 'Stop')
		- 警告メッセージ表示 (WarningPreference = 'Continue')
		- 詳細メッセージ表示 (VerbosePreference = 'Continue')
		- デバッグメッセージ表示 (DebugPreference = 'Continue')
		- 情報メッセージ表示 (InformationPreference = 'Continue')

		2. 表示される情報
		- 現在の設定内容
		- IPアドレス関連情報
		- スクリプト内の全変数
		- コマンド使用方法のガイド

		3. 利用可能な機能
		- 対話型コマンド実行
		- 設定値の確認
		- 環境変数の確認
		- 動画ダウンロードのテスト

	.EXAMPLE
		# 通常モードで実行
		.\debug_console.ps1

		# GUIモードで実行
		.\debug_console.ps1 gui

	.OUTPUTS
		System.Void
		このスクリプトは以下の出力を行います：
		- コンソールへのデバッグ情報の表示
		- トースト通知による進捗状況の表示
		- エラー発生時のエラーメッセージ
		- デバッグコマンドの実行結果
		- 環境情報の詳細レポート
#>

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
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
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
$ErrorActionPreference = 'Stop'					#2エラー時中断
$WarningPreference = 'Continue'					#3警告メッセージ
$VerbosePreference = 'Continue'					#4詳細メッセージ
$DebugPreference = 'Continue'					#5デバッグメッセージ
$InformationPreference = 'Continue'				#6情報メッセージ

Start-Sleep -Seconds 1

# 設定内容取得
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 設定内容 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Get-Setting | Format-Table -HideTableHeaders

# IPアドレス関連
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ IPアドレス ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
$script:clientEnvs.GetEnumerator() | Format-Table -HideTableHeaders

# 全変数
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 変数 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Get-Variable | Format-Table -HideTableHeaders

# コマンド使用方法
Write-Output ''
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Output '以下のようなコマンドが実行できます。'
Write-Output "　　- Invoke-VideoDownload -episodeID 'ep12345678'"
Write-Output "　　- Get-VideoInfo -episodeID 'ep12345678'"
Write-Output "　　- Get-VideoLinksFromKeyword -keyword 'キーワード'"
Write-Output '　　　　キーワードは以下の形式で指定できます：'
Write-Output '　　　　　　- episodes/{id}: 特定のエピソード'
Write-Output '　　　　　　- series/{id}: シリーズ'
Write-Output '　　　　　　- talents/{id}: タレント'
Write-Output '　　　　　　- tag/{id}: タグ'
Write-Output '　　　　　　- ranking/{id}: ランキング'
Write-Output '　　　　　　- new/{id}: 新着'
Write-Output '　　　　　　- end/{id}: 終了間近'
Write-Output '　　　　　　- mypage/{page}: マイページ'
Write-Output '　　　　　　- toppage: トップページ'
Write-Output '　　　　　　- sitemap: サイトマップ'
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Output ''
