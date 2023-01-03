# :tv:**TVerRec**:tv: TVer 一括ダウンロード・保存

![Logo](https://raw.githubusercontent.com/dongaba/TVerRec/master/img/TVerRec-Logo-Low.png)

[![GitHub release](https://img.shields.io/github/v/release/dongaba/TVerRec?color=blue)](https://github.com/dongaba/TVerRec/releases)
[![License](https://img.shields.io/github/license/dongaba/TVerRec?color=blue)](https://opensource.org/licenses/MIT)
[![CodeFactor](https://www.codefactor.io/repository/github/dongaba/tverrec/badge)](https://www.codefactor.io/repository/github/dongaba/tverrec)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1b42499be57b48818db8c3c90d73adb3)](https://app.codacy.com/gh/dongaba/TVerRec/dashboard)
[![DevSkim](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml)
[![PSScriptAnalyzer](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml)
[![TVerRec Launch](https://hits.sh/github.com/dongaba/TVerRec/launch.svg?view=today-total&color=9f9f9f&label=TVerRec%20Launch)](https://hits.sh/github.com/dongaba/TVerRec/launch)
[![Video Searche](https://hits.sh/github.com/dongaba/TVerRec/search.svg?view=today-total&color=9f9f9f&label=Video%20Search)](https://hits.sh/github.com/dongaba/TVerRec/search)
[![Video Download](https://hits.sh/github.com/dongaba/TVerRec/download.svg?view=today-total&color=9f9f9f&label=Video%20Download)](https://hits.sh/github.com/dongaba/TVerRec/download)
[![Video Validate](https://hits.sh/github.com/dongaba/TVerRec/validate.svg?view=today-total&color=9f9f9f&label=Video%20Validate)](https://hits.sh/github.com/dongaba/TVerRec/validate)

TVerRecは、テレビ番組配信サイトTVer(ティーバー<https://tver.jp>)の番組をダウンロード保存するためのダウンローダー、ダウンロード支援ツールです。

- TVerRecはPowerShell CoreをインストールしたWindows/MacOS/Linuxで動作します。
- **TVerRecはWindows PowerShellをサポートしなくなりました。PowerShell Coreでご利用ください。**
- Windows環境でPowerShell Coreがインストールされていない場合は、TVerRecが自動的にPowerShell Coreをインストールします。
- Windows環境に手動でPowerShell Coreをインストールする方法やMacOS、Linux環境へのPowerShellのインストールについては[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/PowerShell%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)を参照してください。

## 動作の前提条件

- OS
  - Windows
  - MacOS
  - Linux
- 必要なソフトウェア
  - PowerShell Core(Windows環境では自動インストール)
  - youtube-dl(自動ダウンロード)
  - ffmpeg(Windows環境では自動ダウンロード)

## 主な機能

各機能の詳細は[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/)を参照してください。

1. 番組の**ジャンル**や**出演タレント**、**番組名**などの**キーワード指定**して**一括ダウンロード**します。
2. TVerの**全録**が可能です。(厳密には録画ではなくダウンロード)
3. TVerの**番組サムネイルをダウンロードファイルに埋め込み**ます。
4. 字幕データがTVerにある場合は、**字幕情報もダウンロードファイルに埋め込み**ます。
5. 並列ダウンロードによる**高速ダウンロード**が可能です。(当方環境では1Gbpsの回線で800Mbpsでダウンロード可能)
6. もちろん**番組を1本ずつ指定したダウンロード**も可能です。
7. また、ダウンロードした**番組が破損していないかの検証**も行います。
8. ダウンロードされたファイルは、最終保存先に**自動的に整理**可能です。
9. 動作に必要なyoutube-dlやffmpegなどの必要コンポーネントは**自動的に最新版がダウンロード**されます。(ffmpegの自動ダウンロードはWindowsのみ)
10. Windows環境ではトースト通知によりダウンロードの進捗状況などを通知します。
11. 動作に必要なツールは自動インストール・ダウンロード
12. **日本国外からもVPN不要**で利用することができます。

## 基本的な使い方

- 一括ダウンロード

  - TVerのカテゴリ毎のページを指定して起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
  - 同様に、推しのタレントや番組を指定して起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
  - 同様に、各放送局毎のページを指定して起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。

- リストダウンロード

  - 指定したカテゴリやタレントによる番組の自動ダウンロード以外に、ダウンロード候補をリストファイルに出力し、リストファイルを編集した後にダウンロードすることも可能です。

- 個別ダウンロード
  - また、番組を1本ずつ指定してダウンロードすることもできます。

## ダウンロード対象の設定

ダウンロード対象番組の設定方法については[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E5%AF%BE%E8%B1%A1%E7%95%AA%E7%B5%84%E3%81%AE%E8%A8%AD%E5%AE%9A)を参照してください。

## 環境設定方法

初期設定や環境設定の方法については[Wikiのこちらのページ](https://github.com/dongaba/TVerRec/wiki/%E5%88%9D%E6%9C%9F%E8%A8%AD%E5%AE%9A%E3%83%BB%E7%92%B0%E5%A2%83%E8%A8%AD%E5%AE%9A%E3%81%AE%E6%96%B9%E6%B3%95)を参照してください。

## 実行方法

TVerRec の使い方・実行方法については[Wiki こちらのページ](https://github.com/dongaba/TVerRec/wiki/TVerRec%E3%81%AE%E4%BD%BF%E3%81%84%E6%96%B9)を参照してください。

## フォルダ構成

<details>
<summary>フォルダ構成は以下のようになっています。(ここをクリックすると展開)</summary>

    TVerRec/
    ├─ bin/ ............................. 実行ファイル格納用フォルダ(初期状態は空)
    │
    ├─ conf/ ............................. 設定
    │  ├─ ignore.conf....................... ダウンロード対象外設定ファイル(存在しない場合は起動時にサンプルファイルがコピーされます)
    │  ├─ ignore.sample.conf................ サンプルダウンロード対象外設定ファイル
    │  ├─ keyword.conf...................... ダウンロード対象キーワードファイル(存在しない場合は起動時にサンプルファイルがコピーされます)
    │  ├─ keyword.sample.conf............... サンプルダウンロード対象キーワードファイル
    │  ├─ system_setting.ps1 ............... デフォルトシステム設定ファイル
    │  └─ user_setting.ps1 ................. ユーザ設定ファイル(必要に応じて自分で作成してください)
    │
    ├─ db/ ............................... データベース
    │  ├─ ffmpeg_error.log.................. ffmpegのエラーログ(処理中に作成され、一定時間経過後に自動削除されます)
    │  ├─ history.csv ...................... ダウンロード履歴(存在しない場合は起動時に作成されます)
    │  ├─ history.lock ..................... 複数インスタンス起動時のダウンロード履歴ファイルの排他制御用ファイル
    │  ├─ history.sample.csv ............... 空のダウンロード履歴
    │  └─ list.lock ........................ 複数インスタンス起動時のダウンロードリストファイルの排他制御用ファイル
    │
    ├─ img/ .............................. 画像
    │  ├─ TVerRec-Logo.png ................. アプリロゴ
    │  ├─ TVerRec-Logo-Low.png ............. アプリロゴ(低いやつ)
    │  ├─ TVerRec-Toast.png ................ トースト通知用アプリロゴ
    │  └─ TVerRec-Toast-Large.png .......... トースト通知用アプリロゴ(デカいやつ)
    │
    ├─ lib/ .............................. ライブラリ
    │  └─ win .............................. Windows用ライブラリ
    │      ├─ common ......................... 共通ライブラリ用
    │      └─ core ........................... PowerShell Core用フォルダ(配下のファイルは省略)
    │
    ├─ list/ ............................. リスト
    │  ├─ list.csv ......................... ダウンロードリスト(存在しない場合は起動時に作成されます)
    │  └─ list.sample.csv .................. 空のダウンロードリスト
    │
    ├─ src/ .............................. 各種ソース
    │  ├─ functions/ ....................... 各種共通関数
    │  │  ├─ common_functions.ps1 ............ 共通関数定義
    │  │  ├─ tver_functions.ps1 .............. TVer用共通関数定義
    │  │  ├─ update_ffmpeg.ps1 ............... ffmpeg自動更新ツール
    │  │  ├─ update_yt-dlp.ps1 ............... yt-dlp自動更新ツール
    │  │  └─ update_ytdl-patched.ps1 ......... ytdl-patched自動更新ツール
    │  ├─ delete_trash.ps1 ................. ダウンロード対象外番組削除ツール
    │  ├─ generate_list.ps1 ................ ダウンロードリスト作成ツール
    │  ├─ move_vide.ps1 .................... 番組を保存先に移動するツール
    │  ├─ tverrec_bulk.ps1 ................. 一括ダウンロードツール
    │  ├─ tverrec_list.ps1 ................. リストダウンロードツール
    │  ├─ tverrec_single.ps1 ............... 単体ダウンロードツール
    │  └─ validate_video.ps1 ............... ダウンロード済番組の整合性チェックツール
    │
    ├─ unix/ ............................. Linux/Mac用シェルスクリプト
    │  ├─ a.download_video.sh .............. キーワードを元一括ダウンロードするシェルスクリプト
    │  ├─ b.delete_video.sh ................ ダウンロード対象外番組・中間ファイル削除シェルスクリプト
    │  ├─ c.validate_video.sh .............. ダウンロード済番組の整合性チェックシェルスクリプト
    │  ├─ d.move_video.sh .................. 番組を保存先に移動するシェルスクリプト(もし必要であれば)
    │  ├─ start_tverrec.sh ................. キーワードを元に無限一括ダウンロード起動シェルスクリプト
    │  ├─ stop_tverrec.sh .................. 無限一括ダウンロード終了シェルスクリプト
    │  ├─ x.generate_list.sh ............... ダウンロードリストを生成するシェルスクリプト
    │  ├─ y.tverrec_list.sh ................ ダウンロードリストを元にダンロードするシェルスクリプト
    │  └─ z.download_single_video.sh ....... 番組を1本ずつダウンロードするシェルスクリプト
    │
    ├─ win/ .............................. Windows用BATファイル
    │  ├─ a.download_video.bat ............. キーワードを元一括ダウンロードするBAT
    │  ├─ b.delete_video.bat ............... ダウンロード対象外番組・中間ファイル削除BAT
    │  ├─ c.validate_video.bat ............. ダウンロード済番組の整合性チェックBAT
    │  ├─ d.move_video.bat ................. 番組を保存先に移動するBAT(もし必要であれば)
    │  ├─ start_tverrec.bat ................ キーワードを元に無限一括ダウンロード起動BAT
    │  ├─ stop_tverrec.bat ................. 無限一括ダウンロード終了BAT
    │  ├─ x.generate_list.bat .............. ダウンロードリストを生成するBAT
    │  ├─ y.tverrec_list.bat ............... ダウンロードリストを元にダンロードするBAT
    │  └─ z.download_single_video.bat ...... 番組を1本ずつダウンロードするBAT
    │
    ├─ CHANGELOG.md ......................... 変更履歴
    ├─ LICENSE .............................. ライセンス
    ├─ README.md ............................ このファイル
    ├─ TODO.md .............................. 今後の改善予定
    └─ VERSION .............................. バージョン表記用ファイル

</details>

## 注意事項

- 著作権

  - このプログラムの著作権はdongabaが保有しています。

- 免責
  - このソフトウェアを使用して発生したいかなる損害にも、作者は責任を負わないものとします。
    各自の自己責任で使用してください。

## ライセンス

- TVerRec は[The MIT License](https://opensource.org/licenses/MIT)に基づき、複製や再配布、改変が許可されます。

Copyright (c) dongaba. All rights reserved.
