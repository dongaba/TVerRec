Import-Module Pester -MinimumVersion 5.0

#----------------------------------------------------------------------
# tver_functions.ps1 のテスト
#
#   Invoke-Pester ./test/functions/tver_functions.Test.ps1 -Output Detailed               # すべて
#   Invoke-Pester ./test/functions/tver_functions.Test.ps1 -Output Detailed -ExcludeTag 'TVer'   # モックのみ(オフライン)
#   Invoke-Pester ./test/functions/tver_functions.Test.ps1 -Output Detailed -Tag 'TVer'   # TVerへの実接続のみ
#
#   ※ TVerタグのテストは日本国内(またはVPN/Proxy経由)からの実行を前提とします
#----------------------------------------------------------------------

# region BeforeAll
BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$targetFile = $PSCommandPath.Replace('test', 'src').Replace('.Test.ps1', '.ps1')
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:scriptRoot = Convert-Path ./src
	Set-Location $script:scriptRoot
	$script:disableToastNotification = $false
	# メッセージテーブル(警告メッセージの書式に必要)
	$script:msg = (Get-Content -Path (Join-Path $script:scriptRoot '../resources/lang/messages.json') -Raw | ConvertFrom-Json).'ja-JP'
	. ($targetFile).Replace('tver', 'common')
	function Invoke-StatisticsCheck {}
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')

	# 関数が参照するスクリプト変数(StrictMode下で未定義参照にならないように初期化)
	$script:timeoutSec = 30
	$script:jpIP = '133.242.0.10'
	$script:proxyUrl = $null
	$script:myMemberSID = $null
	$script:myPlatformUID = $null
	$script:myPlatformToken = $null
	$script:platformUID = 'test-uid'
	$script:platformToken = 'test-token'
	$script:sitemapParseEpisodeOnly = $true
	$script:removeSpecialNote = $false
	$script:commonHttpHeader = @{
		'x-tver-platform-type' = 'web'
		'Origin'               = 'https://tver.jp'
		'Referer'              = 'https://tver.jp/'
		'X-Forwarded-For'      = $script:jpIP
	}

	# テスト用のリンクコレクションを生成
	function New-TestLinkCollection {
		[PSCustomObject]@{
			episodeLinks     = @{}
			seriesLinks      = New-Object System.Collections.Generic.List[String]
			seasonLinks      = New-Object System.Collections.Generic.List[String]
			talentLinks      = New-Object System.Collections.Generic.List[String]
			specialMainLinks = New-Object System.Collections.Generic.List[String]
			specialLinks     = New-Object System.Collections.Generic.List[String]
			categoryLinks    = New-Object System.Collections.Generic.List[String]
		}
	}
	# APIレスポンスのコンテンツ要素を生成
	function New-Item ([String]$type, [String]$id, [Int64]$endAt = 0) {
		[PSCustomObject]@{ type = $type ; content = [PSCustomObject]@{ id = $id ; endAt = $endAt } }
	}
}
# endregion BeforeAll

#----------------------------------------------------------------------
# TVerのAPI Tokenを取得
#----------------------------------------------------------------------
Describe 'Get-Token' {
	Context 'モックチェック' {
		BeforeEach {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ platform_uid = 'mocked-uid' ; platform_token = 'mocked-token' } } }
		}
		AfterAll {
			$script:platformUID = 'test-uid'
			$script:platformToken = 'test-token'
		}

		It 'トークンが変数にセットされること' {
			Get-Token
			$script:platformUID | Should -BeExactly 'mocked-uid'
			$script:platformToken | Should -BeExactly 'mocked-token'
		}
		It '呼び出しの引数が正しいこと' {
			Get-Token
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
				$Uri -eq 'https://platform-api.tver.jp/v2/api/platform_users/browser/create' -and
				$Method -eq 'POST' -and
				$Body -eq 'device_type=pc'
			}
		}
		It 'HTTPエラーの際に例外を投げること' {
			Mock Invoke-RestMethod { throw 'error' }
			{ Get-Token } | Should -Throw
		}
	}
}

