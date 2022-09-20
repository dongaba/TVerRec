# Change Log

## [2.5.1](https://github.com/dongaba/TVerRec/releases/tag/v2.5.1)

### Added

- バージョンアップ時にリストファイル(Keywordファイル、Ignoreファイル)がクリアされないようにする

### Changed

- TVerへのAPIコール数を削減し高速化
- ファイルアクセスを削減し高速化
- ソースコードのリファクタリングを実施
- GEO IPのチェックの完全廃止

### Fixed

- トーストメッセージの誤植を修正
- エラーメッセージの誤植を修正


## [2.5.0](https://github.com/dongaba/TVerRec/releases/tag/v2.5.0)

### Added

- 新着ビデオリストからのダウンロード機能を追加
- ランキングからのダウンロード機能を追加

### Changed

- トップページの解析を最新のトップページレイアウトに合わせて改良
- ジャンル ID などの指定による検索を変更し、タグ検索として新着番組以外からも対象を検索するように改良
- 指定可能な タグ検索 (旧 ID 検索) に使用する Tag の最新化(Keyword.conf を更新しています)
- 指定可能な TV 局の最新化(Keyword.conf を更新しています)
- 標準の youtoube-dl を ytdl-patched に変更
- 無視リストの判定を番組シリーズ名だけでなく番組名でも判定するように変更

### Fixed

## [2.4.9](https://github.com/dongaba/TVerRec/releases/tag/v2.4.9)

### Added

### Changed

- youtube-dl の取得元を 2 箇所から選択できるように変更

### Fixed

- 毎回 yt-dlp がダウンロードされる問題を修正

## [2.4.8](https://github.com/dongaba/TVerRec/releases/tag/v2.4.8)

### Added

### Changed

- トースト表示時の不要なメッセージを削減
- youtube-dl を別バージョンに差し替え

### Fixed

## [2.4.7](https://github.com/dongaba/TVerRec/releases/tag/v2.4.7)

### Added

### Changed

### Fixed

- Windows 用の起動 BAT が LOOP に失敗する不具合を修正 (泣)

## [2.4.6](https://github.com/dongaba/TVerRec/releases/tag/v2.4.6)

### Added

### Changed

### Fixed

- Windows 用の起動 BAT が LOOP に失敗する不具合を修正

## [2.4.5](https://github.com/dongaba/TVerRec/releases/tag/v2.4.5)

### Added

- Windows 向けトースト通知機能を追加

### Changed

- バージョンアップ時にダウンロード済みリストファイルが上書きされないように修正
- Windows の一括実行 BAT でキーボード入力による終了処理を追加

### Fixed

- Windows PowerShell 環境で動画ファイルの移動に失敗する不具合を修正

## [2.4.4](https://github.com/dongaba/TVerRec/releases/tag/v2.4.4)

### Added

- ハートビート機能を追加

### Changed

- ライセンスを Apache 2 ライセンスから MIT ライセンスに変更

### Fixed

- ダウンロード済みリストの引き落としがされない問題を修正

## [2.4.3](https://github.com/dongaba/TVerRec/releases/tag/v2.4.3)

### Added

- ツールの自動アップデートを無効化するオプションを追加(「$true」で無効化。いずれも初期値は$false)
  - youtube-dl の自動アップデートを無効化 $script:disableUpdateYoutubedl = $true
  - ffmpeg の自動アップデートを無効化$script:disableUpdateFfmpeg = $true

### Changed

### Fixed

## [2.4.2](https://github.com/dongaba/TVerRec/releases/tag/v2.4.2)

### Added

- 動画検証の高速化オプションを 2 つ追加(「$true」で高速化。いずれも初期値は$false)
  - ffprobe を使った簡易検証 $script:simplifiedValidation = $true
  - 動画検証を全く行わない $script:disableValidation = $true
- 放送局ごとのフォルダを作ってからダウンロードするオプションを追加(「$true」で有効化。初期値は$false)

### Changed

- 動画ファイル検証時の冗長なメッセージを削除

### Fixed

- ステータスバーが表示されない問題を修正

## [2.4.1](https://github.com/dongaba/TVerRec/releases/tag/v2.4.1)

### Added

### Changed

- user_setting.ps1 に Mac や Linux 用の指定方法を追加

### Fixed

- Linux/Mac で youtube-dl がダウンロードされない問題を修正
- Windows Power Shell で不要ファイル削除機能でエラーとなっていた問題を修正

## [2.4.0](https://github.com/dongaba/TVerRec/releases/tag/v2.4.0)

### Added

- TVer のトップページに表示される動画をダウンロードするキーワード「toppage」を追加

### Changed

- Invoke-WebRequest のプログレスバーを非表示に変更

### Fixed

- youtube-dl がダウンロードされない問題を修正
- ffmpeg がダウンロードされない問題を修正
- 一部ファイルの読み込みに失敗していた問題を修正

## [2.3.9](https://github.com/dongaba/TVerRec/releases/tag/v2.3.9)

### Added

- TVerRec 自身のバージョンチェック機能を追加

### Changed

- `src`フォルダ内の構成を変更
- 設定ファイルの拡張子を変更
- Windows PowerShell 環境用のソースコードの精製方法を変更

### Fixed

- Invoke-Expression の使用を中止
- ffmpegErrorLog のゴミが削除されなかった不具合を修正
- ffmpeg の Mac/Linux 向けダウンロード機能が失敗する不具合を修正
- Windows PowerShell 環境での複数のバグを修正

## [2.3.8](https://github.com/dongaba/TVerRec/releases/tag/v2.3.8)

### Added

- TVer のリニューアルによりフリーワード検索の精度が大幅に下がっていますので、できればタレント ID 指定、番組 ID 指定で録画したほうが確実です。
- 同様にジャンル指定の精度も大幅に下がっているようですのでご注意ください。

### Changed

- `conf/keyword.conf`をテキストエディターで開いてダウンロード対象のタレントの名前や番組名、ジャンル、TV 局などを設定します
  - 不要なキーワードは `#` でコメントアウトするか削除してください。
  - 主なジャンルは網羅しているつもりですが、不足があるかもしれませんので、必要に応じて適宜自分で補ってください。
  - ダウンロード対象の指定の方法はいくつかありますが、現在のところ a と b が確実にダウンロードする方法です。c と d と e は TVer の検索機能が改善されるまで動画を取りこぼす可能性や不要な動画が山ほどダウンロードされる可能性が高いです。
    1. **タレント ID 指定**(番組 ID は TVer のサイトで確認できます)
    2. **番組 ID 指定**(番組 ID は TVer のサイトで確認できます)
    3. **ジャンル指定**(事前に用意されているもののみ)
    4. **番組タイトル**のみを対象としたフリーワード検索
    5. **フリーワード指定**

### Fixed
