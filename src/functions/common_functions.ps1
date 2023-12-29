###################################################################################
#
#		共通関数スクリプト
#
###################################################################################
Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#GC
#----------------------------------------------------------------------
function Invoke-GarbageCollection() {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	Write-Verbose -Message 'Starting garbage collection...'
	[System.GC]::Collect()
	Write-Verbose -Message 'Waiting for pending finalizers...'
	[System.GC]::WaitForPendingFinalizers()
	Write-Verbose -Message 'Performing a final pass of garbage collection...'
	[System.GC]::Collect()
	Write-Verbose -Message 'Garbage collection completed.'
}

#region タイムスタンプ

#----------------------------------------------------------------------
#タイムスタンプ更新
#----------------------------------------------------------------------
function Get-TimeStamp {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}

#----------------------------------------------------------------------
#UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
function ConvertFrom-UnixTime {
	[CmdletBinding()]
	[OutputType([System.Void])]
	param (
		[Parameter(Mandatory = $true)][int64]$UnixTime
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$EpochDate = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0

	return ($EpochDate.AddSeconds($UnixTime).ToLocalTime())
}

#----------------------------------------------------------------------
#DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
function ConvertTo-UnixTime {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)][DateTime]$InputDate
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$EpochDate = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0

	return ([Math]::Floor(($InputDate.ToUniversalTime() - $EpochDate).TotalSeconds))
}

#endregion タイムスタンプ

#region 文字列操作

#----------------------------------------------------------------------
#ファイル名・ディレクトリ名に禁止文字の削除
#----------------------------------------------------------------------
function Get-FileNameWithoutInvalidChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true)][String]$Name
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$invalidChars = [IO.Path]::GetInvalidFileNameChars() -Join ''
	$resultPattern = '[{0}]' -f [Regex]::Escape($invalidChars)
	$Name = $Name.Replace($resultPattern , '')

	#Linux/MacではGetInvalidFileNameChars()が不完全なため、ダメ押しで置換
	$additionalReplaces = '[*\?<>|]'
	$additionalValidChar = '-'
	$Name = $Name -replace $additionalReplaces, $additionalValidChar
	$additionalReplaces = '[]'
	$additionalValidChar = ''
	$Name = $Name -replace $additionalReplaces, $additionalValidChar

	return $Name
}

