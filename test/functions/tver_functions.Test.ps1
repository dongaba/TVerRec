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
	# * パスに「test」「src」「tver」を含むディレクトリ配下でも正しく解決できるよう、リポジトリルートから組み立てる
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot ('src/functions/{0}' -f (Split-Path $PSCommandPath -Leaf).Replace('.Test.ps1', '.ps1'))
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:scriptRoot = Convert-Path (Join-Path $script:repoRoot 'src')
	Set-Location $script:scriptRoot
	$script:disableToastNotification = $false
	# メッセージテーブル(警告メッセージの書式に必要)
	$script:msg = (Get-Content -Path (Join-Path $script:scriptRoot '../resources/lang/messages.json') -Raw | ConvertFrom-Json).'ja-JP'
	. (Join-Path $script:repoRoot 'src/functions/common_functions.ps1')
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
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'テスト用のオブジェクトを生成するだけで、システムの状態は変更しない')]
		Param ()
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
	function New-Item {
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'テスト用のオブジェクトを生成するだけで、システムの状態は変更しない')]
		Param ([String]$type, [String]$id, [Int64]$endAt = 0)
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
		@{ url = 'https://tver.jp/lp/episodes/epuaqm8ooq' ; expected = 'epuaqm8ooq' }
		@{ url = 'https://tver.jp/lp/episodes/epuaqm8ooq?p=0' ; expected = 'epuaqm8ooq' }
		@{ url = 'https://www.tver.jp/episodes/epuaqm8ooq' ; expected = 'epuaqm8ooq' }
	) {
		Get-EpisodeIDFromURL -url $url | Should -BeExactly $expected
	}
	It 'エピソード以外のURLでは空文字を返すこと: <url>' -ForEach @(
		@{ url = 'https://tver.jp/series/sre2549ef6' }
		@{ url = 'https://tver.jp/lp/f0033031' }
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
		It 'lp/episodes指定でもエピソードIDを返すこと' {
			Get-VideoLinksFromKeyword -keyword 'lp/episodes/epuaqm8ooq?p=0' | Should -BeExactly 'epuaqm8ooq'
			Should -Invoke Get-LinkFromKeyword -Times 0 -Exactly
		}
		It 'lp/series指定でもseriesLinksとして処理されること' {
			Get-VideoLinksFromKeyword -keyword 'lp/series/sre2549ef6' | Out-Null
			Should -Invoke Get-LinkFromKeyword -Times 1 -Exactly -ParameterFilter { $id -eq 'sre2549ef6' -and $linkType -eq 'seriesLinks' }
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
		It 'キーワードの「&」「#」「空白」がURLエンコードされること' {
			Mock Invoke-RestMethod { [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = @() } } }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/api' -Type 'keyword' -Keyword 'King & Prince #1' -LinkCollection ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example/api?platform_uid=test-uid&platform_token=test-token&keyword=King%20%26%20Prince%20%231' }
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

	# 一括ダウンロード中は、シリーズ・シーズン・タレントのAPI結果を実行中だけ使い回す($script:searchCacheがあるときだけ)
	Context 'API結果のキャッシュ(一括ダウンロード用)' {
		BeforeEach {
			Mock Get-LinkFromKeyword {}
			Mock Write-Warning {}
			Remove-Variable -Name searchCache -Scope Script -ErrorAction SilentlyContinue
			$script:seriesResponse = [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = @((New-Item 'episode' 'ep1' 100)) } }
		}
		AfterEach { Remove-Variable -Name searchCache -Scope Script -ErrorAction SilentlyContinue }

		It 'シリーズのAPIは、同じURLの2回目以降はキャッシュを使い、結果も同じになること' {
			$script:searchCache = @{}
			Mock Invoke-RestMethod { $script:seriesResponse }
			$lc1 = New-TestLinkCollection
			$lc2 = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc1)
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc2)
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly
			$lc1.episodeLinks['ep1'] | Should -Be 100
			$lc2.episodeLinks['ep1'] | Should -Be 100
		}
		It 'シーズン・タレントのAPIもキャッシュされること' {
			$script:searchCache = @{}
			Mock Invoke-RestMethod { $script:seriesResponse }
			foreach ($url in 'https://example/callSeasonEpisodes/s1', 'https://example/callTalentEpisode/t1') {
				$lc = New-TestLinkCollection
				Get-SearchResult -baseURL $url -LinkCollection ([Ref]$lc)
				$lc = New-TestLinkCollection
				Get-SearchResult -baseURL $url -LinkCollection ([Ref]$lc)
			}
			Should -Invoke Invoke-RestMethod -Times 2 -Exactly
		}
		It 'IDが違えば別のAPIとして呼ばれること' {
			$script:searchCache = @{}
			Mock Invoke-RestMethod { $script:seriesResponse }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc)
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr2' -LinkCollection ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 2 -Exactly
		}
		It '新着・キーワード検索など、対象外のAPIはキャッシュしないこと' {
			$script:searchCache = @{}
			# 新着(new)は入れ子のContents、キーワード検索は直下のContentsを返す
			Mock Invoke-RestMethod {
				if ($Uri -like '*callNewerDetail*') { [PSCustomObject]@{ Result = [PSCustomObject]@{ Contents = [PSCustomObject]@{ Contents = @((New-Item 'episode' 'ep2' 200)) } } } }
				else { $script:seriesResponse }
			}
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/callNewerDetail/x' -Type 'new' -LinkCollection ([Ref]$lc)
			Get-SearchResult -baseURL 'https://example/callNewerDetail/x' -Type 'new' -LinkCollection ([Ref]$lc)
			Get-SearchResult -baseURL 'https://example/callKeywordSearch' -Type 'keyword' -Keyword 'abc' -LinkCollection ([Ref]$lc)
			Get-SearchResult -baseURL 'https://example/callKeywordSearch' -Type 'keyword' -Keyword 'abc' -LinkCollection ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 4 -Exactly
			$script:searchCache.Count | Should -Be 0
		}
		It '失敗した結果はキャッシュせず、次回は再度APIを呼ぶこと' {
			$script:searchCache = @{}
			$script:restCalls = 0
			Mock Invoke-RestMethod {
				$script:restCalls++
				if ($script:restCalls -eq 1) { throw 'Response status code does not indicate success: 500 (Server Error).' }
				$script:seriesResponse
			}
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc)
			$lc.episodeLinks.Count | Should -Be 0
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 2 -Exactly
			$lc.episodeLinks['ep1'] | Should -Be 100
		}
		It 'キャッシュ用の変数がなければ、従来どおり毎回APIを呼ぶこと' {
			Mock Invoke-RestMethod { $script:seriesResponse }
			$lc = New-TestLinkCollection
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc)
			Get-SearchResult -baseURL 'https://example/callSeriesSeasons/sr1' -LinkCollection ([Ref]$lc)
			Should -Invoke Invoke-RestMethod -Times 2 -Exactly
			Test-Path Variable:Script:searchCache | Should -BeFalse
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
		It 'channelコンポーネントは警告なしで読み飛ばし、他のコンテンツは処理すること' {
			Mock Invoke-RestMethod {
				[PSCustomObject]@{ Result = [PSCustomObject]@{ components = @(
						[PSCustomObject]@{ type = 'channel' ; contents = @([PSCustomObject]@{ type = 'channel' ; content = [PSCustomObject]@{ id = 'tbs' } }) },
						[PSCustomObject]@{ type = 'newer' ; contents = @((New-Item 'episode' 'ep1')) }
					)
					}
				}
			}
			$lc = New-TestLinkCollection
			Get-LinkFromTopPage ([Ref]$lc)
			$lc.episodeLinks.Keys | Should -Be @('ep1')
			Should -Invoke Write-Warning -Times 0 -Exactly
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
# マイページから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'Get-LinkFromMyPage' {
	Context 'モックチェック' {
		BeforeEach { Mock Write-Warning {} ; Mock Get-SearchResult {} }

		It '未知のページ名では警告のみで例外を投げず、APIを呼ばないこと' {
			$lc = New-TestLinkCollection
			{ Get-LinkFromMyPage -Page 'unknown' -LinkCollection ([Ref]$lc) } | Should -Not -Throw
			Should -Invoke Write-Warning -Times 1 -Exactly
			Should -Invoke Get-SearchResult -Times 0 -Exactly
		}
		It '既知のページ名ではGet-SearchResultを呼ぶこと' {
			$lc = New-TestLinkCollection
			Get-LinkFromMyPage -Page 'later' -LinkCollection ([Ref]$lc)
			Should -Invoke Get-SearchResult -Times 1 -Exactly
		}
	}
}

