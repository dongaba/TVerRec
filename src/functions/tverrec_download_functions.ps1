###################################################################################
#
#		TVerRec固有関数スクリプト(TVer番組のダウンロード処理、保存ファイル名の決定、失敗ファイルの削除)
#
###################################################################################
<#
	.SYNOPSIS
		TVer番組のダウンロード処理、保存ファイル名の決定、失敗ファイルの削除の関数を定義します。

	.NOTES
		このファイルはtverrec_functions.ps1から読み込まれます。
		単体で読み込まず、tverrec_functions.ps1を読み込んでください。

	.LINK
		https://github.com/dongaba/TVerRec
#>

Set-StrictMode -Version Latest

#region ダウンロード関連
#----------------------------------------------------------------------
# 「《」と「》」、「【」と「】」で挟まれた文字を除去
#----------------------------------------------------------------------
function Remove-SpecialNote {
	<#
		.SYNOPSIS
			特定の特殊文字で囲まれた文字列を削除します。

		.DESCRIPTION
			入力テキストから特定の特殊文字（《》、【】）で囲まれた文字列を削除します。
			ただし、文字列の長さが一定の閾値（10文字）を超える場合のみ削除を行います。

		.PARAMETER text
			処理対象のテキストを指定します。

		.OUTPUTS
			[String]
			特殊文字で囲まれた文字列が削除されたテキスト。

		.EXAMPLE
			$cleanedText = Remove-SpecialNote -text "これは【テスト】です"

		.NOTES
			この関数は以下の処理を行います：
			1. 《》と【】の各ペアの位置を検出
			2. 文字列の長さが閾値（10文字）を超える場合のみ削除
			3. 削除後、余分な空白を除去
			4. 処理後のテキストを返す
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param ([Parameter(Mandatory = $false)][String]$text = '')
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		# 特殊文字の位置を取得し、長さを計算
		$length1 = [Math]::Max(0, $text.IndexOf('》') - $text.IndexOf('《'))
		$length2 = [Math]::Max(0, $text.IndexOf('】') - $text.IndexOf('【'))
	}
	process {
		if ($PSCmdlet.ShouldProcess($text, 'Trim characters')) {
			# 10文字以上あれば特殊文字とその間を削除
			if (($length1 -gt 10) -or ($length2 -gt 10)) { $text = (($text -replace '《.*?》|【.*?】', '') -replace '\s+', ' ').Trim() }
		}
	}
	end {
		return $text
	}
}