#----------------------------------------------------------------------
#英数のみ全角→半角(カタカナは全角)
#----------------------------------------------------------------------
function Get-NarrowChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[String]$text
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$replaceChars = @{
		'０１２３４５６７８９'                                           = '0123456789'
		'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
		'＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：．，'                          = '@#$%^&*-+_/[]{}()<> \\";:.,'
	}
	foreach ($entry in $replaceChars.GetEnumerator()) {
		for ($i = 0; $i -lt $entry.Name.Length; $i++) {
			$text = $text.Replace($entry.Name[$i], $entry.Value[$i])
		}
	}

	$replacements = @{
		'ｱ'  = 'ア'
		'ｲ'  = 'イ'
		'ｳ'  = 'ウ'
		'ｴ'  = 'エ'
		'ｵ'  = 'オ'
		'ｶ'  = 'カ'
		'ｷ'  = 'キ'
		'ｸ'  = 'ク'
		'ｹ'  = 'ケ'
		'ｺ'  = 'コ'
		'ｻ'  = 'サ'
		'ｼ'  = 'シ'
		'ｽ'  = 'ス'
		'ｾ'  = 'セ'
		'ｿ'  = 'ソ'
		'ﾀ'  = 'タ'
		'ﾁ'  = 'チ'
		'ﾂ'  = 'ツ'
		'ﾃ'  = 'テ'
		'ﾄ'  = 'ト'
		'ﾅ'  = 'ナ'
		'ﾆ'  = 'ニ'
		'ﾇ'  = 'ヌ'
		'ﾈ'  = 'ネ'
		'ﾉ'  = 'ノ'
		'ﾊ'  = 'ハ'
		'ﾋ'  = 'ヒ'
		'ﾌ'  = 'フ'
		'ﾍ'  = 'ヘ'
		'ﾎ'  = 'ホ'
		'ﾏ'  = 'マ'
		'ﾐ'  = 'ミ'
		'ﾑ'  = 'ム'
		'ﾒ'  = 'メ'
		'ﾓ'  = 'モ'
		'ﾔ'  = 'ヤ'
		'ﾕ'  = 'ユ'
		'ﾖ'  = 'ヨ'
		'ﾗ'  = 'ラ'
		'ﾘ'  = 'リ'
		'ﾙ'  = 'ル'
		'ﾚ'  = 'レ'
		'ﾛ'  = 'ロ'
		'ﾜ'  = 'ワ'
		'ｦ'  = 'ヲ'
		'ﾝ'  = 'ン'
		'ｧ'  = 'ァ'
		'ｨ'  = 'ィ'
		'ｩ'  = 'ゥ'
		'ｪ'  = 'ェ'
		'ｫ'  = 'ォ'
		'ｬ'  = 'ャ'
		'ｭ'  = 'ュ'
		'ｮ'  = 'ョ'
		'ｯ'  = 'ッ'
		'ｰ'  = 'ー'
		'ｳﾞ' = 'ヴ'
		'ｶﾞ' = 'ガ'
		'ｷﾞ' = 'ギ'
		'ｸﾞ' = 'グ'
		'ｹﾞ' = 'ゲ'
		'ｺﾞ' = 'ゴ'
		'ｻﾞ' = 'ザ'
		'ｼﾞ' = 'ジ'
		'ｽﾞ' = 'ズ'
		'ｾﾞ' = 'ゼ'
		'ｿﾞ' = 'ゾ'
		'ﾀﾞ' = 'ダ'
		'ﾁﾞ' = 'ヂ'
		'ﾂﾞ' = 'ヅ'
		'ﾃﾞ' = 'デ'
		'ﾄﾞ' = 'ド'
		'ﾊﾞ' = 'バ'
		'ﾋﾞ' = 'ビ'
		'ﾌﾞ' = 'ブ'
		'ﾍﾞ' = 'ベ'
		'ﾎﾞ' = 'ボ'
		'ﾊﾟ' = 'パ'
		'ﾋﾟ' = 'ピ'
		'ﾌﾟ' = 'プ'
		'ﾍﾟ' = 'ペ'
		'ﾎﾟ' = 'ポ'
	}
	foreach ($replacement in $replacements.GetEnumerator()) {
		$text = $text.Replace($replacement.Name, $replacement.Value)
	}

	return $text
}

#----------------------------------------------------------------------
#いくつかの特殊文字を置換
#----------------------------------------------------------------------
function Remove-SpecialCharacter {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$replacements = @{
		'&amp;' = '&'
		'*'     = '＊'
		'|'     = '｜'
		':'     = '：'
		';'     = '；'
		'"'     = '' #削除
		'“'     = '' #削除
		'”'     = '' #削除
		','     = '' #削除
		'?'     = '？'
		'!'     = '！'
		'/'     = '-' #代替文字
		'\'     = '-' #代替文字
		'<'     = '＜'
		'>'     = '＞'
	}
	foreach ($replacement in $replacements.GetEnumerator()) {
		$text = $text.Replace($replacement.Name, $replacement.Value)
	}

	return $text
}

#----------------------------------------------------------------------
#タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
function Remove-TabSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return $text.Replace("`t", ' ').Replace('  ', ' ')
}

#----------------------------------------------------------------------
#設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
function Remove-Comment {
	[OutputType([String])]
	Param ([String]$text)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	return $text.Split("`t")[0].Split(' ')[0].Split('#')[0]
}

#endregion 文字列操作

#region ファイル操作

