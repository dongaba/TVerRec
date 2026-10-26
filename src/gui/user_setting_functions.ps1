###################################################################################
#
#		ユーザー設定ファイルの読み書き関数スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		設定画面(gui_setting.ps1)が、user_setting.ps1を読み書きするための関数を定義します。

	.DESCRIPTION
		user_setting.ps1は、`$script:変数名 = 値`の行を並べたスクリプトです。
		設定画面は、その行を読み取って画面に表示し、画面の入力から行を作って、自動生成の区間
		(##Start Setting Generated from GUI ～ ##End Setting Generated from GUI)に書き戻します。
		画面(WPF)に依存しない部分を、このファイルにまとめています。画面の部品は触らないので、
		WPFの無い環境でもテストできます。

	.NOTES
		このファイルはgui_setting.ps1から読み込まれます。
		メッセージ($script:msg)に、SettingDefault・SettingTrue・SettingFalse・SettingUndefinedが必要です。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#----------------------------------------------------------------------
# user_setting.ps1の1項目を、画面に表示する文字列に変換
#----------------------------------------------------------------------
function ConvertTo-SettingDisplayText {
	<#
		.SYNOPSIS
			user_setting.ps1の内容から、1つの設定項目の、画面に表示する文字列を返します。

		.DESCRIPTION
			項目の行が見つかれば、その値(前後の空白と引用符を除いたもの)を返します。
			$trueと$falseは、それぞれ「する」「しない」(言語に応じた表示)に、
			preferredLanguageは、ja-JPを「日本語」、en-USを「English」に変換します。
			行が見つからなければ、「未設定」(downloadBaseDirなど、既定値のない項目)または「デフォルト値」を返します。

		.PARAMETER Attribute
			設定項目の変数名を指定します。例: $script:downloadBaseDir

		.PARAMETER Content
			user_setting.ps1の各行を指定します。

		.OUTPUTS
			[String]
			画面に表示する文字列。

		.EXAMPLE
			ConvertTo-SettingDisplayText -Attribute '$script:loopCycle' -Content (Get-Content ./conf/user_setting.ps1)
	#>
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true)][String]$Attribute,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()][AllowEmptyString()][String[]]$Content
	)
	# 既定値を持たず、未指定なら「未設定」と表示する項目
	$undefAttributes = @('$script:downloadBaseDir', '$script:downloadWorkDir', '$script:saveBaseDir', '$script:myPlatformUID', '$script:myPlatformToken', '$script:myMemberSID', '$script:proxyUrl')
	# * $nullを@()で包むと要素が1つ($null)の配列になり、if式の結果は配列が展開されてしまうため、@()でif式ごと包む
	$lines = @(if ($null -ne $Content) { $Content })
	$matchedLines = @($lines -match ('^{0}' -f [RegEx]::Escape($Attribute)))
	$parts = @()
	if ($matchedLines.Count -ne 0) { $parts = @($matchedLines[0].Split('=', 2)) }
	if ($parts.Count -lt 2) {
		if ($Attribute -in $undefAttributes) { return $script:msg.SettingUndefined }
		return $script:msg.SettingDefault
	}
	$text = $parts[1].Trim().Trim("'")
	if ($Attribute -eq '$script:preferredLanguage') {
		$text = switch ($text) {
			'ja-JP' { '日本語' }
			'en-US' { 'English' }
			default { $script:msg.SettingDefault }
		}
	}
	switch ($text) {
		'$true' { $text = $script:msg.SettingTrue }
		'$false' { $text = $script:msg.SettingFalse }
	}
	return $text
}

#----------------------------------------------------------------------
# 画面の入力を、user_setting.ps1の1行に変換
#----------------------------------------------------------------------
function ConvertTo-UserSettingLine {
	<#
		.SYNOPSIS
			設定画面の入力から、user_setting.ps1に書き込む1行を作ります。

		.DESCRIPTION
			入力が空、「デフォルト値」、「未設定」のときは、行を作りません($nullを返します)。
			「する」「しない」は$true・$falseに、言語は「日本語」「English」からja-JP・en-USに変換します。
			数値と、$・{・}を含む値(変数や式)は、そのまま書き出し、それ以外は、単一引用符で囲んで書き出します。

		.PARAMETER Attribute
			設定項目の変数名を指定します。例: $script:downloadBaseDir

		.PARAMETER Text
			画面に入力されている文字列を指定します。

		.OUTPUTS
			[String]
			user_setting.ps1に書き込む1行。書き込まない場合は$null。

		.EXAMPLE
			ConvertTo-UserSettingLine -Attribute '$script:loopCycle' -Text '3600'
	#>
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $true)][String]$Attribute,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$Text
	)
	# 言語設定はラベルから保存値に変える
	if ($Attribute -eq '$script:preferredLanguage') {
		$Text = switch ($Text) {
			'日本語' { 'ja-JP' }
			'English' { 'en-US' }
			default { '' }
		}
	}
	if ($Text -in '', $script:msg.SettingDefault, $script:msg.SettingUndefined) { return $null }
	if ($Text -eq $script:msg.SettingTrue) { return ('{0} = $true' -f $Attribute) }
	if ($Text -eq $script:msg.SettingFalse) { return ('{0} = $false' -f $Attribute) }
	$number = 0
	if (([Int]::TryParse($Text, [Ref]$number)) -or ($Text -match '[${}]')) { return ('{0} = {1}' -f $Attribute, $Text) }
	return ('{0} = ''{1}''' -f $Attribute, $Text)
}

