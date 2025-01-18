###################################################################################
#
#		個別ダウンロード処理スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
$script:guiMode = if ($args) { [String]$args[0] } else { '' }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理
Invoke-RequiredFileCheck
Suspend-Process
Get-Token
$keyword = $script:msg.KeywordForSingleDownload

# GUI起動を判定
if (!$script:guiMode) { $script:guiMode = $false }

#----------------------------------------------------------------------
# 無限ループ
while ($true) {
	# いろいろ初期化
	$videoLink = ''
	# 移動先ディレクトリの存在確認(稼働中に共有ディレクトリが切断された場合に対応)
	if (!(Test-Path $script:downloadBaseDir -PathType Container)) { Throw ($script:msg.DownloadDirNotAccessible) }
	# youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
	Wait-YtdlProcess $script:parallelDownloadFileNum
	Suspend-Process

	# 複数アドレス入力用配列
	$script:videoPageList = @()

	if (!$script:guiMode) {
		$script:videoPageList = @((Read-Host $script:msg.SingleDownloadCUIMessage).Trim().Split())
	} else {
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
	}

	# 配列の空白要素を削除
	$script:videoPageList = @($script:videoPageList) -ne ''
	if (-not $script:videoPageList) { break }

	# 複数入力されていたら全てダウンロード
	foreach ($videoLink in  $script:videoPageList) {
		# youtube-dlプロセスの確認と、youtube-dlのプロセス数が多い場合の待機
		Wait-YtdlProcess $script:parallelDownloadFileNum
		Suspend-Process

		switch -Regex ($videoLink) {
			'^https://tver.jp/(/?.*)' { # TVer番組ダウンロードのメイン処理
				Write-Output ('')
				Write-Output ($script:msg.MediumBoldBorder)
				Write-Output ('{0}: {1}' -f $script:msg.SingleDownloadTVerURL, $videoLink)
				Invoke-VideoDownload -Keyword ([ref]$keyword) -VideoLink ([ref]$videoLink) -Force $script:forceSingleDownload
				continue
			}
			'^.*://' { # TVer以外のサイトへの対応
				Write-Output ('')
				Write-Output ($script:msg.MediumBoldBorder)
				Write-Output ('{0}: {1}' -f $script:msg.SingleDownloadNonTVerURL, $videoLink)
				Invoke-NonTverYtdl $videoLink
				Start-Sleep -Seconds 1
				continue
			}
			default { Write-Warning ('{0}: {1}' -f $script:msg.SingleDownloadNotURL, $videoLink) ; continue }
		}
	}

}

Remove-Variable -Name args, keyword, videoPageURL -ErrorAction SilentlyContinue

Invoke-GarbageCollection

Write-Output ('')
Write-Output ($script:msg.LongBoldBorder)
Write-Output ($script:msg.SingleDownloadCompleted)
Write-Output ($script:msg.LongBoldBorder)
