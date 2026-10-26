################################################################################
#
#		TVer固有関数スクリプト(番組情報の整形)
#
################################################################################
<#
	.SYNOPSIS
		番組情報の整形(放送局名、タイトル、放送日、説明文など)と、番組情報オブジェクトの生成の関数を定義します。

	.NOTES
		このファイルはtver_functions.ps1から読み込まれます。
		単体で読み込まず、tver_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

# 放送局IDと放送局名の対応表(Get-BroadcasterNameが初回呼び出し時に読み込む)と、対応表にない放送局IDの警告済み管理
$script:broadcasterMap = $null
$script:unknownBroadcasterID = @{}

#----------------------------------------------------------------------
# JSONの入れ子のプロパティを安全に取得
#----------------------------------------------------------------------
function Get-JsonProperty {
	<#
		.SYNOPSIS
			JSONから変換したオブジェクトの入れ子のプロパティを安全に取得します。

		.DESCRIPTION
			Set-StrictModeが有効でも、途中のプロパティが存在しない場合に例外とならず$nullを返します。

		.PARAMETER object
			取得元のオブジェクト。

		.PARAMETER path
			たどるプロパティ名の配列。

		.EXAMPLE
			Get-JsonProperty $response @('episode', 'title')
	#>
	[CmdletBinding()]
	[OutputType([Object])]
	Param (
		[Parameter(Mandatory = $false)][AllowNull()][Object]$object,
		[Parameter(Mandatory = $true)][String[]]$path
	)
	$current = $object
	foreach ($name in $path) {
		if ($null -eq $current) { return $null }
		if ($current.PSObject.Properties.Name -contains $name) { $current = $current.$name }
		else { return $null }
	}
	return $current
}

