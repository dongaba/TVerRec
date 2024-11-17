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
if "%PROCESSOR_ARCHITECTURE%" EQU "AMD64" (
	powershell Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx
	powershell Add-AppxPackage %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx
	del /q %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx

	powershell Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
	powershell Add-AppxPackage %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
	del /q %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
)
if "%PROCESSOR_ARCHITECTURE%" EQU "IA64" (
	powershell Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx
	powershell Add-AppxPackage %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx
	del /q %TEMP%\Microsoft.VCLibs.x64.14.00.Desktop.appx

	powershell Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
	powershell Add-AppxPackage %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
	del /q %TEMP%\Microsoft.UI.Xaml.2.8.x64.appx
)
if "%PROCESSOR_ARCHITECTURE%" EQU "ARM64" (
	powershell Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.arm64.14.00.Desktop.appx -OutFile %TEMP%\Microsoft.VCLibs.arm64.14.00.Desktop.appx
	powershell Add-AppxPackage %TEMP%\Microsoft.VCLibs.arm64.14.00.Desktop.appx
	del /q %TEMP%\Microsoft.VCLibs.arm64.14.00.Desktop.appx

	powershell Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.arm64.appx -OutFile %TEMP%\Microsoft.UI.Xaml.2.8.arm64.appx
	powershell Add-AppxPackage %TEMP%\Microsoft.UI.Xaml.2.8.arm64.appx
	del /q %TEMP%\Microsoft.UI.Xaml.2.8.arm64.appx
)

echo.
echo WinGetをインストールします...
powershell Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile %TEMP%\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
powershell Add-AppxPackage %TEMP%\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
del /q %TEMP%\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle


echo.
echo 最後にPowerShellをインストールします...
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements

echo.
rem mshta vbscript:execute("MsgBox(""PowerShellのインストールが完了しました。""):close")
powershell -Command "Add-Type -Assembly System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('PowerShellのインストールが完了しました。', 'TVerRec')"

explorer.exe "C:\Users\WDAGUtilityAccount\Desktop\TVerRec\win"