#----------------------------------------------------------------------
# TVer番組ダウンロードのメイン処理
#----------------------------------------------------------------------
function Invoke-VideoDownload {
	<#
		.SYNOPSIS
			TVer番組のダウンロードを実行するメイン処理です。

		.DESCRIPTION
			指定されたURLからTVer番組をダウンロードし、必要な情報を記録します。
			ダウンロード履歴とダウンロードリストの両方を更新します。

		.PARAMETER keyword
			検索キーワードを参照で指定します。

		.PARAMETER videoLink
			ダウンロードするTVer番組のURLを参照で指定します。

		.PARAMETER force
			強制的にダウンロードを実行するかどうかを指定します。
			デフォルトは$falseです。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Invoke-VideoDownload -keyword $keyword -episodeID $episodeID -force $true

		.NOTES
			この関数は以下の処理を行います：
			1. 指定されたURLから番組情報を取得
			2. ダウンロード履歴とダウンロードリストを更新
			3. youtube-dlを使用して番組をダウンロード
			4. ダウンロード結果を記録

			状態の振り分け設定：
			- 履歴ファイルに存在する場合：
			- ID変更時のダウンロード設定あり：再ダウンロード
			- ID変更時のダウンロード設定なし：スキップ
			- 履歴ファイルに存在しない場合：
			- ファイルが存在する：検証のみ
			- ファイルが存在しない：
				- ダウンロード対象外リストに存在：無視
				- ダウンロード対象外リストに存在しない：ダウンロード
	#>
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$keyword,
		[Parameter(Mandatory = $true)][String]$episodeID,
		[Parameter(Mandatory = $false)][Boolean]$force = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$newVideo = $null
	$skipDownload = $false
	# TVerのAPIを叩いて番組情報取得
	Invoke-StatisticsCheck -Operation 'getinfo' -TVerType 'link' -TVerID $episodeID
	$videoInfo = Get-VideoInfo $episodeID
	if ($null -eq $videoInfo) { Write-Warning ($script:msg.EpisodeInfoRetrievalFailed) ; return }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'keyword' -Value $keyword
	# ダウンロードファイル名を生成
	Format-VideoFileInfo ([Ref]$videoInfo)
	# 番組タイトルが取得できなかった場合はスキップ次の番組へ
	if (($videoInfo.fileName -eq '.mp4') -or ($videoInfo.fileName -eq '.ts')) { Write-Warning ($script:msg.EpisodeTitleRetrievalFailed) ; return }
	# 番組情報のコンソール出力
	Show-VideoInfo ([Ref]$videoInfo)
	if ($DebugPreference -ne 'SilentlyContinue') { Show-VideoDebugInfo ([Ref]$videoInfo) }
	# 字幕の有無の記録と、字幕が追加された番組の再ダウンロード判定
	$subtitleTracking = Test-SubtitleTrackingEnabled
	$subtitleStatus = $null
	$subtitleRecheck = $false
	$histFileData = $null
	if (!$force -and $subtitleTracking) {
		$histFileData = @(Get-LatestHistoryCached)
		$subtitleHists = @($histFileData.Where({ $_ -and $_.PSObject.Properties['subtitle'] }))
		$sameEpisodeHists = @($subtitleHists.Where({ $_.videoPage -eq $videoInfo.episodePageURL }))
		if (($sameEpisodeHists.Count -ne 0) -and ($sameEpisodeHists[0].subtitle -eq '0')) {
			# 字幕なしで保存済みの番組	→字幕が追加されたか確認する
			foreach ($ignoreTitle in @(Get-IgnoreListCached)) {
				if ($ignoreTitle -and (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard)) { return }
			}
			Write-Output ($script:msg.SubtitleRecheck)
			$subtitleStatus = Get-VideoSubtitleStatus -EpisodePageURL $videoInfo.episodePageURL -IsSubtitle $videoInfo.isSubtitle
			if ($subtitleStatus -ne '1') { Write-Output ($script:msg.SubtitleNotAdded) ; return }
			Write-Output ($script:msg.SubtitleAdded)
			$subtitleRecheck = $true
		}
	}
	if ($force -or $subtitleRecheck) {
		$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
		$newVideo = Format-HistoryRecord $videoInfo
	} else {
		<# * 状態の振り分け設定
			* ここまで来ているということはEpisodeIDでは履歴とマッチしなかったということ
			* 考えられる原因は履歴ファイルがクリアされてしまっていること、または、EpisodeIDが変更になったこと
				* 履歴ファイルに存在する	→番組IDが変更になったあるいは、番組名の重複
					* ID変更時のダウンロード設定あり
						検証済	→再ダウンロード
						検証中	→元々の番組IDとしてはそのうち検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
						未検証	→元々の番組IDとしては次回検証されるので、再ダウンロード。検証に失敗しても新IDでダウンロード検証されるはず
					* ID変更時のダウンロード設定なし
						検証済	→元々の番組IDとしては問題ないのでSKIP
						検証中	→元々の番組IDとしてはそのうち検証されるのでSKIP
						未検証	→元々の番組IDとしては次回検証されるのでSKIP
				* 履歴ファイルに存在しない
					ファイルが存在する	→検証だけする
					ファイルが存在しない
						ダウンロード対象外リストに存在する	→無視
						ダウンロード対象外リストに存在しない	→ダウンロード
		#>
		#ダウンロード履歴ファイルのデータを読み込み(字幕の判定で読み込み済みの場合は再利用)
		if ($null -eq $histFileData) { $histFileData = @(Get-LatestHistoryCached) }
		if ($videoInfo.fileRelPath) { $histMatch = @($histFileData.Where({ $_.videoPath -eq $videoInfo.fileRelPath })) }
		else { Write-Warning ($script:msg.FileNameRetrievalFailed) ; return }

		if ($script:downloadWhenEpisodeIdChanged) {
			if (($histMatch.Count -ne 0) -or (Test-Path $videoInfo.filePath)) {
				$ignoreTitles = @(Get-IgnoreListCached)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard) {
						# エピソードIDが変更になったがダウンロード対象外リストと合致	→無視する
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
						$videoInfo.fileName = '-- IGNORED --'
						$videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
						break
					}
				}
				# エピソードIDが変更になった	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeIdChanged)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord $videoInfo
				}
			} else {
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
				$ignoreTitles = @(Get-IgnoreListCached)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard) {
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
						$videoInfo.fileName = '-- IGNORED --'
						$videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
						break
					}
				}
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeAdded)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord $videoInfo
				}
			}
		} else {
			if ($histMatch.Count -ne 0) {
				# 履歴ファイルに存在する	→スキップして次のファイルに
				Write-Warning ($script:msg.DownloadHistExists)
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '1' ; $videoInfo.fileName = '-- SKIPPED --'
				$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
			} elseif (Test-Path $videoInfo.filePath) {
				# 履歴ファイルに存在しないが、実ファイルが存在する	→検証だけする
				Write-Warning ($script:msg.DownloadFileExists)
				$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- SKIPPED --'
				$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
			} else {
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストと合致	→無視する
				$ignoreTitles = @(Get-IgnoreListCached)
				foreach ($ignoreTitle in $ignoreTitles) {
					if (Test-IgnoreMatch -Pattern $ignoreTitle -Target @($videoInfo.fileName, $videoInfo.seriesName) -Mode Wildcard) {
						Update-IgnoreList $ignoreTitle ; Write-Warning ($script:msg.IgnoreEpisodeAdded)
						$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0' ; $videoInfo.fileName = '-- IGNORED --' ; $videoInfo.fileRelPath = '-- IGNORED --'
						$newVideo = Format-HistoryRecord $videoInfo ; $skipDownload = $true
						break
					}
				}
				# 履歴ファイルに存在せず、実ファイルも存在せず、ダウンロード対象外リストとも合致しない	→ダウンロードする
				if (!$skipDownload) {
					Write-Output ($script:msg.DownloadEpisodeAdded)
					$videoInfo | Add-Member -MemberType NoteProperty -Name 'validated' -Value '0'
					$newVideo = Format-HistoryRecord $videoInfo
				}
			}
		}
	}

	# ダウンロードする番組の字幕の有無を記録
	if ($subtitleTracking -and !$skipDownload -and $newVideo) {
		if ($null -eq $subtitleStatus) { $subtitleStatus = Get-VideoSubtitleStatus -EpisodePageURL $videoInfo.episodePageURL -IsSubtitle $videoInfo.isSubtitle }
		$newVideo.subtitle = $subtitleStatus
	}
	# ダウンロード履歴CSV書き出し
	Wait-FileLock $script:histLockFilePath
	try {
		$newVideo | Export-Csv -LiteralPath $script:histFilePath -Encoding UTF8 -Append ; Start-Sleep -Seconds 1
		Write-Debug ($script:msg.HistWritten)
		Add-LatestHistoryCache $newVideo
	} catch { Write-Warning ($script:msg.HistUpdateFailed) ; return }
	finally { Unlock-File $script:histLockFilePath | Out-Null }
	# スキップ対象やダウンロード対象外は飛ばして次のファイルへ
	if ($skipDownload) { return }
	# 番組ディレクトリがなければ作成
	if ($script:sortVideoBySeries -and !(Test-Path $videoInfo.fileDir -PathType Container)) {
		try { New-Item -ItemType Directory -Path $videoInfo.fileDir -Force -ErrorAction Stop | Out-Null }
		catch { Write-Warning ($script:msg.CreateEpisodeDirFailed) ; return }
	}
	# youtube-dl起動
	if ($script:ytdlRandomIp -and $script:proxyUrl) {
		Write-Output ($script:msg.MediumBoldBorder)
		Write-Output ($script:msg.NotifyYtdlOptions1)
		Write-Output ($script:msg.NotifyYtdlOptions2)
		Write-Output ($script:msg.NotifyYtdlOptions3)
		Write-Output ($script:msg.MediumBoldBorder)
	}
	try { Invoke-Ytdl ([Ref]$videoInfo) }
	catch { Write-Warning ($script:msg.InvokeYtdlFailed) }
	# 1秒待機
	Start-Sleep -Seconds 1
	Remove-Variable -Name keyword, videoLink, force, newVideo, skipDownload, episodeID, histFileData, histMatch, ignoreTitles, ignoreTitle, subtitleTracking, subtitleStatus, subtitleRecheck, subtitleHists, sameEpisodeHists -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 保存ファイル名を設定
