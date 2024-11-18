@echo off
powershell Set-WinUserLanguageList -Force ja-JP
powershell Set-WinSystemLocale -SystemLocale ja-JP
powershell Set-WinUILanguageOverride -Language ja-JP
powershell Set-WinHomeLocation 122
powershell -Command "Add-Type -Assembly System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('日本語化を完了するには再起動が必要です。OKを押すと自動的にWindowsサンドボックスを再起動します。', 'TVerRec')"
powershell Restart-Computer
