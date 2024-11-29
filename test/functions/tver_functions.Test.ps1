Import-Module Pester -MinimumVersion 5.0

#region BeforeAll

#----------------------------------------------------------------------
#テスト対象ファイルの読み込み
#----------------------------------------------------------------------
BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	$targetfile = $PSCommandPath.replace('test', 'src').replace('.Test.ps1', '.ps1')
	Write-Host ('　テスト対象: {0}' -f $targetfile)
	$script:scriptRoot = Convert-Path ./src
	Set-Location $script:scriptRoot
	$script:disableToastNotification = $false
	. ($targetfile).replace('tver', 'common')
	function Invoke-StatisticsCheck {}
	. $targetfile
	Write-Host ('　テスト対象の読み込みを行いました')

	$script:seriesID = 'sre2549ef6'	#カンブリア宮殿
	$script:seasonID = 's0000038'	#カンブリア宮殿
	$script:talentID = 't021fb6'	#村上龍
	$script:specialMainID = 'zone4'	#北海道・東北
	$script:specialDetailID = 'hokkaido-tohoku'	#北海道・東北
	$script:tagID = 'golf'	#ゴルフ
	$script:genre = 'drama'	#ドラマ
	$script:keyword = 'カンブリア'
	$script:requestHeader = @{
		'x-tver-platform-type' = 'web'
		'Origin'               = 'https://tver.jp'
		'Referer'              = 'https://tver.jp'
	}
	function MockProcessSearchResults {
		Param ($baseURL, $type, $keyword)
		return [PSCustomObject]@{
			episodeLinks = @('https://tver.jp/episodes/dummy2', 'https://tver.jp/episodes/dummy1', 'https://tver.jp/episodes/dummy2')  | Sort-Object -Unique
			seasonLinks  = @('seasonDummy2', 'seasonDummy1', 'seasonDummy2')  | Sort-Object -Unique
			seriesLinks  = @('seriesDummy2', 'seriesDummy1', 'seriesDummy2')  | Sort-Object -Unique
			specialLinks = @('specialDummy2', 'specialDummy1', 'specialDummy2')  | Sort-Object -Unique
		}
	}
}

