###################################################################################
#
#		個別ダウンロード処理スクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecで個別の番組URLをダウンロードするスクリプト

	.DESCRIPTION
		指定されたURLの番組を個別にダウンロードします。
		以下の機能を提供します：
		1. TVer番組の個別ダウンロード
		2. 複数URLの一括ダウンロード
		3. GUI/CUIでのURL入力
		4. TVer以外のサイトからのダウンロード対応

	.PARAMETER guiMode
		オプションのパラメータ。GUIモードで実行するかどうかを指定します。
		- 指定なし: CUIモードで実行（コンソールでURL入力）
		- 'gui': GUIモードで実行（ダイアログでURL入力）
		- その他の値: CUIモードで実行

	.NOTES
		前提条件:
		- Windows、Linux、またはmacOS環境で実行する必要があります
		- PowerShell 7.0以上を推奨します
		- TVerRecの設定ファイルが正しく設定されている必要があります
		- GUIモードの場合、Windows Formsが利用可能である必要があります（Windowsのみ）
		- 十分なディスク容量が必要です
		- インターネット接続が必要です
		- TVerのアカウントが必要な場合があります

		処理の流れ:
		1. 初期設定
		1.1 環境チェック
		1.2 トークンの取得
		1.3 GUI/CUIモードの判定
		2. URL入力処理
		2.1 GUIモード: ダイアログでの入力
		2.2 CUIモード: コンソールでの入力
		3. ダウンロード処理
		3.1 URLの種類判定（TVer/その他）
		3.2 並列ダウンロードの制御
		3.3 個別番組のダウンロード
		4. 後処理
		4.1 ダウンロード完了の待機
		4.2 一時ファイルの削除

		対応URL:
		- TVer: https://tver.jp/で始まるURL
		- その他: youtube-dlでサポートされているサイトのURL

	.EXAMPLE
		# 通常モードで実行（CUI）
		.\download_single.ps1

		# GUIモードで実行
		.\download_single.ps1 gui

	.OUTPUTS
		System.Void
		このスクリプトは以下の出力を行います：
		- コンソールへの進捗状況の表示
		- GUIモードの場合、URL入力ダイアログの表示
		- エラー発生時のエラーメッセージ
		- 処理完了時のサマリー情報
		- ダウンロードした動画ファイル
#>

Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 関数定義
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Show-UrlInputDialog {
	try {
		# アセンブリの読み込み
		Add-Type -AssemblyName System.Windows.Forms | Out-Null
		Add-Type -AssemblyName System.Drawing | Out-Null

		# フォームの作成
		$inputForm = New-Object System.Windows.Forms.Form -Property @{
			Text            = $script:msg.SingleDownloadFormTitle
			Size            = New-Object System.Drawing.Size(520, 300)
			StartPosition   = 'CenterScreen'
			MaximizeBox     = $False
			MinimizeBox     = $False
			FormBorderStyle = 'Fixed3D'
			KeyPreview      = $True
			TopLevel        = $true
			ShowIcon        = $False
		}
		$inputForm.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { $inputForm.Close() } })
		$inputForm.Add_Shown({ $inputForm.Activate() })

		# ボタンの作成
		$okButton = New-Object System.Windows.Forms.Button -Property @{
			Location = New-Object System.Drawing.Size(415, 10)
			Size     = New-Object System.Drawing.Size(75, 20)
			Text     = $script:msg.SingleDownloadGUIOkButton
		}
		$okButton.Add_Click({ $script:videoPageList = @($inputTextBox.Text.Split("`r`n").Split()) ; $inputForm.Close() })
		$inputForm.Controls.Add($okButton)

		# テキストラベルの作成
		$inputTextLabel = New-Object System.Windows.Forms.Label -Property @{
			Location = New-Object System.Drawing.Size(10, 10)
			Size     = New-Object System.Drawing.Size(480, 20)
			Text     = $script:msg.SingleDownloadGUIMessage
		}
		$inputForm.Controls.Add($inputTextLabel)

		# テキストボックスの作成
		$inputTextBox = New-Object System.Windows.Forms.TextBox -Property @{
			Location   = New-Object System.Drawing.Size(10, 40)
			Size       = New-Object System.Drawing.Size(480, 200)
			Multiline  = $true
			ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
		}
		$inputForm.Controls.Add($inputTextBox)

		# ダイアログの表示
		$inputForm.ShowDialog() | Out-Null

		return $script:videoPageList
	} catch {
		Write-Error "URL入力ダイアログの表示中にエラーが発生しました: $($_.Exception.Message)"
		Write-Error "Stack trace: $($_.ScriptStackTrace)"
		throw
	}
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