#----------------------------------------------------------------------
# 放送局IDから放送局名を取得
#----------------------------------------------------------------------
function Get-BroadcasterName {
	<#
		.SYNOPSIS
			放送局IDから放送局名を取得します。

		.DESCRIPTION
			新世代API(contents-api)は放送局名ではなく放送局ID(broadcast_provider_id)を返すため、
			resources/broadcaster/broadcaster.confの対応表から、旧APIのBroadcasterNameと同じ放送局名を取得します。
			対応表は初回の呼び出し時に読み込み、以降は読み込み済みの内容を使用します。
			対応表にない放送局IDの場合は$nullを返します。

		.PARAMETER broadcasterID
			放送局ID(例: tx)。

		.EXAMPLE
			Get-BroadcasterName -broadcasterID 'tx'
	#>
	[CmdletBinding()]
	[OutputType([String])]
	Param ([Parameter(Mandatory = $true)][AllowEmptyString()][String]$broadcasterID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($null -eq $script:broadcasterMap) {
		$map = @{}
		try {
			foreach ($line in (Get-Content -Path (Join-Path $script:broadcasterDir 'broadcaster.conf') -Encoding UTF8 -ErrorAction Stop)) {
				if (($line.Trim() -eq '') -or $line.TrimStart().StartsWith('#')) { continue }
				$columns = $line.Split("`t")
				if ($columns.Count -ge 2) { $map[$columns[0].Trim()] = $columns[1].Trim() }
			}
		} catch { Write-Warning ($script:msg.BroadcasterListLoadFailed -f $_.Exception.Message) }
		$script:broadcasterMap = $map
	}
	if ($script:broadcasterMap.ContainsKey($broadcasterID)) { return $script:broadcasterMap[$broadcasterID] }
	return $null
}

#----------------------------------------------------------------------
# 番組情報のシーズン名・エピソード番号・放送日を整形
#----------------------------------------------------------------------
function Format-VideoInfoText {
	<#
		.SYNOPSIS
			番組情報のシーズン名・エピソード名・エピソード番号・放送日を整形します。

		.DESCRIPTION
			新旧どちらのAPIで取得した番組情報にも共通する整形処理です。
			- 「《」と「》」で挟まれた文字の除去(設定が有効な場合)
			- シーズン名が「本編」の場合や、シリーズ名がシーズン名を含む場合のシーズン名のクリア
			- エピソード番号の補正と2桁への0埋め
			- 放送日への年の補完

		.PARAMETER seriesName
			シリーズ名。

		.PARAMETER seasonName
			シーズン名。

		.PARAMETER episodeName
			エピソード名。

		.PARAMETER episodeNum
			エピソード番号。

		.PARAMETER broadcastDate
			放送日の表示文字列(例: 10月18日(日)放送)。

		.OUTPUTS
			PSCustomObject
			seasonName、episodeName、episodeNum、broadcastDateを持つオブジェクトを返します。
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$seriesName,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$seasonName,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$episodeName,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$episodeNum,
		[Parameter(Mandatory = $true)][AllowEmptyString()][String]$broadcastDate
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$videoSeries = $seriesName
	$videoSeason = $seasonName
	$videoEpisodeNum = $episodeNum
	# 「《」と「》」で挟まれた文字を除去
	if ($script:removeSpecialNote) { $videoSeason = Remove-SpecialNote $videoSeason ; $episodeName = Remove-SpecialNote $episodeName }
	# シーズン名が本編の場合はシーズン名をクリア
	if ($videoSeason -eq '本編') { $videoSeason = '' }
	# シリーズ名がシーズン名を含む場合はシーズン名をクリア
	if ($videoSeries -cmatch [RegEx]::Escape($videoSeason)) { $videoSeason = '' }
	# エピソード番号を極力修正
	if (($videoEpisodeNum -match '^\d+$') -and (([Int]$videoEpisodeNum -eq 1) -or ([Int]$videoEpisodeNum % 10 -eq 0)) -and ($episodeName -imatch '((?:#|第|Episode|ep|Take|Vol|Part|Chapter|Flight|Karte|Case|Stage|Mystery|Ope|Story|Sign|Trap|Letter|Act)+\.?\s?)(\d+)(.*)')) { $videoEpisodeNum = $matches[2] }
	# エピソード番号が1桁の際は頭0埋めして2桁に
	$videoEpisodeNum = $videoEpisodeNum.PadLeft(2, '0')
	# 放送日を整形
	if ($broadcastDate -cmatch '([0-9]+)(月)([0-9]+)(日)(.+?)(放送|配信)') {	# ! きょうのわんこなど「2025/3/17週放送」のようなパターンもある
		$currentYear = (Get-Date).Year
		try {
			$parsedBroadcastDate = [DateTime]::ParseExact(('{0}{1}{2}' -f $currentYear, $matches[1].PadLeft(2, '0'), $matches[3].PadLeft(2, '0')), 'yyyyMMdd', $null)
			# * 実日付の翌日よりも放送日が未来だったら当年ではなく昨年の番組と判断する(年末の番組を年初にダウンロードするケース)
			$broadcastYear = $parsedBroadcastDate -gt (Get-Date).AddDays(+1) ? $currentYear - 1 : $currentYear
			$broadcastDate = ('{0}年{1}{2}{3}{4}{5}' -f $broadcastYear, $matches[1].PadLeft(2, '0'), $matches[2], $matches[3].PadLeft(2, '0'), $matches[4], $matches[6])
		} catch {
			# * 上記でエラーが出た場合は年が間違っているはず。年が不明なので年無しで整形する
			$broadcastDate = ('{0}{1}{2}{3}{4}' -f $matches[1].PadLeft(2, '0'), $matches[2], $matches[3].PadLeft(2, '0'), $matches[4], $matches[6])
		}
	}
	return [PSCustomObject]@{
		seasonName    = $videoSeason
		episodeName   = $episodeName
		episodeNum    = $videoEpisodeNum
		broadcastDate = $broadcastDate
	}
}

#----------------------------------------------------------------------
# UNIX時間(秒)を日本時間(JST)の日時に変換
#----------------------------------------------------------------------
function ConvertFrom-UnixTimeToJst {
	<#
		.SYNOPSIS
			UNIX時間(秒)を日本時間(JST)の日時に変換します。

		.DESCRIPTION
			実行環境のタイムゾーンに依存せず、常に日本時間(JST)で扱います。
			ローカル時刻に変換してから+9時間すると、JST環境で9時間ずれるためです。

		.PARAMETER UnixSeconds
			UNIX時間(秒)を指定します。

		.OUTPUTS
			[DateTime]
	#>
	[OutputType([DateTime])]
	Param ([Parameter(Mandatory = $true)][Int64]$UnixSeconds)
	return [DateTimeOffset]::FromUnixTimeSeconds($UnixSeconds).ToOffset([TimeSpan]::FromHours(9)).DateTime
}

#----------------------------------------------------------------------
# シリーズ名・シーズン名・エピソード名をファイル名に使える形に整形
#----------------------------------------------------------------------
function Format-TitleText {
	<#
		.SYNOPSIS
			シリーズ名・シーズン名・エピソード名を、ファイル名に使える形に整形します。

		.DESCRIPTION
			全角英数字などの半角化、ファイル名に使えない文字の除去、前後の空白の除去を行います。

		.PARAMETER Text
			整形する文字列を指定します。$nullは空文字として扱います。

		.OUTPUTS
			[String]
	#>
	[OutputType([String])]
	Param ([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$Text)
	return (Remove-SpecialCharacter (Get-NarrowChar $Text)).Trim()
}

#----------------------------------------------------------------------
# 放送局名・制作会社名などを半角化して前後の空白を除去
#----------------------------------------------------------------------
function Format-NarrowText {
	<#
		.SYNOPSIS
			放送局名・制作会社名などを、全角英数字などを半角化して前後の空白を除去します。

		.PARAMETER Text
			整形する文字列を指定します。$nullは空文字として扱います。

		.OUTPUTS
			[String]
	#>
	[OutputType([String])]
	Param ([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$Text)
	return (Get-NarrowChar $Text).Trim()
}

#----------------------------------------------------------------------
# 放送日の表示文字列を整形(「ほか」の除去、「放送分」「配信分」の置換)
#----------------------------------------------------------------------
function Format-BroadcastDateLabel {
	<#
		.SYNOPSIS
			放送日の表示文字列から、「ほか」を除き、「放送分」「配信分」を「放送」「配信」にします。

		.PARAMETER Text
			放送日の表示文字列を指定します。$nullは空文字として扱います。

		.OUTPUTS
			[String]
	#>
	[OutputType([String])]
	Param ([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$Text)
	return $Text.Replace('ほか', '').Replace('放送分', '放送').Replace('配信分', '配信').Trim()
}

#----------------------------------------------------------------------
# 番組説明を整形(「&amp;」の置換、半角化、前後の空白の除去)
#----------------------------------------------------------------------
function Format-DescriptionText {
	<#
		.SYNOPSIS
			番組説明の「&amp;」を「&」にし、全角英数字などを半角化して前後の空白を除去します。

		.PARAMETER Text
			番組説明を指定します。$nullは空文字として扱います。

		.OUTPUTS
			[String]
	#>
	[OutputType([String])]
	Param ([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$Text)
	return (Get-NarrowChar $Text.Replace('&amp;', '&')).Trim()
}

#----------------------------------------------------------------------
# 番組情報オブジェクトの作成(新旧APIで共通)
#----------------------------------------------------------------------
function New-VideoInfoObject {
	<#
		.SYNOPSIS
			Get-VideoInfoとGet-VideoInfoLegacyが返す番組情報オブジェクトを作成します。

		.DESCRIPTION
			シーズン名・エピソード名・エピソード番号・放送日をFormat-VideoInfoTextで整形し、
			シリーズ・エピソードのページURLを組み立てて、番組情報オブジェクトを返します。
			新旧どちらのAPIで取得した場合も、同じプロパティを同じ順序で返します。

		.OUTPUTS
			[PSCustomObject]
			seriesName、seriesID、seriesPageURL、seasonName、seasonID、episodeNum、episodeID、episodePageURL、
			episodeName、mediaName、providerName、broadcastDate、endTime、versionNum、isSubtitle、
			videoInfoURL、descriptionText を持つオブジェクト。
	#>
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$SeriesName,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$SeriesID,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$SeasonName,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$SeasonID,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$EpisodeNum,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$EpisodeID,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$EpisodeName,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$MediaName,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$ProviderName,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$BroadcastDate,
		[Parameter(Mandatory = $true)][DateTime]$EndTime,
		[Parameter(Mandatory = $true)][AllowNull()]$VersionNum,
		[Parameter(Mandatory = $true)][AllowNull()]$IsSubtitle,
		[Parameter(Mandatory = $true)][String]$VideoInfoURL,
		[Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][String]$DescriptionText
	)
	# 「《」と「》」で挟まれた文字の除去、シーズン名・エピソード番号・放送日の整形
	$formatted = Format-VideoInfoText -seriesName $SeriesName -seasonName $SeasonName -episodeName $EpisodeName -episodeNum $EpisodeNum -broadcastDate $BroadcastDate
	return [PSCustomObject]@{
		seriesName      = $SeriesName
		seriesID        = $SeriesID
		seriesPageURL   = ('https://tver.jp/series/{0}' -f $SeriesID)
		seasonName      = $formatted.seasonName
		seasonID        = $SeasonID
		episodeNum      = $formatted.episodeNum
		episodeID       = $EpisodeID
		episodePageURL  = ('https://tver.jp/episodes/{0}' -f $EpisodeID)
		episodeName     = $formatted.episodeName
		mediaName       = $MediaName
		providerName    = $ProviderName
		broadcastDate   = $formatted.broadcastDate
		endTime         = $EndTime
		versionNum      = $VersionNum
		isSubtitle      = $IsSubtitle
		videoInfoURL    = $VideoInfoURL
		descriptionText = $DescriptionText
	}
}
