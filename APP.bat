@echo off
rem ========================================================
rem PrefetchView & ProcessHacker
rem ========================================================

setlocal

rem URLs to download
set "URL_PREFETCH=https://files1.majorgeeks.com/b684bf95952226064ded6f12b6fb14f197ea24dc/system/winprefetchview.zip"
set "URL_PROCESSHACKER=https://deac-fra.dl.sourceforge.net/project/systeminformer/systeminformer-3.2.25011-release-setup.exe?viasf=1"

rem Output filenames
set "OUT_PREFETCH=WinPrefetchView.zip"
set "OUT_PROCESSHACKER=ProcessHacker-Setup.exe"

echo.
echo Downloading PrefetchView...
powershell -Command "Try { Invoke-WebRequest -Uri '%URL_PREFETCH%' -OutFile '%OUT_PREFETCH%'; Write-Host '  -> PrefetchView downloaded as %OUT_PREFETCH%' } Catch { Write-Error '  ! PrefetchView Failed' }"

echo.
echo Downloading ProcessHacker...
powershell -Command "Try { Invoke-WebRequest -Uri '%URL_PROCESSHACKER%' -OutFile '%OUT_PROCESSHACKER%'; Write-Host '  -> ProcessHacker downloaded as %OUT_PROCESSHACKER%' } Catch { Write-Error '  !  ProcessHacker Failed' }"

echo.
echo Done irani
pause
