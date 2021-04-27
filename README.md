■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
tverrec - TVerビデオダウンローダ -
サポートなしのフリーソフト
https://github.com/Dicekay/tverrec
■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

■このソフトの説明

powershellのスクリプトで書かれた動画配信サイトのTver専用の動画ダウンローダです。

windows10で動作確認していますが、おそらくWindows7、8でも動作します。

powershellはMacOSX、Linuxにも移植されてるのでもしかしたら動作するかもです。


■使い方

 1. src\tverrec_bulk.ps1をテキストエディターで開いてユーザ設定。

 2. PowerShell の実行ポリシーの変更。
    https://bit.ly/32HAwOKを参照してRemoteSignedに

 3. ffmpeg.exeを別途ダウンロードして、binフォルダの中に配置します。

 4. Windows環境ではstart_tverrec.batで起動。永遠にループして稼働し続けます。
    もしくはps1にPowerShellを関連付け変更してtverrec_bulk.ps1をクリックで起動。

 5. start_tverrec.batで起動した場合は、stop_tverrec.batで停止できます。
    関連するダウンロード処理もすべて強制停止されるので注意してください。
    ダウンロードを止めたくない場合は、tverecのウィンドウを「X」ボタンで閉じてください。


■おすすめの使い方

 ・ tverrecはクリップボードを使って動作します。
    tverrec動作中はクリップボードを使えなくなるため、
    別ユーザを作ってtverrec専用に割り当てるのがおすすめです。
    
 ・ 別ユーザを作れない場合は、tverrec用のChromeのユーザプロファイルを作成して、
    tveerec動作中もChromeでのブラウジングをできるようにするのがおすすめです。

 ・ TVえerのカテゴリ毎のページを指定してstart_tverrec.batで起動すれば、
    新しい番組が配信されたら自動的にダウンロードされるようになります。

 ・ 同様に、フォローしているタレントページを指定してstart_tverrec.batで起動すれば、
    新しい番組が配信されたら自動的にダウンロードされるようになります。

 ・ 同様に、各放送局毎のページを指定してstart_tverrec.batで起動すれば、
    新しい番組が配信されたら自動的にダウンロードされるようになります。


■注意点

 ・ 解像度の指定はできません。
    解像度はブラウザで再生するのと同じで回線によって自動で決定します。


■設定

 ・ そのうち説明します



■アンインストール

 ・ レジストリは一切使っていないでの、ゴミ箱に捨てれば良いです。



----------------------------------------------------------------------
tverrec - TVer Video Downloader
  License free software with no support
  https://github.com/Dicekay/tverrec
----------------------------------------------------------------------

- Description of this software

 This is a video downloader for Tver, a video distribution site written in powershell script. It has been tested on Windows 10, but it will probably work on Windows 7 and 8 as well. It may work on Windows 7 and 8. powershell has been ported to MacOSX and Linux as well, so it may work.

- How to use

1. open src\tverrec_bulk.ps1 in a text editor and set user preferences. 2.
2. change the PowerShell execution policy. Refer to https://bit.ly/32HAwOK.
3. download ffmpeg.exe separately and place it in the bin folder. 
4. In Windows environment, start it with start_tverrec.bat. It will loop forever and keep running. Or change the PowerShell association to ps1 and click tverrec_bulk.ps1 to start it. 
5. If you start it with start_tverrec.bat, you can stop it with stop_tverrec.bat.Note that all related download processes will also be forcibly stopped. If you do not want to stop the download, close the tverec window with the "X" button.

- Recommended usage

 tverrec works with the clipboard. When tverrec is running, you cannot use the clipboard. If you can't create a separate user, you can use the clipboard only for tverrec.
 If you can't create a separate user, create a Chrome user profile for tverrec. If you cannot create a separate user, we recommend that you create a Chrome user profile for tverrec so that you can browse in Chrome while tveerec is running.
 If you specify a page for each category of TVEER and start it with start_tverrec.bat. If you specify a page for each category of TVEer and start it with start_tverrec.bat, new programs will be downloaded automatically when they are distributed.
 In the same way, if you start start_tverrec.bat by specifying a talent page you are following, it will automatically download new programs when they are distributed. Similarly, if you specify a talent page you follow and start it with start_tverrec.bat, it will automatically download when a new program is distributed.
 In the same way, if you specify the page for each station and start_tverrec.bat. In the same way, if you specify a page for each station and start it with start_tverrec.bat, it will be downloaded automatically when a new program is distributed.

-Cautions

 The resolution cannot be specified. The resolution is automatically determined by the line, the same as when playing in a browser.

-Settings

 will explain it later.

-Uninstallation

 The registry is not used at all, so you can just throw it in the trash.


