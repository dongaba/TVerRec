# Change Log

## [2.7.6](https://github.com/dongaba/TVerRec/releases/tag/v2.7.6)

### 2.7.6 Added

- Windows 環境向けに GUI 画面を追加(予定)

### 2.7.6 Changed

- 移動先フォルダを複数指定した際に区切り文字前後にスペースがあっても動作するように
- 文言の微調整
- アプリロゴの変更

### 2.7.6 Fixed

- 個別ダウンロードで TVer の番組 URL 以外を入力した際に無限ループになっていた問題を修正
- ffmpeg と youtube-dl のバー助演チェックに失敗する場合がある問題を修正

## [2.7.5](https://github.com/dongaba/TVerRec/releases/tag/v2.7.5)

### 2.7.5 Added

### 2.7.5 Changed

### 2.7.5 Fixed

- 整合性チェックに失敗した履歴の削除ができなかった問題を修正

## [2.7.4](https://github.com/dongaba/TVerRec/releases/tag/v2.7.4)

### 2.7.4 Added

### 2.7.4 Changed

### 2.7.4 Fixed

- 整合性チェックに失敗した履歴の削除ができなかった問題を修正

## [2.7.3](https://github.com/dongaba/TVerRec/releases/tag/v2.7.3)

### 2.7.3 Added

### 2.7.3 Changed

- ダウンロードリスト作成時に、すでにダウンロード履歴ファイルにある番組を除外するように変更
- ダウンロードの進行状況がわかるように、Windows 環境における youtube-dl や ffmpeg のウィンドウ表示を「最小化」を初期値に変更
- ダウンロード履歴の重複削除のロジックを変更(videoPage で単一のものを残すように)

### 2.7.3 Fixed

- ファイルの削除処理の並列化でファイルが削除されないことがあるので廃止
- ファイルの移動処理の並列化でファイルが移動されないことがあるので廃止
- 「.」で終わる番組名のダウンロード不具合を修正
- チェック対象に同一のファイル名が複数ある際の整合性チェックを改善

## [2.7.2](https://github.com/dongaba/TVerRec/releases/tag/v2.7.2)

### 2.7.2 Added

- リストファイル 0 件時のエラー処理追加

### 2.7.2 Changed

- 並列処理時に逐次進捗を表示するように変更
- Google Colab 用のテンプレートを複数 Cell に分割
- Google Colab 用のテンプレートに Google Drive をマウントする処理を追加
- Write-Host の廃止
- TVer の仕様変更に伴いダウンロード履歴の重複削除ロジックを変更
- 動画ファイルの簡易検証実行する際に必ずエラーになってした不具合を修正

### 2.7.2 Fixed

- ytdl-patched の自動更新でエラーメッセージの間違いを修正
- ffmpeg の自動更新で ffprobe のダウンロード不具合を修正
- リストダウンロードでダウンロード済判定の不具合を修正

- ## [2.7.1](https://github.com/dongaba/TVerRec/releases/tag/v2.7.1)

### 2.7.1 Added

- Google Colab 用のテンプレートを追加

### 2.7.1 Changed

### 2.7.1 Fixed

- Docker コンテナ版の設定ファイル不備を修正
- ダウンロード対象外リストが 0 件の際にエラーとなる不具合を修正

## [2.7.0](https://github.com/dongaba/TVerRec/releases/tag/v2.7.0)

### 2.7.0 Added

- Docker コンテナの作成に対応
- TVerRec の自動アップデート機能を追加
- Mac/Linux 環境向けの ffmpeg 自動更新機能を追加
- Windows 環境で Zone Identifier 削除機能を追加

### 2.7.0 Changed

- ソースコード内の Path 表記を Unix 形式に統一
- ソースコードの折り返しを極力短く
- bat ファイルを cmd ファイルに変更
- cmd ファイル以外を BOM なし UTF-8、LF に統一
- `$script:addEpisodeNumber` のデフォルト値を `$true` に変更
- `$script:removeSpecialNote` のデフォルト値を `$true` に変更
- ダウンロード対象外番組判定を高速化(対象外判定されたキーワードを優先的に判定)
- ファイルの削除処理の並列化(環境によっては高速化)
- ファイルの移動処理の並列化(環境によっては高速化)
- 番組移動先ディレクトリ`$script:saveBaseDir`に複数ディレクトリを指定可能に
- `keyword.sample.conf`の初期状態をすべてコメントアウトに

