# Change Log

## [2.5.9](https://github.com/dongaba/TVerRec/releases/tag/v2.5.9)

### 2.5.9 Added

### 2.5.9 Changed

### 2.5.9 Fixed

- `$script:saveBaseDir`で指定されるディレクトリがからの際にエラーとなる[問題](https://github.com/dongaba/TVerRec/issues/19)を修正

## [2.5.8](https://github.com/dongaba/TVerRec/releases/tag/v2.5.8)

### 2.5.8 Added

### 2.5.8 Changed

### 2.5.8 Fixed

- Linux用の動画保存先先フォルダの指定が間違っている[問題](https://github.com/dongaba/TVerRec/issues/18)を修正

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
- ビデオ検証時のデコードオプションが設定されている際のメッセージの色を変更
- ソースコードの可読性を向上
- ビデオ検証時に検証結果を OK/NG で表示するように変更
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
- ビデオ移動時に空フォルダを削除しない仕様に変更

### 2.5.5 Fixed

- ゴミファイルの削除が不完全な場合がある問題を修正
- 無視リストに入っている動画がダウンロードされることがある問題を修正

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

- 新着ビデオリストからのダウンロード機能を追加
- ランキングからのダウンロード機能を追加

### 2.5.0 Changed

- トップページの解析を最新のトップページレイアウトに合わせて改良
- ジャンル ID などの指定による検索を変更し、タグ検索として新着番組以外からも対象を検索するように改良
- 指定可能な タグ検索 (旧 ID 検索) に使用する Tag の最新化(Keyword.conf を更新しています)
- 指定可能な TV 局の最新化(Keyword.conf を更新しています)
- 標準の youtoube-dl を ytdl-patched に変更
- 無視リストの判定を番組シリーズ名だけでなく番組名でも判定するように変更

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

- バージョンアップ時にダウンロード済みリストファイルが上書きされないように修正
- Windows の一括実行 BAT でキーボード入力による終了処理を追加

### 2.4.5 Fixed

- Windows PowerShell 環境で動画ファイルの移動に失敗する不具合を修正

## [2.4.4](https://github.com/dongaba/TVerRec/releases/tag/v2.4.4)

### 2.4.4 Added

- ハートビート機能を追加

### 2.4.4 Changed

- ライセンスを Apache 2 ライセンスから MIT ライセンスに変更

### 2.4.4 Fixed

- ダウンロード済みリストの引き落としがされない問題を修正

## [2.4.3](https://github.com/dongaba/TVerRec/releases/tag/v2.4.3)

### 2.4.3 Added

- ツールの自動アップデートを無効化するオプションを追加(「$true」で無効化。いずれも初期値は$false)
  - youtube-dl の自動アップデートを無効化 $script:disableUpdateYoutubedl = $true
  - ffmpeg の自動アップデートを無効化$script:disableUpdateFfmpeg = $true

### 2.4.3 Changed

### 2.4.3 Fixed

## [2.4.2](https://github.com/dongaba/TVerRec/releases/tag/v2.4.2)

### 2.4.2 Added

- 動画検証の高速化オプションを 2 つ追加(「$true」で高速化。いずれも初期値は$false)
  - ffprobe を使った簡易検証 $script:simplifiedValidation = $true
  - 動画検証を全く行わない $script:disableValidation = $true
- 放送局ごとのフォルダを作ってからダウンロードするオプションを追加(「$true」で有効化。初期値は$false)

### 2.4.2 Changed

- 動画ファイル検証時の冗長なメッセージを削除

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

- TVer のトップページに表示される動画をダウンロードするキーワード「toppage」を追加

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

- `src`フォルダ内の構成を変更
- 設定ファイルの拡張子を変更
- Windows PowerShell 環境用のソースコードの精製方法を変更

### 2.3.9 Fixed

- Invoke-Expression の使用を中止
- ffmpegErrorLog のゴミが削除されなかった不具合を修正
- ffmpeg の Mac/Linux 向けダウンロード機能が失敗する不具合を修正
- Windows PowerShell 環境での複数のバグを修正

## [2.3.8](https://github.com/dongaba/TVerRec/releases/tag/v2.3.8)

### 2.3.8 Added

- TVer のリニューアルによりフリーワード検索の精度が大幅に下がっていますので、できればタレント ID 指定、番組 ID 指定で録画したほうが確実です。
- 同様にジャンル指定の精度も大幅に下がっているようですのでご注意ください。

### 2.3.8 Changed

- `conf/keyword.conf`をテキストエディターで開いてダウンロード対象のタレントの名前や番組名、ジャンル、TV 局などを設定します
  - 不要なキーワードは `#` でコメントアウトするか削除してください。
  - 主なジャンルは網羅しているつもりですが、不足があるかもしれませんので、必要に応じて適宜自分で補ってください。
  - ダウンロード対象の指定の方法はいくつかありますが、現在のところ a と b が確実にダウンロードする方法です。c と d と e は TVer の検索機能が改善されるまで動画を取りこぼす可能性や不要な動画が山ほどダウンロードされる可能性が高いです。
    1. **タレント ID 指定**(番組 ID は TVer のサイトで確認できます)
    2. **番組 ID 指定**(番組 ID は TVer のサイトで確認できます)
    3. **ジャンル指定**(事前に用意されているもののみ)
    4. **番組タイトル**のみを対象としたフリーワード検索
    5. **フリーワード指定**

### 2.3.8 Fixed
