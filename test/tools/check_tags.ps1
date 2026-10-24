###################################################################################
#
#		TVerのtag一覧とキーワードサンプルファイルの突き合わせ
#
###################################################################################
<#
	.SYNOPSIS
		TVerで使われているtagを収集し、keyword.sample.confに漏れや無効なtagがないか確認します。

	.DESCRIPTION
		TVerには「tag一覧」を返すAPIがないため、次の4つの情報源からtagの候補を集め、
		すべての候補をtag検索API(callTagSearch)で実際に検索して有効性を確認します。

		1. サイトマップ(https://tver.jp/sitemap.xml)に載っている /tags/xxx
		2. トップページ・カテゴリページのAPIが返すtagへのリンク
		3. 番組情報に含まれる放送局ID(放送局tagはサイトマップに載らないため)
		4. 規則的な名前のtag(zone1〜、曜日)の総当たり
		5. keyword.sample.confに書かれているtag

		tag検索APIは、存在するtagにはHTTP 200(tagの正式名称と件数付き)、
		存在しないtagにはHTTP 404を返すため、これで有効性を判定します。

	.PARAMETER KeywordFile
		突き合わせるキーワードファイルのパス。既定は resources/sample/keyword.sample.conf です。

	.PARAMETER EpisodeSampleSize
		放送局IDを集めるために調べる番組数の上限。多いほど漏れが減りますが時間がかかります。

	.PARAMETER JpIP
		日本国外から実行する場合に、X-Forwarded-Forヘッダに設定する日本のIPアドレス。

	.EXAMPLE
		pwsh ./test/tools/check_tags.ps1

	.EXAMPLE
		pwsh ./test/tools/check_tags.ps1 -EpisodeSampleSize 3000 -OutFile ./tag_report.csv

	.NOTES
		PowerShell 7以上が必要です(ForEach-Object -Parallelを使用)。
		放送局のtagは「調べた番組に出てきた放送局」しか見つからないため、EpisodeSampleSizeを増やすと漏れが減ります。
		TVerRecのリポジトリ内の test/tools に配置して使用します。
#>
[CmdletBinding()]
Param (
	[String]$KeywordFile = (Join-Path $PSScriptRoot '../../resources/sample/keyword.sample.conf'),
	[Int]$EpisodeSampleSize = 1500,
	[String]$JpIP = '',
	[String]$OutFile = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$apiBase = 'https://platform-api.tver.jp/service/api'
$headers = @{
	'x-tver-platform-type' = 'web'
	'Origin'               = 'https://tver.jp'
	'Referer'              = 'https://tver.jp/'
}
if ($JpIP) { $headers['X-Forwarded-For'] = $JpIP }

#----------------------------------------------------------------------
# トークン取得
#----------------------------------------------------------------------
Write-Host '🔑 TVerのトークンを取得しています'
$token = (Invoke-RestMethod -Uri 'https://platform-api.tver.jp/v2/api/platform_users/browser/create' -Method POST -Body 'device_type=pc' -ContentType 'application/x-www-form-urlencoded' -Headers $headers).result
$auth = 'platform_uid={0}&platform_token={1}' -f $token.platform_uid, $token.platform_token

# 候補: tag → 見つかった情報源のリスト
$candidates = @{}
function Add-Candidate ([String]$tag, [String]$source) {
	$tag = ($tag -split '[?#]')[0].Trim('/').Trim()
	if (-not $tag) { return }
	if (-not $candidates.ContainsKey($tag)) { $candidates[$tag] = [System.Collections.Generic.List[String]]::new() }
	if (-not $candidates[$tag].Contains($source)) { $candidates[$tag].Add($source) }
}

#----------------------------------------------------------------------
# 1. サイトマップ
#----------------------------------------------------------------------
Write-Host '🗺️ サイトマップからtagを収集しています'
$sitemap = (Invoke-WebRequest -Uri 'https://tver.jp/sitemap.xml' -Headers $headers).Content
foreach ($m in [RegEx]::Matches($sitemap, '<loc>https://tver\.jp/tags/([^<]+)</loc>')) { Add-Candidate $m.Groups[1].Value 'サイトマップ' }

#----------------------------------------------------------------------
# 2. トップページ・カテゴリページのtagリンク
#----------------------------------------------------------------------
Write-Host '🏠 トップページとカテゴリページからtagを収集しています'
$pages = @('v2/callHome')
try {
	$homeResult = Invoke-RestMethod -Uri ('{0}/v2/callHome?{1}' -f $apiBase, $auth) -Headers $headers
	foreach ($c in @($homeResult.result.categoryTabs)) { if ($c) { $pages += ('v1/callCategoryHome/{0}' -f $c.id) } }
} catch { Write-Warning 'トップページの取得に失敗しました' }
foreach ($page in $pages) {
	try {
		$json = (Invoke-WebRequest -Uri ('{0}/{1}?{2}' -f $apiBase, $page, $auth) -Headers $headers).Content
		foreach ($m in [RegEx]::Matches($json, '/tags/([A-Za-z0-9_\-]+)')) { Add-Candidate $m.Groups[1].Value 'トップ/カテゴリ' }
	} catch { Write-Warning ('{0} の取得に失敗しました' -f $page) }
}

#----------------------------------------------------------------------
# 3. 番組情報の放送局ID
#----------------------------------------------------------------------
Write-Host '📺 番組情報から放送局IDを収集しています'
$episodes = @{}
$episodeSources = @('v1/callNewerDetail/all', 'v1/callEnderDetail/all', 'v1/callEpisodeRanking', 'v1/callTagSearch/independence', 'v1/callTagSearch/zone1', 'v1/callTagSearch/short')
foreach ($src in $episodeSources) {
	try {
		$r = Invoke-RestMethod -Uri ('{0}/{1}?{2}' -f $apiBase, $src, $auth) -Headers $headers
		$contents = $r.result.contents
		# 新着・終了間近・ランキングは1階層深い
		$items = foreach ($c in @($contents)) { if ($c.PSObject.Properties.Name -contains 'contents') { $c.contents } else { $c } }
		foreach ($i in @($items)) { if ($i.type -eq 'episode') { $episodes[$i.content.id] = $i.content.version } }
	} catch { Write-Warning ('{0} の取得に失敗しました' -f $src) }
}
$providers = @($episodes.GetEnumerator() | Select-Object -First $EpisodeSampleSize | ForEach-Object -ThrottleLimit 16 -Parallel {
		try {
			$s = Invoke-RestMethod -Uri ('https://statics.tver.jp/content/episode/{0}.json?v={1}' -f $_.Key, $_.Value) -Headers $using:headers -TimeoutSec 20
			if ($s.broadcastProviderID) { [PSCustomObject]@{ id = $s.broadcastProviderID ; label = $s.broadcastProviderLabel } }
		} catch {}
	} | Sort-Object id -Unique)
# * 放送局IDとtagのIDが偶然一致する場合がある(例: サンテレビの「sun」と日曜日の「sun」)ため、放送局名も記録する
foreach ($p in $providers) {
	Add-Candidate $p.id ('放送局ID({0})' -f $p.label)
	# * 放送局IDが別のtagと衝突している場合、「{ID}tv」が放送局のtagになっていることがある(例: サンテレビは「suntv」)
	Add-Candidate ('{0}tv' -f $p.id) ('放送局ID+tv({0})' -f $p.label)
}
Write-Host ('　番組{0}件から放送局ID {1}種類を収集しました' -f [Math]::Min($episodes.Count, $EpisodeSampleSize), $providers.Count)

#----------------------------------------------------------------------
# 4. 規則的な名前のtag
#----------------------------------------------------------------------
1..12 | ForEach-Object { Add-Candidate ('zone{0}' -f $_) '総当たり' }
'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun' | ForEach-Object { Add-Candidate $_ '総当たり' }

#----------------------------------------------------------------------
# 5. キーワードファイル
#----------------------------------------------------------------------
$sample = [ordered]@{}
if (Test-Path $KeywordFile) {
	foreach ($line in Get-Content -LiteralPath $KeywordFile) {
		if ($line -match '^#*\s*tag/([^\s#]+)\s*(?:#(.*))?$') {
			$sample[$Matches[1]] = if ($Matches[2]) { $Matches[2].Trim() } else { '' }
			Add-Candidate $Matches[1] 'キーワードファイル'
		}
	}
} else { Write-Warning ('キーワードファイルが見つかりません: {0}' -f $KeywordFile) }

#----------------------------------------------------------------------
# 全候補をtag検索APIで確認
#----------------------------------------------------------------------
Write-Host ('🔍 tag候補 {0}件をTVerで検索して確認しています' -f $candidates.Count)
$results = @($candidates.Keys | Sort-Object | ForEach-Object -ThrottleLimit 8 -Parallel {
		$tag = $_
		$status = 0 ; $name = '' ; $count = $null
		try {
			$r = Invoke-RestMethod -Uri ('{0}/v1/callTagSearch/{1}?{2}' -f $using:apiBase, [Uri]::EscapeDataString($tag), $using:auth) -Headers $using:headers -TimeoutSec 20
			$status = 200
			if ($r.result.PSObject.Properties.Name -contains 'tag') { $name = $r.result.tag.name }
			if ($r.result.PSObject.Properties.Name -contains 'resultCount') { $count = $r.result.resultCount }
			else { $count = @($r.result.contents | Where-Object type -EQ 'episode').Count }
		} catch {
			$status = if ($_.Exception.Response) { [Int]$_.Exception.Response.StatusCode } else { -1 }
		}
		[PSCustomObject]@{ tag = $tag ; status = $status ; name = $name ; count = $count }
	})

$report = foreach ($r in $results) {
	$inSample = $sample.Contains($r.tag)
	$state = switch ($true) {
		{ $r.status -eq 404 -and $inSample } { '❌ 無効(サンプルから削除候補)' ; break }
		{ $r.status -eq 404 } { $null ; break }	# 総当たりで存在しなかったものは表示しない
		{ $r.status -ne 200 } { ('⚠️ 確認失敗(HTTP {0})' -f $r.status) ; break }
		{ -not $inSample } { '★ 未掲載(サンプルへの追加候補)' ; break }
		{ $r.count -eq 0 } { '💤 有効だが現在0件' ; break }
		default { '✅ 掲載済み' }
	}
	if ($state) {
		[PSCustomObject]@{
			状態          = $state
			tag           = $r.tag
			TVer上の名称  = $r.name
			件数          = $r.count
			サンプルの名称 = if ($inSample) { $sample[$r.tag] } else { '' }
			情報源        = ($candidates[$r.tag] -join ', ')
		}
	}
}

$report = $report | Sort-Object 状態, tag
Write-Host ''
$report | Where-Object 状態 -NE '✅ 掲載済み' | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
Write-Host ('掲載済みで有効: {0}件 / 未掲載: {1}件 / 無効: {2}件 / 0件: {3}件' -f
	@($report | Where-Object 状態 -Like '✅*').Count,
	@($report | Where-Object 状態 -Like '★*').Count,
	@($report | Where-Object 状態 -Like '❌*').Count,
	@($report | Where-Object 状態 -Like '💤*').Count)

# サンプルに追記できる形式で出力
$missing = @($report | Where-Object 状態 -Like '★*')
if ($missing.Count -gt 0) {
	Write-Host ''
	Write-Host '📝 keyword.sample.conf に追記する場合の行:'
	foreach ($m in $missing) { Write-Host ('#tag/{0}	#{1}' -f $m.tag, $m.'TVer上の名称') }
}

if ($OutFile) {
	$report | Export-Csv -LiteralPath $OutFile -Encoding UTF8 -NoTypeInformation
	Write-Host ('💾 結果を保存しました: {0}' -f $OutFile)
}
