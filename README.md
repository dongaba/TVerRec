# :tv:**TVerRec**:tv: - TVer 一括ダウンロード・保存・録画 -

![GitHub release (latest by date)](https://img.shields.io/github/v/release/dongaba/TVerRec)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CodeFactor](https://www.codefactor.io/repository/github/dongaba/tverrec/badge)](https://www.codefactor.io/repository/github/dongaba/tverrec)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1b42499be57b48818db8c3c90d73adb3)](https://www.codacy.com/gh/dongaba/TVerRec/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=dongaba/TVerRec&amp;utm_campaign=Badge_Grade)
[![DevSkim](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml)
[![PSScriptAnalyzer](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml)

TVerRecは、動画配信サイトTVer ( ティーバー <https://tver.jp/> ) の動画を録画保存するためのダウンローダー、ダウンロード支援ツールです。

## 2022/4/1のTVerのリニューアルに本格対応しました

- Windows/MacOS/Linuxで動作します。
- 必要なツールは自動的にダウンロードされますが、うまくいかない場合は以下から取得してください。
  - youtube-dl-pathed [https://github.com/ytdl-patched/ytdl-patched/releases]
  - ffmpeg [https://www.ffmpeg.org/download.html]
- TVerのリニューアルによりフリーワード検索の精度が大幅に下がっていますので、できればタレントID指定、番組ID指定で録画したほうが確実です。
- 同様にジャンル指定の精度も大幅に下がっているようですのでご注意ください。

## ざっくり以下のようなことができます

1. 動画の**ジャンル**や**出演タレント**、**番組名**などの**キーワード指定**して**一括ダウンロード**します。
    - **CMは入っていない**ため気に入った番組を配信終了を気にすることなくいつまでも保存しておくことができます。
    - TVerRecはループ実行するようになっているので、**1回起動すれば新しい番組が配信される都度自動でダウンロード、録画、保存**されるようになります。
2. TVerの**全録画**が可能です。
    - ちまちまURLをコピペしたり画面録画する必要はなく、起動して放置するだけの全自動録画です。控えめに言って最高です。
3. TVerの動画**サムネイルを動画ファイルに埋め込み**ます。
4. 字幕データがTVerにある場合は、**字幕情報も動画に埋め込み**ます。
5. 並列ダウンロードによる**高速ダウンロードが可能**です。(デフォルト設定で5ファイル同時ダウンロード、1ファイルあたり10並列ダウンロード、合計最大50並列ダウンロード)
6. もちろん動画を**1本ずつ指定したダウンロードも可能**です。
    - なかには全録なんかしてられねーよ、という方もいらっしゃることでしょう。安心してください。
    - 動画のURLを指定することでダウンロードしたい動画を1本ずつ指定することも可能です。
7. また、ダウンロード保存した動画が正常に再生できるかどうか**動画が壊れていないかの検証**も行います。
    - もし動画ファイルが壊れている場合には自動的に再ダウンロードします。
    - 動画の検証時にffmpegを使用しますが、ハードウェアアクセラレーションを使えば、CPU使用率を抑えることができます。(使用するPCでの性能によっては処理時間が長くなることがあります。その場合はハードウェアアクセラレーションを無効化できます)
8. ダウンロードされたファイルは、最終保存先に**自動的に整理**可能です。
    - 例えば毎週同じ番組をダウンロードする場合、最終保存先に番組名のフォルダがあれば自動的に全番組が最終保存先のフォルダに移動されます。
    - 最終保存先に同名のフォルダがなければ、動画ファイルは保存先フォルダに残り続けます。
9. 動作に必要なyoutube-dlやffmpegなどの必要コンポーネントは**自動的に最新版がダウンロード**されます。(ffmpegの自動ダウンロードはWindowsのみ)
10. **日本国外からもVPN不要**で利用することができます。

## ダウンロード対象番組の設定方法

`conf/keyword.conf`をテキストエディターで開いてダウンロード対象のタレントや番組、ジャンル、TV局などを設定します

- 不要なキーワードは `#` でコメントアウトするか削除してください。
- 主なジャンルは網羅しているつもりですが、不足があるかもしれませんので、必要に応じて適宜自分で補ってください。
- ダウンロード対象の指定の方法はいくつかありますが、現在のところ 1 と 2 が確実にダウンロードする方法です。3～10はTVerの検索機能が改善されるまで動画を取りこぼす可能性や不要な動画がダウンロードされる可能性があります。

1. 番組IDを指定
    - 番組IDを指定します
    - 番組IDは、TVerで番組ページを検索した際のURLに含まれる「series/srxxxxxxxx」です
2. タレントIDを指定
    - タレントIDを指定します
    - タレントIDは、TVerでタレントページを検索した際のURLに含まれる「talents/txxxxxx」です
3. ジャンルを指定
   - ジャンルを指定します
   - 指定可能な曜日は`conf/keyword.conf`に記載されています(バージョンアップとともに変化する可能性があります)
4. ランキングを指定
   - ランキングを指定します
   - 指定可能なランキングは`conf/keyword.conf`に記載されています(バージョンアップとともに変化する可能性があります)
5. 特集を指定
   - TVerの特集を指定します
   - 指定可能な特集は`conf/keyword.conf`に記載されています(バージョンアップとともに変化する可能性があります)
6. 地域限定番組を指定
   - 地域を指定します
   - 指定可能な地域は`conf/keyword.conf`に記載されています(バージョンアップとともに変化する可能性があります)
7. テレビ局を指定
   - テレビ局を指定します
   - 指定可能なテレビ局は`conf/keyword.conf`に記載されています(バージョンアップとともに変化する可能性があります)
8. 放送曜日を指定
   - 放送曜日を指定します
   - 指定可能な曜日は`conf/keyword.conf`に記載されています(バージョンアップとともに変化する可能性があります)
9. 番組名を指定
    - 番組名のみにヒットするフリーワード検索です
    - 「title/ちびまる子ちゃん」のように指定します
10. フリーワード検索
    - 上記のいずれにも該当しない番組をフリーワードで指定できますが、検索結果の精度はTVerのみぞ知るところです
    - 番組名だけでなくタレント名なども検索の対象になるようですが、詳細な検索対象は不明です

## ダウンロード対象外の番組の設定方法

`conf/ignore.conf`をテキストエディターで開いて、ダウンロードしたくない番組名を設定します。

- ダウンロード条件にマッチする動画は全てダウンロードされるので、場合によってはダウンロードしたくない番組もまとめてダウンロードされます。そのような時には個別にダウンロード対象外に指定できます。

## 環境設定方法

### ユーザ設定

ユーザ設定は`conf/user_setting.ps1`をテキストエディターで開いて行ってください。

- `$script:downloadBaseDir`には動画をダウンロードするフォルダを設定します。
- `$script:downloadWorkDir`には動画をダウンロードするさいにできる中間ファイルを格納するフォルダを設定します。
- `$script:saveBaseDir`にはダウンロードした動画を移動する先のフォルダを設定します。
  - ここで設定したフォルダ配下(再帰的にチェックします)にあるフォルダと`$script:downloadBaseDir`にあるフォルダが一致する場合、動画ファイルが`$script:downloadBaseDir`から`$script:saveBaseDir`配下の各フォルダ配下に移動されます。同名のファイルがある場合は上書きされます。
- `$script:parallelDownloadFileNum`は同時に並行でダウンロードする動画の数を設定します。
- `$script:parallelDownloadNumPerFile`はそれぞれの動画をダウンロードする際の並行ダウンロード数を設定します。
  - つまり、`$script:parallelDownloadFileNum`×`$script:parallelDownloadNumPerFile`が実質的な最大同時ダウンロード数になります。
- `$script:windowShowStyle`にはyoutube-dlのウィンドウをどのように表示するかを設定します。
  - `Normal` / `Maximized` / `Minimized` / `Hidden` の4つが指定可能です。
  - 初期値は`Hidden`でダウンロードウィンドウは非表示となりますが、`Normal`等に設定することでダウンロードの進捗を確認することができます。
- `$script:forceSoftwareDecodeFlag`に`$true`を設定するとハードウェアアクセラレーションを使わなくなります。
  - 高速なCPUが搭載されている場合はハードウェアアクセラレーションよりもCPUで処理したほうが処理が早い場合があります。
- `$script:ffmpegDecodeOption`に直接ffmpegのオプションを記載することでハードウェアアクセラレーションを有効化できます。
  - 例えばIntel CPUを搭載した一般的なPCであれば、`'-hwaccel qsv -c:v h264_qsv'`を設定することで、CPU内蔵のアクセラレータを使ってCPU負荷を下げつつ高速に処理することが可能です。
  - この設定は`$script:forceSoftwareDecodeFlag`が`$true`に設定されていると無効化されます。

### システム設定

より細かく設定を変更したい場合は`conf/system_setting.ps1`をテキストエディターで開いてシステム設定を行ってください。(通常は必要ありません)

- `$script:appVersion`はアプリケーションのバージョンです。
  - ここを変えても表示が変わるだけで機能が変わるわけではありません。
  - 現時点ではバージョン表記をする以外には使われておりません。
- `$VerbosePreference`や`$DebugPreference`を設定することで、より詳細な情報が画面に出力されます。
  - 設定可能な値はGoogleしてください。PowerShellの設定がそのまま使えます。
- `$script:fileNameLengthMax`はOSやファイルシステムが許容するファイル名の最大長をバイト指定で記載します。
- 一般的なWindows環境では特に変更する必要はありません。
  - ここで指定した長さを超えるファイル名が生成されそうになると、ファイル名が収まるように自動的にファイル名が短縮されます。
  - なので、あまり深い階層を保存先に指定すると頻繁にファイル名が短縮されたり、エラーとなることがあります。
- `$script:binDir`、`$script:dbDir`は各種フォルダの設定です。
  - ソースファイルから見た際の相対パス指定となるようにしてください。
- `$script:keywordFilePath`、`$script:ignoreFilePath`はそれぞれダウンロード対象キーワードとダウンロード対象外番組を設定するファイルの名前です。
- `$script:listFilePath`はダウンロードの未済管理をするファイルの名前です。
- `$script:ffpmegErrorLogPath`は動画のチェックをする際にエラーを一時的に出力するファイルのパスです。
  - 初期値では`$script:listFilePath`と同じ場所に出力するようになっています。(が、処理が終われば自動的に削除されます)
- `$script:ytdlPath`と`$script:ffmpegPath`はそれぞれyoutube-dlとffmpegの実行ファイルの配置場所を指定しています。
  - ソースファイルから見た際の相対パス指定となるようにしてください。

## おすすめの使い方

- TVerのカテゴリ毎のページを指定して`win/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、フォローしているタレントや番組名を指定して`win/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、各放送局毎のページを指定して`win/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 動画ファイルの検証に時間がかかる場合、複数のPCで同時に検証を行うことで複数の動画を並行して検証できるため、検証時間を短縮できます。
  そのためには、ダウンロード先などの各フォルダを共有フォルダにして同時に複数のPCからアクセスできるようにする必要があります。

## 前提条件

Windows10とWindows11で動作確認していますが、おそらくWindows7、8でも動作します。
Windows PowerShell 5.1とPowerShell Core 7.2の双方で動作しています。おそらくそれ以外のVersionでも動作すると思います。

PowerShellはMacOS、Linuxにも移植されてるので動作します。
MacOSでもPowerShellをインストールし動作確認をしています。
([参考](https://docs.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.2))
一応、PowerShell 7.2をインストールしたRaspberry Pi OSで簡易に動作確認をしていますが、性能的にRaspberry Pi 4じゃないと厳しそうです。
([参考](https://docs.microsoft.com/ja-jp/powershell/scripting/install/install-raspbian?view=powershell-7.2))

## 実行方法

以下の手順でバッチファイルを実行してください。

1. TVerRecをダウロードして任意のディレクトリで解凍してください。
    - または、`git clone`してください。ただし、リリース版ではないため不具合が含まれている可能性があります。
2. [環境設定方法](#環境設定方法)、[ダウンロード対象の設定方法](#ダウンロード対象の設定方法)、[ダウンロード対象外の番組の設定方法](#ダウンロード対象外の番組の設定方法)を参照して環境設定、ダウンロード設定を行ってください。
3. Windows環境では `win/start_tverrec.bat`を実行してください。
    - 処理が完了しても10分ごとに永遠にループして稼働し続けます。
    - 上記でPowerShellが起動しない場合は、PowerShell の実行ポリシーのRemoteSignedなどに変更する必要があるかもしれません。
    ([参考](https://docs.microsoft.com/ja-jp/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2))
    - LinuxやMacOSも基本的に同じ使い方ですが、以下の章を参照してください。
4. TVerRecを `win/start_tverrec.bat`で起動した場合は、`win/stop_tverrec.bat`でTVerRecを停止できます。
    - 関連するダウンロード処理もすべて強制停止されるので注意してください。
    - ダウンロードを止めたくない場合は、tverecのウィンドウを閉じるボタンで閉じてください。
5. TVerRecを `win/start_tverrec.bat`で実行している各ツールを個別に起動するために、`win/a.download_video.bat` / `win/b.delete_trash.bat` / `win/c.validate_video.bat` / `win/d.move_video.bat`を使うこともできます。それぞれ、動画のダウンロドード、無視した動画やダウンロード中断時のゴミファイルの削除、ダウンロードした動画の検証、検証した動画の保存先への移動を行います。(`win/start_tverrec.bat`はこれらを自動的に、且つ無限に実行します)
6. 動画を1本ずつダウンロードしたい場合は`win/z.download_single_video.bat`を実行し、動画のURLを1本ずつ指定してください。

## Linux/Macでの利用方法

- `ffmpeg`と`youtube-dl`を`bin`ディレクトリに配置するか、シンボリックリンクを貼ってください。
  - または、`conf/system_setting.ps1`に**相対パス指定で**`ffmpeg`と`youtube-dl`のパスを記述してください。
- 上記説明の`win/*.bat`は`unix/*.sh`に読み替えて実行してください。

## フォルダ構成

```text
TVerRec/
├─ bin/ .................................. 実行ファイル格納用フォルダ
│
├─ conf/ ................................. 設定フォルダ
│  ├─ ignore.conf .......................... ダウンロード対象外設定ファイル
│  ├─ keyword.conf ......................... ダウンロード対象ジャンル設定ファイル
│  ├─ system_setting.ps1 ................... システム設定ファイル
│  └─ user_setting.ps1 ..................... ユーザ設定ファイル
│
├─ db/ ................................... データベース
│  ├─ tver.csv ............................. ダウンロードリスト
│  ├─ tver.lock ............................ 複数インスタンス起動時の排他制御用ファイル
│  └─ ffmpeg_error.log...................... ffmpegのエラーログ(処理中に作成され、自動的に削除されます)
│
├─ src/ .................................. 各種ソース
│  ├─ functions/ ........................... 各種共通関数
│  │  ├─ common_functions.ps1 ............. 共通関数定義
│  │  ├─ tver_functions.ps1 ............... TVer用共通関数定義
│  │  ├─ update_ffmpeg.ps1 ................ ffmpeg自動更新ツール
│  │  └─ update_ytdl-patched.ps1 .......... ytdl-patched自動更新ツール
│  ├─ delete_trash.ps1 ..................... ダウンロード対象外ビデオ削除ツール
│  ├─ move_vide.ps1 ........................ ビデオを保存先に移動するツール
│  ├─ tverrec_bulk.ps1 ..................... 一括ダウンロードツール本体
│  ├─ tverrec_single.ps1 ................... 単体ダウンロードツール
│  └─ validate_video.ps1 ................... ダウンロード済みビデオの整合性チェックツール
│
├─ unix/ ................................. Linux/Mac用シェルスクリプト
│  ├─ a.download_video.sh .................. 一括ダウンロードするシェルスクリプト
│  ├─ b.delete_video.sh .................... ダウンロード対象外ビデオ・中間ファイル削除シェルスクリプト
│  ├─ c.validate_video.sh .................. ダウンロード済みビデオの整合性チェックシェルスクリプト
│  ├─ d.move_video.sh ...................... ビデオを保存先に移動するシェルスクリプト(もし必要であれば)
│  ├─ z.download_single_video.sh ........... ビデオを1本ずつダウンロードするシェルスクリプト
│  ├─ start_tverrec.sh ..................... 無限一括ダウンロード起動シェルスクリプト
│  └─ stop_tverrec.sh ...................... 無限一括ダウンロード終了シェルスクリプト
│
├─ win/ .................................. Windows用BATファイル
│  ├─ a.download_video.bat ................. 一括ダウンロードするBAT
│  ├─ b.delete_video.bat ................... ダウンロード対象外ビデオ・中間ファイル削除BAT
│  ├─ c.validate_video.bat ................. ダウンロード済みビデオの整合性チェックBAT
│  ├─ d.move_video.bat ..................... ビデオを保存先に移動するBAT(もし必要であれば)
│  ├─ z.download_single_video.bat .......... ビデオを1本ずつダウンロードするBAT
│  ├─ start_tverrec.bat .................... 無限一括ダウンロード起動BAT
│  └─ stop_tverrec.bat ..................... 無限一括ダウンロード終了BAT
│
├─ CHANGELOG.md ............................. 変更履歴
├─ LICENSE .................................. ライセンス
├─ README.md ................................ このファイル
├─ TODO.md .................................. 今後の改善予定のリスト
└─ VERSION .................................. バージョン表記用ファイル
```

## アンインストール方法

- レジストリとかめんどくさいものは一切使っていないでの、不要になったらゴミ箱に捨てれば良いです。

## 注意事項

- 著作権について
  - このプログラムの著作権は dongaba が保有しています。
- 事故、故障など
  - 本ツールを使用して起こった何らかの事故、故障などの責任は負いかねますので、ご使用の際はこのことを承諾したうえでご利用ください。

## ライセンス

- TVerRecは[Apache License, Version 2.0のライセンス規約](http://www.apache.org/licenses/LICENSE-2.0)に基づき、複製や再配布、改変が許可されます。

Copyright(c) 2022 dongaba All Rights Reserved.
