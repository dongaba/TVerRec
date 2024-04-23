###################################################################################
#
#		番組リストファイル出力処理 - 再帰呼び出し子スレッド用スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

if ($args.Count -ge 2) {
	$keyword = [String]$args[0]
	$videoLinks = $args[1..($args.Count - 1)]
} else { Write-Error ('❌️ 子プロセスの引数が不足しています') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Write-Error ('❌️ カレントディレクトリの設定に失敗しました') ; exit 1 }
if ($script:scriptRoot.Contains(' ')) { Write-Error ('❌️ TVerRecはスペースを含むディレクトリに配置できません') ; exit 1 }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize_child.ps1'))
	if (!$?) { Write-Error ('❌️ TVerRecの初期化処理に失敗しました') ; exit 1 }
} catch { Write-Error ('❌️ 関数の読み込みに失敗しました') ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Get-Token
foreach ($videoLink in $videoLinks) {
	Write-Output ('　{0}' -f $videoLink)
	Update-VideoList -Keyword $keyword -EpisodePage $videoLink
}

Remove-Variable -Name keyword, videoLinks, videoLink -ErrorAction SilentlyContinue
