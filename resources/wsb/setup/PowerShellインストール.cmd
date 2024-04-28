@echo off

powershell Write-Output 'まずはWinGetをインストールするために必要なソフトウェアをインストールします...'

powershell Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx
powershell Add-AppxPackage %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx
del /q %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx

powershell Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
powershell Add-AppxPackage %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
del /q %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx

powershell Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile %TEMP%\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
powershell Add-AppxPackage %TEMP%\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
del /q %TEMP%\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

powershell Write-Output '次にPowerShellをインストールします...'
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements

mshta vbscript:execute("MsgBox(""PowerShellのインストールが完了しました。""):close")

explorer.exe "C:\Users\WDAGUtilityAccount\Desktop\TVerRec\win"
