###################################################################################
#
#		TVerRec固有関数スクリプト(分割したファイルの読み込み)
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecの主要な機能を提供する関数群を定義します。

	.DESCRIPTION
		TVerRecアプリケーションの中核となる機能を提供する関数群を定義します。
		主に以下の4つのカテゴリの機能を提供します：
		1. TVer APIアクセス関連
		- APIトークンの取得と管理
		- 番組情報の取得と解析
		2. ダウンロード管理関連
		- 番組のダウンロード処理
		- ダウンロードリストの管理
		- ダウンロード履歴の管理
		3. ファイル管理関連
		- ダウンロードファイルの命名規則
		- ファイルの整合性チェック
		- 一時ファイルの管理
		4. システム管理関連
		- 設定の管理
		- 統計情報の収集
		- 環境情報の管理

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		主要な機能：
		- TVer番組の検索とダウンロード
		- ダウンロードリストの作成と管理
		- ダウンロード履歴の管理
		- ファイルの整合性チェック
		- システム設定の管理
		- 統計情報の収集

		構成:
		関数は用途ごとに次のファイルへ分割しています。このファイルは、それらを順に読み込みます。
		- tverrec_startup_functions.ps1 ........ 起動時の確認処理
		- tverrec_history_functions.ps1 ........ ダウンロード履歴
		- tverrec_list_functions.ps1 ........... ダウンロードリスト・キーワード
		- tverrec_ignore_functions.ps1 ......... ダウンロード対象外リスト
		- tverrec_match_functions.ps1 .......... ダウンロード済み・登録済みの除外
		- tverrec_ytdl_functions.ps1 ........... youtube-dlの起動・プロセス管理
		- tverrec_download_functions.ps1 ....... ダウンロード処理・失敗ファイルの削除
		- tverrec_integrity_functions.ps1 ...... ffmpeg・字幕修復・整合性チェック
		- tverrec_environment_functions.ps1 .... 環境情報・設定・統計情報
		- tverrec_move_functions.ps1 ........... 番組ファイルの移動

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
Add-Type -AssemblyName 'System.Globalization' | Out-Null

#----------------------------------------------------------------------
# 分割した関数ファイルの読み込み
# * 読み込み順は分割前のファイルの並びと同じ。tverrec_environment_functions.ps1は読み込み時にGet-SysInfoなどを実行するため、依存する関数より後に読み込むこと
#----------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'tverrec_startup_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_history_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_list_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_ignore_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_match_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_ytdl_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_download_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_integrity_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_environment_functions.ps1')
. (Join-Path $PSScriptRoot 'tverrec_move_functions.ps1')
