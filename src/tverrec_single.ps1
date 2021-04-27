$CurrentDir = Split-Path $MyInvocation.MyCommand.Path
Set-Location $CurrentDir
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Output '    GYAO&Tver動画ダウンローダ powershell ver1.0.1 rev.DN'
Write-Output '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#設定ここから

#ChromeのUserDataフォルダのフルパス
$usr_dir = "$ENV:UserProfile\OneDrive\TverRecording\ChromeUserData\" 

#保存先のフルパス
$savepath = 'V:\TVer\'

#ffmpegのフルパス windowsはこのまま(MacやLinuxの人は変える)
$ffmpeg_path = $CurrentDir + '\lib\ffmpeg.exe'

#Chrome拡張機能のフルパス
$crx_path = $CurrentDir + '\lib\gyao.crx'
$ad_killer_path = $CurrentDir + '\lib\TVerEnqueteDisabler.crx' 

#dllのパス
Add-Type -Path 'lib\WebDriver.dll';
Add-Type -Path 'lib\WebDriver.Support.dll';
Add-Type -Path 'lib\Selenium.WebDriverBackedSelenium.dll';

#設定ここまで
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#無限ループ
while ($true) {
	$title = ''
	$sub_title = ''
	$url = Read-Host 'URLを入力してください。' 

	#クリップボードを空にする
	Set-Clipboard -Value ' '
	$clip_url = '';

	#Chrome起動
	$ChromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
	$ChromeOptions.AddArguments(@(' --renderer-process-limit=3', ' --media-cache-size=104857600', ' --disable-infobars', " --user-data-dir=$usr_dir"))
	$ChromeOptions.AddExtensions("$crx_path")
	$ChromeOptions.AddExtensions("$ad_killer_path")
	$ChromeOptions.AddUserProfilePreference('credentials_enable_service', $false)
	$ChromeOptions.AddUserProfilePreference('profile.password_manager_enabled', $false)
	$driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
	#ChromeのWindow最小化
	#	$driver.manage().Window.Minimize()

	#ChromeにURLを渡す
	$driver.url = $url


	#ループで読み込み完了を待つ
	for ($i = 0; $i -lt 30; $i++) {

		#再生ボタンをクリック
		$element = $driver.FindElementByXpath('/html/body')
		$element.Click()
		$element.SendKeys($driver.keys.Enter)

		#クリップボード取得
		$clip_url = Get-Clipboard -Format Text

		#クリップボードにURLがが入ったら抜ける
		$regex = '([a-zA-Z]{3,})://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'		#正規表現URLパターン
		if ($clip_url -notmatch $regex) {
		} else {
			break
		}
		Start-Sleep -Milliseconds 300
	}

	#Chromeからタイトル取得
	$title = $driver.Title

	#TVer用サブタイトル取得
	if ($url -match 'tver.jp') {
		$null = $driver.PageSource -match 'program_subtitle" type="hidden" value="(.+?)"'
		$sub_title = $Matches[1]
	}

	#GYAO用サブタイトル取得
	if ($url -match 'gyao.yahoo.co.jp') {
		$null = $driver.PageSource -match 'class="video-player-title">(.+?)<'
		$sub_title = $Matches[1]
	}

	#Chrome終了
	$driver.Close()
	$driver.Dispose()
	#	$driver.Quit()
	Start-Sleep -Milliseconds 1000		#オブジェクト破棄に時間がかかるため待機

	#タイトルの不要部分を除去
	$title = $title -replace ' \| (映画|音楽|アニメ|韓流|バラエティ|スポーツ|見逃し配信) \| 無料動画GYAO\!', ''
	$title = $title.Replace('｜民放公式テレビポータル「TVer（ティーバー）」 - 無料で動画見放題', '')
	$title = $title.trim()
	if ($null -ne $sub_title) { $sub_title = $sub_title.trim() }

	#ファイル名を設定
	if ([string]::IsNullOrEmpty($sub_title)) {
		$filepath = $title + '.mp4'
	} else {
		$filepath = $title + ' ' + $sub_title + '.mp4'
	}

	#windowsでファイル名にできない文字列を除去
	$filepath = $filepath -replace '(\?|\!|>|<|:|\\|/|\|)', ''
	$filepath = $filepath -replace '(&amp;)', '&'

	#ffmpegのコマンド
	$Argument = ' -n -i "' + $clip_url + '" -vcodec copy -acodec copy "' + $savepath + $filepath + '"'

	$null = Start-Process -FilePath ($ffmpeg_path) -ArgumentList $Argument -WindowStyle Minimize		# or Hidden


	Write-Output '終わりました。'
}