#----------------------------------------------------------------------
# URLからエピソードIDを抽出 (#301 のリグレッション)
#----------------------------------------------------------------------
Describe 'Get-EpisodeIDFromURL' {
	It '<url> から <expected> を抽出すること' -ForEach @(
		@{ url = 'https://tver.jp/episodes/epuaqm8ooq' ; expected = 'epuaqm8ooq' }
		@{ url = 'https://tver.jp/episodes/epuaqm8ooq?p=0' ; expected = 'epuaqm8ooq' }
		@{ url = 'https://tver.jp/episodes/epuaqm8ooq?play=feature&p=0' ; expected = 'epuaqm8ooq' }
		@{ url = 'https://tver.jp/episodes/epuaqm8ooq/' ; expected = 'epuaqm8ooq' }
		@{ url = 'https://tver.jp/episodes/epuaqm8ooq#top' ; expected = 'epuaqm8ooq' }
	) {
		Get-EpisodeIDFromURL -url $url | Should -BeExactly $expected
	}
	It 'エピソード以外のURLでは空文字を返すこと: <url>' -ForEach @(
		@{ url = 'https://tver.jp/series/sre2549ef6' }
		@{ url = 'https://tver.jp/episodes/' }
		@{ url = 'https://example.com/episodes/epuaqm8ooq' }
		@{ url = '' }
	) {
		Get-EpisodeIDFromURL -url $url | Should -BeExactly ''
	}
}

#----------------------------------------------------------------------
# キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
Describe 'Get-VideoLinksFromKeyword' {
	Context 'モックチェック' {
		BeforeEach {
			Mock Get-LinkFromKeyword {}
			Mock Get-LinkFromTopPage {}
			Mock Get-LinkFromSiteMap {}
			Mock Get-LinkFromMyPage {}
		}

		It 'episodes指定でエピソードIDをそのまま返すこと' {
			Get-VideoLinksFromKeyword -keyword 'episodes/epuaqm8ooq' | Should -BeExactly 'epuaqm8ooq'
		}
		It 'episodes指定でクエリ文字列やコメントを除去すること' {
			Get-VideoLinksFromKeyword -keyword "episodes/epuaqm8ooq?p=0`t#コメント" | Should -BeExactly 'epuaqm8ooq'
		}
		It 'series指定でseriesLinksとしてAPI呼び出しされること' {
			Get-VideoLinksFromKeyword -keyword 'series/sre2549ef6?p=0' | Out-Null
			Should -Invoke Get-LinkFromKeyword -Times 1 -Exactly -ParameterFilter { $id -eq 'sre2549ef6' -and $linkType -eq 'seriesLinks' }
		}
		It '<keyword> が <linkType> として処理されること' -ForEach @(
			@{ keyword = 'tag/golf' ; id = 'golf' ; linkType = 'tag' }
			@{ keyword = 'new/all' ; id = 'all' ; linkType = 'new' }
			@{ keyword = 'end/drama' ; id = 'drama' ; linkType = 'end' }
			@{ keyword = 'ranking/all' ; id = 'all' ; linkType = 'ranking' }
		) {
			$expectedId = $id ; $expectedLinkType = $linkType
			Get-VideoLinksFromKeyword -keyword $keyword | Out-Null
			Should -Invoke Get-LinkFromKeyword -Times 1 -Exactly -ParameterFilter { $id -eq $expectedId -and $linkType -eq $expectedLinkType }
		}
		It 'フリーワードはkeywordとして処理されること' {
			Get-VideoLinksFromKeyword -keyword 'カンブリア' | Out-Null
			Should -Invoke Get-LinkFromKeyword -Times 1 -Exactly -ParameterFilter { $id -eq 'カンブリア' -and $linkType -eq 'keyword' }
		}
		It 'toppage/sitemapがそれぞれの関数に振り分けられること' {
			Get-VideoLinksFromKeyword -keyword 'toppage' | Out-Null
			Get-VideoLinksFromKeyword -keyword 'sitemap' | Out-Null
			Should -Invoke Get-LinkFromTopPage -Times 1 -Exactly
			Should -Invoke Get-LinkFromSiteMap -Times 1 -Exactly
		}
		It '結果が0件の場合は何も返さないこと' {
			Get-VideoLinksFromKeyword -keyword 'tag/golf' | Should -BeNullOrEmpty
		}
	}
}