### 2.7.0 Fixed

- Linux 環境で nohup のエラーメッセージが出ないように修正
- Windows 環境で WindowsTerminal.exe で実行されたプロセスが終了されない問題を修正
- 特殊文字を含むダンロード対象外判定が正しく実行されていなかった不具合を修正
- 個別ダウンロード処理が終了しない不具合を修正

## [2.6.9](https://github.com/dongaba/TVerRec/releases/tag/v2.6.9)

3 件のプルリクを取り込み

### 2.6.9 Added

### 2.6.9 Changed

- youtube-dl に ffmpeg の Path を渡すように変更

### 2.6.9 Fixed

- TV 局毎のディレクトリに保存している際に、番組を最終移動先に正しく移動できるように修正
- youtube-dl の実行監視の不具合を修正

## [2.6.8](https://github.com/dongaba/TVerRec/releases/tag/v2.6.8)

### 2.6.8 Added

### 2.6.8 Changed

### 2.6.8 Fixed

- v2.6.7 で追加した 2 つの BAT ファイルの改行コードが不正だった問題を修正

## [2.6.7](https://github.com/dongaba/TVerRec/releases/tag/v2.6.7)

### 2.6.7 Added

### 2.6.7 Changed

- シーズン名の取得方法を変更(複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがあるため)
- ネット界隈で設定が難しいと指摘があったので`system_settings.ps1`に追加の説明を記載
- シリーズ名がシーズン名を含む場合はシーズン名をクリア

### 2.6.7 Fixed

- Readme の Wiki へのリンク切れを修正

## [2.6.6](https://github.com/dongaba/TVerRec/releases/tag/v2.6.6)

### 2.6.6 Added

- エピソード番号を取得しファイル名に付加する機能を追加(下位互換性担保のため初期値はオフ)
- 番組名に付く「《」と「》」で挟まれたコメント(補足情報?)を削除する機能を追加(下位互換性担保のため初期値はオフ)
- ダウンロード履歴ファイルの破損レコードを削除する機能を追加
- キーワードから番組リストを出力する機能を追加

### 2.6.6 Changed

- Readme を修正、更新
- 用語の統一(ビデオ、番組を番組に統一、など)
- シーズン名が「本編」の場合にシーズン名をクリア
- 一部特殊文字の扱いを変更(削除や半角変換をせず全角で出力)
- 機能追加に伴い、変数名やファイル名を変更

### 2.6.6 Fixed

- youtube-dl の仕様により一部特殊文字を含む番組がダウンロードされなかった問題を修正
- 処理済み番組本数のカウントが不正だった問題を修正

## [2.6.5](https://github.com/dongaba/TVerRec/releases/tag/v2.6.5)

### 2.6.5 Added

### 2.6.5 Changed

- Readme を少し修正

### 2.6.5 Fixed

