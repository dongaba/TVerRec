# Change Log

## [3.0.3](https://github.com/dongaba/TVerRec/releases/tag/v3.0.3)

### 3.0.3 Added

### 3.0.3 Changed

- メッセージ出力フォーマットの変更
- ロックの精度を改善(ロックのメカニズムを変更)
- エラーハンドリングを改善

### 3.0.3 Fixed

- Windows 環境で GUI 版の実行ログ表示について最大行数を設定可能に
- 連続稼働時のメモリ使用量の削減
- `&amp;`が正しく置換されない不具合を修正
- Unix 時間への変換にタイムゾーンが考慮されていなかった不具合を修正
- トップページの処理でシリーズやシーズンを取得できていなかった不具合を修正

## [3.0.2](https://github.com/dongaba/TVerRec/releases/tag/v3.0.2)

### 3.0.2 Added

### 3.0.2 Changed

- 不要ファイル削除処理の可読性とパフォーマンスを向上

### 3.0.2 Fixed

- Mac と Windows/Linux 混在環境で移動処理が濁点や半濁点を含むディレクトリを取りこぼす問題を修正

## [3.0.1](https://github.com/dongaba/TVerRec/releases/tag/v3.0.1)

### 3.0.1 Added

### 3.0.1 Changed

### 3.0.1 Fixed

- サイトマップダウンロード時に内部ファイル名が表示される不具合を修正

## [3.0.0](https://github.com/dongaba/TVerRec/releases/tag/v3.0.0)

### 3.0.0 Added

- TVer の提供するエピソード番号が｢1｣のときに、適切なエピソード番号を類推して置換する機能を追加
- ダウンロードリストに番組説明を出力するオプションを追加
- アップデータ自身のアップデート機能を追加
- Docker コンテナにおける Apple Silicon のサポート

### 3.0.0 Changed

- コード最適化によるメモリ使用量の削減
- 動画移動時に子ディレクトリだけでなく配下のディレクトリ全てを移動の対象にするように変更
- dash 形式の動画を極力ダウンロードしないように変更
- log ディレクトリの新設
- Mac 混在環境でダウンロード対象外リストが NFD で記載されてしまった場合に NFC で出力するように変更
- ダウンロード対象外リストとの比較を NFC に変換して実施するように変更
- ダウンロード対象外リストとの比較でワイルドカードを処理可能に変更
- メモリ使用量削減
- トップページからのダウンロードの大幅高速化

### 3.0.0 Fixed

- GUI 版の実行ログを取りこぼすことがある不具合を修正
- Windows 環境でフォルダ指定にドライブを指定した際にエラーが発生する場合がある不具合を修正

## [2.9.9](https://github.com/dongaba/TVerRec/releases/tag/v2.9.9)

### 2.9.9 Added

### 2.9.9 Changed

### 2.9.9 Fixed

- GUI 版で「キーワードファイル」「除外リスト」「リストファイル」のクイックリンクが動作しない不具合の修正
- Tver 以外のサイトからダウンロードが出来なくなっていた不具合の修正

## [2.9.8](https://github.com/dongaba/TVerRec/releases/tag/v2.9.8)

### 2.9.8 Added

- 個別ダウンロードで TVer 以外の URL も許容する機能を追加(ただし整合性検証等の追加機能には未対応)

### 2.9.8 Changed

- CUI 版でループ処理実行時に待機残り時間を表示する機能を改善
- コードリファクタリング
- Windows 環境で winget がない場合に winget の入手先へのリンクを表示する機能を追加
- 番組の情報を引き回すためにカスタムオブジェクトを作成
- ディレクトリ体系を整理

### 2.9.8 Fixed

- ffmpeg 6.1 に対応
- Windows 環境で PowerShell 7.4.0 のバグにより整合性検証が必ず失敗する問題に対処

## [2.9.7](https://github.com/dongaba/TVerRec/releases/tag/v2.9.7)

