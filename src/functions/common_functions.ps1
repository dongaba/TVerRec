###################################################################################
#
#		共通関数スクリプト
#
###################################################################################
<#
	.SYNOPSIS
	TVerRecの共通機能を提供する関数群を定義します。

	.DESCRIPTION
	TVerRecアプリケーションで使用される共通の機能を提供する関数群を定義します。
	主に以下の7つのカテゴリの機能を提供します：

	1. メモリ管理関連
		- ガベージコレクションの制御
		- メモリ使用の最適化

	2. 時間処理関連
		- タイムスタンプの生成と変換
		- UNIX時間とDateTime型の相互変換

	3. 文字列処理関連
		- ファイル名の無効文字除去
		- 全角/半角文字の変換
		- 特殊文字の処理

	4. ファイル操作関連
		- ファイルの削除と管理
		- ZIPファイルの展開
		- ファイルロックの制御

	5. ディスク管理関連
		- ディスク容量の監視
		- 空き容量の確認

	6. 通知機能関連
		- トースト通知の表示
		- 進捗状況の表示と更新

	7. データ変換関連
		- Base64エンコードデータの変換
		- 画像データの処理

	.NOTES
	前提条件:
	- Windows、Linux、またはmacOS環境で実行する必要があります
	- PowerShell 7.0以上を推奨します
	- 十分なディスク容量が必要です
	- インターネット接続が必要な場合があります

	主要な機能：
	- システムリソースの効率的な管理
	- ファイルシステムの安全な操作
	- マルチプラットフォーム対応の通知機能
	- データ形式の変換と処理
	- 文字列とエンコーディングの処理

	構成:
	関数は用途ごとに次のファイルへ分割しています。このファイルは、それらを順に読み込みます。
	- common_system_functions.ps1 ... ガベージコレクション・ディスク容量・Base64画像・GUI更新間隔
	- common_time_functions.ps1 ..... タイムスタンプ・UNIX時間の変換
	- common_string_functions.ps1 ... ファイル名の無効文字・全角半角・特殊文字の処理
	- common_file_functions.ps1 ..... ファイルの削除・ZIPの展開・ファイルロック
	- common_toast_functions.ps1 .... トースト通知・進捗表示

	.EXAMPLE
		# 関数の読み込み
		. .\common_functions.ps1

		# ガベージコレクションの実行
		Invoke-GarbageCollection

		# タイムスタンプの取得
		$timestamp = Get-TimeStamp

		# ファイル名の無効文字を除去
		$safeName = Remove-InvalidFileNameChars "無効な文字を含むファイル名"

	.LINK
	https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
# 分割した関数ファイルの読み込み
# * common_toast_functions.ps1は読み込み時に$script:libDirを参照するため、initialize.ps1で設定を読み込んだ後に、このファイルを読み込むこと
#----------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'common_system_functions.ps1')
. (Join-Path $PSScriptRoot 'common_time_functions.ps1')
. (Join-Path $PSScriptRoot 'common_string_functions.ps1')
. (Join-Path $PSScriptRoot 'common_file_functions.ps1')
. (Join-Path $PSScriptRoot 'common_toast_functions.ps1')