#----------------------------------------------------------------------
# 自動生成の区間を差し替えた、user_setting.ps1の内容を作成
#----------------------------------------------------------------------
function Merge-UserSettingContent {
	<#
		.SYNOPSIS
			既存のuser_setting.ps1の、自動生成の区間だけを差し替えた内容を返します。

		.DESCRIPTION
			既存の内容から、自動生成の区間(開始・終了のマーカーの行を含む)を、新しい行に差し替えます。
			区間の前後に、ユーザーが書いた行があれば、そのまま残します。
			既存の内容が空なら、開始マーカー、新しい行、終了マーカーだけを返します。

		.PARAMETER ExistingContent
			既存のuser_setting.ps1の各行を指定します。

		.PARAMETER GeneratedLines
			自動生成の区間に入れる行(マーカーを除く)を指定します。

		.OUTPUTS
			[String[]]
			新しいuser_setting.ps1の各行。

		.NOTES
			既存の内容に、開始マーカーが無ければ、区間の前の行は無く、終了マーカーが無ければ、既存の全行を区間の後ろに残します。
			マーカーが複数ある場合は、最初に見つかったものを区間として扱います。
	#>
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $false)][AllowNull()][AllowEmptyCollection()][AllowEmptyString()][String[]]$ExistingContent = @(),
		[Parameter(Mandatory = $false)][AllowNull()][AllowEmptyCollection()][AllowEmptyString()][String[]]$GeneratedLines = @()
	)
	$startSegment = '##Start Setting Generated from GUI'
	$endSegment = '##End Setting Generated from GUI'
	# * $nullを@()で包むと要素が1つ($null)の配列になり、if式の結果は配列が展開されてしまうため、@()でif式ごと包む
	$existing = @(if ($null -ne $ExistingContent) { $ExistingContent })
	$generated = @(if ($null -ne $GeneratedLines) { $GeneratedLines })
	$total = $existing.Count
	$headLineNum = 0
	$tailLineNum = $total
	if ($total -ne 0) {
		for ($i = 0 ; $i -lt $total ; $i++) { if ($existing[$i] -match $startSegment) { $headLineNum = $i + 1 ; break } }
		for ($i = 0 ; $i -lt $total ; $i++) { if ($existing[$i] -match $endSegment) { $tailLineNum = $total - ($i + 1) ; break } }
	}
	$newSetting = @()
	# 自動生成の開始位置が2行目以降の場合にだけ、自動生成より前の部分がある
	if ($headLineNum -ge 2) { $newSetting += $existing[0..($headLineNum - 2)] }
	$newSetting += $startSegment
	$newSetting += $generated
	$newSetting += $endSegment
	# 自動生成より後の部分
	if (($total -ne 0) -and ($tailLineNum -gt 0)) { $newSetting += $existing[($total - $tailLineNum)..($total - 1)] }
	return $newSetting
}

#----------------------------------------------------------------------
# 動作停止スケジュールの設定行の作成
#----------------------------------------------------------------------
function ConvertTo-StopScheduleLine {
	<#
		.SYNOPSIS
			曜日ごとの停止時間から、user_setting.ps1に書き込む動作停止スケジュールの行を作ります。

		.PARAMETER StopHours
			曜日をキー、停止する時間(0～23)の配列を値とするハッシュテーブルを指定します。

		.PARAMETER Days
			曜日の並び(Mon、Tue、…)を指定します。この順に書き出します。

		.OUTPUTS
			[String[]]
			$script:stopSchedule = @{ ～ } の各行。

		.EXAMPLE
			ConvertTo-StopScheduleLine -StopHours @{ Mon = @(1, 2) } -Days @('Mon', 'Tue')
	#>
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $true)][Hashtable]$StopHours,
		[Parameter(Mandatory = $true)][String[]]$Days
	)
	$stopSetting = @('$script:stopSchedule = @{')
	foreach ($day in $Days) {
		$hoursOfDay = if ($StopHours.ContainsKey($day)) { @($StopHours[$day]) } else { @() }
		$stopSetting += ("`t'{0}' = @({1})" -f $day, ($hoursOfDay -join ', '))
	}
	$stopSetting += '}'
	return $stopSetting
}

#----------------------------------------------------------------------
# 動作停止スケジュールの設定の読み取り
#----------------------------------------------------------------------
function Get-StopScheduleFromSetting {
	<#
		.SYNOPSIS
			user_setting.ps1の動作停止スケジュールから、曜日ごとの停止時間を読み取ります。

		.PARAMETER Content
			user_setting.ps1の各行を指定します。

		.PARAMETER Days
			読み取る曜日(Mon、Tue、…)を指定します。

		.OUTPUTS
			[Hashtable]
			曜日をキー、停止する時間(整数)の配列を値とするハッシュテーブル。設定がない曜日はキーを持ちません。
			読み取り中に解釈できない値があれば、そこまでに読み取れた分を返します。

		.EXAMPLE
			Get-StopScheduleFromSetting -Content (Get-Content ./conf/user_setting.ps1) -Days @('Mon', 'Tue')
	#>
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()][AllowEmptyString()][String[]]$Content,
		[Parameter(Mandatory = $true)][String[]]$Days
	)
	$result = @{}
	try {
		$lines = @(if ($null -ne $Content) { $Content })
		$stopDetail = [RegEx]::Match(($lines -join "`n"), '\$script:stopSchedule\s*=\s*@\{([^}]*)\}')
		if (!$stopDetail.Success) { return $result }
		$stopString = $stopDetail.Groups[1].Value
		foreach ($day in $Days) {
			if ($stopString -match "'$day'\s*=\s*@\(([^)]*)\)") {
				$hoursOfDay = @($matches[1].Split(',').Trim().where({ $_ }).ForEach({ [Int]$_ }))
				if ($hoursOfDay.Count -ne 0) { $result[$day] = $hoursOfDay }
			}
		}
	} catch { return $result }
	return $result
}