#----------------------------------------------------------------------
# TVerのAPIを叩いて番組情報取得
#----------------------------------------------------------------------
Describe 'Get-VideoInfo' {
	Context 'モックチェック' {
		It '配信終了日時が実行環境のタイムゾーンに関係なくJSTで返ること' {
			# 1800622799 = 2027-01-22 12:59:59 UTC = 2027-01-22 21:59:59 JST
			Mock Invoke-RestMethod {
				if ($Uri -like '*callEpisode*') {
					[PSCustomObject]@{ Result = [PSCustomObject]@{
							Episode = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 'ep1' ; SeriesTitle = 'S' ; Title = 'T' ; BroadcasterName = 'B' ; ProductionProviderName = 'P' ; BroadcastDateLabel = '' ; EndAt = 1800622799 ; version = 3 } }
							Series = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 'sr1' } }
							Season = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 's1' ; Title = '' } }
						}
					}
				} else { [PSCustomObject]@{ Description = 'd' ; No = '1' } }
			}
			$info = Get-VideoInfo -episodeID 'ep1'
			$info.endTime.ToString('yyyy-MM-dd HH:mm:ss') | Should -Be '2027-01-22 21:59:59'
		}
	}
}

#----------------------------------------------------------------------
# 放送局IDから放送局名を取得
#----------------------------------------------------------------------
Describe 'Get-BroadcasterName' {
	Context 'モックチェック' {
		It '対応表にある放送局IDから旧APIのBroadcasterNameと同じ名称が取得できること' {
			Get-BroadcasterName -broadcasterID 'tx' | Should -BeExactly 'テレ東'
			Get-BroadcasterName -broadcasterID 'cx' | Should -BeExactly 'フジテレビ'
		}
		It '整形前の名称(全角文字など)がそのまま返ること' {
			Get-BroadcasterName -broadcasterID 'bs4' | Should -BeExactly 'ＢＳ日本'
		}
		It '対応表にない放送局IDは$nullが返ること' {
			Get-BroadcasterName -broadcasterID 'unknown-station' | Should -BeNullOrEmpty
		}
		It '空の放送局IDは$nullが返ること' {
			Get-BroadcasterName -broadcasterID '' | Should -BeNullOrEmpty
		}
	}
}