#----------------------------------------------------------------------
#指定したPath配下の指定した条件でファイルを削除
#----------------------------------------------------------------------
function Remove-Files {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[parameter(Mandatory = $true)][System.IO.FileInfo]$basePath,
		[Parameter(Mandatory = $true)][Object]$conditions,
		[Parameter(Mandatory = $true)][int32]$delPeriod
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$limiteDateTime = (Get-Date).AddDays(-1 * $delPeriod)
	if ($script:enableMultithread) {
		Write-Debug ('Multithread Processing Enabled')
		#並列化が有効の場合は並列化
		try {
			$conditions.Split(',').Trim() | ForEach-Object -Parallel {
				Write-Output ('　{0}' -f (Join-Path $using:basePath $_))
				$null = (Get-ChildItem -LiteralPath $using:basePath -Recurse -File -Filter $_ -ErrorAction SilentlyContinue).Where({ $_.LastWriteTime -lt $using:limiteDateTime }) | Remove-Item -Force -ErrorAction SilentlyContinue
			} -ThrottleLimit $script:multithreadNum
		} catch { Write-Warning ('❗ 削除できないファイルがありました') }
	} else {
		#並列化が無効の場合は従来型処理
		try {
			foreach ($condition in $conditions.Split(',').Trim()) {
				Write-Output ('　{0}' -f (Join-Path $basePath $condition))
				$null = (Get-ChildItem -LiteralPath $basePath -Recurse -File -Filter $condition -ErrorAction SilentlyContinue).Where({ $_.LastWriteTime -lt $limiteDateTime }) | Remove-Item -Force -ErrorAction SilentlyContinue
			}
		} catch { Write-Warning ('❗ 削除できないファイルがありました') }
	}

}

#----------------------------------------------------------------------
#Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([void])]
	Param(
		[Parameter(Mandatory = $true)][string]$path,
		[Parameter(Mandatory = $true)][string]$destination
	)

	if (Test-Path -Path $path) {
		Write-Verbose ('{0}を{1}に展開します' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('{0}を展開しました' -f $path)
	} else { Write-Error ('{0}が見つかりません' -f $path) }
}

#endregion ファイル操作

#region ファイルロック

#----------------------------------------------------------------------
#ファイルのロック
#----------------------------------------------------------------------
function Lock-File {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true)][System.IO.FileInfo]$path
	)

	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)

	$fileLocked = $false
	try {
		#ファイルを開こうとしファイルロックを検出
		$script:fileInfo = New-Object System.IO.FileInfo $path
		$script:fileStream = $script:fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$fileLocked = $true
	} catch { $fileLocked = $false }

	#結果の返却
	return [PSCustomObject]@{
		path       = $path
		fileLocked = $fileLocked
	}
}

#----------------------------------------------------------------------
#ファイルのアンロック
#----------------------------------------------------------------------
function Unlock-File {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true)][System.IO.FileInfo]$path
	)

	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)

	$fileLocked = $true
	try {
		#ロックされていなければストリームを閉じる
		if ($script:fileStream) { $script:fileStream.Close() }
		$script:fileStream.Dispose()
		$fileLocked = $false
	} catch { $fileLocked = $true }

	#結果の返却
	return [PSCustomObject]@{
		path       = $path
		fileLocked = $fileLocked
	}
}

#----------------------------------------------------------------------
#ファイルのロック確認
#----------------------------------------------------------------------
function Get-FileLockStatus {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[parameter(Mandatory = $true)][System.IO.FileInfo]$path
	)

	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)

	$fileLocked = $true
	try {
		#ファイルを開こうとしファイルロックを検出
		$fileInfo = New-Object System.IO.FileInfo $path
		$fileStream = $fileInfo.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		#ロックされていなければストリームを閉じる
		if ($fileStream) { $fileStream.Close() }
		$fileLocked = $false
	} catch { $fileLocked = $true }

	#結果の返却
	return [PSCustomObject]@{
		path       = $path
		fileLocked = $fileLocked
	}
}

#endregion ファイルロック

#region コンソール出力