#----------------------------------------------------------------------
# IDまたはキーワードによる番組検索
#----------------------------------------------------------------------
Describe 'Get-LinkFromKeyword' {
	Context 'モックチェック' {
		BeforeEach { Mock Get-SearchResult {} }

		It '<linkType> で正しいURLとTypeが渡されること' -ForEach @(
			@{ linkType = 'seriesLinks' ; id = 'sr1' ; url = 'https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/sr1' ; type = '' }
			@{ linkType = 'seasonLinks' ; id = 's1' ; url = 'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/s1' ; type = '' }
			@{ linkType = 'talentLinks' ; id = 't1' ; url = 'https://platform-api.tver.jp/service/api/v1/callTalentEpisode/t1' ; type = '' }
			@{ linkType = 'specialMainLinks' ; id = 'sm1' ; url = 'https://platform-api.tver.jp/service/api/v1/callSpecialContents/sm1' ; type = 'specialmain' }
			@{ linkType = 'specialLinks' ; id = 'sp1' ; url = 'https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/sp1' ; type = 'specialdetail' }
			@{ linkType = 'tag' ; id = 'golf' ; url = 'https://platform-api.tver.jp/service/api/v1/callTagSearch/golf' ; type = '' }
			@{ linkType = 'new' ; id = 'all' ; url = 'https://platform-api.tver.jp/service/api/v1/callNewerDetail/all' ; type = 'new' }
			@{ linkType = 'end' ; id = 'all' ; url = 'https://platform-api.tver.jp/service/api/v1/callEnderDetail/all' ; type = 'end' }
			@{ linkType = 'ranking' ; id = 'all' ; url = 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' ; type = 'ranking' }
			@{ linkType = 'ranking' ; id = 'drama' ; url = 'https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/drama' ; type = 'ranking' }
			@{ linkType = 'category' ; id = 'drama' ; url = 'https://platform-api.tver.jp/service/api/v1/callCategoryHome/drama' ; type = 'category' }
			@{ linkType = 'keyword' ; id = 'カンブリア' ; url = 'https://platform-api.tver.jp/service/api/v2/callKeywordSearch' ; type = 'keyword' }
		) {
			$lc = New-TestLinkCollection
			$expectedUrl = $url ; $expectedType = $type
			Get-LinkFromKeyword -id $id -linkType $linkType -LinkCollection ([Ref]$lc)
			Should -Invoke Get-SearchResult -Times 1 -Exactly -ParameterFilter { $baseURL -eq $expectedUrl -and "$Type" -eq $expectedType }
		}
	}
}

#----------------------------------------------------------------------
# 検索結果の解析
#----------------------------------------------------------------------
Describe 'Get-SearchResult' {
	Context 'モックチェック' {
		BeforeEach { Mock Get-LinkFromKeyword {} ; Mock Write-Warning {} }

		It '通常の検索結果を種類別に振り分けること(live/bannerは除外)' {
			Mock Invoke-RestMethod {
				[PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = @(
							(New-Item 'episode' 'ep1' 100), (New-Item 'live' 'le1'), (New-Item 'banner' 'b1'),
							(New-Item 'series' 'sr1'), (New-Item 'season' 's1'), (New-Item 'talent' 't1'), (New-Item 'specialMain' 'sm1')
						)
					}
				}
			}
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -LinkCollection ([Ref]$lc)
			$lc.episodeLinks['ep1'] | Should -Be 100
			$lc.seriesLinks | Should -Be @('sr1')
			$lc.seasonLinks | Should -Be @('s1')
			$lc.talentLinks | Should -Be @('t1')
			$lc.specialMainLinks | Should -Be @('sm1')
			Should -Invoke Write-Warning -Times 0 -Exactly
		}
		It '匿名アクセス時にplatform_uid/platform_tokenとキーワードが付与されること' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = @() } } }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -Type 'keyword' -Keyword 'abc' -LinkCollection ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example/api?platform_uid=test-uid&platform_token=test-token&keyword=abc' }
		}
		It 'ログイン時はmember_sidが付与されること' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = @() } } }
			$script:myMemberSID = 'sid123'
			try {
				$lc = New-TestLinkCollection
				Get-SearchResult -baseURL 'https://example/api' -Type 'mypage' -RequireData 'later' -LoginRequired $true -LinkCollection ([Ref]$lc)
				Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example/api?member_sid=sid123&require_data=later' }
			} finally { $script:myMemberSID = $null }
		}
		It 'new/end/rankingは入れ子のContentsを参照すること' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = [PSCustomObject]@{ Contents = @((New-Item 'episode' 'ep2' 200)) } } } }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -Type 'new' -LinkCollection ([Ref]$lc)
			$lc.episodeLinks.Keys | Should -Be @('ep2')
		}
		It 'specialmainのspecialはspecialLinksに追加されること' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ specialContents = @((New-Item 'special' 'sp1')) } } }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -Type 'specialmain' -LinkCollection ([Ref]$lc)
			$lc.specialLinks | Should -Be @('sp1')
		}
		It 'specialdetailはContent.Contentsを参照すること' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = [PSCustomObject]@{ Content = [PSCustomObject]@{ Contents = @((New-Item 'series' 'sr9')) } } } } }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -Type 'specialdetail' -LinkCollection ([Ref]$lc)
			$lc.seriesLinks | Should -Be @('sr9')
		}
		It 'categoryはcomponents配下のcontentsを参照すること' {
			Mock Invoke-RestMethod {
				[PSCustomObject]@{ Result = [PSCustomObject]@{ components = @(
							[PSCustomObject]@{ type = 'billboard' ; contents = @((New-Item 'specialMain' 'sm7')) },
							[PSCustomObject]@{ type = 'richHorizontal' ; contents = @((New-Item 'episode' 'ep7' 700), (New-Item 'series' 'sr7')) }
						)
					}
				}
			}
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -Type 'category' -LinkCollection ([Ref]$lc)
			$lc.episodeLinks['ep7'] | Should -Be 700
			$lc.seriesLinks | Should -Be @('sr7')
			$lc.specialMainLinks | Should -Be @('sm7')
		}
		It 'HTTPエラー時は警告を出して例外を投げないこと' {
			Mock Invoke-RestMethod { throw 'Response status code does not indicate success: 400 (Bad Request).' }
			$lc = New-TestLinkCollection
			{ Get-SearchResult -baseURL 'https://example/api' -LinkCollection ([Ref]$lc) } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 1 -Exactly
		}
	}
}