#----------------------------------------------------------------------
function Format-VideoFileInfo {
	<#
		.SYNOPSIS
			ビデオファイルの保存情報を設定します。

		.DESCRIPTION
			ビデオ情報からファイル名、ディレクトリパス、相対パスなどの
			保存に必要な情報を生成します。

		.PARAMETER videoInfo
			ビデオ情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Format-VideoFileInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の処理を行います：
			1. シリーズ名、シーズン名、エピソード番号などからファイル名を生成
			2. メディア名やシリーズ名に基づいてディレクトリパスを生成
			3. ファイル名の長さ制限を適用
			4. ビデオ情報オブジェクトに保存情報を追加
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$videoName = ''
	# ファイル名を生成
	if ($script:addSeriesName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seriesName) }
	if ($script:addSeasonName) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.seasonName) }
	if ($videoName.Trim() -ne $videoInfo.episodeName.Trim() ) {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターン
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
		$videoName = ('{0}{1}' -f $videoName, $videoInfo.episodeName)
	} else {
		if ($script:addBroadcastDate) { $videoName = ('{0}{1} ' -f $videoName, $videoInfo.broadcastDate.replace('/', '-')) }	#きょうのわんこなど「2025/3/17週放送」のようなパターン
		if ($script:addEpisodeNumber) { $videoName = ('{0}Ep{1} ' -f $videoName, $videoInfo.episodeNum) }
	}
	# ファイル名にできない文字列を除去
	$videoName = ((Get-FileNameWoInvalidChar (Remove-SpecialCharacter $videoName)) -replace '\s+', ' ').Trim()
	# SMBで255バイトまでしかファイル名を持てないらしいので、超えないようにファイル名をトリミング。安全目の上限値としており、限界値は攻めていない
	$fileNameLimit = $script:fileNameLengthMax - 30
	if ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) {
		while ([System.Text.Encoding]::UTF8.GetByteCount($videoName) -gt $fileNameLimit) { $videoName = $videoName.Substring(0, $videoName.Length - 1) }
		$videoName = ('{0}……' -f $videoName)
	}
	$videoName = ('{0}.{1}' -f $videoName, $script:videoContainerFormat)
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileName' -Value $videoName

	# フォルダ名を生成
	$videoFileDir = @()
	if ($script:sortVideoByMedia) { $videoFileDir += Get-FileNameWoInvalidChar (Remove-SpecialCharacter ($videoInfo.mediaName).Trim(' ', '.')) }
	if ($script:sortVideoBySeries) {
		$seriesDirName = Get-FileNameWoInvalidChar (Remove-SpecialCharacter ('{0} {1}' -f $videoInfo.seriesName, $videoInfo.seasonName ).Trim(' ', '.'))
		# フォルダ名もSMBの255バイト制限があるため、長い場合はトリミング(末尾の空白・ピリオドはWindowsで使えないので除去)
		$dirNameLimit = $script:fileNameLengthMax - 30
		if ([System.Text.Encoding]::UTF8.GetByteCount($seriesDirName) -gt $dirNameLimit) {
			while ([System.Text.Encoding]::UTF8.GetByteCount($seriesDirName) -gt $dirNameLimit) { $seriesDirName = $seriesDirName.Substring(0, $seriesDirName.Length - 1) }
			$seriesDirName = ('{0}……' -f $seriesDirName.Trim(' ', '.'))
		}
		$videoFileDir += $seriesDirName
	}
	if ($videoFileDir) { $videoFileDir = Join-Path $script:downloadBaseDir @videoFileDir }		# 3コ以上行けるので配列のまま渡す
	else { $videoFileDir = $script:downloadBaseDir }
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileDir' -Value $videoFileDir.Replace('\', '/')

	$videoFilePath = Join-Path $videoFileDir $videoInfo.fileName
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'filePath' -Value $videoFilePath.Replace('\', '/')
	$videoFileRelPath = $videoFilePath.Replace($script:downloadBaseDir, '')
	$videoInfo | Add-Member -MemberType NoteProperty -Name 'fileRelPath' -Value $videoFileRelPath.Replace('\', '/').TrimStart('/')

	Remove-Variable -Name videoName, fileNameLimit, seriesDirName, dirNameLimit, videoFileDir, videoFilePath, videoFileRelPath -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 番組情報表示
#----------------------------------------------------------------------
function Show-VideoInfo {
	<#
		.SYNOPSIS
			番組の基本情報をコンソールに表示します。

		.DESCRIPTION
			指定されたビデオ情報から、番組名、放送日、メディア名、終了日時、
			エピソード詳細などの情報をコンソールに表示します。

		.PARAMETER videoInfo
			表示する番組情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Show-VideoInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の情報を表示します：
			1. エピソード名（ファイル名から拡張子を除いたもの）
			2. 放送日
			3. メディア名
			4. 終了日時
			5. エピソード詳細（説明文）
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Output ($script:msg.EpisodeName -f $videoInfo.fileName.Replace($script:videoContainerFormat, ''))
	Write-Output ($script:msg.BroadcastDate -f $videoInfo.broadcastDate)
	Write-Output ($script:msg.MediaName -f $videoInfo.mediaName)
	Write-Output ($script:msg.EndDate -f $videoInfo.endTime)
	<#
		Write-Output ($script:msg.IsBrightcove -f $videoInfo.isBrightcove)
		Write-Output ($script:msg.IsStreaks -f $videoInfo.isStreaks)
	#>
	Write-Output ($script:msg.EpisodeDetail -f $videoInfo.descriptionText)
}

#----------------------------------------------------------------------
# 番組情報デバッグ表示
#----------------------------------------------------------------------
function Show-VideoDebugInfo {
	<#
		.SYNOPSIS
			番組のデバッグ情報をコンソールに表示します。

		.DESCRIPTION
			指定されたビデオ情報から、デバッグ用の情報（エピソードページURL）を
			コンソールに表示します。

		.PARAMETER videoInfo
			表示する番組情報を含むオブジェクトを参照で指定します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.EXAMPLE
			Show-VideoDebugInfo -videoInfo ([ref]$videoInfo)

		.NOTES
			この関数は以下の情報を表示します：
			1. エピソードページのURL
	#>
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][PSCustomObject][Ref]$videoInfo)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Debug $videoInfo.episodePageURL
}

