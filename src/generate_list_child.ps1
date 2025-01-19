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
} else { Throw ('❌️ 子プロセスの引数が不足しています。Arguments for child process are missing') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize_child.ps1'))
} catch { Throw ('❌️ 関数の読み込みに失敗しました。Failed to load function.') }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Get-Token
foreach ($videoLink in $videoLinks) {
	Write-Output ('　{0}' -f $videoLink)
	Update-VideoList -Keyword ([Ref]$keyword) -VideoLink ([Ref]$videoLink)
}

Remove-Variable -Name keyword, videoLinks, videoLink -ErrorAction SilentlyContinue
