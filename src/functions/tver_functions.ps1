###################################################################################
#
#		TVer固有関数スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのTVer固有の機能を提供する関数群

	.DESCRIPTION
		TVerRecのTVer固有の機能を実装した関数群を提供します。
		以下の主要な機能を含みます：
		1. TVerのAPIトークン取得
		2. 番組検索と情報取得
		3. ダウンロードリストの管理
		4. 番組情報の解析と整形

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		主要な機能:
		1. APIアクセス
		- トークン取得と管理
		- 各種APIエンドポイントへのアクセス
		- レスポンスの解析

		2. 番組検索
		- キーワードによる検索
		- シリーズ/エピソード情報の取得
		- タレント/タグによる検索
		- マイページ/トップページからの情報取得

		3. 情報管理
		- 番組情報の整形
		- ダウンロードリストの作成
		- 無視リストとの照合

		4. 地域制限対応
		- 日本のIPアドレス取得
		- GeoIP情報の管理

		含まれる主要関数:
		- Get-Token: TVerのAPIトークンを取得
		- Get-VideoLinksFromKeyword: キーワードから番組リンクを取得
		- Get-VideoInfo: 番組の詳細情報を取得
		- Update-VideoList: ダウンロードリストを更新
		- Get-JpIP: 日本のIPアドレスを取得

	構成:
		関数は用途ごとに次のファイルへ分割しています。このファイルは、それらを順に読み込みます。
		- tver_api_functions.ps1 ......... APIトークン・日本のIPアドレス
		- tver_link_functions.ps1 ........ 番組リンク・エピソードIDの取得
		- tver_format_functions.ps1 ...... 番組情報の整形・番組情報オブジェクトの生成
		- tver_info_functions.ps1 ........ 番組情報の取得(新旧API)

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
# 分割した関数ファイルの読み込み
#----------------------------------------------------------------------
. (Join-Path $PSScriptRoot 'tver_api_functions.ps1')
. (Join-Path $PSScriptRoot 'tver_link_functions.ps1')
. (Join-Path $PSScriptRoot 'tver_format_functions.ps1')
. (Join-Path $PSScriptRoot 'tver_info_functions.ps1')