#----------------------------------------------------------------------
# トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'Get-LinkFromTopPage' {
	Context 'モックチェック' {
		BeforeEach { Mock Write-Warning {} }

		It 'v2のcallHomeを呼び出すこと' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ components = @([PSCustomObject]@{ type = 'newer' ; contents = @((New-Item 'episode' 'ep1')) }) } } }
			$lc = New-TestLinkCollection
			Get-LinkFromTopPage ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -like 'https://platform-api.tver.jp/service/api/v2/callHome?platform_uid=*' }
		}
		It 'liveの後ろにあるコンテンツも取りこぼさないこと' {
			Mock Invoke-RestMethod {
				[PSCustomObject]@{ Result = [PSCustomObject]@{ components = @(
							[PSCustomObject]@{ type = 'richHorizontal' ; contents = @((New-Item 'episode' 'ep1'), (New-Item 'live' 'le1'), (New-Item 'episode' 'ep2'), (New-Item 'series' 'sr1')) }
						)
					}
				}
			}
			$lc = New-TestLinkCollection
			Get-LinkFromTopPage ([Ref]$lc)
			@($lc.episodeLinks.Keys | Sort-Object) | Should -Be @('ep1', 'ep2')
			$lc.seriesLinks | Should -Be @('sr1')
		}
		It '種類別に振り分けられ、topicsは入れ子を参照すること' {
			Mock Invoke-RestMethod {
				[PSCustomObject]@{ Result = [PSCustomObject]@{ components = @(
							[PSCustomObject]@{ type = 'billboard' ; contents = @((New-Item 'specialMain' 'sm1')) },
							[PSCustomObject]@{ type = 'special' ; contents = @((New-Item 'special' 'sp1')) },
							[PSCustomObject]@{ type = 'talent' ; contents = @((New-Item 'talent' 't1')) },
							[PSCustomObject]@{ type = 'seasonEpisode' ; contents = @((New-Item 'season' 's1')) },
							[PSCustomObject]@{ type = 'topics' ; contents = [PSCustomObject]@{ Content = [PSCustomObject]@{ Content = @((New-Item 'episode' 'ep9')) } } }
						)
					}
				}
			}
			$lc = New-TestLinkCollection
			Get-LinkFromTopPage ([Ref]$lc)
			$lc.specialMainLinks | Should -Be @('sm1')
			$lc.specialLinks | Should -Be @('sp1')
			$lc.talentLinks | Should -Be @('t1')
			$lc.seasonLinks | Should -Be @('s1')
			$lc.episodeLinks.Keys | Should -Be @('ep9')
		}
		It '対象外のコンポーネントでは警告を出さないこと' {
			Mock Invoke-RestMethod {
				$types = @('banner', 'resume', 'favorite', 'onAirLiveEpisode', 'watchingSeries', 'similarSeries', 'watchlistReminder', 'welcome')
				[PSCustomObject]@{ Result = [PSCustomObject]@{ components = @($types.ForEach({ [PSCustomObject]@{ type = $_ ; contents = @() } })) } }
			}
			$lc = New-TestLinkCollection
			Get-LinkFromTopPage ([Ref]$lc)
			Should -Invoke Write-Warning -Times 0 -Exactly
		}
		It '未知のコンポーネントでは警告を出すこと' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ components = @([PSCustomObject]@{ type = 'somethingNew' ; contents = @() }) } } }
			$lc = New-TestLinkCollection
			Get-LinkFromTopPage ([Ref]$lc)
			Should -Invoke Write-Warning -Times 1 -Exactly
		}
		It 'resultが空(v1廃止時の挙動)でも例外にならず警告を出すこと' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{} } }
			$lc = New-TestLinkCollection
			{ Get-LinkFromTopPage ([Ref]$lc) } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 1 -Exactly
		}
	}
}

