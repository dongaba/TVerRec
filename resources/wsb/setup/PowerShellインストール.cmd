@echo off

echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo WinGetをインストールするために必要なソフトウェアをインストールします...

echo 　WinGet PowerShell moduleをPSGalleryからインストールします...
powershell -Command "Install-PackageProvider -Name NuGet -Force | Out-Null"
powershell -Command "Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null"

echo 　Repair-WinGetPackageManagerコマンドレットを使用してWinGetを使用可能な状態にします...
powershell -Command "Repair-WinGetPackageManager"

echo 　WinGetのインストールが完了しました。

echo.
echo Notepad++をインストールします...
winget install -e --id Notepad++.Notepad++ --accept-source-agreements --accept-package-agreements --source winget

echo.
echo VLCをインストールします...
winget install -e --id VideoLAN.VLC --accept-source-agreements --accept-package-agreements --source winget

echo.
echo Gitをインストールします...
winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements --source winget

echo.
echo VS Codeをインストールします...
winget install -e --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements --source winget

echo.
echo PowerShellをインストールします...
winget install -e --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --source winget

echo.
powershell -Command "Add-Type -AssemblyName System.Windows.Forms | Out-Null ; [System.Windows.Forms.MessageBox]::Show('PowerShellのインストールが完了しました。', 'TVerRec')"

explorer.exe "C:\Users\WDAGUtilityAccount\Desktop\TVerRec\win"