#endregion BeforeAll

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
Describe 'TVerのAPI Tokenを取得' {
	BeforeAll {
		$script:timeoutSec = 30
		$script:platformUID = $null
		$script:platformToken = $null
	}

	Context 'モックチェック' {
		BeforeAll {
			Mock Invoke-RestMethod {
				return @{
					Result = @{
						platform_uid   = 'mocked-uid'
						platform_token = 'mocked-token'
					}
				}
			}
		}

		It 'トークンを正しく変数にセットされること' {
			Get-Token
			$script:platformUID | Should -BeExactly 'mocked-uid'
			$script:platformToken | Should -BeExactly 'mocked-token'
		}
		It '呼び出しの引数が正しいこと' {
			Get-Token
			Assert-MockCalled Invoke-RestMethod -Times 1 -ParameterFilter {
				$Uri -eq 'https://platform-api.tver.jp/v2/api/platform_users/browser/create' -and
				$Method -eq 'POST' -and
				$Headers['Content-Type'] -eq 'application/x-www-form-urlencoded' -and
				$Body -eq 'device_type=pc' -and
				$TimeoutSec -eq $script:timeoutSec
			}
		}
		It 'HTTPエラーの際にエラーを投げるされること' {
			Mock Invoke-RestMethod { throw }
			{ Get-Token } | Should -Throw
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		It 'エラーなく返却されること' {
			{ Get-Token } | Should -Not -Throw
		}
		It 'トークンの型がStringであること' {
			Get-Token
			$script:platformUID | Should -BeOfType string
			$script:platformToken | Should -BeOfType string
		}
		It 'トークンの長さが想定どおりであること' {
			Get-Token
			$script:platformUID.Length | Should -Be 36
			$script:platformToken.Length | Should -Be 40
		}
	}
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------


#----------------------------------------------------------------------
#各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'SeriesIDによる番組検索から番組ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] }
			}
			Mock @mockParams
		}

		It 'SeriesIDが入力されエラーとならないこと' {
			{ Get-LinkFromSeriesID -seriesID '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromSeriesID -seriesID $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testSeriesID = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/$testSeriesID"
			Get-LinkFromSeriesID -seriesID '12345'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { $baseURL -eq $expectedBaseURL }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromSeriesID -seriesID '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			$result.seasonLinks.Count | Should -Be 2
			$result.seasonLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromSeriesID -seriesID '12345'
			$result.seasonLinks | Should -Contain 'seasonDummy1'
			$result.seasonLinks | Should -Contain 'seasonDummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromSeriesID -seriesID $seriesID } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromSeriesID -seriesID $seriesID
			$result | Should -BeOfType PSCustomObject
		}
		It 'シーズンが返却されること' {
			$result = Get-LinkFromSeriesID -seriesID $seriesID
			@($result.seasonLinks).Count | Should -BeGreaterOrEqual 1
			@($result.seasonLinks)[0].Substring(0, 1) | Should -Be 's'
		}
	}
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'SeasonIDによる番組検索から番組ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] }
			}
			Mock @mockParams
		}

		It 'SeasonIDが入力されエラーとならないこと' {
			{ Get-LinkFromSeasonID -seasonID '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromSeasonID -seasonID $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testSeasonID = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/$testSeasonID"
			Get-LinkFromSeasonID -seasonID '12345'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { $baseURL -eq $expectedBaseURL }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromSeasonID -seasonID '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromSeasonID -seasonID '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromSeasonID -seasonID $seasonID } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromSeasonID -seasonID $seasonID
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromSeasonID -seasonID $seasonID
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'TalentIDによるタレント検索から番組ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] }
			}
			Mock @mockParams
		}

		It 'TalentIDが入力されエラーとならないこと' {
			{ Get-LinkFromTalentID -talentID '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromTalentID -talentID $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testTalentID = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callTalentEpisode/$testTalentID"
			Get-LinkFromTalentID -talentID '12345'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { $baseURL -eq $expectedBaseURL }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromTalentID -talentID '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromTalentID -talentID '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromTalentID -talentID $talentID } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromTalentID -talentID $talentID
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromTalentID -talentID $talentID
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#SpecialIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
Describe 'SpecialIDによる特集ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] -type $args[1] }
			}
			Mock @mockParams
		}

		It 'SpecialIDが入力されエラーとならないこと' {
			{ Get-LinkFromSpecialMainID -specialMainID '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromSpecialMainID -specialMainID $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testSpecialMainID = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callSpecialContents/$testSpecialMainID"
			Get-LinkFromSpecialMainID -specialMainID '12345'
			Assert-MockCalled -CommandName ProcessSearchResults -Times 1 -Exactly -ParameterFilter { ($baseURL -eq $expectedBaseURL) -and ($Type -eq 'specialmain') }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromSpecialMainID -specialMainID '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			$result.specialLinks.Count | Should -Be 2
			$result.specialLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromSpecialMainID -specialMainID '12345'
			$result.specialLinks | Should -Contain 'specialDummy1'
			$result.specialLinks | Should -Contain 'specialDummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromSpecialMainID -specialMainID $specialMainID } | Should -Not -Throw
		}
		It 'String型で返却されること' {
			$result = Get-LinkFromSpecialMainID -specialMainID $specialMainID
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromSpecialMainID -specialMainID $specialMainID
			@($result.specialLinks).Count | Should -BeGreaterOrEqual 1
			@($result.specialLinks)[0] | Should -Be 'hokkaido-tohoku'
		}
	}
}