#----------------------------------------------------------------------
# 番組情報の整形
#----------------------------------------------------------------------
Describe 'Format-VideoInfoText' {
	Context 'モックチェック' {
		BeforeAll {
			# Remove-SpecialNoteはtverrec_functions.ps1の関数のため、このテストでは簡易版で代用する
			function Remove-SpecialNote { Param ([String]$text) return ($text -replace '《[^》]*》', '') }
		}
		BeforeEach { $script:removeSpecialNote = $false }
		It 'エピソード番号が1桁のときは頭0埋めして2桁になること' {
			(Format-VideoInfoText -seriesName 'S' -seasonName '' -episodeName 'T' -episodeNum '2' -broadcastDate '').episodeNum | Should -BeExactly '02'
		}
		It 'シーズン名が本編のときはシーズン名がクリアされること' {
			(Format-VideoInfoText -seriesName 'S' -seasonName '本編' -episodeName 'T' -episodeNum '1' -broadcastDate '').seasonName | Should -BeExactly ''
		}
		It 'シリーズ名がシーズン名を含むときはシーズン名がクリアされること' {
			(Format-VideoInfoText -seriesName 'ドラマ season2' -seasonName 'season2' -episodeName 'T' -episodeNum '3' -broadcastDate '').seasonName | Should -BeExactly ''
		}
		It '《》で挟まれた文字が設定有効時に除去されること' {
			$script:removeSpecialNote = $true
			(Format-VideoInfoText -seriesName 'S' -seasonName '' -episodeName 'T《再》' -episodeNum '3' -broadcastDate '').episodeName | Should -BeExactly 'T'
		}
		It '放送日に年が補完されること' {
			$result = Format-VideoInfoText -seriesName 'S' -seasonName '' -episodeName 'T' -episodeNum '3' -broadcastDate ((Get-Date).AddDays(-1).ToString('M月d日') + '(月)放送')
			$result.broadcastDate | Should -Match '^[0-9]{4}年[0-9]{2}月[0-9]{2}日'
		}
	}
}

