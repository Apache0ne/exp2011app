@echo off
setlocal
cd /d "%~dp0"

echo Exp2011App - iPhone installer
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Hello-App.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" echo Installer exited with code %EXITCODE%.
echo Press any key to close.
pause >nul
exit /b %EXITCODE%