### 2.9.7 Added

- 個別ダウンロード時にダウンロード対象外リストや履歴を無視して強制ダウンロードする機能を追加

### 2.9.7 Changed

- tver_funcitons.ps1 を分割

### 2.9.7 Fixed

- 履歴ファイルが 0 件時にリストダウンロードが失敗する問題を修正

## [2.9.6](https://github.com/dongaba/TVerRec/releases/tag/v2.9.6)

### 2.9.6 Added

### 2.9.6 Changed

### 2.9.6 Fixed

- 1 ファイルコミット漏れ

## [2.9.5](https://github.com/dongaba/TVerRec/releases/tag/v2.9.5)

### 2.9.5 Added

- CUI 版でループ処理実行時に待機残り時間を表示する機能を追加
- TVerRec の配置ディレクトリをチェックする機能を追加(スペースを含むディレクトリでは動作不可)

### 2.9.5 Changed

- 変数のスコープを調整
- 帯域制限しない設定を追加
- 設定ファイルの項目名を調整
- 一部処理の共通化とリファクタリング
- リストダウンロード処理のリファクタリング
- ダウンロードリスト作成処理のリファクタリング
- ダウンロードリスト作成処理の進捗表示を変更
- ダウンロード作成処理のマルチスレッド処理を廃止
- ダウンロード対象外ファイルとの突合処理の精度を向上
- ダウンロード対象外ファイル更新処理の信頼性を改善
- ダウンロード履歴との突合処理をリファクタリング(不具合があったかも?)

### 2.9.5 Fixed

- ffprobe の簡易検証が失敗する問題を修正
- 検証を無効化している際にループ処理が番組移動処理にいかない問題を修正
- 不要ファイル削除処理で、ダウンロード対象外リストに入っているディレクトリが削除されないことがある問題を修正
- GUI 版の設定画面で設定値に`=`を含む値の読み込み不具合を修正
- ダウンロード履歴やダウンロード対象外リストが 0 件時にエラーが出ることがある不具合を修正
- Linux/Mac 環境でホームディレクトリ配下にダウンロード先ディレクトリを設定し`~`で設定ファイルを記載している場合の不具合を修正

## [2.9.4](https://github.com/dongaba/TVerRec/releases/tag/v2.9.4)

### 2.9.4 Added

### 2.9.4 Changed

### 2.9.4 Fixed

- 個別ダウンロードが失敗する不具合を修正

## [2.9.3](https://github.com/dongaba/TVerRec/releases/tag/v2.9.3)

### 2.9.3 Added

### 2.9.3 Changed

- ダウンロード履歴がない場合のエラーメッセージを抑制

### 2.9.3 Fixed

- サイトマップからの全件ダウンロード時のパースエラーを修正
- ダウンロード対象外リストがからの場合の削除処理の不具合を修正

## [2.9.2](https://github.com/dongaba/TVerRec/releases/tag/v2.9.2)

### 2.9.2 Added

### 2.9.2 Changed

- どうやら自動アップデート機能に不具合あるようなので自動アップデートを無効化

### 2.9.2 Fixed

## [2.9.1](https://github.com/dongaba/TVerRec/releases/tag/v2.9.1)

### 2.9.1 Added

### 2.9.1 Changed

### 2.9.1 Fixed

- GUI 版も TVerRec の自動アップデートの不具合を修正(できたかな?)

## [2.9.0](https://github.com/dongaba/TVerRec/releases/tag/v2.9.0)

v2.8.2 以降で特定条件下で TVerRec の自動アップデートがされない不具合がありました。
自動アップデートがされずに毎回自動アップデートの画面が出ている場合は、win/update_tverrec.cmd または unix/update_tverrec.sh を実行するか、v2.9.0 まで手動でバージョンアップをお願いします。

### 2.9.0 Added

### 2.9.0 Changed

### 2.9.0 Fixed

- GUI 版も TVerRec の自動アップデートの不具合を修正(できたかな?)