#----------------------------------------------------------------------
# 番組情報取得(新世代API)
#----------------------------------------------------------------------
Describe 'Get-VideoInfo(新世代API)' {
	Context 'モックチェック' {
		BeforeAll {
			# 新世代API(contents-api v2/episodes)のレスポンスを生成
			function New-ContentsApiResponse {
				[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'テスト用のオブジェクトを生成するだけで状態を変更しない')]
				Param ([String]$broadcasterID = 'tx')
				[PSCustomObject]@{
					episode = [PSCustomObject]@{
						id                    = 'ep1'
						title                 = 'T'
						broadcast_provider_id = $broadcasterID
						production_provider   = [PSCustomObject]@{ display_name = '制作局' }
						broadcast_date_label  = ''
						description           = 'D &amp; E'
						index_no              = 2
						is_subtitle           = $true
						end_at                = '2027-01-22T12:59:59Z'
						view_status           = [PSCustomObject]@{ end_at = 1800622799 }
					}
					season  = [PSCustomObject]@{ id = 's1' ; title = '本編' }
					series  = [PSCustomObject]@{ id = 'sr1' ; title = 'S' }
				}
			}
			# 旧API(callEpisode + statics)のレスポンスを生成
			function New-LegacyApiResponse {
				[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'テスト用のオブジェクトを生成するだけで状態を変更しない')]
				Param ([String]$uri)
				if ($uri -like '*callEpisode*') {
					[PSCustomObject]@{ Result = [PSCustomObject]@{
							Episode = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 'ep1' ; SeriesTitle = 'S' ; Title = 'T' ; BroadcasterName = '旧API放送局名' ; ProductionProviderName = 'P' ; BroadcastDateLabel = '' ; EndAt = 1800622799 ; version = 3 } }
							Series = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 'sr1' } }
							Season = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 's1' ; Title = '' } }
						}
					}
				} else { [PSCustomObject]@{ Description = 'd' ; No = '1' } }
			}
		}
		BeforeEach { $script:unknownBroadcasterID = @{} }
		It '新世代APIの1回の呼び出しで番組情報が取得でき、旧APIは呼ばれないこと' {
			Mock Invoke-RestMethod { New-ContentsApiResponse }
			$info = Get-VideoInfo -episodeID 'ep1'
			$info.seriesName | Should -BeExactly 'S'
			$info.seriesID | Should -BeExactly 'sr1'
			$info.seasonName | Should -BeExactly ''
			$info.seasonID | Should -BeExactly 's1'
			$info.episodeID | Should -BeExactly 'ep1'
			$info.episodeNum | Should -BeExactly '02'
			$info.mediaName | Should -BeExactly 'テレ東'
			$info.providerName | Should -BeExactly '制作局'
			$info.descriptionText | Should -BeExactly 'D & E'
			$info.isSubtitle | Should -BeTrue
			$info.versionNum | Should -BeNullOrEmpty
			$info.endTime.ToString('yyyy-MM-dd HH:mm:ss') | Should -Be '2027-01-22 21:59:59'
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -like '*platform-api*' }
		}
		It '放送局名は制作局(production_provider)ではなく対応表の放送局名になること' {
			Mock Invoke-RestMethod { New-ContentsApiResponse -broadcasterID 'bs9' }
			(Get-VideoInfo -episodeID 'ep1').mediaName | Should -BeExactly 'WOWOW'
		}
		It '対応表にない放送局IDは旧APIの放送局名になり、警告が1回だけ表示されること' {
			Mock Invoke-RestMethod { if ($Uri -like '*contents-api*') { New-ContentsApiResponse -broadcasterID 'newstation' } else { New-LegacyApiResponse -uri $Uri } }
			Mock Write-Warning {}
			$info1 = Get-VideoInfo -episodeID 'ep1'
			$info2 = Get-VideoInfo -episodeID 'ep1'
			$info1.mediaName | Should -BeExactly '旧API放送局名'
			$info2.mediaName | Should -BeExactly '旧API放送局名'
			Should -Invoke Write-Warning -Times 1 -Exactly
		}
		It '対応表になく旧APIでも取得できないときは放送局IDがそのまま使われること' {
			Mock Invoke-RestMethod { if ($Uri -like '*contents-api*') { New-ContentsApiResponse -broadcasterID 'newstation' } else { throw 'legacy API failed' } }
			(Get-VideoInfo -episodeID 'ep1' 3>$null).mediaName | Should -BeExactly 'newstation'
		}
		It '新世代APIの呼び出しに失敗したときは旧APIにフォールバックすること' {
			Mock Invoke-RestMethod { if ($Uri -like '*contents-api*') { throw 'contents API failed' } else { New-LegacyApiResponse -uri $Uri } }
			$info = Get-VideoInfo -episodeID 'ep1'
			$info.mediaName | Should -BeExactly '旧API放送局名'
			$info.episodeID | Should -BeExactly 'ep1'
		}
		It '新世代APIのレスポンスにepisodeがないときは旧APIにフォールバックすること' {
			Mock Invoke-RestMethod { if ($Uri -like '*contents-api*') { [PSCustomObject]@{ code = 4002 } } else { New-LegacyApiResponse -uri $Uri } }
			(Get-VideoInfo -episodeID 'ep1').mediaName | Should -BeExactly '旧API放送局名'
		}
	}
}