#----------------------------------------------------------------------
# ダウンロードスケジュールに合わせたスケジュール制御
#----------------------------------------------------------------------
function Suspend-Process () {
	<#
		.SYNOPSIS
			ダウンロードスケジュールに基づいてプロセスを一時停止します。

		.DESCRIPTION
			ダウンロードスケジュールに基づいてプロセスを一時停止します。
			指定された曜日と時間にダウンロードを停止し、次の正時まで待機します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. 現在の日付と時刻を取得
			2. スケジュールに基づいて停止時間を確認
			3. 停止時間の場合は次の正時まで待機
	#>
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($script:scheduleStop) {
		Write-Debug ('Checking execution schedule')
		while ($true) {
			$currentDateTime = Get-Date
			$currentDay = ($currentDateTime).DayOfWeek.ToString().Substring(0, 3)
			$currentHour = ($currentDateTime).Hour
			if ($script:stopSchedule.ContainsKey($currentDay)) {
				if ($script:stopSchedule[$currentDay] -contains $currentHour) {
					Write-Output ($script:msg.WaitSuspendTime -f ($currentDateTime))
					# 次の正時までの時間差を計算
					$timeDifference = $currentDateTime.Date.AddHours($currentDateTime.Hour + 1) - $currentDateTime
					Start-Sleep -Seconds ([math]::Ceiling($timeDifference.TotalSeconds))
				} else { break }
			} else { break }
		}
	}
	Remove-Variable -Name currentDateTime, currentDay, currentHour, timeDifference -ErrorAction SilentlyContinue
}
#endregion ダウンロード関連