#----------------------------------------------------------------------
# サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'Get-LinkFromSiteMap' {
	Context 'モックチェック' {
		BeforeAll {
			$script:sitemapXml = [xml]@'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://tver.jp/</loc></url>
  <url><loc>https://tver.jp/episodes/ep1</loc></url>
  <url><loc>https://tver.jp/episodes/ep1</loc></url>
  <url><loc>https://tver.jp/episodes/ep2</loc></url>
  <url><loc>https://tver.jp/series/sr1</loc></url>
  <url><loc>https://tver.jp/specials/keibalive/all26_0403</loc></url>
  <url><loc>https://tver.jp/specials/keibalive/all26_0404</loc></url>
  <url><loc>https://tver.jp/categories/drama</loc></url>
  <url><loc>https://tver.jp/live/ntv</loc></url>
  <url><loc>https://tver.jp/tags/golf</loc></url>
</urlset>
'@
		}
		BeforeEach {
			Mock Invoke-RestMethod { $script:sitemapXml }
			Mock Get-LinkFromKeyword {}
			Mock Write-Warning {}
		}
		AfterAll { $script:sitemapParseEpisodeOnly = $true }

		It 'エピソードのみ処理する設定ではエピソードだけを抽出すること' {
			$script:sitemapParseEpisodeOnly = $true
			$lc = New-TestLinkCollection
			Get-LinkFromSiteMap ([Ref]$lc)
			@($lc.episodeLinks.Keys | Sort-Object) | Should -Be @('ep1', 'ep2')
			$lc.seriesLinks.Count | Should -Be 0
			$lc.specialMainLinks.Count | Should -Be 0
			Should -Invoke Get-LinkFromKeyword -Times 0 -Exactly
		}
		It 'エピソード以外も処理する設定で例外にならないこと(categoryLinks未定義のリグレッション)' {
			$script:sitemapParseEpisodeOnly = $false
			$lc = New-TestLinkCollection
			{ Get-LinkFromSiteMap ([Ref]$lc) } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 0 -Exactly
		}
		It 'キーワード処理経由(実際のリンクコレクション)でも例外にならずエピソードを返すこと' {
			$script:sitemapParseEpisodeOnly = $false
			{ $script:sitemapResult = @(Get-VideoLinksFromKeyword -keyword 'sitemap') } | Should -Not -Throw
			@($script:sitemapResult | Sort-Object) | Should -Be @('ep1', 'ep2')
			Should -Invoke Get-LinkFromKeyword -Times 1 -Exactly -ParameterFilter { $id -eq 'keibalive' -and $linkType -eq 'specialMainLinks' }
			Should -Invoke Get-LinkFromKeyword -Times 0 -Exactly -ParameterFilter { $linkType -eq 'specialLinks' }
		}
		It 'specialsはspecialMainLinksとして重複なく登録されること' {
			$script:sitemapParseEpisodeOnly = $false
			$lc = New-TestLinkCollection
			Get-LinkFromSiteMap ([Ref]$lc)
			$lc.seriesLinks | Should -Be @('sr1')
			$lc.specialMainLinks | Should -Be @('keibalive')
			$lc.specialLinks.Count | Should -Be 0
		}
		It 'categoriesはcategoryとして検索されること' {
			$script:sitemapParseEpisodeOnly = $false
			$lc = New-TestLinkCollection
			Get-LinkFromSiteMap ([Ref]$lc)
			Should -Invoke Get-LinkFromKeyword -Times 1 -Exactly -ParameterFilter { $id -eq 'drama' -and $linkType -eq 'category' }
			$lc.categoryLinks.Count | Should -Be 0
		}
	}
}