#----------------------------------------------------------------------
# JSONの入れ子のプロパティを安全に取得
#----------------------------------------------------------------------
Describe 'Get-JsonProperty' {
	BeforeAll {
		$script:jsonObj = [PSCustomObject]@{
			a      = [PSCustomObject]@{ b = [PSCustomObject]@{ c = 5 } }
			flag   = $false
			zero   = 0
			empty  = ''
			nothing = $null
			text   = 'abc'
			list   = @(1, 2, 3)
		}
	}
	It '入れ子のプロパティをたどって値を返すこと' {
		Get-JsonProperty $script:jsonObj @('a', 'b', 'c') | Should -Be 5
	}
	It 'プロパティ名が1つでも取得できること' {
		Get-JsonProperty $script:jsonObj @('text') | Should -Be 'abc'
	}
	It '途中のオブジェクトを返せること' {
		(Get-JsonProperty $script:jsonObj @('a', 'b')).c | Should -Be 5
	}
	It '存在しないプロパティは$nullを返すこと' {
		Get-JsonProperty $script:jsonObj @('x') | Should -BeNullOrEmpty
		Get-JsonProperty $script:jsonObj @('a', 'x', 'c') | Should -BeNullOrEmpty
	}
	It 'Set-StrictModeが有効でも、存在しないプロパティで例外にならないこと' {
		Set-StrictMode -Version Latest
		try {
			{ Get-JsonProperty $script:jsonObj @('a', 'x', 'c') } | Should -Not -Throw
			{ Get-JsonProperty $script:jsonObj @('x', 'y', 'z') } | Should -Not -Throw
		} finally { Set-StrictMode -Off }
	}
	It '値が$false・0・空文字でも、$nullではなくそのまま返すこと' {
		$flag = Get-JsonProperty $script:jsonObj @('flag')
		$flag | Should -BeFalse
		($null -eq $flag) | Should -BeFalse
		$zero = Get-JsonProperty $script:jsonObj @('zero')
		$zero | Should -Be 0
		($null -eq $zero) | Should -BeFalse
		$empty = Get-JsonProperty $script:jsonObj @('empty')
		$empty | Should -BeExactly ''
		($null -eq $empty) | Should -BeFalse
	}
	It '値が$nullのプロパティの先をたどっても$nullを返すこと' {
		Get-JsonProperty $script:jsonObj @('nothing') | Should -BeNullOrEmpty
		Get-JsonProperty $script:jsonObj @('nothing', 'x') | Should -BeNullOrEmpty
	}
	It '取得元が$nullでも$nullを返すこと' {
		Get-JsonProperty $null @('a') | Should -BeNullOrEmpty
	}
	It '文字列など、プロパティを持たない値の先をたどっても$nullを返すこと' {
		Get-JsonProperty $script:jsonObj @('text', 'x') | Should -BeNullOrEmpty
	}
	It '配列のプロパティは配列のまま返すこと' {
		@(Get-JsonProperty $script:jsonObj @('list')) | Should -Be @(1, 2, 3)
	}
}

