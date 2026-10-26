################################################################################
#
#		TVer固有関数スクリプト(番組情報の取得)
#
################################################################################
<#
	.SYNOPSIS
		TVerのAPI(新旧)から番組の詳細情報を取得する関数を定義します。

	.NOTES
		このファイルはtver_functions.ps1から読み込まれます。
		単体で読み込まず、tver_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#----------------------------------------------------------------------
# TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
function Get-VideoInfo {
	<#
		.SYNOPSIS
			TVerの番組情報を取得します。

		.DESCRIPTION
			指定されたエピソードIDを使用して、新世代API(contents-api.tver.jpのv2/episodes)から番組の詳細情報を取得します。
			1回の呼び出しで、シリーズ・シーズン・エピソードの情報、説明文、エピソード番号、字幕の有無が得られ、
			platform_uid・platform_tokenも不要です。
			次の場合は、旧API(Get-VideoInfoLegacy)にフォールバックします。
			- 新世代APIの呼び出しに失敗した場合、または必要な項目が得られなかった場合
			- 放送局IDがresources/broadcaster/broadcaster.confにない場合(旧APIの放送局名と同じ名称にするため。警告を表示します)

		.PARAMETER episodeID
			情報を取得するエピソードのID。

		.EXAMPLE
			Get-VideoInfo -episodeID "123456"

		.OUTPUTS
			PSCustomObject
			Get-VideoInfoLegacyと同じプロパティを持つオブジェクトを返します。
			新世代APIで取得した場合、versionNumは$nullです(旧APIのstatics取得用のバージョンのため不要)。

		.NOTES
			放送局名は、フォルダ名などに使われるため旧APIのBroadcasterNameと同じ値を返す必要があります。
			そのため新世代APIのproduction_provider(制作局)は使いません(放送局と異なる場合があるため)。
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ([Parameter(Mandatory = $true)][String]$episodeID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$tverVideoInfoURL = 'https://contents-api.tver.jp/contents/api/v2/episodes/{0}' -f $episodeID
	try {
		$response = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec
		$episode = Get-JsonProperty $response @('episode')
		$series = Get-JsonProperty $response @('series')
		$season = Get-JsonProperty $response @('season')
		if (($null -eq $episode) -or ($null -eq $series)) { throw 'episode or series is missing' }
		$videoEpisodeID = [String](Get-JsonProperty $episode @('id'))
		if ($videoEpisodeID -eq '') { throw 'episode id is missing' }
		# 放送局名(旧APIのBroadcasterNameと同じ名称にするため対応表を使用)
		$broadcasterID = [String](Get-JsonProperty $episode @('broadcast_provider_id'))
		$mediaName = Get-BroadcasterName -broadcasterID $broadcasterID
		if ([String]::IsNullOrEmpty($mediaName)) {
			if (-not $script:unknownBroadcasterID.ContainsKey($broadcasterID)) {
				$script:unknownBroadcasterID[$broadcasterID] = $true
				Write-Warning ($script:msg.UnknownBroadcasterID -f $broadcasterID)
			}
			$legacyInfo = Get-VideoInfoLegacy -episodeID $episodeID
			if ($null -ne $legacyInfo) { return $legacyInfo }
			# * 旧APIでも取得できない場合は、他の放送局と混ざらないよう放送局IDをそのまま使用する
			Write-Warning ($script:msg.UnknownBroadcasterIDFallback -f $broadcasterID)
			$mediaName = $broadcasterID
		}
		# 終了日時(UNIX秒)。無ければISO 8601の値から変換する
		$endAt = Get-JsonProperty $episode @('view_status', 'end_at')
		if ($null -eq $endAt) { $endAt = [DateTimeOffset]::Parse([String](Get-JsonProperty $episode @('end_at'))).ToUnixTimeSeconds() }
		# * 実行環境のタイムゾーンに依存せず常に日本時間(JST)で扱う
		$endTime = ConvertFrom-UnixTimeToJst -UnixSeconds $endAt
		# 字幕の有無。項目が無いときは$nullとし、呼び出し側でyoutube-dlでの確認にフォールバックさせる
		$isSubtitleValue = Get-JsonProperty $episode @('is_subtitle')
		$isSubtitle = if ($null -ne $isSubtitleValue) { [Boolean]$isSubtitleValue } else { $null }
		# シリーズ名は旧APIのEpisode.Content.SeriesTitleに合わせ、series.titleを採用(比較して全件一致を確認済み)
		$videoSeries = Format-TitleText (Get-JsonProperty $series @('title'))
		$videoSeriesID = [String](Get-JsonProperty $series @('id'))
		$videoSeason = Format-TitleText (Get-JsonProperty $season @('title'))
		$videoSeasonID = [String](Get-JsonProperty $season @('id'))
		$episodeName = Format-TitleText (Get-JsonProperty $episode @('title'))
		$mediaName = Format-NarrowText $mediaName
		$providerName = Format-NarrowText (Get-JsonProperty $episode @('production_provider', 'display_name'))
		$broadcastDate = Format-BroadcastDateLabel (Get-JsonProperty $episode @('broadcast_date_label'))
		$descriptionText = Format-DescriptionText (Get-JsonProperty $episode @('description'))
		$videoEpisodeNum = Format-NarrowText (Get-JsonProperty $episode @('index_no'))
	} catch {
		# * 新世代APIで取得できなかった場合は旧APIにフォールバック
		Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $_.Exception.Message)
		return (Get-VideoInfoLegacy -episodeID $episodeID)
	}
	return Build-VideoInfoObject -SeriesName $videoSeries -SeriesID $videoSeriesID -SeasonName $videoSeason -SeasonID $videoSeasonID -EpisodeNum $videoEpisodeNum -EpisodeID $videoEpisodeID -EpisodeName $episodeName -MediaName $mediaName -ProviderName $providerName -BroadcastDate $broadcastDate -EndTime $endTime -VersionNum $null -IsSubtitle $isSubtitle -VideoInfoURL $tverVideoInfoURL -DescriptionText $descriptionText
}

