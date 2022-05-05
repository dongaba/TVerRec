# Change Log

## [Unreleased](https://github.com/dongaba/TVerRec)

### Added

### Changed

- ライセンスをApache 2ライセンスからMITライセンスに変更

### Fixed

## [2.4.3](https://github.com/dongaba/TVerRec/releases/tag/v2.4.3)

### Added

- ツールの自動アップデートを無効化するオプションを追加(「$true」で無効化。いずれも初期値は$false)
  - youtube-dlの自動アップデートを無効化 $script:disableUpdateYoutubedl = $true
  - ffmpegの自動アップデートを無効化$script:disableUpdateFfmpeg = $true

### Changed

### Fixed

## [2.4.2](https://github.com/dongaba/TVerRec/releases/tag/v2.4.2)

### Added

- 動画検証の高速化オプションを2つ追加(「$true」で高速化。いずれも初期値は$false)
  - ffprobeを使った簡易検証 $script:simplifiedValidation = $true
  - 動画検証を全く行わない $script:disableValidation = $true
- 放送局ごとのフォルダを作ってからダウンロードするオプションを追加(「$true」で有効化。初期値は$false)

### Changed

- 動画ファイル検証時の冗長なメッセージを削除

### Fixed

- ステータスバーが表示されない問題を修正

## [2.4.1](https://github.com/dongaba/TVerRec/releases/tag/v2.4.1)

### Added

### Changed

- user_setting.ps1にMacやLinux用の指定方法を追加

### Fixed

- Linux/Macでyoutube-dlがダウンロードされない問題を修正
- Windows Power Shellで不要ファイル削除機能でエラーとなっていた問題を修正

## [2.4.0](https://github.com/dongaba/TVerRec/releases/tag/v2.4.0)

### Added

- TVerのトップページに表示される動画をダウンロードするキーワード「toppage」を追加

### Changed

- Invoke-WebRequestのプログレスバーを非表示に変更

### Fixed

- youtube-dlがダウンロードされない問題を修正
- ffmpegがダウンロードされない問題を修正
- 一部ファイルの読み込みに失敗していた問題を修正

## [2.3.9](https://github.com/dongaba/TVerRec/releases/tag/v2.3.9)

### Added

- TVerRec自身のバージョンチェック機能を追加

### Changed

- `src`フォルダ内の構成を変更
- 設定ファイルの拡張子を変更
- Windows PowerShell環境用のソースコードの精製方法を変更

### Fixed

- Invoke-Expressionの使用を中止
- ffmpegErrorLogのゴミが削除されなかった不具合を修正
- ffmpegのMac/Linux向けダウンロード機能が失敗する不具合を修正
- Windows PowerShell環境での複数のバグを修正

## [2.3.8](https://github.com/dongaba/TVerRec/releases/tag/v2.3.8)

### Added

- TVerのリニューアルによりフリーワード検索の精度が大幅に下がっていますので、できればタレントID指定、番組ID指定で録画したほうが確実です。
- 同様にジャンル指定の精度も大幅に下がっているようですのでご注意ください。

### Changed

- `conf/keyword.conf`をテキストエディターで開いてダウンロード対象のタレントの名前や番組名、ジャンル、TV局などを設定します
  - 不要なキーワードは `#` でコメントアウトするか削除してください。
  - 主なジャンルは網羅しているつもりですが、不足があるかもしれませんので、必要に応じて適宜自分で補ってください。
  - ダウンロード対象の指定の方法はいくつかありますが、現在のところ a と b が確実にダウンロードする方法です。c と d と e はTVerの検索機能が改善されるまで動画を取りこぼす可能性や不要な動画が山ほどダウンロードされる可能性が高いです。
    1. **タレントID指定**(番組IDはTVerのサイトで確認できます)
    2. **番組ID指定**(番組IDはTVerのサイトで確認できます)
    3. **ジャンル指定**(事前に用意されているもののみ)
    4. **番組タイトル**のみを対象としたフリーワード検索
    5. **フリーワード指定**

### Fixed