#----------------------------------------------------------------------
# エピソード以外のリンクをためたバッファを順次API呼び出し
#----------------------------------------------------------------------
Describe 'Get-LinkFromBuffer' {
	BeforeEach {
		Mock Get-LinkFromKeyword { $script:calledIds += $id ; $script:calledTypes += $linkType }
		$script:calledIds = @()
		$script:calledTypes = @()
	}
	It '重複を除き、IDの昇順に1回ずつGet-LinkFromKeywordを呼ぶこと' {
		$lc = New-TestLinkCollection
		Get-LinkFromBuffer -TverIDs @('sr2', 'sr1', 'sr2') -TverIDType 'seriesLinks' -LinkCollection ([Ref]$lc) 6>$null
		Should -Invoke Get-LinkFromKeyword -Times 2 -Exactly
		$script:calledIds | Should -Be @('sr1', 'sr2')
	}
	It 'バッファの種類がそのままlinkTypeとして渡されること' {
		$lc = New-TestLinkCollection
		Get-LinkFromBuffer -TverIDs @('s1') -TverIDType 'seasonLinks' -LinkCollection ([Ref]$lc) 6>$null
		$script:calledTypes | Should -Be @('seasonLinks')
	}
	It '取得後に、リンクコレクション内の重複を除いてIDの昇順に整えること' {
		$lc = New-TestLinkCollection
		foreach ($id in 'sr2', 'sr1', 'sr2') { $lc.seriesLinks.Add($id) }
		foreach ($id in 't2', 't1', 't2') { $lc.talentLinks.Add($id) }
		foreach ($id in 's2', 's1', 's1') { $lc.seasonLinks.Add($id) }
		foreach ($id in 'sp2', 'sp1', 'sp2') { $lc.specialLinks.Add($id) }
		Get-LinkFromBuffer -TverIDs @('x') -TverIDType 'seasonLinks' -LinkCollection ([Ref]$lc) 6>$null
		$lc.seriesLinks | Should -Be @('sr1', 'sr2')
		$lc.talentLinks | Should -Be @('t1', 't2')
		$lc.seasonLinks | Should -Be @('s1', 's2')
		$lc.specialLinks | Should -Be @('sp1', 'sp2')
		($lc.seriesLinks -is [System.Collections.Generic.List[String]]) | Should -BeTrue
	}
	It 'リンクが空のコレクションでも例外にならないこと' {
		$lc = New-TestLinkCollection
		{ Get-LinkFromBuffer -TverIDs @('x') -TverIDType 'seriesLinks' -LinkCollection ([Ref]$lc) 6>$null } | Should -Not -Throw
		$lc.seriesLinks.Count | Should -Be 0
	}
	It 'IDが$nullや空配列ならGet-LinkFromKeywordを呼ばないこと' {
		$lc = New-TestLinkCollection
		Get-LinkFromBuffer -TverIDs $null -TverIDType 'seriesLinks' -LinkCollection ([Ref]$lc) 6>$null
		Get-LinkFromBuffer -TverIDs @() -TverIDType 'seriesLinks' -LinkCollection ([Ref]$lc) 6>$null
		Should -Invoke Get-LinkFromKeyword -Times 0 -Exactly
	}
	It '許可されていないバッファの種類は受け付けないこと' {
		$lc = New-TestLinkCollection
		{ Get-LinkFromBuffer -TverIDs @('x') -TverIDType 'categoryLinks' -LinkCollection ([Ref]$lc) 6>$null } | Should -Throw
	}
}

