# :tv:**TVerRec**:tv: TVer 一括ダウンロード・保存

![Logo](https://raw.githubusercontent.com/dongaba/TVerRec/master/img/TVerRec-Logo-Low.png)

[![GitHub release](https://img.shields.io/github/v/release/dongaba/TVerRec?color=blue)](https://github.com/dongaba/TVerRec/releases)
[![License](https://img.shields.io/github/license/dongaba/TVerRec?color=blue)](https://opensource.org/licenses/MIT)
[![CodeFactor](https://www.codefactor.io/repository/github/dongaba/tverrec/badge)](https://www.codefactor.io/repository/github/dongaba/tverrec)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1b42499be57b48818db8c3c90d73adb3)](https://app.codacy.com/gh/dongaba/TVerRec/dashboard)
[![DevSkim](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml)
[![PSScriptAnalyzer](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml)
[![TVerRec Launch](https://hits.sh/github.com/dongaba/TVerRec/launch.svg?view=total&color=9f9f9f&label=TVerRec%20Launched)](https://hits.sh/github.com/dongaba/TVerRec/launch)
[![Video Search](https://hits.sh/github.com/dongaba/TVerRec/search.svg?view=total&color=9f9f9f&label=Video%20Searched)](https://hits.sh/github.com/dongaba/TVerRec/search)
[![Video Download](https://hits.sh/github.com/dongaba/TVerRec/download.svg?view=total&color=9f9f9f&label=Video%20Downloaded)](https://hits.sh/github.com/dongaba/TVerRec/download)
[![Video Validate](https://hits.sh/github.com/dongaba/TVerRec/validate.svg?view=total&color=9f9f9f&label=Video%20Validated)](https://hits.sh/github.com/dongaba/TVerRec/validate)

TVerRec は、テレビ番組配信サイト TVer(ティーバー<https://tver.jp>)の番組をダウンロード保存するためのダウンローダー、ダウンロード支援ツールです。

- TVerRec は PowerShell Core をインストールした Windows/MacOS/Linux で動作します。
- TVerRec Docker イメージも[配布中](https://hub.docker.com/r/dongaba/tverrec)です。
- **TVerRec は Windows PowerShell をサポートません。PowerShell Core でご利用ください。**
- Windows 環境で PowerShell Core がインストールされていない場合は、TVerRec が自動的に PowerShell Core をインストールします。
- Windows 環境に手動で PowerShell Core をインストールする方法や MacOS、Linux 環境への PowerShell のインストールについては[Wiki のこちらのページ](https://github.com/dongaba/TVerRec/wiki/PowerShell%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB)を参照してください。

## 動作の前提条件

- OS

  - Windows
  - MacOS
  - Linux

- 必要なソフトウェア
  - PowerShell Core (Windows 環境では自動インストールされます)
  - youtube-dl (自動ダウンロードされます)
  - ffmpeg (自動ダウンロードされます)
  - Python (Linux/Mac 環境のみ必要。Windows 環境では不要)

または、Docker を使ってコンテナとして動作させることも可能です。
コンテナは Linux のイメージで作成されており、必要なツールは全て設定済みの状態で起動します。
設定ファイルを用意・修正し、ディスクのマウント・バインドを設定すればすぐに利用開始できます。

## 主な機能

各機能の詳細は[Wiki のこちらのページ](https://github.com/dongaba/TVerRec/wiki/)を参照してください。

1. 番組の**ジャンル**や**出演タレント**、**番組名**などの**キーワード指定**して**一括ダウンロード**します。
2. TVer の**全録**が可能です。(厳密には録画ではなくダウンロード)
3. TVer の**番組サムネイルをダウンロードファイルに埋め込み**ます。
4. 字幕データが TVer にある場合は、**字幕情報もダウンロードファイルに埋め込み**ます。
5. 並列ダウンロードによる**高速ダウンロード**が可能です。(当方環境では 1Gbps の回線で 800Mbps でダウンロード可能)
6. もちろん**番組を 1 本ずつ指定したダウンロード**も可能です。
7. また、ダウンロードした**番組が破損していないかの検証**も行います。
8. ダウンロードされたファイルは、最終保存先に**自動的に整理**可能です。
9. 動作に必要な youtube-dl や ffmpeg などの必要コンポーネントは**自動的に最新版がダウンロード**されます。
10. Windows 環境ではトースト通知によりダウンロードの進捗状況などを通知します。
11. **日本国外からも VPN 不要**で利用することができます。

## 基本的な使い方

1. 番組のダウンロード

   3 つのダウンロードモードがあります。

   1. 一括ダウンロード

      - TVer のカテゴリ毎のページを指定して起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
      - 同様に、推しのタレントや番組を指定して起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
      - 同様に、各放送局毎のページを指定して起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。

   2. リストダウンロード

      - 指定したカテゴリやタレントによる番組の自動ダウンロード以外に、ダウンロード候補をリストファイルに出力し、リストファイルを編集した後にダウンロードすることも可能です。

   3. 個別ダウンロード
      - また、番組を 1 本ずつ指定してダウンロードすることもできます。

2. 番組の検証

   - ダウンロードした番組が正しく再生できる状態か検証します。(ネット回線等の制約でファイルが破損していることがあるため)
   - 番組の検証にはハードウェアアクセラレーションを活用することが可能です。
   - リソースが潤沢にない環境では簡易検証モードを使ったり、検証をしないことも可能です。

3. 番組の整理
   - ダウンロードした番組を番組名別ディレクトリに整理します。
   - Plex 等のライブラリ管理ツールを使っている場合は、ダウンロードした番組を自動的にライブラリディレクトリに移動します。

## ダウンロード対象の設定

ダウンロード対象番組の設定方法については[Wiki のこちらのページ](https://github.com/dongaba/TVerRec/wiki/%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E5%AF%BE%E8%B1%A1%E7%95%AA%E7%B5%84%E3%81%AE%E8%A8%AD%E5%AE%9A)を参照してください。

## 環境設定方法

初期設定や環境設定の方法については[Wiki のこちらのページ](https://github.com/dongaba/TVerRec/wiki/%E5%88%9D%E6%9C%9F%E8%A8%AD%E5%AE%9A%E3%83%BB%E7%92%B0%E5%A2%83%E8%A8%AD%E5%AE%9A%E3%81%AE%E6%96%B9%E6%B3%95)を参照してください。

## 実行方法

TVerRec の使い方・実行方法については[Wiki こちらのページ](https://github.com/dongaba/TVerRec/wiki/TVerRec%E3%81%AE%E4%BD%BF%E3%81%84%E6%96%B9)を参照してください。

## ディレクトリ構成

ディレクトリ構成は以下のようになっています。(ここをクリックすると展開)

    TVerRec/
    ├─ bin/ ............................. 実行ファイル格納用ディレクトリ(初期状態は空)
    │
    ├─ conf/ ............................. 設定
    │  ├─ ignore.conf....................... ダウンロード対象外設定ファイル(存在しない場合は起動時にサンプルがコピーされます)
    │  ├─ ignore.sample.conf................ サンプルダウンロード対象外設定ファイル
    │  ├─ keyword.conf...................... ダウンロード対象キーワードファイル(存在しない場合は起動時にサンプルがコピーされます)
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
    ├─ docker/ ........................... Docker用サンプル
    │  ├─ docker-compose.yaml .............. docker-composeファイル
    │  ├─ Dockerfile ....................... Dockerファイル
    │  ├─ Dockerfile.alpine ................ Alpine LinuxをベースにしたDockerイメージ用Dockerfileのサンプル
    │  └─ Dockerfile.ubuntu ................ Ubuntu LinuxをベースにしたDockerイメージ用Dockerfileのサンプル
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
    │      └─ core ........................... PowerShell Core用ディレクトリ(配下のファイルは省略)
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
    │  │  ├─ update_tverrec.ps1 .............. TVerRec自身の自動更新ツール
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
    │  ├─ d.move_video.sh .................. 番組を保存先に移動するシェルスクリプト
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

## 注意事項

- 著作権

  - このプログラムの著作権は dongaba が保有しています。

- 免責
  - このソフトウェアを使用して発生したいかなる損害にも、作者は責任を負わないものとします。
    各自の自己責任で使用してください。

## ライセンス

- TVerRec は[The MIT License](https://opensource.org/licenses/MIT)に基づき、複製や再配布、改変が許可されます。

Copyright (c) dongaba. All rights reserved.