- v2.6.4 で個別ダウンロードの修正を漏らしていた[不具合](https://github.com/dongaba/TVerRec/issues/22)を修正

## [2.6.4](https://github.com/dongaba/TVerRec/releases/tag/v2.6.4)

### 2.6.4 Added

### 2.6.4 Changed

- ファイル I/O の削減による大幅高速化(条件により最大で数十～数百倍)
- ダウンロード対象外との照合を高速化

### 2.6.4 Fixed

## [2.6.3](https://github.com/dongaba/TVerRec/releases/tag/v2.6.3)

### 2.6.3 Added

### 2.6.3 Changed

### 2.6.3 Fixed

- youtube-dl のプロセス数取得の[不具合](https://github.com/dongaba/TVerRec/issues/21)を修正

## [2.6.2](https://github.com/dongaba/TVerRec/releases/tag/v2.6.2)

### 2.6.2 Added

### 2.6.2 Changed

- ハングアップ対策として Web アクセスにタイムアウトを設定(system_setting.ps1 で秒数を指定可能)
- Linux での youtube-dl の多重度チェックをより正確に
- エラーハンドリングの改善
- TVer 側の仕様変更により、番組名検索を廃止
- Windows での 処理の高速化

### 2.6.2 Fixed

- ダウンロード先ディレクトリが空の際にエラーとなる問題を修正
- Linux と Mac でファイル名・ディレクトリ名に使えない文字のチェックが不完全だったのを修正

## [2.6.1](https://github.com/dongaba/TVerRec/releases/tag/v2.6.1)

### 2.6.1 Added

### 2.6.1 Changed

### 2.6.1 Fixed

- youtube-dl の多重度チェックが正しく機能せず youtube-dl を無限に起動していた問題修正

## [2.6.0](https://github.com/dongaba/TVerRec/releases/tag/v2.6.0)

### 2.6.0 Added

### 2.6.0 Changed

### 2.6.0 Fixed

- `system_setting.ps1`に Typo があったのを修正

## [2.5.9](https://github.com/dongaba/TVerRec/releases/tag/v2.5.9)

### 2.5.9 Added

### 2.5.9 Changed

### 2.5.9 Fixed

- `$script:saveBaseDir`で指定されるディレクトリが空の際にエラーとなる[問題](https://github.com/dongaba/TVerRec/issues/19)を修正

## [2.5.8](https://github.com/dongaba/TVerRec/releases/tag/v2.5.8)

### 2.5.8 Added

### 2.5.8 Changed

### 2.5.8 Fixed

- Linux 用の番組移動先先ディレクトリの指定が間違っている[問題](https://github.com/dongaba/TVerRec/issues/18)を修正

## [2.5.7](https://github.com/dongaba/TVerRec/releases/tag/v2.5.7)

### 2.5.7 Added

- PowerSehll Core がインストールされていない Windows で実行した場合に、PowerShell を自動でインストールするか確認する機能を追加

### 2.5.7 Changed

- Windows PowerShell のサポートを終了(Windows PowerShell に起因する不具合が多いため。ご理解ください)

### 2.5.7 Fixed

## [2.5.6](https://github.com/dongaba/TVerRec/releases/tag/v2.5.6)

### 2.5.6 Added

### 2.5.6 Changed

- 標準の youtoube-dl を yt-dlp に変更
- 番組検証時のデコードオプションが設定されている際のメッセージの色を変更
- ソースコードの可読性を向上
- 番組検証時に検証結果を OK/NG で表示するように変更
- Linux で一括ダウンロードを即時再実行できるように変更

### 2.5.6 Fixed

- Linux で youtoube-dl の指定を yt-dlp にした際に、同時多重ダウンロードの上限が効いていなかった問題を修正
- 一部 Linux 環境で youtuve-dl の実行に失敗する問題の修正
- サンプルファイルの名称設定ミスを修正
- トップページの特集ページの処理のバグを修正

## [2.5.5](https://github.com/dongaba/TVerRec/releases/tag/v2.5.5)

### 2.5.5 Added

### 2.5.5 Changed

- TVerRec のバージョンアップチェック機能を改良
- コンソールウィンドウ内のプログレスバーを廃止
- コンソール表示を簡素化
- PowerShell Core の存在チェックを改良(Microsoft Store 版も判定可能に)
- ソースコードのリファクタリング
- 番組移動時に空ディレクトリを削除しない仕様に変更

### 2.5.5 Fixed

- ゴミファイルの削除が不完全な場合がある問題を修正
- ダウンロード対象外に入っている番組がダウンロードされることがある問題を修正

## [2.5.4](https://github.com/dongaba/TVerRec/releases/tag/v2.5.4)

### 2.5.4 Added

### 2.5.4 Changed

- Powershell Desktop で放送日のパースに失敗する問題を修正

### 2.5.4 Fixed

## [2.5.3](https://github.com/dongaba/TVerRec/releases/tag/v2.5.3)

### 2.5.3 Added

### 2.5.3 Changed

- 関数の引数チェックを厳密するように変更
- PowerShell Core が使える際には、PowerShell Desktop 用のファイルを生成しないように変更 (Windows 限定)
- バージョンアップ時に設定ファイルがクリアされないようにする
- リアルタイム配信には対応していないため、ダウンロードを試みないように変更
- 番組説明の取得用 URL の動的変化に対応
- ファイル名を生成する際に全角ピリオドも半角に変更するように変更

### 2.5.3 Fixed

- 空白を含むタイトル検索が正しく処理できていなかった問題を修正
- バージョンアップ通知が正しくされていなかった問題を修正

## [2.5.2](https://github.com/dongaba/TVerRec/releases/tag/v2.5.2)

### 2.5.2 Added

### 2.5.2 Changed

### 2.5.2 Fixed

- 一部変数の展開に失敗していたのを修正

## [2.5.1](https://github.com/dongaba/TVerRec/releases/tag/v2.5.1)

### 2.5.1 Added

- バージョンアップ時にリストファイル(Keyword ファイル、Ignore ファイル)がクリアされないようにする

### 2.5.1 Changed

- TVer への API コール数を削減し高速化
- ファイルアクセスを削減し高速化
- ソースコードのリファクタリングを実施
- GEO IP のチェックの完全廃止

### 2.5.1 Fixed

- トーストメッセージの誤植を修正
- エラーメッセージの誤植を修正

## [2.5.0](https://github.com/dongaba/TVerRec/releases/tag/v2.5.0)

### 2.5.0 Added

- 新着番組リストからのダウンロード機能を追加
- ランキングからのダウンロード機能を追加

### 2.5.0 Changed

- トップページの解析を最新のトップページレイアウトに合わせて改良
- ジャンル ID などの指定による検索を変更し、タグ検索として新着番組以外からも対象を検索するように改良
- 指定可能な タグ検索 (旧 ID 検索) に使用する Tag の最新化(Keyword.conf を更新しています)
- 指定可能な TV 局の最新化(Keyword.conf を更新しています)
- 標準の youtoube-dl を ytdl-patched に変更
- ダウンロード対象外リストの判定を番組シリーズ名だけでなく番組名でも判定するように変更

### 2.5.0 Fixed

## [2.4.9](https://github.com/dongaba/TVerRec/releases/tag/v2.4.9)

### 2.4.9 Added

### 2.4.9 Changed

- youtube-dl の取得元を 2 箇所から選択できるように変更

### 2.4.9 Fixed

- 毎回 yt-dlp がダウンロードされる問題を修正

## [2.4.8](https://github.com/dongaba/TVerRec/releases/tag/v2.4.8)

### 2.4.8 Added

### 2.4.8 Changed

- トースト表示時の不要なメッセージを削減
- youtube-dl を別バージョンに差し替え

### 2.4.8 Fixed

## [2.4.7](https://github.com/dongaba/TVerRec/releases/tag/v2.4.7)

### 2.4.7 Added

### 2.4.7 Changed

### 2.4.7 Fixed

- Windows 用の起動 BAT が LOOP に失敗する不具合を修正 (泣)

## [2.4.6](https://github.com/dongaba/TVerRec/releases/tag/v2.4.6)

### 2.4.6 Added

### 2.4.6 Changed

### 2.4.6 Fixed

- Windows 用の起動 BAT が LOOP に失敗する不具合を修正

## [2.4.5](https://github.com/dongaba/TVerRec/releases/tag/v2.4.5)

### 2.4.5 Added

- Windows 向けトースト通知機能を追加

### 2.4.5 Changed

- バージョンアップ時にダウンロード履歴ファイルが上書きされないように修正
- Windows の一括実行 BAT でキーボード入力による終了処理を追加

### 2.4.5 Fixed

- Windows PowerShell 環境でダウンロードファイルの移動に失敗する不具合を修正

## [2.4.4](https://github.com/dongaba/TVerRec/releases/tag/v2.4.4)

### 2.4.4 Added

- ハートビート機能を追加

### 2.4.4 Changed

- ライセンスを Apache 2 ライセンスから MIT ライセンスに変更

### 2.4.4 Fixed

- ダウンロード履歴の引き落としがされない問題を修正

## [2.4.3](https://github.com/dongaba/TVerRec/releases/tag/v2.4.3)

### 2.4.3 Added

- ツールの自動アップデートを無効化するオプションを追加(「$true」で無効化。いずれも初期値は$false)
  - youtube-dl の自動アップデートを無効化 $script:disableUpdateYoutubedl = $true
  - ffmpeg の自動アップデートを無効化$script:disableUpdateFfmpeg = $true

### 2.4.3 Changed

### 2.4.3 Fixed

## [2.4.2](https://github.com/dongaba/TVerRec/releases/tag/v2.4.2)

### 2.4.2 Added

- 番組検証の高速化オプションを 2 つ追加(「$true」で高速化。いずれも初期値は$false)
  - ffprobe を使った簡易検証 $script:simplifiedValidation = $true
  - 番組検証を全く行わない $script:disableValidation = $true
- 放送局ごとのディレクトリを作ってからダウンロードするオプションを追加(「$true」で有効化。初期値は$false)

### 2.4.2 Changed

- ダウンロードファイル検証時の冗長なメッセージを削除

### 2.4.2 Fixed

- ステータスバーが表示されない問題を修正

## [2.4.1](https://github.com/dongaba/TVerRec/releases/tag/v2.4.1)

### 2.4.1 Added

### 2.4.1 Changed

- user_setting.ps1 に Mac や Linux 用の指定方法を追加

### 2.4.1 Fixed

- Linux/Mac で youtube-dl がダウンロードされない問題を修正
- Windows Power Shell で不要ファイル削除機能でエラーとなっていた問題を修正

## [2.4.0](https://github.com/dongaba/TVerRec/releases/tag/v2.4.0)

### 2.4.0 Added

- TVer のトップページに表示される番組をダウンロードするキーワード「toppage」を追加

### 2.4.0 Changed

- Invoke-WebRequest のプログレスバーを非表示に変更

### 2.4.0 Fixed

- youtube-dl がダウンロードされない問題を修正
- ffmpeg がダウンロードされない問題を修正
- 一部ファイルの読み込みに失敗していた問題を修正

## [2.3.9](https://github.com/dongaba/TVerRec/releases/tag/v2.3.9)

### 2.3.9 Added

- TVerRec 自身のバージョンチェック機能を追加

### 2.3.9 Changed

- `src`ディレクトリ内の構成を変更
- 設定ファイルの拡張子を変更
- Windows PowerShell 環境用のソースコードの精製方法を変更

### 2.3.9 Fixed

- Invoke-Expression の使用を中止
- ffmpegErrorLog のゴミが削除されなかった不具合を修正
- ffmpeg の Mac/Linux 向けダウンロード機能が失敗する不具合を修正
- Windows PowerShell 環境での複数のバグを修正

## [2.3.8](https://github.com/dongaba/TVerRec/releases/tag/v2.3.8)

### 2.3.8 Added

- TVer のリニューアルによりフリーワード検索の精度が大幅に下がっていますので、できればタレント ID 指定、番組 ID 指定でダウンロードしたほうが確実です。
- 同様にジャンル指定の精度も大幅に下がっているようですのでご注意ください。

### 2.3.8 Changed

- `conf/keyword.conf`をテキストエディターで開いてダウンロード対象のタレントの名前や番組名、ジャンル、TV 局などを設定します
  - 不要なキーワードは `#` でコメントアウトするか削除してください。
  - 主なジャンルは網羅しているつもりですが、不足があるかもしれませんので、必要に応じて適宜自分で補ってください。
  - ダウンロード対象の指定の方法はいくつかありますが、現在のところ a と b が確実にダウンロードする方法です。c と d と e は TVer の検索機能が改善されるまで番組を取りこぼす可能性や不要な番組が山ほどダウンロードされる可能性が高いです。
    1. **タレント ID 指定**(番組 ID は TVer のサイトで確認できます)
    2. **番組 ID 指定**(番組 ID は TVer のサイトで確認できます)
    3. **ジャンル指定**(事前に用意されているもののみ)
    4. **番組タイトル**のみを対象としたフリーワード検索
    5. **フリーワード指定**

### 2.3.8 Fixed
