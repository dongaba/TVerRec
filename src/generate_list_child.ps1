###################################################################################
#
#		番組リストファイル出力処理 - 再帰呼び出し子スレッド用スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのダウンロードリスト生成の子プロセス処理スクリプト

	.DESCRIPTION
		generate_list.ps1から呼び出される子プロセス用スクリプトです。
		マルチスレッド処理時に並列で番組情報を取得します。
		以下の機能を提供します：
		1. キーワードに基づく番組情報の取得
		2. 複数URLの並列処理
		3. リストファイルの更新

	.PARAMETER args
		必須パラメータ。以下の順序で指定します：
		1. キーワード（String）
		2. 番組URL（String配列）

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- generate_list.ps1から呼び出される必要があります
		- 必要なパラメータが正しく渡される必要があります
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		処理の流れ:
		1. 初期設定
		1.1 環境チェック
		1.2 パラメータの検証
		1.3 トークンの取得
		2. 番組情報処理
		2.1 各URLの処理
		2.2 番組情報の取得
		2.3 リストの更新

	.EXAMPLE
		# 直接実行は想定されていません
		# generate_list.ps1から以下の形式で呼び出されます
		.\generate_list_child.ps1 "キーワード" "URL1" "URL2" ...

	.OUTPUTS
		System.Void
		このスクリプトは以下の出力を行います：
		- コンソールへの進捗状況の表示
		- エラー発生時のエラーメッセージ
		- 処理完了時のサマリー情報
		- 更新されたリストファイル
#>

Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

if ($args.Count -ge 2) {
	$keyword = [String]$args[0]
	$episodeIDs = $args[1..($args.Count - 1)]
} else { throw ('❌️ 子プロセスの引数が不足しています。Arguments for child process are missing') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize_child.ps1'))
} catch { throw ('❌️ 関数の読み込みに失敗しました。Failed to load function.') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Get-Token
foreach ($episodeID in $episodeIDs) {
	Write-Output ('　{0}' -f $episodeID)
	Update-VideoList -Keyword $keyword -EpisodeID $episodeID
}

Remove-Variable -Name keyword, videoLinks, videoLink -ErrorAction SilentlyContinue