## [2.8.9](https://github.com/dongaba/TVerRec/releases/tag/v2.8.9)

v2.8.2 以降で特定条件下で TVerRec の自動アップデートがされない不具合がありました。
自動アップデートがされずに毎回自動アップデートの画面が出ている場合は、win/update_tverrec.cmd または unix/update_tverrec.sh を実行するか、v2.8.9 まで手動でバージョンアップをお願いします。

### 2.8.9 Added

### 2.8.9 Changed

### 2.8.9 Fixed

## [2.8.8](https://github.com/dongaba/TVerRec/releases/tag/v2.8.8)

### 2.8.8 Added

### 2.8.8 Changed

### 2.8.8 Fixed

- ダウンロードディレクトリがからの場合のエラーハンドリングを追加
- TVerRec の自動アップデートの不具合を修正(できたかな?)

## [2.8.7](https://github.com/dongaba/TVerRec/releases/tag/v2.8.7)

自動アップデートテストのための空アップデート

### 2.8.7 Added

### 2.8.7 Changed

### 2.8.7 Fixed

## [2.8.6](https://github.com/dongaba/TVerRec/releases/tag/v2.8.6)

### 2.8.6 Added

### 2.8.6 Changed

- like を match に置き換えることによる性能改善

### 2.8.6 Fixed

- TVerRec の自動アップデートの不具合を修正(できたかな?)

## [2.8.5](https://github.com/dongaba/TVerRec/releases/tag/v2.8.5)

### 2.8.5 Added

### 2.8.5 Changed

- like を match に置き換えることによる性能改善

### 2.8.5 Fixed

- ダウンロード対象外リストのディレクトリが削除されないことがある不具合を修正

## [2.8.4](https://github.com/dongaba/TVerRec/releases/tag/v2.8.4)

### 2.8.4 Added

### 2.8.4 Changed

### 2.8.4 Fixed

- ダウンロード対象外リストのディレクトリが削除されないことがある不具合を修正

## [2.8.3](https://github.com/dongaba/TVerRec/releases/tag/v2.8.3)

### 2.8.3 Added

### 2.8.3 Changed

### 2.8.3 Fixed

- 空ディレクトリ削除時のメッセージ出力不正を修正

## [2.8.2](https://github.com/dongaba/TVerRec/releases/tag/v2.8.2)

### 2.8.2 Added

- ダウンロード済み番組の番組 ID が変更になった際にも履歴ファイルに追記し以後処理しない機能を追加
- ダウンロード速度を制限する機能を追加
- Mac/Linux 環境でトースト通知する機能を追加

### 2.8.2 Changed

- Doceker 環境で各種設定ファイルを container-data ディレクトリにコピーするように
- linux/386 と linux/arm/v7 の Docker 作成を廃止
- Windows/Linux 環境での ffmpeg の取得先を yt-dlp の自動ビルド版に変更
- Mac 環境での ffmpeg の最新バージョンの取得方法を改善
- Linux/Mac 環境で ExecutionPolicy の指定を削除
- Docker 環境では TVerRec の自動更新を無効化
- youtube-dl の更新スクリプトを 1 本化
- Join-Path の利用を拡大
- GUI の画像データの外出し
- アップデートスクリプト実行時に最新のアップデートスクリプトをダウンロードするように
- コンソール表示の文字色を変更
- ループ処理改善による処理の高速化
- 配列をリストにすることで処理の高速化
- 正規表現のエスケープ･案エスケープ処理を改善
- メモリ開放タイミングの調整による高速化
- メモリ使用量の削減
- トースト通知を無効化するオプションを追加
- 可読性の向上と性能向上
- 無視対象のディレクトリ削除処理を高速化
- ディレクトリ移動処理の高速化
- if 文削減による処理の高速化
- 空ディレクトリ削除処理の高速化
- ダウンロード履歴との照合を高速化
- ループ処理時に整合性検証で不整合があった場合には再度ダウンロードからやり直すように
- youtube-dl のオプションを追加で設定できるように
- GUI でエラーメッセージ、警告メッセージを色付きで出力するように