#region ダウンロード失敗ファイル削除関連
#----------------------------------------------------------------------
# 移動に失敗したファイルを削除(作業フォルダ)
#----------------------------------------------------------------------
<#
.SYNOPSIS
    作業フォルダ内の移動に失敗したファイルを削除します。

.DESCRIPTION
    作業フォルダ内の移動に失敗したファイルを削除します。
    ファイル名が特定のパターンに一致するファイルを削除します。

.OUTPUTS
    [Void]
    この関数は値を返しません。

.NOTES
    この関数は以下の処理を行います：
    1. 作業フォルダ内のファイルを検索
    2. ファイル名が特定のパターンに一致するファイルを削除
#>
function Remove-UnMovedTempFile {
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param ()
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		$targetFiles = (Get-ChildItem -Path $script:downloadWorkDir -File).Where({ $_.Name -match '^ep[a-z0-9]{8}\..*(\.)*(mp4|ts)$' })
	}
	process {
		foreach ($file in $targetFiles) {
			try {
				if ($PSCmdlet.ShouldProcess($file, 'Remove file')) {
					Write-Information ($script:msg.DeleteFile -f $file)
					Remove-Item -LiteralPath $file -Force -ErrorAction Stop
				}
			} catch { Write-Warning ('{0} : {1}' -f $file, $script:msg.FileCannotBeDeleted) }
		}
	}
}

