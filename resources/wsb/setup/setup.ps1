
#日本語化
Write-Output '日本語化します...'
Set-WinUserLanguageList -Force ja-JP      # 言語リストとプロパティを日本語に設定
Set-WinSystemLocale -SystemLocale ja-JP   # システムロケールを 日本 に変更
Set-WinUILanguageOverride -Language ja-JP # 表示言語と地域設定を 日本語 に変更
Set-WinHomeLocation 122                   # 国と地域を 日本 に変更
Write-Output 'ファイアウォールを無効化します...'
Set-NetFirewallProfile -Enabled False

#Download & Install WinGet
Write-Output 'WinGetをインストールします...'
Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile Microsoft.UI.Xaml.2.8.x64.appx
Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
Add-AppxPackage Microsoft.UI.Xaml.2.8.x64.appx
Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

Start-Sleep 5

#Install Packages
Write-Output '必要なソフトウェアをインストールします...'
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
winget install VideoLAN.VLC --accept-source-agreements --accept-package-agreements

Start-Sleep 5

Start-Process explorer 'C:\Users\WDAGUtilityAccount\Desktop\TVerRec'

# システムを再起動(日本語化のために再起動が必要)
Restart-Computer