# 実行モードの設定
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

# ジョブ管理の初期化
$script:jobList = @()
Register-EngineEvent PowerShell.Exiting -Action {
	foreach ($jobId in $script:jobList) {
		Stop-Job -Id $jobId -Force -ErrorAction SilentlyContinue
		Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
	}
} | Out-Null


#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	# 必須ファイルのチェックとトークンの取得
	Invoke-RequiredFileCheck
	Suspend-Process
	Get-Token

	# キーワードの設定
	$keyword = $script:msg.KeywordForSingleDownload

	# GUIモードの判定
	if (!$script:guiMode) { $script:guiMode = $false }

	# ジョブ管理の初期化
	$script:jobList = @()
	Register-EngineEvent PowerShell.Exiting -Action {
		foreach ($jobId in $script:jobList) {
			Stop-Job -Id $jobId -Force -ErrorAction SilentlyContinue
			Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
		}
	} | Out-Null

	#----------------------------------------------------------------------
	# 無限ループ
	while ($true) {
		# 初期化
		$videoLink = ''
		$script:videoPageList = @()

		# ディレクトリの存在確認
		if (!(Test-Path $script:downloadBaseDir -PathType Container)) { throw $script:msg.DownloadDirNotAccessible }

		# youtube-dlプロセスの制御
		Wait-YtdlProcess $script:parallelDownloadFileNum
		Suspend-Process

		# URL入力処理
		if (!$script:guiMode) {
			# CUIモードでの入力
			$script:videoPageList = @((Read-Host $script:msg.SingleDownloadCUIMessage).Trim().Split())
		} else {
			# GUIモードでの入力
			$script:videoPageList = Show-UrlInputDialog
		}

		# 入力の検証
		$script:videoPageList = $script:videoPageList.where({ $_ -ne '' })
		if (-not $script:videoPageList) { break }

		# ダウンロード処理
		foreach ($videoLink in $script:videoPageList) {
			# プロセス制御
			Wait-YtdlProcess $script:parallelDownloadFileNum
			Suspend-Process

			# URLの種類に応じた処理
			switch -Regex ($videoLink) {
				'^https://tver.jp/(/?.*)' {
					# TVer番組のダウンロード
					Write-Output ('')
					Write-Output ($script:msg.MediumBoldBorder)
					Write-Output ('{0}: {1}' -f $script:msg.SingleDownloadTVerURL, $videoLink)
					Invoke-VideoDownload -Keyword $keyword -episodeID $videoLink.Replace('https://tver.jp/episodes/', '') -Force $script:forceSingleDownload
					break
				}
				'^.*://' {
					# その他のサイトのダウンロード
					Write-Output ('')
					Write-Output ($script:msg.MediumBoldBorder)
					Write-Output ('{0}: {1}' -f $script:msg.SingleDownloadNonTVerURL, $videoLink)
					Invoke-NonTverYtdl $videoLink
					Start-Sleep -Seconds 1
					break
				}
				default {
					Write-Warning ('{0}: {1}' -f $script:msg.SingleDownloadNotURL, $videoLink)
				}
			}
		}
	}

	# ダウンロード完了待機
	Write-Output ('')
	Write-Output ($script:msg.WaitingDownloadCompletion)
	Wait-DownloadCompletion

	# リネーム失敗ファイルの削除
	Write-Output ('')
	Write-Output ($script:msg.DeleteFilesFailedToRename)
	Remove-UnRenamedTempFile

} catch {
	Write-Error "Error occurred: $($_.Exception.Message)"
	Write-Error "Stack trace: $($_.ScriptStackTrace)"
	throw
} finally {
	# 変数のクリーンアップ
	Remove-Variable -Name args, keyword, videoPageURL -ErrorAction SilentlyContinue
	Invoke-GarbageCollection

	# 完了メッセージ
	Write-Output ('')
	Write-Output ($script:msg.LongBoldBorder)
	Write-Output ($script:msg.SingleDownloadCompleted)
	Write-Output ($script:msg.LongBoldBorder)
}