#----------------------------------------------------------------------
# 日本のIPアドレス取得 (#277 のリグレッション)
#----------------------------------------------------------------------
Describe 'Get-JpIP' {
	Context 'モックチェック' {
		BeforeEach {
			$script:jpIPList = 'dummy.csv'
			Mock Import-Csv { @([PSCustomObject]@{ start = '133.242.0.0' ; end = '133.242.255.255' }) }
			Mock Start-Sleep {}
		}

		It '日本と判定されたIPアドレスを返すこと' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ CountryCode = 'JP' } }
			$ip = Get-JpIP
			$ip | Should -Match '^133\.242\.\d{1,3}\.\d{1,3}$'
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly
		}
		It 'ip-api.comに接続できない場合も無限ループせずIPアドレスを返すこと' {
			Mock Invoke-RestMethod { throw 'blocked' }
			$ip = Get-JpIP
			$ip | Should -Match '^133\.242\.\d{1,3}\.\d{1,3}$'
			Should -Invoke Invoke-RestMethod -Times 5 -Exactly
		}
		It '範囲が非常に狭いCIDRでも例外にならないこと' {
			Mock Import-Csv { @([PSCustomObject]@{ start = '133.242.0.0' ; end = '133.242.0.1' }) }
			Mock Invoke-RestMethod { [PSCustomObject]@{ CountryCode = 'JP' } }
			{ Get-JpIP } | Should -Not -Throw
		}
	}
}

#----------------------------------------------------------------------
# TVerとの実接続確認
#----------------------------------------------------------------------
Describe 'TVerとの接続確認' -Tag 'TVer' {
	BeforeAll {
		Get-Token
		$script:liveEpisodeID = @(Get-VideoLinksFromKeyword -keyword 'new/all')[0]
	}
	AfterAll {
		$script:platformUID = 'test-uid'
		$script:platformToken = 'test-token'
	}

	It 'トークンが想定どおりの形式であること' {
		$script:platformUID | Should -Match '^[0-9a-z]{30,}$'
		$script:platformToken | Should -Match '^[0-9a-z]{40}$'
	}
	It '<keyword> でエピソードが1件以上返却されること' -ForEach @(
		@{ keyword = 'new/all' }
		@{ keyword = 'end/all' }
		@{ keyword = 'ranking/all' }
		@{ keyword = 'tag/drama' }
		@{ keyword = 'カンブリア' }
	) {
		$result = @(Get-VideoLinksFromKeyword -keyword $keyword)
		$result.Count | Should -BeGreaterOrEqual 1
		$result[0] | Should -Match '^ep[0-9a-z]+$'
	}
	It 'トップページ(v2/callHome)からリンクが取得できること' {
		$lc = New-TestLinkCollection
		Get-LinkFromTopPage ([Ref]$lc) 3>$null
		($lc.episodeLinks.Count + $lc.seriesLinks.Count) | Should -BeGreaterOrEqual 1
	}
	It 'カテゴリページからリンクが取得できること' {
		$lc = New-TestLinkCollection
		Get-LinkFromKeyword -id 'drama' -linkType 'category' -LinkCollection ([Ref]$lc)
		($lc.episodeLinks.Count + $lc.seriesLinks.Count + $lc.specialMainLinks.Count) | Should -BeGreaterOrEqual 1
	}
	It 'シリーズからシーズンが取得できること' {
		$lc = New-TestLinkCollection
		Get-LinkFromKeyword -id 'sre2549ef6' -linkType 'seriesLinks' -LinkCollection ([Ref]$lc)
		$lc.seasonLinks.Count | Should -BeGreaterOrEqual 1
	}
	It '番組情報が取得できること' {
		$info = Get-VideoInfo -episodeID $script:liveEpisodeID
		$info | Should -Not -BeNullOrEmpty
		$info.episodeID | Should -BeExactly $script:liveEpisodeID
		$info.seriesName | Should -Not -BeNullOrEmpty
	}
}