#----------------------------------------------------------------------
# リネームに失敗したファイルを削除(ダウンロード先フォルダ)
#----------------------------------------------------------------------
function Remove-UnRenamedTempFile {
	<#
		.SYNOPSIS
			ダウンロード先フォルダ内のリネームに失敗したファイルを削除します。

		.DESCRIPTION
			ダウンロード先フォルダ内のリネームに失敗したファイルを削除します。
			ファイル名が特定のパターンに一致するファイルを削除します。
			`$script:deleteUnrenamedFile`が`$false`の場合は、削除せずに、残したファイルを警告として表示します。

		.OUTPUTS
			[Void]
			この関数は値を返しません。

		.NOTES
			この関数は以下の処理を行います：
			1. ダウンロード先フォルダ内のファイルを検索
			2. 削除しない設定の場合は、見つけたファイルを警告として表示して終了
			3. ファイル名が特定のパターンに一致するファイルを削除
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param ()
	begin {
		Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
		if ($IsWindows) {
			$forCmd = "for %E in (mp4 ts) do for /r `"$script:downloadBaseDir`" %F in (ep*.%E) do @echo %F"
			$targetFiles = @(& cmd /c $forCmd).Where({ ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') })
		} else {
			$findCmd = "find `"$script:downloadBaseDir`" -type f -name 'ep*.mp4' -or -type f -name 'ep*.ts'"
			$targetFiles = @(& sh -c $findCmd).Where({ ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') })
		}
	}
	process {
		# 削除しない設定の場合は、削除せずに残したファイルを警告として表示する
		if (!$script:deleteUnrenamedFile) {
			foreach ($file in $targetFiles) { Write-Warning ($script:msg.UnrenamedFileKept -f $file) }
			return
		}
		Write-Output ($script:msg.DeleteFilesFailedToRename)
		foreach ($file in $targetFiles) {
			try {
				if ($PSCmdlet.ShouldProcess($file, 'Remove file')) {
					Write-Information ($script:msg.DeleteFile -f $file)
					Remove-Item -LiteralPath $file -Force -ErrorAction Stop
				}
			} catch { Write-Warning ('{0} : {1}' -f $file, $script:msg.FileCannotBeDeleted) }
		}
	}
}
#endregion ダウンロード失敗ファイル削除関連