#----------------------------------------------------------------------
#色付きWrite-Output
#----------------------------------------------------------------------
function Out-Msg-Color {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false)][Object]$text = '',
		[Parameter(Mandatory = $false)][ConsoleColor]$fg,
		[Parameter(Mandatory = $false)][ConsoleColor]$bg,
		[Parameter(Mandatory = $false)][Boolean]$noNL
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$prevFg = $host.UI.RawUI.ForegroundColor
	$prevBg = $host.UI.RawUI.BackgroundColor

	if ($fg) { $host.UI.RawUI.ForegroundColor = $fg }
	if ($bg) { $host.UI.RawUI.BackgroundColor = $bg }

	$writeHostParams = @{
		Object    = $text
		NoNewline = $noNL
	}
	Write-Host @writeHostParams

	$host.UI.RawUI.ForegroundColor = $prevFg
	$host.UI.RawUI.BackgroundColor = $prevBg
}

#endregion コンソール出力

#region トースト通知

#Toast用AppID取得に必要
if (($script:disableToastNotification -ne $true) -and ($IsWindows)) { Import-Module StartLayout -SkipEditionCheck }

#モジュールのインポート
if (!$script:disableToastNotification -and $IsWindows -and (!('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type]))) {
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll')
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll')
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll')
}

#----------------------------------------------------------------------
#トースト表示
#----------------------------------------------------------------------
function Show-GeneralToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$toastProgressContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
    <visual>
        <binding template="ToastGeneric">
            <text>$script:appName</text>
            <text>$text1</text>
            <text>$text2</text>
            <image placement="appLogoOverride" src="$script:toastAppLogo"/>
        </binding>
    </visual>
    $toastSoundElement
</toast>
"@
				$toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
				$toastXML.LoadXml($toastProgressContent)
				$toastNotification = New-Object Windows.UI.Notifications.ToastNotification $toastXML
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toastNotification)
				continue
			}
			$IsLinux {
				if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 }
				continue
			}
			$IsMacOS {
				if (Get-Command osascript -ea SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				continue
			}
			default { continue }
		}
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト表示
#----------------------------------------------------------------------
function Show-ProgressToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][String]$workDetail = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if ($script:disableToastNotification -ne $true) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
    <visual>
        <binding template="ToastGeneric">
            <text>$script:appName</text>
            <text>$text1</text>
            <text>$text2</text>
            <image placement="appLogoOverride" src="$script:toastAppLogo"/>
            <progress value="{progressValue}" title="{progressTitle}" valueStringOverride="{progressValueString}" status="{progressStatus}" />
            <text placement="attribution"></text>
        </binding>
    </visual>
    $toastSoundElement
</toast>
"@
				$toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
				$toastXML.LoadXml($toastContent)
				$toast = New-Object Windows.UI.Notifications.ToastNotification $toastXML
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
				$toastData.Add('progressTitle', $workDetail)
				$toastData.Add('progressValue', '')
				$toastData.Add('progressValueString', '')
				$toastData.Add('progressStatus', '')
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toast)
				continue
			}
			$IsLinux {
				if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 }
				continue
			}
			$IsMacOS {
				if (Get-Command osascript -ea SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				continue
			}
			default { continue }
		}
	}
}

#----------------------------------------------------------------------
#進捗バー付きトースト更新
#----------------------------------------------------------------------
function Update-ProgressToast {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$title = '',
		[Parameter(Mandatory = $true )][String]$rate,
		[Parameter(Mandatory = $false)][String]$leftText = '',
		[Parameter(Mandatory = $false)][String]$rightText = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if ($script:disableToastNotification -ne $true) {
		switch ($true) {
			$IsWindows {
				$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
				$toastData.Add('progressTitle', $script:appName)
				$toastData.Add('progressValue', $rate)
				$toastData.Add('progressValueString', $rightText)
				$toastData.Add('progressStatus', $leftText)
				$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toastProgressData.SequenceNumber = 2
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Update($toastProgressData, $tag , $group)
				continue
			}
			$IsLinux { continue }
			$IsMacOS { continue }
			default { continue }
		}
	}
}

