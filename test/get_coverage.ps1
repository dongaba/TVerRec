###################################################################################
#
#		CIのカバレッジ結果を取得して集計するスクリプト
#
###################################################################################
<#
	.SYNOPSIS
		GitHub Actionsの最新のPester実行結果(coverage.xml)をダウンロードし、カバー率を集計します。

	.DESCRIPTION
		ghコマンドで、指定ブランチの最新の完了したワークフロー実行を探し、
		カバレッジのアーティファクトを取得します。
		取得後、OSごとの命令カバー率、3OSを合算した行カバー率、未カバー行の多いファイルを表示します。
		取得先フォルダは実行のたびに作り直します。(既存のフォルダがあると、ghが上書きに失敗するため)

	.PARAMETER Branch
		対象のブランチを指定します。省略時は、現在のブランチです。

	.PARAMETER Workflow
		対象のワークフローのファイル名を指定します。省略時は、pester.ymlです。

	.PARAMETER OutDir
		取得先のフォルダを指定します。省略時は、リポジトリ直下のcoverage-artifactsです。

	.PARAMETER RunId
		対象の実行IDを指定します。省略時は、指定ブランチの最新の完了した実行です。

	.PARAMETER NoDownload
		ダウンロードせず、取得済みのOutDirを集計します。

	.PARAMETER Top
		未カバー行の多いファイルを何件表示するかを指定します。省略時は、10件です。

	.PARAMETER Exclude
		集計から除外するファイル名を指定します。

	.EXAMPLE
		./test/get_coverage.ps1
		./test/get_coverage.ps1 -Branch beta -Exclude update_tverrec.ps1
		./test/get_coverage.ps1 -NoDownload

	.NOTES
		前提条件:
		- GitHub CLI(gh)がインストールされ、`gh auth login`済みであること
		- ワークフローがcoverage-*という名前でcoverage.xml(JaCoCo形式)をアップロードしていること
#>
[CmdletBinding()]
Param (
	[String]$Branch = '',
	[String]$Workflow = 'pester.yml',
	[String]$OutDir = '',
	[Int64]$RunId = 0,
	[Switch]$NoDownload,
	[Int]$Top = 10,
	[String[]]$Exclude = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (!$OutDir) { $OutDir = Join-Path $repoRoot 'coverage-artifacts' }

#----------------------------------------------------------------------
# ダウンロード
#----------------------------------------------------------------------
if (!$NoDownload) {
	if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw 'ghコマンドが見つかりません。GitHub CLIをインストールしてください。' }
	if ($RunId -eq 0) {
		if (!$Branch) { $Branch = (& git -C $repoRoot branch --show-current) }
		$runs = @(& gh run list --workflow $Workflow --branch $Branch --status completed --limit 1 --json databaseId,conclusion,displayTitle,headSha | ConvertFrom-Json)
		if ($runs.Count -eq 0) { throw ('ブランチ {0} に、完了した {1} の実行がありません。' -f $Branch, $Workflow) }
		$RunId = $runs[0].databaseId
		Write-Output ('対象の実行: {0} [{1}] {2} ({3})' -f $RunId, $runs[0].conclusion, $runs[0].displayTitle, $runs[0].headSha.Substring(0, 7))
	}
	# * 取得先は作り直す。誤って別の場所を消さないよう、リポジトリ配下かつcoverage-artifactsの場合だけ削除する
	if (Test-Path -LiteralPath $OutDir) {
		$full = [IO.Path]::GetFullPath($OutDir)
		if (!$full.StartsWith([IO.Path]::GetFullPath($repoRoot)) -or (Split-Path $full -Leaf) -ne 'coverage-artifacts') {
			throw ('取得先 {0} は、リポジトリ配下のcoverage-artifactsではないため、自動では作り直せません。空のフォルダを指定してください。' -f $OutDir)
		}
		Remove-Item -LiteralPath $full -Recurse -Force
	}
	& gh run download $RunId --dir $OutDir
	if ($LASTEXITCODE -ne 0) { throw 'ghでのダウンロードに失敗しました。' }
}

#----------------------------------------------------------------------
# 集計
#----------------------------------------------------------------------
$files = @(Get-ChildItem -LiteralPath $OutDir -Recurse -Filter 'coverage.xml' -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { throw ('{0} にcoverage.xmlがありません。' -f $OutDir) }

$union = @{}	# ファイル名 -> (行番号 -> いずれかのOSでカバーされたか)
foreach ($file in $files) {
	# * JaCoCo形式のXMLはDOCTYPEを含むため、DTDを無視して読み込む
	$settings = [Xml.XmlReaderSettings]::new()
	$settings.DtdProcessing = [Xml.DtdProcessing]::Ignore
	$settings.XmlResolver = $null
	$reader = [Xml.XmlReader]::Create($file.FullName, $settings)
	try { $xml = [Xml.XmlDocument]::new() ; $xml.Load($reader) } finally { $reader.Dispose() }

	$osName = (Split-Path $file.DirectoryName -Leaf) -replace '^coverage-', ''
	$counter = $xml.report.counter.Where({ $_.type -eq 'INSTRUCTION' }) | Select-Object -First 1
	$covered = [Int]$counter.covered
	$total = $covered + [Int]$counter.missed
	Write-Output ('{0,-16} 命令カバー率 {1,5:N1}% ({2}/{3})' -f $osName, (100 * $covered / $total), $covered, $total)

	foreach ($pkg in $xml.report.package) {
		foreach ($sf in $pkg.sourcefile) {
			if ($Exclude -contains $sf.name) { continue }
			if (!$union.ContainsKey($sf.name)) { $union[$sf.name] = @{} }
			foreach ($line in $sf.line) {
				$nr = [Int]$line.nr
				$hit = ([Int]$line.ci -gt 0)
				$union[$sf.name][$nr] = ($union[$sf.name].ContainsKey($nr) -and $union[$sf.name][$nr]) -or $hit
			}
		}
	}
}

$rows = foreach ($name in $union.Keys) {
	$lines = $union[$name]
	$hit = @($lines.Values.Where({ $_ })).Count
	[PSCustomObject]@{ File = $name ; Total = $lines.Count ; Covered = $hit ; Missed = $lines.Count - $hit ; Rate = if ($lines.Count) { [Math]::Round(100 * $hit / $lines.Count, 1) } else { 100 } }
}
$sumTotal = ($rows | Measure-Object -Property Total -Sum).Sum
$sumCovered = ($rows | Measure-Object -Property Covered -Sum).Sum
Write-Output ''
Write-Output ('{0} OS合算の行カバー率 {1:N1}% ({2}/{3}){4}' -f $files.Count, (100 * $sumCovered / $sumTotal), $sumCovered, $sumTotal, $(if ($Exclude) { ' ※除外: ' + ($Exclude -join ', ') } else { '' }))
Write-Output ''
Write-Output '未カバー行の多いファイル:'
Write-Output ('{0,-30} {1,7} {2,7} {3,7} {4,8}' -f 'File', 'Missed', 'Covered', 'Total', 'Rate(%)')
foreach ($row in ($rows | Sort-Object -Property Missed -Descending | Select-Object -First $Top)) {
	Write-Output ('{0,-30} {1,7} {2,7} {3,7} {4,8:N1}' -f $row.File, $row.Missed, $row.Covered, $row.Total, $row.Rate)
}