### 2.8.2 Fixed

- Docker 環境で xz-utils が漏れていた問題修正
- Docker 環境で sed による置換が間違っていた問題を修正
- Docker 環境で sleep が効いていなかった問題を修正
- Linux 環境で自動ダウンロードする ffmpeg に起因するダウンロードエラーが発生する問題を修正
- ファイル削除時にアクセスできないファイルの存在を無視するように修正
- ダウンロードリスト作成スクリプトの変数未定義不具合を修正
- Windows 環境のリストダウンロードスクリプトのファイル名が間違っていた問題を修正
- アップデートスクリプトが自身を更新しないように修正
- ファイルロックの精度を向上
- 半角カタカナの変換不具合を修正
- 整合性検証中にダウンロード履歴が破損する場合がある問題を修正

## [2.8.1](https://github.com/dongaba/TVerRec/releases/tag/v2.8.1)

### 2.8.1 Added

- 番組シリーズ名、番組シーズン名、番組放送日、番組エピソード番号をファイル名に含めるかどうかを個別設定可能に
- ダウンロード履歴の保持日数を変更可能に
- 番組ファイルへの字幕データの埋め込みを選択可能に
- 番組ファイルへのメタタグの埋め込みを選択可能に

### 2.8.1 Changed

- ダウンロードしようとしているファイル名をダウンロード履歴にあるファイル名と比較し、同じ場合には処理をスキップするように

### 2.8.1 Fixed

- Mac 環境で ffmpeg が正常に更新されない問題を修正
- Mac 環境/Linux 環境で stop_tverrec.sh が正しく動作しなかった問題を修正

## [2.8.0](https://github.com/dongaba/TVerRec/releases/tag/v2.8.0)

### 2.8.0 Added

- サイトマップを処理して番組をダウンロードする機能を追加
- トップページ配下の特集ページからの番組取得機能を追加

### 2.8.0 Changed

- GUI の設定画面で設定をしない場合の表示を変更
- 処理の進捗をより詳細に表示するように変更
- GUI でループ処理をする際に定期的にメモリ解放をするように変更(ただし高価は低い模様)

### 2.8.0 Fixed

## [2.7.9](https://github.com/dongaba/TVerRec/releases/tag/v2.7.9)

### 2.7.9 Added

### 2.7.9 Changed

- Windows 環境で user_setting.ps1 が存在しない場合に、GUI の設定画面を表示するように変更

### 2.7.9 Fixed

- GUI の設定画面がフリーズする問題を修正

## [2.7.8](https://github.com/dongaba/TVerRec/releases/tag/v2.7.8)

### 2.7.8 Added

### 2.7.8 Changed

### 2.7.8 Fixed

- TVerRec の自動更新時に win ディレクトリ内が消失する問題を修正
- Windows 環境で user_setting.ps1 が存在しない際にフリーズする問題を修正

## [2.7.7](https://github.com/dongaba/TVerRec/releases/tag/v2.7.7)

### 2.7.7 Added

### 2.7.7 Changed

### 2.7.7 Fixed

- TVerRec の自動更新機能の不具合を修正(まだ残っているかも。。)
- Alpine Linux の Dockerfile の不具合を修正

## [2.7.6](https://github.com/dongaba/TVerRec/releases/tag/v2.7.6)

### 2.7.6 Added

- Windows 環境向けに GUI 画面を追加(予定)
- Windows Sandbox 環境の設定ファイルを追加

### 2.7.6 Changed

- 移動先ディレクトリを複数指定した際に区切り文字前後にスペースがあっても動作するように
- 文言の微調整
- アプリロゴの変更
- トースト通知のアイコンの切り抜きを丸から四角に変更
- TVerRec の更新処理を改善

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
