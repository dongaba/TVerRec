# :tv:**TVerRec**:tv: - TVerビデオダウンローダ -
TVerRecは、powershellのスクリプトで書かれた動画配信サイトのTver専用の動画ダウンローダです。
動画を1本ずつ指定してダウンロードするのではなく、動画のジャンルや出演タレントを指定して一括ダウンロードします。
ループ実行するようになっているので、1回起動すれば新しい番組が配信される都度ダウンロードされるようになります。
動作に必要なchromedriverやffmpegなどの必要コンポーネントは自動的に最新版がダウンロードされます。

## 前提条件
Google Chromeがインストールされていることが稼働条件です。
Windows10で動作確認していますが、おそらくWindows7、8でも動作します。
PowerShellはMacOS、Linuxにも移植されてるのでメインの機能は動作するかもしれません。
一部の機能はWindowsを前提に作られているので改変なしでは動作しません。(chromedriverの自動更新機能など)

## 実行方法
使い方は非常に簡単です。以下の手順でバッチファイルを実行してください。
1. TVerRecのzipファイルをダウロードし、任意のディレクトリで解凍してください。
2. 以下を参照して環境設定、ダウンロード設定を行ってください。
3. Windows環境では `start_tverrec.bat`を実行してください。
    - 処理が完了しても10分ごとに永遠にループして稼働し続けます。
    - もしくは、ps1ファイルをPowerShellにを関連付けして、`tverrec_bulk.ps1`をクリックで起動。
    - 上記でPowerShellが起動しない場合は、PowerShell の実行ポリシーのRemoteSignedなどに変更する必要があるかもしれません。([参考](https://bit.ly/32HAwOK))
4. TVerRecを `start_tverrec.bat`で起動した場合は、`stop_tverrec.bat`でTVerRecを停止できます。
    - 関連するダウンロード処理もすべて強制停止されるので注意してください。
    - ダウンロードを止めたくない場合は、tverecのウィンドウを閉じるボタンで閉じてください。

## 設定内容
個別の設定はテキストエディタで変更する必要があります。
### 動作環境の設定方法
- `config/user_setting.ini`をテキストエディターで開いてユーザ設定を行ってください。
### ダウンロード対象のジャンルの設定方法
- `config/keyword.ini`をテキストエディターで開いてダウンロード対象のジャンルを設定します。
    - 不要なジャンルは `#` でコメントアウトしてください。
    - ジャンルは網羅しているつもりですが、不足があるかもしれません。
### ダウンロード対象外の番組の設定方法
- `config/ignore.ini`をテキストエディターで開いてダウンロードしたくない番組名を設定します。
    - ジャンル指定でダウンロードすると不要な番組もまとめてダウンロードされるので、個別にダウンロード対象外に指定できます。

## おすすめの使い方
- TVerRecはクリップボードを使って動作します。
  TVerRec動作中はクリップボードを使えなくなるため、別ユーザを作ってTVerRec専用に割り当てるのがおすすめです。
- 別ユーザを作れない場合は、TVerRec用のChromeのユーザプロファイルを作成して、TVerRec動作中もChromeでのブラウジングをできるようにするのがおすすめです。
- TVerのカテゴリ毎のページを指定して`start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、フォローしているタレントページを指定して`start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。
- 同様に、各放送局毎のページを指定して`start_tverrec.bat`で起動すれば、新しい番組が配信されたら自動的にダウンロードされるようになります。

## フォルダ構成
```
tverrec/
├─ bin/ .................................... 実行ファイル格納用フォルダ
│
├─ config/ ............................... 設定フォルダ
│  ├─ ignore.ini ........................... ダウンロード対象外設定ファイル
│  ├─ keyword.ini .......................... ダウンロード対象ジャンル設定ファイル
│  ├─ system_setting.ini ................... システム設定ファイル
│  └─ user_setting.ini ..................... ユーザ設定ファイル
│
├─ crx/ .................................. Chrome拡張機能
│  ├─ tverCopy.crx ......................... TVerビデオURL解析Chrome拡張
│  └─ tverCopy/ ............................ Chrome拡張のソースフォルダ
│
├─ db/ ................................... データベース
│  └─ tver.csv ............................. ダウンロードリスト
│
├─ debug/ ................................ デバッグ用
│
├─ lib/ .................................. SeleniumのDLL格納フォルダ
│
├─ src/ .................................. 各種ソース
│  ├─ common_functions.ps1 ................. 共通関数定義
│  ├─ delete_ignored.ps1 ................... ダウンロード対象外ビデオ削除ツール
│  ├─ tverrec_bulk.ps1 ..................... 一括ダウンロードツール本体
│  ├─ tverrec_functions.ps1 ................ TVer用共通関数定義
│  ├─ tverrec_single.ps1 ................... 単体ダウンロードツール
│  ├─ update_chromedriver.ps1 .............. chromedriver自動更新ツール
│  ├─ update_ffmpeg.ps1 .................... ffmpeg自動更新ツール
│  ├─ update_youtubedl.ps1 ................. youtube-dl自動更新ツール
│  └─ validate_video.ps1 ................... ダウンロード済みビデオの整合性チェックツール
│
├─ delete_video.bat ........................ ダウンロード対象外ビデオ削除BAT
├─ LICENSE ................................. ライセンス
├─ README.md ............................... このファイル
├─ start_tverrec.bat ....................... 一括ダウンロード起動BAT
├─ stop_tverrec.bat ........................ 一括ダウンロード終了BAT
└─ validate_video.bat ...................... ダウンロード済みビデオの整合性チェックBAT
```

## アンインストール方法
- レジストリは一切使っていないでの、不要になったらゴミ箱に捨てれば良いです。

## 注意事項
- 解像度の指定はできません。
    - 解像度はブラウザで再生するのと同じで回線によって自動で決定します。
- 動作中はクリップボードを使用できません。
    - 本ツールはクリップボードを使って機能間のデータ連携をしています。ツールの動作中にクリップボードを使用すると、ダウンロードに失敗したり動作が重くなることがあります。
- 著作権について
    - このプログラムの著作権は dongaba が保有しています。
- 事故、故障など
    - 本ツールを使用して起こった何らかの事故、故障などの責任は負いかねますので、ご使用の際はこのことを承諾したうえでご使用ください。

## ライセンス
- TVerRecは[Apache License, Version 2.0のライセンス規約](http://www.apache.org/licenses/LICENSE-2.0)に基づき、複製や再配布、改変が許可されます。
- TVerRecはApache License, Version 2.0のライセンスで配布されている成果物を含んでいます。
    - WebDriver.dll version 3.141.0
    - WebDriver.Support.dll version 3.141.0
    - Selenium.WebDriverBackedSelenium.dll version 3.141.0

Copyright(c) 2021 dongaba All Rights Reserved.



# :tv:**TVerRec**:tv: - video downloader for TVer -
TVerRec is a dedicated video downloader for Tver, a video distribution site in Japan written in powershell script.
Instead of downloading videos one by one, it downloads them all at once by specifying the genre of the video or the talent who appears in it.
It is designed to run continuously, so if you start it once, it will download every time a new program is delivered.
Necessary components such as chromedriver and ffmpeg are automatically downloaded to the latest version.

## Requirements
Google Chrome must be installed to run.
TVerRec has been tested on Windows 10, but it will probably work on Windows 7 and 8 as well.
PowerShell has been ported to MacOS and Linux, so the main functions may work on them.
Some features are designed only for Windows, so they will not work without modification on other platforms. (e.g. automatic update of chromedriver).


## How to run
It is very easy to use. Please follow the steps below to run the batch file.
1. Download the TVerRec zip file and extract it in any directory. 
2. Please refer to the following section to set up the environment and download settings. 
3. In Windows environment, you can simply run `start_tverrec.bat`.
    - After the download process is completed, TVerRec will continue to run in a loop every 10 minutes forever.
    - Alternatively, associate the ps1 file with PowerShell and click on `tverrec_bulk.ps1` to start.
    - If the above procedure does not work, you may need to change the execution policy of PowerShell (such as RemoteSigned). ([Reference](https://bit.ly/3aNCXno))
4. If you started TVerRec with `start_tverrec.bat`, you can stop TVerRec with `stop_tverrec.bat`.
    - Note that all related child download processes will also be forcibly stopped.
    - If you do not want to stop the download processes, simply close the TVerRec window with the close button.

## Configuration
Individual settings need to be changed in a text editor.
### Enviromental settings
- Open `config/user_setting.ini` with a text editor and configure the user settings as guided.
### Genres settings for download
- Open `config/keyword.ini` with a text editor and set the genre to be downloaded.
    - Comment out unwanted genres with `#`.
    - I've tried to cover all genres, but there may be some missing.
### Ignore settings for download
- Open `config/ignore.ini` with a text editor and set the program names you do not want to download.
    - When you download videos by genre, some unwanted videos will also be downloaded at once, so you can exclude them individually from downloading.

## Recommended usage
- TVerRec works by using the clipboard.
  Since the clipboard cannot be used while TVerRec is running, it is recommended to create a separate user and assign it exclusively to TVerRec.
- If you cannot create a separate user, we recommend that you create a dedicated Chrome user profile for TVerRec so that you can use Chrome while TVerRec is running.
- If you specify a page for each TVer genre and start it with `start_tverrec.bat`, it will automatically download new videos when they are available.
- Similarly, if you specify a talent page you are following and `start_tverrec.bat`, it will automatically download new videos when they become available.
- Similarly, if you specify a page for each broadcaster and `start_tverrec.bat`, new videos will be downloaded automatically when they become available.


## Folder Structure
```
tverrec/
├─ bin/ .................................... folder for .exe
│
├─ config/ ............................... configuration folder
│  ├─ ignore.ini ........................... ignore settings for skipping download
│  ├─ keyword.ini .......................... genre settings for download
│  ├─ system_setting.ini ................... system settings
│  └─ user_setting.ini ..................... user settings
│
├─ crx/ .................................. Chrome Extension
│  ├─ tverCopy.crx ......................... TVer video analyser
│  └─ tverCopy/ ............................ forder for source of Chrome extension
│
├─ db/ ................................... database
│  └─ tver.csv ............................. download list
│
├─ debug/ ................................ for debugging
│
├─ lib/ .................................. for Selenium DLL
│
├─ src/ .................................. source files
│  ├─ check_video.ps1 ...................... check video consistensy
│  ├─ common_functions.ps1 ................. common functions
│  ├─ delete_ignored.ps1 ................... delete ignored videos
│  ├─ tverrec_bulk.ps1 ..................... bulk downloader
│  ├─ tverrec_functions.ps1 ................ TVer specific functions
│  ├─ tverrec_single.ps1 ................... donwloader for a single video
│  ├─ update_chromedriver.ps1 .............. update chromedriver
│  ├─ update_ffmpeg.ps1 .................... update ffmpeg
│  └─ update_youtubedl.ps1 ................. update youtube-dl
│
├─ delete_video.bat ........................ bat file to delete ignored videos
├─ LICENSE ................................. license
├─ README.md ............................... this file
├─ start_tverrec.bat ....................... bat file to start bulk download
├─ stop_tverrec.bat ........................ bat file to stop bulk download
└─ validate_video.bat ...................... bat file to check video consistensy
```

## Uninstallation
- TVerRec doesn't use any registry at all, so if you don't need TVerRec anymore, you can just delete it.

## Notes
- You cannot specify the video resolution.
    - The resolution will be automatically determined by the quality of your internet connection same as when you watch in a browser.
- The clipboard cannot be used during TVerRec is running.
    - TVerRec uses the clipboard to link data between functions. If you use the clipboard while TVerRec is running, the download may fail or the system response may become slow.
- About copyright
    - The copyright of this program is held by dongaba.
- Accidents, malfunctions, etc.
    - I am not responsible for any accidents or malfunctions that may occur when using TVerRec.

## License
- TVerRec may be copied, redistributed, or modified under the terms of the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0 ).
- TVerRec contains artifacts distributed under the license of the Apache License, Version 2.0.
    - WebDriver.dll version 3.141.0
    - WebDriver.Support.dll version 3.141.0
    - Selenium.WebDriverBackedSelenium.dll version 3.141.0

Copyright(c) 2021 dongaba All Rights Reserved.