#----------------------------------------------------------------------
# 旧APIを叩いて番組情報取得
#----------------------------------------------------------------------
Describe 'Get-VideoInfoLegacy' {
	BeforeAll {
		# 旧API(callEpisode)のレスポンスを生成
		function New-LegacyEpisodeResponse {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'テスト用のオブジェクトを生成するだけで状態を変更しない')]
			Param ()
			[PSCustomObject]@{ Result = [PSCustomObject]@{
					Episode = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 'ep1' ; SeriesTitle = 'S' ; Title = 'T' ; BroadcasterName = 'テレ東' ; ProductionProviderName = '制作' ; BroadcastDateLabel = '' ; EndAt = 1800622799 ; version = 3 } }
					Series  = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 'sr1' } }
					Season  = [PSCustomObject]@{ Content = [PSCustomObject]@{ Id = 's1' ; Title = '本編' } }
				}
			}
		}
		# 旧API(statics)のレスポンスを生成。isSubtitleは指定したときだけ項目を持つ
		function New-LegacyStaticsResponse {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'テスト用のオブジェクトを生成するだけで状態を変更しない')]
			Param ([Object]$isSubtitle = $null)
			$r = [PSCustomObject]@{ Description = 'D &amp; E' ; No = '2' }
			if ($null -ne $isSubtitle) { $r | Add-Member -MemberType NoteProperty -Name 'isSubtitle' -Value $isSubtitle }
			return $r
		}
	}
	BeforeEach {
		Mock Write-Warning {}
		Mock Invoke-RestMethod {
			if ($Uri -like '*callEpisode*') { New-LegacyEpisodeResponse }
			else { New-LegacyStaticsResponse }
		}
	}
	It '旧APIの2回の呼び出し(callEpisodeとstatics)で番組情報が取得できること' {
		$info = Get-VideoInfoLegacy -episodeID 'ep1'
		$info.seriesName | Should -BeExactly 'S'
		$info.seriesID | Should -BeExactly 'sr1'
		$info.seriesPageURL | Should -BeExactly 'https://tver.jp/series/sr1'
		$info.seasonName | Should -BeExactly ''
		$info.seasonID | Should -BeExactly 's1'
		$info.episodeID | Should -BeExactly 'ep1'
		$info.episodePageURL | Should -BeExactly 'https://tver.jp/episodes/ep1'
		$info.episodeName | Should -BeExactly 'T'
		$info.episodeNum | Should -BeExactly '02'
		$info.mediaName | Should -BeExactly 'テレ東'
		$info.providerName | Should -BeExactly '制作'
		$info.versionNum | Should -Be 3
		$info.descriptionText | Should -BeExactly 'D & E'
		$info.videoInfoURL | Should -BeExactly 'https://statics.tver.jp/content/episode/ep1.json?v=3'
		Should -Invoke Invoke-RestMethod -Times 2 -Exactly
		Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://platform-api.tver.jp/service/api/v1/callEpisode/ep1?platform_uid=test-uid&platform_token=test-token' }
		Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://statics.tver.jp/content/episode/ep1.json?v=3' }
		Should -Invoke Write-Warning -Times 0 -Exactly
	}
	It '配信終了日時が実行環境のタイムゾーンに関係なくJSTで返ること' {
		# 1800622799 = 2027-01-22 12:59:59 UTC = 2027-01-22 21:59:59 JST
		(Get-VideoInfoLegacy -episodeID 'ep1').endTime.ToString('yyyy-MM-dd HH:mm:ss') | Should -Be '2027-01-22 21:59:59'
	}
	It 'statics側のisSubtitleが<value>なら、Booleanの<expected>を返すこと' -ForEach @(
		@{ value = $true ; expected = $true }
		@{ value = $false ; expected = $false }
	) {
		Mock Invoke-RestMethod {
			if ($Uri -like '*callEpisode*') { New-LegacyEpisodeResponse }
			else { $r = New-LegacyStaticsResponse ; $r | Add-Member -MemberType NoteProperty -Name 'isSubtitle' -Value $value ; $r }
		}
		$isSubtitle = (Get-VideoInfoLegacy -episodeID 'ep1').isSubtitle
		$isSubtitle | Should -BeOfType [Boolean]
		$isSubtitle | Should -Be $expected
	}
	It 'statics側にisSubtitleの項目がなければ$nullを返すこと(呼び出し側でyt-dlpでの確認にフォールバックさせる)' {
		$info = Get-VideoInfoLegacy -episodeID 'ep1'
		($null -eq $info.isSubtitle) | Should -BeTrue
	}
	It 'プロキシ設定があるときは、staticsの取得だけにプロキシを渡すこと' {
		$script:proxyUrl = 'http://proxy.example:8080'
		try {
			Get-VideoInfoLegacy -episodeID 'ep1' | Out-Null
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -like '*statics.tver.jp*' -and $Proxy -eq 'http://proxy.example:8080' }
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -like '*callEpisode*' -and $Proxy }
		} finally { $script:proxyUrl = $null }
	}
	It 'callEpisodeの取得に失敗したときは警告して何も返さず、staticsは取得しないこと' {
		Mock Invoke-RestMethod { throw 'Response status code does not indicate success: 500 (Server Error).' }
		$info = Get-VideoInfoLegacy -episodeID 'ep1'
		$info | Should -BeNullOrEmpty
		Should -Invoke Write-Warning -Times 1 -Exactly
		Should -Invoke Invoke-RestMethod -Times 1 -Exactly
	}
	It 'staticsの取得に失敗したときは警告して何も返さないこと' {
		Mock Invoke-RestMethod {
			if ($Uri -like '*callEpisode*') { New-LegacyEpisodeResponse }
			else { throw 'Response status code does not indicate success: 404 (Not Found).' }
		}
		$info = Get-VideoInfoLegacy -episodeID 'ep1'
		$info | Should -BeNullOrEmpty
		Should -Invoke Write-Warning -Times 1 -Exactly
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