#----------------------------------------------------------------------
# 旧APIを叩いて番組情報取得
#----------------------------------------------------------------------
function Get-VideoInfoLegacy {
	<#
		.SYNOPSIS
			旧API(platform-api / statics)でTVerの番組情報を取得します。

		.DESCRIPTION
			指定されたエピソードIDを使用して、旧APIから番組の詳細情報を取得します。
			新世代API(contents-api)で取得できない場合や、放送局IDが対応表にない場合のフォールバックとして
			Get-VideoInfoから呼び出されます。
			取得される情報には以下のようなものがあります：
			- シリーズ情報
			- シーズン情報
			- エピソード情報
			- 放送局情報
			- 放送日時
			- 配信終了日時
			- 番組説明

		.PARAMETER episodeID
			情報を取得するエピソードのID。

		.EXAMPLE
			Get-VideoInfoLegacy -episodeID "123456"

		.OUTPUTS
			PSCustomObject
			以下のプロパティを持つオブジェクトを返します：
			- seriesName: シリーズ名
			- seriesID: シリーズID
			- seriesPageURL: シリーズページのURL
			- seasonName: シーズン名
			- seasonID: シーズンID
			- episodeNum: エピソード番号
			- episodeID: エピソードID
			- episodePageURL: エピソードページのURL
			- episodeName: エピソード名
			- mediaName: 放送局名
			- providerName: 制作会社名
			- broadcastDate: 放送日
			- endTime: 配信終了日時
			- versionNum: バージョン番号
			- isSubtitle: 字幕の有無($true/$false。取得できなければ$null)
			- videoInfoURL: 動画情報のURL
			- descriptionText: 番組説明

		.NOTES
			この関数はTVerのAPIを呼び出し、番組の詳細情報を取得します。
			取得した情報は整形されて返されます。
	#>
	Param ([Parameter(Mandatory = $true)][String]$episodeID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	#----------------------------------------------------------------------
	# 番組説明以外
	$tverVideoInfoBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisode/'
	$tverVideoInfoURL = ('{0}{1}?platform_uid={2}&platform_token={3}' -f $tverVideoInfoBaseURL, $episodeID, $script:platformUID, $script:platformToken)
	try { $response = Invoke-RestMethod -Uri $tverVideoInfoURL -Method 'GET' -Headers $script:commonHttpHeader -TimeoutSec $script:timeoutSec }
	catch { Write-Warning ($script:msg.HttpOtherError -f $_.Exception.Message) ; return }
	# シリーズ
	<#
		* Series.Content.Titleだと複数シーズンがある際に現在メインで配信中のシリーズ名が返ってくることがある
		* Episode.Content.SeriesTitleだとSeries名+Season名が設定される番組もある
		* 3.2.2からEpisode.Content.SeriesTitleを採用することとする。
		* 理由は、Series.Content.Titleだとファイル名が冗長になることがあることと、複数シーズン配信時に最新シーズン名になってしまうことがあるため。
	#>
	$videoSeries = Format-TitleText $response.Result.Episode.Content.SeriesTitle
	$videoSeriesID = $response.Result.Series.Content.Id
	# シーズン
	$videoSeason = Format-TitleText $response.Result.Season.Content.Title
	$videoSeasonID = $response.Result.Season.Content.Id
	# エピソード
	$episodeName = Format-TitleText $response.Result.Episode.Content.Title
	$videoEpisodeID = $response.Result.Episode.Content.Id
	# 放送局
	$mediaName = Format-NarrowText $response.Result.Episode.Content.BroadcasterName
	$providerName = Format-NarrowText $response.Result.Episode.Content.ProductionProviderName
	# 放送日
	$broadcastDate = Format-BroadcastDateLabel $response.Result.Episode.Content.BroadcastDateLabel
	# 配信終了日時
	# * 実行環境のタイムゾーンに依存せず常に日本時間(JST)で扱う。ローカル時刻変換後に+9hするとJST環境で9時間ずれる
	$endTime = ConvertFrom-UnixTimeToJst -UnixSeconds $response.Result.Episode.Content.EndAt
	#----------------------------------------------------------------------
	# 番組説明
	try {
		$versionNum = $response.Result.Episode.Content.version
		$tverVideoInfoBaseURL = 'https://statics.tver.jp/content/episode/'
		$tverVideoInfoURL = ('{0}{1}.json?v={2}' -f $tverVideoInfoBaseURL, $episodeID, $versionNum)
		$httpParams = @{
			Uri        = $tverVideoInfoURL
			Method     = 'GET'
			Headers    = $script:commonHttpHeader
			TimeoutSec = $script:timeoutSec
		}
		if ($script:proxyUrl) { $httpParams.Proxy = $script:proxyUrl }
		$videoInfo = Invoke-RestMethod @httpParams
		Write-Debug $videoInfo
		$descriptionText = Format-DescriptionText $videoInfo.Description
		$videoEpisodeNum = Format-NarrowText $videoInfo.No
		# 字幕の有無(エピソードJSONのisSubtitle)。項目が無いときは$nullとし、呼び出し側でyoutube-dlでの確認にフォールバックさせる
		$isSubtitle = if ($videoInfo.PSObject.Properties.Name -contains 'isSubtitle') { [Boolean]$videoInfo.isSubtitle } else { $null }
		# * StreaksやBrightcoveからM3U8を取得する処理は不要になったため削除(過去の実装はgitの履歴を参照)
	} catch { Write-Warning ($script:msg.VideoInfoRetrievalFailed -f $_.Exception.Message) ; return }

	return Build-VideoInfoObject -SeriesName $videoSeries -SeriesID $videoSeriesID -SeasonName $videoSeason -SeasonID $videoSeasonID -EpisodeNum $videoEpisodeNum -EpisodeID $videoEpisodeID -EpisodeName $episodeName -MediaName $mediaName -ProviderName $providerName -BroadcastDate $broadcastDate -EndTime $endTime -VersionNum $versionNum -IsSubtitle $isSubtitle -VideoInfoURL $tverVideoInfoURL -DescriptionText $descriptionText
}
