###################################################################################
#
#		TVerRec固有関数スクリプト(ダウンロードリストとキーワードの読み込み・作成)
#
###################################################################################
<#
	.SYNOPSIS
		ダウンロードリストとキーワードの読み込み・作成の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region ダウンロードリスト関連
#----------------------------------------------------------------------
# ダウンロードリストの読み込み
#----------------------------------------------------------------------
function Read-DownloadList {
	<#
		.SYNOPSIS
			ダウンロードリストファイルからダウンロード対象の情報を読み込みます。

		.DESCRIPTION
			ダウンロードリストファイルをCSV形式で読み込み、ダウンロード対象の
			情報を配列として返します。

		.OUTPUTS
			[PSCustomObject[]] ダウンロード対象の情報の配列

		.EXAMPLE
			$downloadList = Read-DownloadList

		.NOTES
			この関数は以下の処理を行います：
			1. リストファイルをロック
			2. CSVファイルとして読み込み
			3. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$listFileData = @()
	try {
		Wait-FileLock $script:listLockFilePath
		$listFileData = Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8
	} catch { throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
	finally { Unlock-File $script:listLockFilePath | Out-Null }
	return $listFileData
}

#----------------------------------------------------------------------
# ダウンロードリストからダウンロードリンクの読み込み
#----------------------------------------------------------------------
function Get-LinkFromDownloadList {
	<#
		.SYNOPSIS
			ダウンロードリストからTVerのエピソードリンクを取得します。

		.DESCRIPTION
			ダウンロードリストファイルからEpisodeIDを抽出し、TVerのエピソード
			リンクに変換して返します。

		.OUTPUTS
			[String[]] TVerのエピソードリンクの配列

		.EXAMPLE
			$videoLinks = Get-LinkFromDownloadList

		.NOTES
			この関数は以下の処理を行います：
			1. リストファイルをロック
			2. CSVファイルとして読み込み
			3. 空行とダウンロード対象外（#で始まる行）を除外
			4. EpisodeIDをTVerのエピソードリンクに変換
			5. ロックを解除
	#>
	[OutputType([String[]])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (Test-Path $script:listFilePath -PathType Leaf) {
		try {
			Wait-FileLock $script:listLockFilePath
			# 空行とダウンロード対象外を除き、EpisodeIDのみを抽出
			$videoLinks = @((Import-Csv -LiteralPath $script:listFilePath -Encoding UTF8).Where({ !($_ -cmatch '^\s*$') }).Where({ !($_.EpisodeID -cmatch '^#') }) | Select-Object episodeID)
		} catch { throw ($script:msg.LoadFailed -f $script:msg.ListFile) }
		finally { Unlock-File $script:listLockFilePath | Out-Null }
	} else { $videoLinks = @() }
	# 有効な行がない場合(ヘッダーのみ、またはすべてコメントアウト)は、StrictModeで空配列のプロパティ参照がエラーになるため、先に返す
	if ($videoLinks.Count -eq 0) { return @() }
	$episodeIDs = [string[]]$videoLinks.episodeID
	return @($episodeIDs)
}

#----------------------------------------------------------------------
# ダウンロードリストデータの成形
#----------------------------------------------------------------------
function Format-ListRecord {
	<#
		.SYNOPSIS
			ビデオ情報をダウンロードリストレコードの形式に整形します。

		.DESCRIPTION
			ビデオ情報オブジェクトを参照で受け取り、ダウンロードリストファイルに
			保存するための形式に整形します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[PSCustomObject]
			ダウンロードリストレコード。以下のプロパティを含みます：
			- seriesName: シリーズ名
			- seriesID: シリーズID
			- seriesPageURL: シリーズページのURL
			- seasonName: シーズン名
			- seasonID: シーズンID
			- episodeNo: エピソード番号
			- episodeName: エピソードタイトル
			- episodeID: エピソードID
			- episodePageURL: エピソードページのURL
			- media: メディア名
			- provider: プロバイダー名
			- broadcastDate: 放送日
			- endTime: 終了時間
			- keyword: キーワード
			- ignoreWord: 無視する単語
			- descriptionText: 説明文（オプション）

		.EXAMPLE
			$listRecord = Format-ListRecord -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. ビデオ情報から必要なデータを抽出
			2. ダウンロードリストレコードの形式に整形
			3. 説明文の有無に応じてプロパティを追加
			4. 整形したレコードを返す
	#>
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$downloadListItem = [PSCustomObject]@{
		seriesName     = $videoInfo.seriesName
		seriesID       = $videoInfo.seriesID
		seriesPageURL  = $videoInfo.seriesPageURL
		seasonName     = $videoInfo.seasonName
		seasonID       = $videoInfo.seasonID
		episodeNo      = $videoInfo.episodeNum
		episodeName    = $videoInfo.episodeName
		episodeID      = $videoInfo.episodeID
		episodePageURL = $videoInfo.episodePageURL
		media          = $videoInfo.mediaName
		provider       = $videoInfo.providerName
		broadcastDate  = $videoInfo.broadcastDate
		endTime        = $videoInfo.endTime
		keyword        = $videoInfo.keyword
		ignoreWord     = $videoInfo.ignoreWord
	}
	if ($script:extractDescTextToList) { $downloadListItem | Add-Member -NotePropertyName descriptionText -NotePropertyValue $videoInfo.descriptionText }
	else { $downloadListItem | Add-Member -NotePropertyName descriptionText -NotePropertyValue '' }
	return $downloadListItem
}

#----------------------------------------------------------------------
# TVer番組ダウンロードリスト作成のメイン処理
#----------------------------------------------------------------------
function Update-VideoList {
	<#
		.SYNOPSIS
			TVer番組のダウンロードリストを作成します。

		.DESCRIPTION
			指定されたキーワードでTVer番組を検索し、ダウンロードリストを作成します。
			無視リストに登録されている番組は除外されます。

		.PARAMETER keyword
			検索キーワードを指定します。

		.OUTPUTS
			System.Void

		.EXAMPLE
			Update-VideoList -keyword "ドラマ"

		.NOTES
			処理の流れ:
			1. キーワードでTVer番組を検索
			2. 無視リストに登録されている番組を除外
			3. ダウンロードリストをCSVファイルに出力
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$keyword,
		[Parameter(Mandatory = $true)][String]$episodeID
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$ignoreWord = ''
	$newVideo = $null
	$ignore = $false
	# TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ($script:msg.EpisodeInfoRetrievalFailed) ; return }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	# ダウンロード対象外に入っている番組の場合はリスト出力しない
	$ignoreTitles = @(Read-IgnoreList)
	foreach ($ignoreTitle in $ignoreTitles) {
		if ($ignoreTitle) {
			if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.seriesName, $videoInfo.episodeName) -Mode Literal) {
				$ignoreWord = $ignoreTitle ; Update-IgnoreList $ignoreTitle ; $ignore = $true
				$videoInfo.episodeID = ('#{0}' -f $videoInfo.episodeID)
				break
			}
		}
	}
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'ignoreWord' -Value $ignoreWord
	# 番組情報のコンソール出力
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo ([Ref]$videoInfo) }
	# スキップフラグが立っているかチェック
	if ($ignore) { Write-Warning ($script:msg.ListIgnoredAdded) ; $newVideo = Format-ListRecord ([Ref]$videoInfo) }
	else { Write-Output ($script:msg.ListAdded) ; $newVideo = Format-ListRecord ([Ref]$videoInfo) }
	# ダウンロードリストCSV書き出し
	try {
		Wait-FileLock $script:listLockFilePath
		if ($PSCmdlet.ShouldProcess($script:listFilePath, 'Add to download list')) { $newVideo | Export-Csv -LiteralPath $script:listFilePath -Encoding UTF8 -Append }
		Write-Debug ($script:msg.ListWritten)
	} catch {
		Write-Warning ($script:msg.ListUpdateFailed) ; return
	} finally {
		Unlock-File $script:listLockFilePath | Out-Null
		Remove-Variable -Name keyword, videoLink, ignoreWord, newVideo, ignore, episodeID, ignoreTitles, ignoreTitle -ErrorAction SilentlyContinue
	}
}

#endregion ダウンロードリスト関連
