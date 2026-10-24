Import-Module Pester -MinimumVersion 5.0

BeforeAll {
	Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
	# * パスに「test」「src」を含むディレクトリ配下でも正しく解決できるよう、リポジトリルートから組み立てる
	$script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
	$targetFile = Join-Path $script:repoRoot 'src/functions/tverrec_functions.ps1'
	Write-Host ('　テスト対象: {0}' -f $targetFile)
	$script:scriptRoot = Convert-Path (Join-Path $script:repoRoot 'src')
	Set-Location $script:scriptRoot
	$script:confDir = Convert-Path (Join-Path $script:repoRoot 'conf')
	$script:msg = (Get-Content -Path (Join-Path $script:repoRoot 'resources/lang/messages.json') -Raw | ConvertFrom-Json).'ja-JP'
	. (Join-Path $script:scriptRoot 'functions/common_functions.ps1')
	. (Join-Path $script:confDir 'system_setting.ps1')
	# user_setting.ps1がない環境(クローン直後やCI)では一時的に作成し、テスト後に削除する
	$script:userSettingPath = Join-Path $script:confDir 'user_setting.ps1'
	$script:cleanupUserSetting = -not (Test-Path $script:userSettingPath)
	if ($script:cleanupUserSetting) {
		@(
			'$script:downloadBaseDir = "./download"'
			'$script:downloadWorkDir = "./work"'
			'$script:saveBaseDir = "./save"'
		) | Set-Content -LiteralPath $script:userSettingPath
	}
	. $script:userSettingPath
	. $targetFile
	Write-Host ('　テスト対象の読み込みを行いました')
	$script:downloadBaseDir = Join-Path $TestDrive 'download'
	$script:sortVideoByMedia = $false
	$script:sortVideoBySeries = $false
	$script:addSeriesName = $false
	$script:addSeasonName = $false
	$script:addBroadcastDate = $false
	$script:addEpisodeNumber = $false
	$script:videoContainerFormat = 'mp4'
	$script:fileNameLengthMax = 255
	New-Item -ItemType Directory -Path $script:downloadBaseDir -Force | Out-Null
}

Describe 'Format-VideoFileInfo' {
	It 'ベースディレクトリのみを返すこと' {
		$videoInfo = [PSCustomObject]@{
			mediaName     = 'Media'
			seriesName    = 'Series'
			seasonName    = 'Season1'
			episodeName   = 'Episode'
			broadcastDate = '2025-04-18'
			episodeNum    = 1
		}
		Format-VideoFileInfo -videoInfo ([ref]$videoInfo)
		$videoInfo.fileDir | Should -BeExactly $script:downloadBaseDir
	}
}

AfterAll {
	if ($script:cleanupUserSetting) { Remove-Item -LiteralPath $script:userSettingPath -ErrorAction SilentlyContinue }
}

Describe 'Merge-ZeroDurationSubtitle' {
	It '0秒字幕を同じ開始時刻の次の字幕にマージする' {
		$srt = "1`n00:00:05,000 --> 00:00:05,000`n字幕1`n`n2`n00:00:05,000 --> 00:00:09,000`n字幕2`n"
		$result = Merge-ZeroDurationSubtitle -SrtText $srt
		$result.MergedCount | Should -Be 1
		$result.Content | Should -Be "1`n00:00:05,000 --> 00:00:09,000`n字幕1`n字幕2`n`n"
	}
	It '0秒字幕が連続しても1つにまとめ、通し番号を振り直す' {
		$srt = "1`n00:00:01,000 --> 00:00:02,000`nA`n`n2`n00:00:05,000 --> 00:00:05,000`nB`n`n3`n00:00:05,000 --> 00:00:05,000`nC`n`n4`n00:00:05,000 --> 00:00:08,000`nD`n"
		$result = Merge-ZeroDurationSubtitle -SrtText $srt
		$result.MergedCount | Should -Be 2
		$result.Content | Should -Be "1`n00:00:01,000 --> 00:00:02,000`nA`n`n2`n00:00:05,000 --> 00:00:08,000`nB`nC`nD`n`n"
	}
	It 'マージ対象がなければ件数0を返す' {
		$srt = "1`n00:00:01,000 --> 00:00:03,000`nあ`n`n2`n00:00:05,000 --> 00:00:09,000`nい`n"
		(Merge-ZeroDurationSubtitle -SrtText $srt).MergedCount | Should -Be 0
	}
	It '次に同じ開始時刻の字幕がない0秒字幕は削除せず残す' {
		$srt = "1`n00:00:05,000 --> 00:00:05,000`n孤立`n`n2`n00:00:07,000 --> 00:00:09,000`n次`n"
		$result = Merge-ZeroDurationSubtitle -SrtText $srt
		$result.MergedCount | Should -Be 0
		$result.Content | Should -Match '孤立'
	}
	It '空文字列でもエラーにならない' {
		(Merge-ZeroDurationSubtitle -SrtText '').MergedCount | Should -Be 0
	}
}