#----------------------------------------------------------------------
#SpecialDetailIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
Describe 'SpecialDetailIDによる特集ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] -type $args[1] }
			}
			Mock @mockParams
		}

		It 'SpecialDetailIDが入力されエラーとならないこと' {
			{ Get-LinkFromSpecialDetailID -specialDetailID '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromSpecialDetailID -specialDetailID $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testSpecialDetailID = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/$testSpecialDetailID"
			Get-LinkFromSpecialDetailID -specialDetailID '12345'
			Assert-MockCalled -CommandName ProcessSearchResults -Times 1 -Exactly -ParameterFilter { ($baseURL -eq $expectedBaseURL) -and ($Type -eq 'specialdetail') }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromSpecialDetailID -specialDetailID '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromSpecialDetailID -specialDetailID '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromSpecialDetailID -specialDetailID $specialDetailID } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromSpecialDetailID -specialDetailID $specialDetailID
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromSpecialDetailID -specialDetailID $specialDetailID
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'タグから番組ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] }
			}
			Mock @mockParams
		}

		It 'タグIDが入力されエラーとならないこと' {
			{ Get-LinkFromTag -tagID '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromTag -tagID $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testTagID = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callTagSearch/$testTagID"
			Get-LinkFromTag -tagID '12345'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { $baseURL -eq $expectedBaseURL }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromTag -tagID '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromTag -tagID '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromTag -tagID $tagID } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromTag -tagID $tagID
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromTag -tagID $tagID
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
Describe '新着から番組ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] -type $args[1] }
			}
			Mock @mockParams
		}

		It 'シリーズIDが入力されエラーとならないこと' {
			{ Get-LinkFromNew -genre '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromNew -genre $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testGenre = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callNewerDetail/$testGenre"
			Get-LinkFromNew -genre '12345'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { ($baseURL -eq $expectedBaseURL) -and ($Type -eq 'new') }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromNew -genre '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromNew -genre '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromNew -genre $genre } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromNew -genre $genre
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromNew -genre $genre
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'ランキングから番組ページのLinkを取得' {
	Context 'モックチェック - 全カテゴリ' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] -type $args[1] }
			}
			Mock @mockParams
		}

		It 'allが入力されエラーとならないこと' {
			{ Get-LinkFromRanking -genre 'all' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromRanking -genre $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$expectedBaseURL = 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking'
			Get-LinkFromRanking -genre 'all'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { ($baseURL -eq $expectedBaseURL) -and ($Type -eq 'ranking') }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromRanking -genre 'all'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromRanking -genre 'all'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'モックチェック - 特定カテゴリ' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] -type $args[1] -keyword $args[2] }
			}
			Mock @mockParams
		}

		It 'genreIDが入力されエラーとならないこと' {
			{ Get-LinkFromRanking -genre '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromRanking -genre $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testGenre = '12345'
			$expectedBaseURL = "https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/$testGenre"
			Get-LinkFromRanking -genre '12345'
			Assert-MockCalled ProcessSearchResults -Times 1 -ParameterFilter { ($baseURL -eq $expectedBaseURL) -and ($Type -eq 'ranking') }
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromRanking -genre '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromRanking -genre '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認 - 全カテゴリ' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromRanking -genre 'all' } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromRanking -genre 'all'
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromRanking -genre 'all'
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}

	Context 'TVerとの接続確認 - 特定カテゴリ' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromRanking -genre $genre } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromRanking -genre $genre
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromRanking -genre $genre
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
Describe 'TVerのAPIを叩いてフリーワード検索' {
	Context 'モックチェック' {
		BeforeAll {
			$mockParams = @{
				CommandName = 'ProcessSearchResults'
				MockWith    = { MockProcessSearchResults -baseURL $args[0] -type $args[1] -keyword $args[2] }
			}
			Mock @mockParams
		}

		It 'SpecialIDが入力されエラーとならないこと' {
			{ Get-LinkFromFreeKeyword -keyword '12345' } | Should -Not -Throw
		}
		It 'nullが入力された際にエラーとなること' {
			{ Get-LinkFromFreeKeyword -keyword $null } | Should -Throw
		}
		It '呼び出しの引数が正しいこと' {
			$testKeyword = '12345'
			$expectedBaseURL = 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch'
			Get-LinkFromFreeKeyword -keyword '12345'
			Assert-MockCalled -CommandName ProcessSearchResults -Times 1 -Exactly -ParameterFilter {
				($baseURL -eq $expectedBaseURL) -and ($Type -eq 'keyword') -and ($Keyword -eq $testKeyword)
			}
		}
		It 'PSCustomObject型を返すこと' {
			$result = Get-LinkFromFreeKeyword -keyword '12345'
			$result | Should -BeOfType [PSCustomObject]
			$result.Count | Should -Be 1
			@($result.episodeLinks).Count | Should -Be 2
			$result.episodeLinks[0] | Should -BeOfType string
		}
		It '重複削除して返却されること' {
			$result = Get-LinkFromFreeKeyword -keyword '12345'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy1'
			$result.episodeLinks | Should -Contain 'https://tver.jp/episodes/dummy2'
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromFreeKeyword -keyword $keyword } | Should -Not -Throw
		}
		It 'PSCustomObject型で返却されること' {
			$result = Get-LinkFromFreeKeyword -keyword $keyword
			$result | Should -BeOfType PSCustomObject
		}
		It 'エピソードが返却されること' {
			$result = Get-LinkFromFreeKeyword -keyword $keyword
			@($result.episodeLinks).Count | Should -BeGreaterOrEqual 1
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
		}
	}
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'トップページから番組ページのLinkを取得' {
	Context 'モックチェック' {
		BeforeAll {
			Mock Invoke-RestMethod {
				return @{
					Result = @{
						Components = @(
							@{Type = 'horizontal' ; Contents = @(
									@{Type = 'live' ; Content = @{ Id = 'horizontal-live' } },
									@{Type = 'episode' ; Content = @{ Id = 'horizontal-episode' } },
									@{Type = 'series' ; Content = @{ Id = 'horizontal-series' } },
									@{Type = 'season' ; Content = @{ Id = 'horizontal-season' } },
									@{Type = 'talent' ; Content = @{ Id = 'horizontal-talent' } },
									@{Type = 'specialMain' ; Content = @{ Id = 'horizontal-specialMain' } },
									@{Type = 'special' ; Content = @{ Id = 'horizontal-specialDetail' } },
									@{Type = 'unsupported' ; Content = @{ Id = 'horizontal-unsupported' } }
								)
							},
							@{Type = 'topics' ; Contents = @(@{Content = @(@{type = 'dummy' ; Content = @(
													@{Type = 'live' ; Content = @{ Id = 'topic-live' } },
													@{Type = 'episode' ; Content = @{ Id = 'topic-episode' } },
													@{Type = 'series' ; Content = @{ Id = 'topic-series' } },
													@{Type = 'season' ; Content = @{ Id = 'topic-season' } },
													@{Type = 'talent' ; Content = @{ Id = 'topic-talent' } },
													@{Type = 'unsupported' ; Content = @{ Id = 'topic-unsupported' } }
												)
											})
									})
							},
							@{Type = 'banner' ; Contents = @(@{Type = 'other' ; Content = @{ Id = 'banner-other' } }) },
							@{Type = 'resume' ; Contents = @(@{Type = 'other' ; Content = @{ Id = 'resume-other' } }) },
							@{Type = 'favorite' ; Contents = @(@{Type = 'other' ; Content = @{ Id = 'favorite-other' } }) },
							@{Type = 'unsupported' ; Contents = @(@{Type = 'unsupported' ; Content = @{ Id = 'unsupported-unsupported' } }) }
						)
					}
				}
			}
			Mock Get-LinkFromSpecialMainID {
				return [PSCustomObject]@{
					episodeLinks = @($args[1])  | Sort-Object -Unique
					seasonLinks  = @($args[1])  | Sort-Object -Unique
					seriesLinks  = @($args[1])  | Sort-Object -Unique
					specialLinks = @($args[1])  | Sort-Object -Unique
				}
			}
			Mock Get-LinkFromSpecialDetailID {
				return [PSCustomObject]@{
					episodeLinks = @($args[1])  | Sort-Object -Unique
					seasonLinks  = @($args[1])  | Sort-Object -Unique
					seriesLinks  = @($args[1])  | Sort-Object -Unique
					specialLinks = @($args[1])  | Sort-Object -Unique
				}
			}
			Mock Get-LinkFromTalentID {
				return [PSCustomObject]@{
					episodeLinks = @($args[1])  | Sort-Object -Unique
					seasonLinks  = @($args[1])  | Sort-Object -Unique
					seriesLinks  = @($args[1])  | Sort-Object -Unique
					specialLinks = @($args[1])  | Sort-Object -Unique
				}
			}
			Mock Get-LinkFromSeasonID {
				return [PSCustomObject]@{
					episodeLinks = @($args[1])  | Sort-Object -Unique
					seasonLinks  = @($args[1])  | Sort-Object -Unique
					seriesLinks  = @($args[1])  | Sort-Object -Unique
					specialLinks = @($args[1])  | Sort-Object -Unique
				}
			}
			Mock Get-LinkFromSeriesID {
				return [PSCustomObject]@{
					episodeLinks = @($args[1])  | Sort-Object -Unique
					seasonLinks  = @($args[1])  | Sort-Object -Unique
					seriesLinks  = @($args[1])  | Sort-Object -Unique
					specialLinks = @($args[1])  | Sort-Object -Unique
				}
			}
			Mock Write-Warning {}
			$script:platformUID = 'test_platform_uid'
			$script:platformToken = 'test_platform_token'
			$script:requestHeader = @{ 'Test-Header' = 'HeaderValue' }
			$script:timeoutSec = 30
		}

		It 'returns a list of episode links' {
			$result = Get-LinkFromTopPage | Sort-Object -Unique
			$result.episodeLinks | Should -Be @('https://tver.jp/episodes/horizontal-episode', 'https://tver.jp/episodes/topic-episode')
			$result.seriesLinks | Should -Be @('horizontal-series', 'topic-series')
			$result.seasonLinks | Should -Be @('horizontal-season', 'topic-season')
			$result.talentLinks | Should -Be @('horizontal-talent', 'topic-talent')
			$result.specialMainLinks | Should -Be @('horizontal-specialMain')
			$result.specialLinks | Should -Be @('horizontal-specialDetail')
		}
	}

	Context 'TVerとの接続確認' -Tag 'TVer' {
		BeforeAll {
			$script:timeoutSec = 30
			Get-Token
			$script:requestHeader = @{
				'x-tver-platform-type' = 'web'
				'Origin'               = 'https://tver.jp'
				'Referer'              = 'https://tver.jp'
			}
		}

		It 'エラーなく返却されること' {
			{ Get-LinkFromTopPage } | Should -Not -Throw
		}
		It 'String型(2つ以上のときは配列で返却されること' {
			$result = Get-LinkFromTopPage

			$result.episodeLinks | Should -BeOfType String
			$result.seriesLinks | Should -BeOfType String
			$result.seasonLinks | Should -Be $null
			$result.talentLinks | Should -BeOfType String
			$result.specialMainLinks | Should -BeOfType String
			$result.specialLinks | Should -BeOfType String
			@($result.episodeLinks)[0].Substring(0, 27) | Should -Be 'https://tver.jp/episodes/ep'
			@($result.seriesLinks)[0].Substring(0, 2) | Should -Be 'sr'
			@($result.talentLinks)[0].Substring(0, 1) | Should -Be 't'
		}
	}
}

#----------------------------------------------------------------------
#サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
Describe 'Get-LinkFromSiteMap' -Tag 'Target' {

	BeforeAll {
			$script:timeoutSec = 30
			$script:sitemapParseEpisodeOnly = $false
			Get-Token
	}

	It 'Returns episode links from sitemap' {
		$result = Get-LinkFromSiteMap
		$result.episodeLinks.Count | Should -BeGreaterOrEqual 1
	}

	It 'Returns series links from sitemap when not episode only' {
		$script:sitemapParseEpisodeOnly = $false
		$result = Get-LinkFromSiteMap
		$result.seriesLinks.Count | Should -BeGreaterOrEqual 1
	}

	It 'Returns series links from sitemap when episode only' {
		$script:sitemapParseEpisodeOnly = $true
		$result = Get-LinkFromSiteMap
		$result.seriesLinks.Count | Should -Be 0
	}

	It 'Returns special links from sitemap when not episode only' {
		$script:sitemapParseEpisodeOnly = $false
		$result = Get-LinkFromSiteMap
		$result.specialLinks.Count | Should -BeGreaterOrEqual 1
	}

}