#----------------------------------------------------------------------
#進捗表示(2行進捗バー)
#----------------------------------------------------------------------
function Show-ProgressToast2Row {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][String]$detail1 = '',
		[Parameter(Mandatory = $false)][String]$detail2 = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false,
		[Parameter(Mandatory = $true )][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($script:disableToastNotification -ne $true) {
		$text2 = $text2 ?? ''
		$detail1 = $detail1 ?? ''
		$detail2 = $detail2 ?? ''

		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' } else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$duration = if (!$duration) { 'short' } else { $duration }
				$toastAttribution = ''
				$toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
	<visual>
		<binding template="ToastGeneric">
			<text>$script:appName</text>
			<text>$text1</text>
			<text>$text2</text>
			<image placement="appLogoOverride" src="$script:toastAppLogo"/>
			<progress value="{progressValue1}" title="{progressTitle1}" valueStringOverride="{progressValueString1}" status="{progressStatus1}" />
			<progress value="{progressValue2}" title="{progressTitle2}" valueStringOverride="{progressValueString2}" status="{progressStatus2}" />
			<text placement="attribution">$toastAttribution</text>
		</binding>
	</visual>
	$toastSoundElement
</toast>
"@
				$toastXML = New-Object Windows.Data.Xml.Dom.XmlDocument
				$toastXML.LoadXml($toastContent)
				$toast = New-Object Windows.UI.Notifications.ToastNotification $toastXML
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
				$toastData.Add('progressTitle1', $detail1)
				$toastData.Add('progressValue1', '')
				$toastData.Add('progressValueString1', '')
				$toastData.Add('progressStatus1', '')
				$toastData.Add('progressTitle2', $detail2)
				$toastData.Add('progressValue2', '')
				$toastData.Add('progressValueString2', '')
				$toastData.Add('progressStatus2', '')
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toast)
				continue
			}
			$IsLinux {
				if (Get-Command notify-send -ea SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 }
				continue
			}
			$IsMacOS {
				if (Get-Command osascript -ea SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				continue
			}
			default { continue }
		}

	}
}

#----------------------------------------------------------------------
#進捗更新(2行進捗バー)
#----------------------------------------------------------------------
function Update-ProgressToast2Row {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$title1 = '',
		[Parameter(Mandatory = $true )][String]$rate1,
		[Parameter(Mandatory = $false)][String]$leftText1 = '',
		[Parameter(Mandatory = $false)][String]$rightText1 = '',
		[Parameter(Mandatory = $false)][String]$title2 = '',
		[Parameter(Mandatory = $true )][String]$rate2,
		[Parameter(Mandatory = $false)][String]$leftText2 = '',
		[Parameter(Mandatory = $false)][String]$rightText2 = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group
	)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	if (!($script:disableToastNotification)) {
		$rightText1 = switch ($rightText1 ) {
			'' { '' }
			'0' { '完了' }
			default { ('残り時間 {0}分' -f ([Int][Math]::Ceiling($rightText1 / 60))) }
		}
		$rightText2 = switch ($rightText2 ) {
			'' { '' }
			'0' { '完了' }
			default { ('残り時間 {0}分' -f ([Int][Math]::Ceiling($rightText2 / 60))) }
		}

		if ($script:disableToastNotification -ne $true) {
			switch ($true) {
				$IsWindows {
					$toastData = New-Object 'system.collections.generic.dictionary[String,string]'
					$toastData.Add('progressTitle1', $title1)
					$toastData.Add('progressValue1', $rate1)
					$toastData.Add('progressValueString1', $rightText1)
					$toastData.Add('progressStatus1', $leftText1)
					$toastData.Add('progressTitle2', $title2)
					$toastData.Add('progressValue2', $rate2)
					$toastData.Add('progressValueString2', $rightText2)
					$toastData.Add('progressStatus2', $leftText2)
					$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
					$toastProgressData.SequenceNumber = 2
					$null = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Update($toastProgressData, $tag , $group)
					continue
				}
				$IsLinux { continue }
				$IsMacOS { continue }
				default { continue }
			}
		}

	}
}
#endregion トースト通知

#----------------------------------------------------------------------
#Base64画像の展開
#----------------------------------------------------------------------
function ConvertFrom-Base64 {
	param ($base64)
	$img = New-Object System.Windows.Media.Imaging.BitmapImage
	$img.BeginInit()
	$img.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64)
	$img.EndInit()
	$img.Freeze()
	return $img
}