# :tv:**TVerRec**:tv: - TVer 一括ダウンロード・保存・録画 -

[![Logo](https://raw.githubusercontent.com/dongaba/TVerRec/master/img/TVerRec.png)](#readme)

[![GitHub release](https://img.shields.io/github/v/release/dongaba/TVerRec?color=blue)](https://github.com/dongaba/TVerRec/releases)
[![License](https://img.shields.io/github/license/dongaba/TVerRec?color=blue)](https://opensource.org/licenses/MIT)
[![CodeFactor](https://www.codefactor.io/repository/github/dongaba/tverrec/badge)](https://www.codefactor.io/repository/github/dongaba/tverrec)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/1b42499be57b48818db8c3c90d73adb3)](https://app.codacy.com/gh/dongaba/TVerRec/dashboard)
[![DevSkim](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/devskim.yml)
[![PSScriptAnalyzer](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml/badge.svg)](https://github.com/dongaba/TVerRec/actions/workflows/powershell.yml)
[![TVerRec Launched](https://hits.sh/github.com/dongaba/TVerRec/launch.svg?view=today-total&color=9f9f9f&label=TVerRec%20Launched)](https://hits.sh/github.com/dongaba/TVerRec/launch)
[![Video Searched](https://hits.sh/github.com/dongaba/TVerRec/search.svg?view=today-total&color=9f9f9f&label=Video%20Searched)](https://hits.sh/github.com/dongaba/TVerRec/search)
[![Video Downloaded](https://hits.sh/github.com/dongaba/TVerRec/download.svg?view=today-total&color=9f9f9f&label=Video%20Downloaded)](https://hits.sh/github.com/dongaba/TVerRec/download)
[![Video Validated](https://hits.sh/github.com/dongaba/TVerRec/validate.svg?view=today-total&color=9f9f9f&label=Video%20Validated)](https://hits.sh/github.com/dongaba/TVerRec/validate)

TVerRec は、動画配信サイト TVer ( ティーバー <https://tver.jp/> ) の動画を録画保存するためのダウンローダー、ダウンロード支援ツールです。

- Windows/MacOS/Linux で動作します。
- 必要なツールは自動的にダウンロードされますが、うまくいかない場合は以下から取得してください。
  - yt-dlp [https://github.com/yt-dlp/yt-dlp/releases]
  - ffmpeg [https://www.ffmpeg.org/download.html]
- 検索機能を改良したので、タグ検索機能を使うことでほぼ確実に録画可能となりました。
- 番組名検索・フリーワード検索の精度は依然としてそれほど高くないのでご注意ください。

## ざっくり以下のようなことができます

1. 動画の**ジャンル**や**出演タレント**、**番組名**などの**キーワード指定**して**一括ダウンロード**します。
   - **CM は入っていない**ため気に入った番組を配信終了を気にすることなくいつまでも保存しておくことができます。
   - TVerRec はループ実行するようになっているので、**1 回起動すれば新しい番組が配信される都度自動でダウンロード、録画、保存**されるようになります。
2. TVer の**全録画**が可能です。
   - ちまちま URL をコピペしたり画面録画する必要はなく、起動して放置するだけの全自動録画です。控えめに言って最高です。
3. TVer の動画**サムネイルを動画ファイルに埋め込み**ます。
4. 字幕データが TVer にある場合は、**字幕情報も動画に埋め込み**ます。
5. 並列ダウンロードによる**高速ダウンロードが可能**です。(デフォルト設定で 5 ファイル同時ダウンロード、1 ファイルあたり 10 並列ダウンロード、合計最大 50 並列ダウンロード)
6. もちろん動画を**1 本ずつ指定したダウンロードも可能**です。
   - なかには全録なんかしてられねーよ、という方もいらっしゃることでしょう。安心してください。
   - 動画の URL を指定することでダウンロードしたい動画を 1 本ずつ指定することも可能です。
7. また、ダウンロード保存した動画が正常に再生できるかどうか**動画が壊れていないかの検証**も行います。
   - もし動画ファイルが壊れている場合には自動的に再ダウンロードします。
   - 動画の検証時に ffmpeg を使用しますが、ハードウェアアクセラレーションを使えば、CPU 使用率を抑えることができます。(使用する PC での性能によっては処理時間が長くなることがあります。その場合はハードウェアアクセラレーションを無効化できます)
8. ダウンロードされたファイルは、最終保存先に**自動的に整理**可能です。
   - 例えば毎週同じ番組をダウンロードする場合、最終保存先に番組名のフォルダがあれば自動的に全番組が最終保存先のフォルダに移動されます。
   - 最終保存先に同名のフォルダがなければ、動画ファイルは保存先フォルダに残り続けます。
9. 動作に必要な youtube-dl や ffmpeg などの必要コンポーネントは**自動的に最新版がダウンロード**されます。(ffmpeg の自動ダウンロードは Windows のみ)
10. **日本国外からも VPN 不要**で利用することができます。

## ダウンロード対象番組の設定方法

`conf/keyword.conf`をテキストエディターで開いてダウンロード対象のタレントや番組、ジャンル、TV 局などを設定します。
`conf/keyword.conf`が存在しない場合は`conf/keyword.sample.conf`をコピーして`conf/keyword.conf`を作成することができます。
(手作業でコピーしなくても初回起動時に自動的にサンプルファイルをコピーして作成されますが、そのままだと TVer の全動画がダウンロードされてしまうのでご注意ください。)

- 不要なキーワードは `#` でコメントアウトするか削除してください。
- 主なジャンルは網羅しているつもりですが、不足があるかもしれませんので、必要に応じて適宜自分で補ってください。
- ダウンロード対象の指定の方法はいくつかあります。

1. 番組 ID を指定
   - 番組 ID を指定します
   - 番組 ID は、TVer で番組ページを検索した際の URL に含まれる「series/srxxxxxxxx」です
   - 毎週チェックしている番組がある際に便利ですね
2. タレント ID を指定
   - タレント ID を指定します
   - タレント ID は、TVer でタレントページを検索した際の URL に含まれる「talents/txxxxxx」です
   - 推しの出演番組を漏らさずダウンロードしちゃいましょう
3. タグを指定
   - タグは、`conf/keyword.sample.conf`に記載されている「tag/txxxxxx」です
   - 指定可能なタグは`conf/keyword.sample.conf`に記載されています(バージョンアップとともに変化する可能性があります)
   - 以下のような指定が可能です。
     1. ジャンルを指定: ジャンルを指定します
     2. 地域限定番組を指定: 地域を指定します
     3. テレビ局を指定: テレビ局を指定します
     4. 放送曜日を指定: 放送曜日を指定します
   - ジャンル指定以外はあんまり使い道ないかもしれないですね
4. 新着をダウンロード
   - 新着ビデオの種類を指定します
   - 指定可能な種類は`conf/keyword.sample.conf`に記載されています(バージョンアップとともに変化する可能性があります
5. ランキングを指定
   - ランキングの種類を指定します
   - 指定可能な種類は`conf/keyword.sample.conf`に記載されています(バージョンアップとともに変化する可能性があります
   - 話題になっている番組をチェックしたい場合にどうぞ
6. トップページを指定
   - TVer のトップページに表示される動画を可能な限りダウンロードします
   - TVer のトップページに表示されている動画がシリーズ物の場合、シリーズの動画すべてをダウンロードしようとします
   - ニーズがあるかわかりませんが一応作っておきました
7. 番組名を指定
   - 番組名のみにヒットするフリーワード検索です
   - 「title/ちびまる子ちゃん」のように指定します
   - 珠にしか放送されない番組でSeries IDがわからない場合や、番組名のキーワード検索に便利です
8. フリーワード検索
   - 上記のいずれにも該当しない番組をフリーワードで指定できますが、検索結果の精度は TVer のみぞ知るところです
   - 番組名だけでなくタレント名なども検索の対象になるようですが、詳細な検索対象は不明です
   - あまり精度良くないですが、とりあえず多めにダウンロードしておきたい方はどうぞ

## ダウンロード対象外の番組の設定方法

`conf/ignore.conf`をテキストエディターで開いて、ダウンロードしたくない番組名を設定します。
`conf/ignore.conf`が存在しない場合は`conf/ignore.sample.conf`をコピーして`conf/ignore.conf`を作成することができます。
(手作業でコピーしなくても初回起動時に自動的にサンプルファイルをコピーして作成されます。)

- ダウンロード条件にマッチする動画は全てダウンロードされるので、場合によってはダウンロードしたくない番組もまとめてダウンロードされます。そのような時には個別にダウンロード対象外に指定できます。

## 環境設定方法

### アプリの設定

アプリの設定は`conf/user_setting.ps1`をテキストエディターで開いて行ってください。(存在しない場合は`conf/system_setting.ps1`をコピーして作成してください)

- `$script:downloadBaseDir`には動画をダウンロードするフォルダを設定します。
- `$script:downloadWorkDir`には動画をダウンロードするさいにできる中間ファイルを格納するフォルダを設定します。
- `$script:saveBaseDir`にはダウンロードした動画を移動する先のフォルダを設定します。
  - ここで設定したフォルダ配下(再帰的にチェックします)にあるフォルダと`$script:downloadBaseDir`にあるフォルダが一致する場合、動画ファイルが`$script:downloadBaseDir`から`$script:saveBaseDir`配下の各フォルダ配下に移動されます。同名のファイルがある場合は上書きされます。
- `$script:parallelDownloadFileNum`は同時に並行でダウンロードする動画の数を設定します。
- `$script:parallelDownloadNumPerFile`はそれぞれの動画をダウンロードする際の並行ダウンロード数を設定します。
  - つまり、`$script:parallelDownloadFileNum`×`$script:parallelDownloadNumPerFile`が実質的な最大同時ダウンロード数になります。
- `$script:sortVideoByMedia`は放送局(テレビ局)ごとのフォルダを作って動画をダウンロードするかを設定します。

  - `$false`の場合の保存先は以下のようになります

        ダウンロード先\
          └動画シリーズ名 動画シーズン名\
            └動画シリーズ名 動画シーズン名 放送日 動画タイトル名.mp4

  - `$true`の際の保存先は以下のようになります

        ダウンロード先\
          └放送局\
            └動画シリーズ名 動画シーズン名\
              └動画シリーズ名 動画シーズン名 放送日 動画タイトル名.mp4

- `$script:windowShowStyle`には youtube-dl のウィンドウをどのように表示するかを設定します。

  - `Normal` / `Maximized` / `Minimized` / `Hidden` の 4 つが指定可能です。
  - 初期値は`Hidden`でダウンロードウィンドウは非表示となりますが、`Normal`等に設定することでダウンロードの進捗を確認することができます。

- `$script:forceSoftwareDecodeFlag`に`$true`を設定すると、動画検証時にハードウェアアクセラレーションを使わなくなります。

  - 高速な CPU が搭載されている場合はハードウェアアクセラレーションよりも CPU で処理したほうが処理が早い場合があります。

- `$script:ffmpegDecodeOption`に直接 ffmpeg のオプションを記載することで動画検証時にハードウェアアクセラレーションを有効化できます。

  - 例えば Intel CPU を搭載した一般的な PC であれば、`'-hwaccel qsv -c:v h264_qsv'`を設定することで、CPU 内蔵のアクセラレータを使って CPU 負荷を下げつつ高速に処理することが可能です。
  - この設定は`$script:forceSoftwareDecodeFlag`が`$true`に設定されていると無効化されます。

- 動画検証の高速化オプションとして、他にも以下の 2 つがあります。

  - `$script:simplifiedValidation`は検証を簡素化するかどうかを設定します。
    - `$false`(初期値)を設定すると、ffmpeg を使って動画の検証を行います。PC の性能にもよりますが動画の長さの数分の 1 から数倍の時間がかかりますが、検証精度は非常に高いです。(全フレームがデコードできるか確認している模様)
    - `$true`を設定することで、ffmpeg による動画の完全検証ではなく、ffprobe による簡易検証に切り替えます。動画 1 本あたり数秒で検証が完了しますが、検証精度は低いです。(おそらくメタデータの検査だけの模様)
  - `$script:disableValidation`は検証を行わなくするかどうかを設定します。
    - `$true`を設定することで、動画の検証を完全に止めることができます。

- TVerRec の特徴の 1 つでもある youtube-dl と ffmpeg の自動アップデートですが、ツール配布元の不具合等により自動アップデートがうまく動作しない場合には無効化することが可能です。

  - `$script:disableUpdateYoutubedl`に`$true`を設定すると youtube-dl の自動アップデートが無効化されます。
  - `$script:disableUpdateFfmpeg`に`$true`を設定すると ffmpeg の自動アップデートが無効化されます。

- youtube-dl に起因する問題が起きた際には以下の 2 種類の youtube-dl を使い分けることが可能です。
  - `$script:preferredYoutubedl`に`ytdl-patched`(初期値)を設定すると [ytdl-patched](https://github.com/ytdl-patched/ytdl-patched) から取得します。こちらの方が頻繁に更新されており、不具合発生時にもすぐバグ修正される傾向があります。
  - `$script:preferredYoutubedl`に`yt-dlp`を設定すると [yt-dlp](https://github.com/yt-dlp/yt-dlp) から取得します。こちらの方が安定していますが、不具合発生時のバグ修正には時間がかかる傾向があります。

より細かく設定を変更したい場合は以下のような項目も設定変更が可能です。(通常は必要ありません)

- `$script:appVersion`はアプリケーションのバージョンです。
  - ここを変えても表示が変わるだけで機能が変わるわけではありません。
  - 現時点ではバージョン表記をする以外には使われておりません。
- `$VerbosePreference`や`$DebugPreference`を設定することで、より詳細な情報が画面に出力されます。
  - 設定可能な値は Google してください。PowerShell の設定がそのまま使えます。
- `$script:fileNameLengthMax`は OS やファイルシステムが許容するファイル名の最大長をバイト指定で記載します。
- 一般的な Windows 環境では特に変更する必要はありません。
  - ここで指定した長さを超えるファイル名が生成されそうになると、ファイル名が収まるように自動的にファイル名が短縮されます。
  - なので、あまり深い階層を保存先に指定すると頻繁にファイル名が短縮されたり、エラーとなることがあります。
- `$script:binDir`、`$script:dbDir`は各種フォルダの設定です。
  - ソースファイルから見た際の相対パス指定となるようにしてください。
- `$script:keywordFilePath`、`$script:ignoreFilePath`はそれぞれダウンロード対象キーワードとダウンロード対象外番組を設定するファイルの名前です。
- `$script:listFilePath`はダウンロードの未済管理をするファイルの名前です。
- `$script:ffpmegErrorLogPath`は動画のチェックをする際にエラーを一時的に出力するファイルのパスです。
  - 初期値では`$script:listFilePath`と同じ場所に出力するようになっています。(が、処理が終われば自動的に削除されます)
- `$script:ytdlPath`と`$script:ffmpegPath`はそれぞれ youtube-dl と ffmpeg の実行ファイルの配置場所を指定しています。
  - ソースファイルから見た際の相対パス指定となるようにしてください。

## おすすめの使い方

- TVer のカテゴリ毎のページを指定して`win/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、フォローしているタレントや番組名を指定して`win/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、各放送局毎のページを指定して`win/start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 動画ファイルの検証に時間がかかる場合、複数の PC で同時に検証を行うことで複数の動画を並行して検証できるため、検証時間を短縮できます。
  そのためには、ダウンロード先などの各フォルダを共有フォルダにして同時に複数の PC からアクセスできるようにする必要があります。

## 前提条件

Windows10 と Windows11 で動作確認しています。
おそらく Windows7、8、8.1 でも動作するような気もしますが、手元に環境がないのでサポートできません。
Windows PowerShell 5.1 と PowerShell Core 7.2 の双方で動作しています。おそらくそれ以外の Version でも動作するように思います。

PowerShell は MacOS、Linux にも移植されてるので動作します。
MacOS でも PowerShell をインストールし動作確認をしています。
([参考](https://docs.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.2))
一応、PowerShell 7.2 をインストールした Raspberry Pi OS で簡易に動作確認をしていますが、性能的に Raspberry Pi 4 じゃないと厳しそうです。
([参考](https://docs.microsoft.com/ja-jp/powershell/scripting/install/install-raspbian?view=powershell-7.2))

## 実行方法

以下の手順でバッチファイルを実行してください。

1. TVerRec をダウロードして任意のディレクトリで解凍してください。
   - または、`git clone`してください。ただし、リリース版ではないため不具合が含まれている可能性があります。
2. [環境設定方法](#環境設定方法)、[ダウンロード対象番組の設定方法](#ダウンロード対象番組の設定方法)、[ダウンロード対象外の番組の設定方法](#ダウンロード対象外の番組の設定方法)を参照して環境設定、ダウンロード設定を行ってください。
3. Windows 環境では `win/start_tverrec.bat`を実行してください。
   - 処理が完了しても 10 分ごとに永遠にループして稼働し続けます。
   - 上記で PowerShell が起動しない場合は、PowerShell の実行ポリシーの RemoteSigned などに変更する必要があるかもしれません。
     ([参考](https://docs.microsoft.com/ja-jp/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2))
   - Linux や MacOS も基本的に同じ使い方ですが、以下の章を参照してください。
4. TVerRec を `win/start_tverrec.bat`で起動した場合は、`win/stop_tverrec.bat`で TVerRec を停止できます。
   - 関連するダウンロード処理もすべて強制停止されるので注意してください。
   - ダウンロードを止めたくない場合は、tverec のウィンドウを閉じるボタンで閉じてください。
5. TVerRec を `win/start_tverrec.bat`で実行している各ツールを個別に起動するために、`win/a.download_video.bat` / `win/b.delete_trash.bat` / `win/c.validate_video.bat` / `win/d.move_video.bat`を使うこともできます。それぞれ、動画のダウンロドード、無視した動画やダウンロード中断時のゴミファイルの削除、ダウンロードした動画の検証、検証した動画の保存先への移動を行います。(`win/start_tverrec.bat`はこれらを自動的に、且つ無限に実行します)
6. 動画を 1 本ずつダウンロードしたい場合は`win/z.download_single_video.bat`を実行し、動画の URL を 1 本ずつ指定してください。
   - `win/b.validate.bat`を実行するとダウンロードできていないファイルがある場合(正確にはダウンロードしたビデオファイルが破損している場合)に、ダウンロード済みリストからダウンロード履歴を削除するので、再度ダウンロードできるようになります。
   - `win/b.delete_video.sh`を実行するとダウンロードが中断してしまった際のゴミファイルなどの掃除ができるので、定期的に実行するとディスク容量を節約できます。
   - `win/d.move_video.sh`を実行すると、動画を最終保存先に移動することも可能です。

## Linux/Mac での利用方法

- `ffmpeg`と`youtube-dl`を`bin`ディレクトリに配置するか、シンボリックリンクを貼ってください。
  - または、`conf/system_setting.ps1`に**相対パス指定で**`ffmpeg`と`youtube-dl`のパスを記述してください。
- 上記説明の`win/*.bat`は`unix/*.sh`に読み替えて実行してください。

## フォルダ構成

フォルダ構成は以下のようになっています。

    TVerRec/
    ├─ bin/ ............................. 実行ファイル格納用フォルダ (初期状態は空)
    │
    ├─ conf/ ............................. 設定
    │  ├─ ignore.conf....................... ダウンロード対象外設定ファイル(存在しない場合は起動時にサンプルファイルがコピーされます)
    │  ├─ ignore.sample.conf................ サンプルダウンロード対象外設定ファイル
    │  ├─ keyword.conf...................... ダウンロード対象ジャンル設定ファイル(存在しない場合は起動時にサンプルファイルがコピーされます)
    │  ├─ keyword.sample.conf............... サンプルダウンロード対象ジャンル設定ファイル
    │  ├─ system_setting.ps1 ............... デフォルトシステム設定ファイル
    │  └─ user_setting.ps1 ................. ユーザ設定ファイル(必要に応じて自分で作成してください)
    │
    ├─ db/ ............................... データベース
    │  ├─ tver.csv ......................... ダウンロードリスト (存在しない場合は起動時に作成されます)
    │  ├─ tver.sample.csv .................. 空のダウンロードリスト
    │  ├─ tver.lock ........................ 複数インスタンス起動時の排他制御用ファイル
    │  └─ ffmpeg_error.log.................. ffmpegのエラーログ (処理中に作成され、一定時間経過後に自動削除されます)
    │
    ├─ img/ .............................. 画像
    │  ├─ TVerRec (Large).png .............. アプリロゴ (デカいやつ)
    │  ├─ TVerRec-Square (Large).png ....... トースト通知用アプリロゴ (デカいやつ)
    │  ├─ TVerRec.png ...................... アプリロゴ
    │  └─ TVerRec-Square.png ............... トースト通知用アプリロゴ
    │
    ├─ lib/ .............................. ライブラリ
    │  └─ win .............................. Windows用ライブラリ
    │      ├─ common ......................... 共通ライブラリ用
    │      ├─ core ........................... PowerShell Core用フォルダ (配下のファイルは省略)
    │      └─ desktop ........................ Windows PowerShell用フォルダ (配下のファイルは省略)
    │
    ├─ src/ .............................. 各種ソース
    │  ├─ functions/ ....................... 各種共通関数
    │  │  ├─ common_functions.ps1 ............ 共通関数定義
    │  │  ├─ tver_functions.ps1 .............. TVer用共通関数定義
    │  │  ├─ update_ffmpeg.ps1 ............... ffmpeg自動更新ツール
    │  │  ├─ update_yt-dlp.ps1 ............... yt-dlp自動更新ツール
    │  │  └─ update_ytdl-patched.ps1 ......... ytdl-patched自動更新ツール
    │  ├─ delete_trash.ps1 ................. ダウンロード対象外ビデオ削除ツール
    │  ├─ move_vide.ps1 .................... ビデオを保存先に移動するツール
    │  ├─ tverrec_bulk.ps1 ................. 一括ダウンロードツール本体
    │  ├─ tverrec_single.ps1 ............... 単体ダウンロードツール
    │  └─ validate_video.ps1 ............... ダウンロード済みビデオの整合性チェックツール
    │
    ├─ unix/ ............................. Linux/Mac用シェルスクリプト
    │  ├─ a.download_video.sh .............. 一括ダウンロードするシェルスクリプト
    │  ├─ b.delete_video.sh ................ ダウンロード対象外ビデオ・中間ファイル削除シェルスクリプト
    │  ├─ c.validate_video.sh .............. ダウンロード済みビデオの整合性チェックシェルスクリプト
    │  ├─ d.move_video.sh .................. ビデオを保存先に移動するシェルスクリプト(もし必要であれば)
    │  ├─ z.download_single_video.sh ....... ビデオを1本ずつダウンロードするシェルスクリプト
    │  ├─ start_tverrec.sh ................. 無限一括ダウンロード起動シェルスクリプト
    │  └─ stop_tverrec.sh .................. 無限一括ダウンロード終了シェルスクリプト
    │
    ├─ win/ .............................. Windows用BATファイル
    │  ├─ a.download_video.bat ............. 一括ダウンロードするBAT
    │  ├─ b.delete_video.bat ............... ダウンロード対象外ビデオ・中間ファイル削除BAT
    │  ├─ c.validate_video.bat ............. ダウンロード済みビデオの整合性チェックBAT
    │  ├─ d.move_video.bat ................. ビデオを保存先に移動するBAT(もし必要であれば)
    │  ├─ z.download_single_video.bat ...... ビデオを1本ずつダウンロードするBAT
    │  ├─ start_tverrec.bat ................ 無限一括ダウンロード起動BAT
    │  └─ stop_tverrec.bat ................. 無限一括ダウンロード終了BAT
    │
    ├─ CHANGELOG.md ......................... 変更履歴
    ├─ LICENSE .............................. ライセンス
    ├─ README.md ............................ このファイル
    ├─ TODO.md .............................. 今後の改善予定のリスト
    └─ VERSION .............................. バージョン表記用ファイル

## アンインストール方法

- レジストリとかめんどくさいものは一切使っていないでの、不要になったらゴミ箱に捨てれば良いです。

## 注意事項

- 著作権
  - このプログラムの著作権は dongaba が保有しています。
- 免責
  - このソフトウェアを使用して発生したいかなる損害にも、作者は責任を負わないものとします。各自の自己責任で使用してください。

## ライセンス

- TVerRec は[The MIT License](https://opensource.org/licenses/MIT)に基づき、複製や再配布、改変が許可されます。

Copyright (c) dongaba. All rights reserved.
