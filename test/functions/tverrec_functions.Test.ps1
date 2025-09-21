Import-Module Pester -MinimumVersion 5.0

BeforeAll {
    Write-Host ('テストスクリプト: {0}' -f $PSCommandPath)
    $targetFile = $PSCommandPath.Replace('test', 'src').Replace('.Test.ps1', '.ps1')
    Write-Host ('　テスト対象: {0}' -f $targetFile)
    $script:scriptRoot = Convert-Path ./src
    Set-Location $script:scriptRoot
    $script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
    . (Join-Path $script:scriptRoot 'functions/common_functions.ps1')
    . (Join-Path $script:confDir 'system_setting.ps1')
    $userSettingPath = Join-Path $script:confDir 'user_setting.ps1'
    if (-not (Test-Path $userSettingPath)) {
        '$script:downloadBaseDir = "./download"' | Set-Content -LiteralPath $userSettingPath
        '$script:downloadWorkDir = "./work"' | Add-Content -LiteralPath $userSettingPath
        '$script:saveBaseDir = "./save"' | Add-Content -LiteralPath $userSettingPath
        $script:_cleanupUserSetting = $true
    }
    . $userSettingPath
    . $targetFile
    Write-Host ('　テスト対象の読み込みを行いました')
    $script:downloadBaseDir = Join-Path $PSScriptRoot '../tmp'
    $script:sortVideoByMedia = $false
    $script:sortVideoBySeries = $false
    $script:addSeriesName = $false
    $script:addSeasonName = $false
    $script:addBroadcastDate = $false
    $script:addEpisodeNumber = $false
    $script:videoContainerFormat = 'mp4'
    $script:fileNameLengthMax = 255
    if (-not (Test-Path $script:downloadBaseDir)) { New-Item -ItemType Directory -Path $script:downloadBaseDir | Out-Null }
}

Describe 'Format-VideoFileInfo' {
    It 'ベースディレクトリのみを返すこと' {
        $videoInfo = [PSCustomObject]@{
            mediaName = 'Media'
            seriesName = 'Series'
            seasonName = 'Season1'
            episodeName = 'Episode'
            broadcastDate = '2025-04-18'
            episodeNum = 1
        }
        Format-VideoFileInfo -videoInfo ([ref]$videoInfo)
        $videoInfo.fileDir | Should -BeExactly $script:downloadBaseDir
    }
}

AfterAll {
    if (Get-Variable -Name _cleanupUserSetting -Scope Script -ErrorAction SilentlyContinue) {
        if ($script:_cleanupUserSetting) {
            Remove-Item $userSettingPath -ErrorAction SilentlyContinue
        }
    }
}
